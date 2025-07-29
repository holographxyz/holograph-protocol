// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * ----------------------------------------------------------------------------
 * @title FeeRouter (Omnichain) – Holograph 2.0 + Doppler Integration
 * ----------------------------------------------------------------------------
 * Enhanced omnichain router that:
 *   • Implements single-slice model: ALL fees (ETH primary, ERC-20 optional)
 *     are processed with configurable protocol fee, remainder to treasury
 *   • ETH-primary operation with optional ERC-20 token support
 *   • Uses role-based keeper automation with dust protection (MIN_BRIDGE_VALUE)
 *   • Bridges protocol skim to Ethereum via LayerZero V2 messaging (message-only pattern)
 *   • Wraps to WETH, swaps to HLG on Uniswap V3 (multi-tier: 0.05%, 0.3%, 1%)
 *   • Burns 50% of acquired HLG, stakes 50% to StakingRewards
 *   • Treasury is owner-configurable for admin flexibility
 *
 * Integration with Doppler:
 *   • Factory forwards full launch ETH and sets integrator = FeeRouter
 *   • Keeper pulls accumulated fees (ETH primary, ERC-20 optional) from Airlock contracts
 *   • All fee inflows processed through _splitFee() for consistency
 *
 * Security:
 *   • Role-based access (KEEPER_ROLE) for automation functions
 *   • Dust protection (MIN_BRIDGE_VALUE) to avoid failed transactions
 *   • Trusted remotes for cross-chain message validation
 *   • Emergency pause functionality
 * ----------------------------------------------------------------------------
 */
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/LayerZero-v2/packages/layerzero-v2/evm/protocol/contracts/interfaces/ILayerZeroEndpointV2.sol";
import "../lib/LayerZero-v2/packages/layerzero-v2/evm/protocol/contracts/interfaces/ILayerZeroReceiver.sol";
import "../lib/LayerZero-v2/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OptionsBuilder.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IStakingRewards.sol";
import "./interfaces/IAirlock.sol";
import "./interfaces/IUniswapV3Factory.sol";

/**
 * @title FeeRouter
 * @notice ETH-primary fee router with optional ERC-20 support
 * @dev Primary flow: ETH fees → bridge → swap → burn/stake HLG
 *      Optional: ERC-20 tokens via collectAirlockFees
 * @author Holograph Protocol
 */
contract FeeRouter is Ownable, AccessControl, ReentrancyGuard, Pausable, ILayerZeroReceiver {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                 Constants                                  */
    /* -------------------------------------------------------------------------- */
    /// @notice Uniswap V3 pool fee tier (0.3%)
    uint24 public constant POOL_FEE = 3000;

    /// @notice Current protocol fee in basis points (50% = 5000 bps, settable by owner)
    uint16 public holographFeeBps = 5000;

    /// @notice Minimum value required to bridge (dust protection)
    uint256 public constant MIN_BRIDGE_VALUE = 0.01 ether;

    /// @notice Swap deadline buffer (configurable by owner)
    uint256 public swapDeadlineBuffer = 15 minutes;

    /// @notice Role identifier for keeper automation
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    /// @notice Maximum allowed gas limit for LayerZero bridging
    uint256 public constant MAX_BRIDGE_GAS_LIMIT = 2_000_000;

    /// @notice Default slippage protection in basis points (3%)
    uint256 public constant DEFAULT_SLIPPAGE_BPS = 300;

    /// @notice Minimum liquidity required for pool validation (prevents dust pools)
    uint128 public constant MIN_POOL_LIQUIDITY = 1000;

    /* -------------------------------------------------------------------------- */
    /*                                Immutables                                  */
    /* -------------------------------------------------------------------------- */
    /// @notice LayerZero V2 endpoint for cross-chain messaging
    ILayerZeroEndpointV2 public immutable lzEndpoint;

    /// @notice Remote chain endpoint ID (Ethereum ⇄ Base)
    uint32 public immutable remoteEid;

    /// @notice Staking rewards contract for HLG distribution
    IStakingRewards public immutable stakingPool;

    /// @notice HLG token contract for burn and stake operations
    IERC20 public immutable HLG;

    /// @notice Wrapped ETH contract for swapping
    IWETH9 public immutable WETH;

    /// @notice Uniswap V3 swap router for token exchanges
    ISwapRouter public immutable swapRouter;

    /// @notice Cached Uniswap V3 factory (saves a call per pool probe)
    IUniswapV3Factory private immutable _factory;

    /* -------------------------------------------------------------------------- */
    /*                                 Storage                                    */
    /* -------------------------------------------------------------------------- */

    /// @notice Trusted remote addresses for LayerZero security
    mapping(uint32 => bytes32) public trustedRemotes;

    /// @notice Treasury address receiving remainder of fees after protocol take
    address public treasury;

    /// @notice Trusted Airlock addresses allowed to push ETH
    mapping(address => bool) public trustedAirlocks;

    /* -------------------------------------------------------------------------- */
    /*                                  Errors                                    */
    /* -------------------------------------------------------------------------- */
    error EthRescueFailed();
    error FeeExceedsMaximum();
    error GasLimitExceeded(uint256 maxAllowed, uint256 given);
    error InsufficientBalance();
    error InsufficientForBridging();
    error InsufficientOutput(uint256 expected, uint256 actual);
    error InvalidDeadlineBuffer();
    error InvalidRemoteEid();
    error InvalidSwapRouter();
    error NoRoute();
    error NotEndpoint();
    error SwapRouterNotSet();
    error TreasuryTransferFailed();
    error TrustedRemoteNotSet();
    error UntrustedRemote();
    error UntrustedSender();
    error ZeroAddress();
    error ZeroAmount();

    /* -------------------------------------------------------------------------- */
    /*                                  Events                                    */
    /* -------------------------------------------------------------------------- */
    /// @notice Emitted when fees are processed through the slicing mechanism
    event SlicePulled(address indexed airlock, address indexed token, uint256 holoAmt, uint256 treasuryAmt);

    /// @notice Emitted when tokens are bridged to remote chain
    event TokenBridged(address indexed token, uint256 amount, uint64 nonce);

    /// @notice Emitted when tokens are swapped for HLG
    event Swapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    /// @notice Emitted when HLG rewards are sent to staking pool
    event RewardsSent(uint256 hlgAmt);

    /// @notice Emitted when HLG tokens are burned
    event Burned(uint256 hlgAmt);

    /// @notice Emitted when trusted remote is updated
    event TrustedRemoteSet(uint32 indexed eid, bytes32 remote);

    /// @notice Emitted when treasury address is updated
    event TreasuryUpdated(address indexed newTreasury);

    /// @notice Emitted when an Airlock is added or removed from trusted list
    event TrustedAirlockSet(address indexed airlock, bool trusted);

    /// @notice Emitted when protocol fee is updated
    event HolographFeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);

    /// @notice Emitted when dust accumulates that cannot be processed
    event Accumulated(address indexed token, uint256 amount);

    /// @notice Emitted when an invalid message is received and ignored
    event InvalidMessageIgnored(address token, uint256 amount, string reason);

    /// @notice Emitted when dust is recovered by the owner
    event DustRecovered(address indexed token, uint256 amount);

    /// @notice Emitted when reserves are running low
    event LowReserves(uint256 currentBalance, uint256 requiredAmount);

    /// @notice Emitted when swap deadline buffer is updated
    event SwapDeadlineBufferUpdated(uint256 newBuffer);

    /* -------------------------------------------------------------------------- */
    /*                               Constructor                                  */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Initialize the FeeRouter contract
     * @dev Sets up all immutable addresses, grants admin role to deployer, and
     *      validates critical addresses to prevent deployment errors
     * @param _endpoint LayerZero V2 endpoint address
     * @param _remoteEid Remote chain endpoint ID for cross-chain messaging
     * @param _stakingPool StakingRewards contract address (zero on non-Ethereum chains)
     * @param _hlg HLG token address (zero on non-Ethereum chains)
     * @param _weth WETH9 contract address (zero on non-Ethereum chains)
     * @param _swapRouter Uniswap V3 SwapRouter address (zero on non-Ethereum chains)
     * @param _treasury Initial treasury address for fee collection
     * @param _owner Initial owner address for the contract
     */
    constructor(
        address _endpoint,
        uint32 _remoteEid,
        address _stakingPool,
        address _hlg,
        address _weth,
        address _swapRouter,
        address _treasury,
        address _owner
    ) Ownable(_owner) {
        if (_endpoint == address(0)) revert ZeroAddress();
        if (_remoteEid == 0) revert InvalidRemoteEid();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();

        lzEndpoint = ILayerZeroEndpointV2(_endpoint);
        remoteEid = _remoteEid;
        stakingPool = IStakingRewards(_stakingPool);
        HLG = IERC20(_hlg);
        WETH = IWETH9(_weth);

        // Cache swap router and factory only if provided (Ethereum deployments)
        swapRouter = ISwapRouter(_swapRouter);
        if (_swapRouter != address(0)) {
            try swapRouter.factory() returns (IUniswapV3Factory factory) {
                _factory = factory;
            } catch {
                revert InvalidSwapRouter();
            }
        } else {
            _factory = IUniswapV3Factory(address(0));
        }
        treasury = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Integrator Pull (Keeper)                        */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Collect accumulated fees from a Doppler Airlock
     * @dev Keeper-only function that pulls integrator fees from completed auctions
     * @param airlock Airlock contract address
     * @param token Token contract address
     * @param amt Amount to collect
     */
    function collectAirlockFees(address airlock, address token, uint256 amt)
        external
        onlyRole(KEEPER_ROLE)
        nonReentrant
        whenNotPaused
    {
        if (airlock == address(0)) revert ZeroAddress();
        if (amt == 0) revert ZeroAmount();

        uint256 balanceBefore;
        if (token == address(0)) {
            balanceBefore = address(this).balance;
        } else {
            balanceBefore = IERC20(token).balanceOf(address(this));
        }

        IAirlock(airlock).collectIntegratorFees(address(this), token, amt);

        // Process both ETH and ERC20 tokens through _splitFee
        uint256 balanceAfter;
        uint256 received;

        if (token == address(0)) {
            balanceAfter = address(this).balance;
            received = balanceAfter - balanceBefore;
        } else {
            balanceAfter = IERC20(token).balanceOf(address(this));
            received = balanceAfter - balanceBefore;
        }

        if (received > 0) {
            _splitFee(token, received);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                               Core Slicing                                 */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Unified fee splitter (configurable protocol fee / remainder to treasury)
     * @param token Token address (address(0) for ETH)
     * @param amount Total amount to split
     */
    function _splitFee(address token, uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();

        uint256 protocolFee = (amount * holographFeeBps) / 10_000;
        uint256 treasuryFee = amount - protocolFee;

        // Forward treasury share immediately
        if (treasuryFee > 0) {
            if (token == address(0)) {
                // Use call pattern to avoid 2300 gas limit for contract treasuries
                (bool success,) = payable(treasury).call{value: treasuryFee}("");
                if (!success) revert TreasuryTransferFailed();
            } else {
                IERC20(token).safeTransfer(treasury, treasuryFee);
            }
        }

        // Convert protocol share to HLG on Ethereum – accumulate on other chains
        if (protocolFee > 0 && address(HLG) != address(0)) {
            _convertToHLG(token, protocolFee, 0);
        }

        emit SlicePulled(msg.sender, token, protocolFee, treasuryFee);
    }

    /**
     * @notice Convert arbitrary token/ETH into HLG and distribute (burn + stake)
     * @param token  Input token (address(0) for native ETH)
     * @param amount Amount of the input token
     * @param minOut Minimum HLG expected from final swap (0 to ignore)
     */
    function _convertToHLG(address token, uint256 amount, uint256 minOut) internal {
        if (token == address(HLG)) {
            _distribute(amount);
            return;
        }

        // Step (a): wrap native ETH → WETH
        if (token == address(0)) {
            WETH.deposit{value: amount}();
            token = address(WETH);
        }

        // Step (b): swap non-WETH tokens into WETH if a pool exists, otherwise give up
        if (token != address(WETH)) {
            if (!_poolExists(token, address(WETH))) {
                emit Accumulated(token, amount); // Track unswappable dust
                return;
            }
            uint256 minWethOut = _calculateMinOut(amount, DEFAULT_SLIPPAGE_BPS);
            amount = _swapSingle(token, address(WETH), amount, minWethOut);
            token = address(WETH);
        }

        // Step (c): WETH → HLG (must have a pool or revert)
        if (!_poolExists(address(WETH), address(HLG))) revert NoRoute();
        
        // Apply slippage protection to second hop if minOut not specified
        uint256 finalMinOut = minOut;
        if (minOut == 0) {
            finalMinOut = _calculateMinOut(amount, DEFAULT_SLIPPAGE_BPS);
        }
        
        amount = _swapSingle(address(WETH), address(HLG), amount, finalMinOut);

        _distribute(amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Bridge Functions                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Bridge accumulated ETH to remote chain for HLG conversion
     * @dev Keeper-only; enforces dust threshold to avoid uneconomical transactions
     * @param minGas Minimum gas units for lzReceive execution on destination
     * @param minHlg Minimum HLG tokens expected from swap (slippage protection)
     */
    function bridge(uint256 minGas, uint256 minHlg) external onlyRole(KEEPER_ROLE) nonReentrant whenNotPaused {
        if (minGas > MAX_BRIDGE_GAS_LIMIT) revert GasLimitExceeded(MAX_BRIDGE_GAS_LIMIT, minGas);
        _bridge(minGas, minHlg);
    }

    /**
     * @notice Internal implementation of bridge functionality
     * @param minGas Minimum gas units for lzReceive execution
     * @param minHlg Minimum HLG tokens expected from swap
     */
    function _bridge(uint256 minGas, uint256 minHlg) internal {
        // Validate inputs before any processing (fail-fast)
        if (remoteEid == 0) revert InvalidRemoteEid();
        if (trustedRemotes[remoteEid] == bytes32(0)) revert TrustedRemoteNotSet();
        
        uint256 bal = address(this).balance;
        if (bal < MIN_BRIDGE_VALUE) revert InsufficientBalance();

        // Send both the ETH amount and minimum HLG expected for slippage protection
        bytes memory payload = abi.encode(address(0), bal, minHlg);
        bytes memory options = _buildLzReceiveOption(minGas);

        // Build LayerZero V2 messaging parameters
        MessagingParams memory msgParams = MessagingParams({
            dstEid: remoteEid,
            receiver: trustedRemotes[remoteEid],
            message: payload,
            options: options,
            payInLzToken: false
        });

        // Calculate LayerZero messaging fee (small amount for cross-chain message)
        MessagingFee memory fee = lzEndpoint.quote(msgParams, payable(msg.sender));
        uint256 lzFee = fee.nativeFee;
        
        // Ensure we have enough balance to cover both LZ fee and bridged amount
        if (bal <= lzFee) revert InsufficientForBridging();
        
        uint256 bridgedAmount = bal - lzFee;
        
        // Update payload with actual bridged amount (excluding LZ fee)
        payload = abi.encode(address(0), bridgedAmount, minHlg);
        msgParams.message = payload;

        // Send LayerZero message with only messaging fee (not bridged ETH)
        MessagingReceipt memory receipt = lzEndpoint.send{value: lzFee}(msgParams, payable(msg.sender));
        emit TokenBridged(address(0), bridgedAmount, receipt.nonce);
    }

    /**
     * @notice Process accumulated dust in batch when balance reaches threshold
     * @param minGas Minimum gas units for lzReceive execution on destination
     * @dev Keeper-only function for periodic dust processing
     */
    function processDustBatch(uint256 minGas) external onlyRole(KEEPER_ROLE) nonReentrant whenNotPaused {
        if (minGas > MAX_BRIDGE_GAS_LIMIT) revert GasLimitExceeded(MAX_BRIDGE_GAS_LIMIT, minGas);
        uint256 balance = address(this).balance;
        if (balance >= MIN_BRIDGE_VALUE) {
            // Process accumulated dust with no minimum HLG requirement
            _bridge(minGas, 0);
        }
    }


    /* -------------------------------------------------------------------------- */
    /*                            LayerZero Receive                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Handle incoming protocol fees from Base chain
     * @dev Processes bridged tokens through local HLG swap/burn/stake and verifies the caller is a trusted remote
     * @param _origin Message origin information
     * @param _guid Unique message identifier
     * @param _message Encoded token, amount, and slippage protection data
     * @param _executor Executor address
     * @param _extraData Additional data
     */
    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable override nonReentrant {
        _enforceEndpointAndRemote(_origin.srcEid);

        // Decode the message payload (token, amount, minHlg)
        (address token, uint256 amount, uint256 minHlg) = abi.decode(_message, (address, uint256, uint256));
        
        // Only process ETH (address(0)) - ERC-20 bridging removed
        if (token != address(0)) {
            emit InvalidMessageIgnored(token, amount, "Only ETH bridging supported");
            return;
        }
        
        // Use local ETH balance, not msg.value (which is just executor fee)
        uint256 localBalance = address(this).balance;
        if (localBalance >= amount) {
            _convertToHLG(token, amount, minHlg);
        } else {
            // Emit events for insufficient local reserves
            emit LowReserves(localBalance, amount);
            emit Accumulated(token, amount - localBalance);
        }
    }

    /// @notice Shared checks for LayerZero sender & trusted remote
    function _enforceEndpointAndRemote(uint32 srcEid) internal view {
        if (msg.sender != address(lzEndpoint)) revert NotEndpoint();
        if (trustedRemotes[srcEid] == bytes32(0)) revert UntrustedRemote();
    }

    /// @notice Check if initialization path is allowed (required by ILayerZeroReceiver)
    function allowInitializePath(Origin calldata _origin) external view returns (bool) {
        return trustedRemotes[_origin.srcEid] != bytes32(0);
    }

    /// @notice Get next nonce for sender (required by ILayerZeroReceiver)
    function nextNonce(uint32 _eid, bytes32 _sender) external view returns (uint64) {
        return lzEndpoint.inboundNonce(address(this), _eid, _sender) + 1;
    }


    /* -------------------------------------------------------------------------- */
    /*                              Token Swapping                               */
    /* -------------------------------------------------------------------------- */


    /**
     * @notice Execute single-hop swap via Uniswap V3
     * @dev Direct token-to-token swap through single pool
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amtIn Input token amount
     * @param minOut Minimum output tokens expected
     * @return actualOut Actual tokens received from swap
     */
    function _swapSingle(address tokenIn, address tokenOut, uint256 amtIn, uint256 minOut) internal returns (uint256) {
        // Validate router before any processing
        ISwapRouter router = swapRouter;
        if (address(router) == address(0)) revert SwapRouterNotSet();
        
        IERC20(tokenIn).forceApprove(address(router), amtIn);

        // Find the best available fee tier
        uint24 feeTier = _getBestFeeTier(tokenIn, tokenOut);

        // Calculate deadline
        uint256 deadline = block.timestamp + swapDeadlineBuffer;

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: feeTier,
            recipient: address(this),
            deadline: deadline,
            amountIn: amtIn,
            amountOutMinimum: minOut,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = router.exactInputSingle(params);
        if (amountOut < minOut) revert InsufficientOutput(minOut, amountOut);
        
        emit Swapped(tokenIn, tokenOut, amtIn, amountOut);
        return amountOut;
    }


    /* -------------------------------------------------------------------------- */
    /*                              Burn & Stake                                 */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Distribute HLG tokens: 50% burn, 50% stake
     * @dev Implements tokenomics by burning half and staking half for rewards
     * @param hlgAmt Total HLG amount to distribute
     */
    function _distribute(uint256 hlgAmt) internal {
        if (hlgAmt == 0) return;

        // Cache HLG and staking pool to reduce SLOADs
        IERC20 hlg = HLG;
        IStakingRewards stakingPoolAddr = stakingPool;

        uint256 stakeAmt;
        uint256 burnAmt;
        unchecked {
            stakeAmt = hlgAmt / 2;
            burnAmt = hlgAmt - stakeAmt;
        }

        if (burnAmt > 0) {
            hlg.safeTransfer(address(0), burnAmt);
            emit Burned(burnAmt);
        }

        if (stakeAmt > 0) {
            hlg.forceApprove(address(stakingPoolAddr), stakeAmt);
            stakingPoolAddr.addRewards(stakeAmt);
            emit RewardsSent(stakeAmt);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                Utilities                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Check if Uniswap V3 pool exists for token pair across multiple fee tiers with sufficient liquidity
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return exists True if pool exists with sufficient liquidity
     */
    function _poolExists(address tokenA, address tokenB) internal view returns (bool) {
        if (address(_factory) == address(0)) return false;
        
        // Check multiple fee tiers in order of preference
        uint24[3] memory feeTiers = [uint24(500), uint24(3000), uint24(10000)];
        for (uint256 i = 0; i < feeTiers.length; i++) {
            address pool = _factory.getPool(tokenA, tokenB, feeTiers[i]);
            if (pool != address(0)) {
                // Check if pool has sufficient liquidity
                try IUniswapV3Pool(pool).liquidity() returns (uint128 liquidity) {
                    if (liquidity >= MIN_POOL_LIQUIDITY) {
                        return true;
                    }
                } catch {
                    // Pool exists but liquidity call failed - skip this pool
                    continue;
                }
            }
        }
        return false;
    }

    /**
     * @notice Get the best available fee tier for a token pair with sufficient liquidity
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return feeTier The fee tier of the first available pool with sufficient liquidity
     */
    function _getBestFeeTier(address tokenA, address tokenB) internal view returns (uint24) {
        if (address(_factory) == address(0)) return 3000; // Default fallback
        
        // Check multiple fee tiers in order of preference (lowest fees first)
        uint24[3] memory feeTiers = [uint24(500), uint24(3000), uint24(10000)];
        for (uint256 i = 0; i < feeTiers.length; i++) {
            address pool = _factory.getPool(tokenA, tokenB, feeTiers[i]);
            if (pool != address(0)) {
                // Check if pool has sufficient liquidity
                try IUniswapV3Pool(pool).liquidity() returns (uint128 liquidity) {
                    if (liquidity >= MIN_POOL_LIQUIDITY) {
                        return feeTiers[i];
                    }
                } catch {
                    // Pool exists but liquidity call failed - skip this pool
                    continue;
                }
            }
        }
        return 3000; // Default fallback
    }

    /**
     * @notice Calculate minimum output amount with slippage protection
     * @param amountIn Input amount
     * @param slippageBps Slippage in basis points
     * @return minOut Minimum output amount after slippage
     */
    function _calculateMinOut(uint256 amountIn, uint256 slippageBps) internal pure returns (uint256) {
        return (amountIn * (10_000 - slippageBps)) / 10_000;
    }

    /**
     * @notice Build LayerZero receive options with gas limit
     * @param gasLimit Gas units to allocate for lzReceive
     * @return Encoded options for LayerZero message
     */
    function _buildLzReceiveOption(uint256 gasLimit) internal pure returns (bytes memory) {
        return OptionsBuilder.newOptions().addExecutorLzReceiveOption(uint128(gasLimit), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Admin                                     */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Set trusted remote address for cross-chain messaging
     * @param eid Remote chain endpoint ID
     * @param remote Trusted contract address on remote chain (as bytes32)
     * @dev Only callable by the contract owner
     */
    function setTrustedRemote(uint32 eid, bytes32 remote) external onlyOwner {
        trustedRemotes[eid] = remote;
        emit TrustedRemoteSet(eid, remote);
    }

    /**
     * @notice Update treasury address (admin function)
     * @param newTreasury The new treasury address
     * @dev Validates non-zero address; only callable by owner
     */
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /**
     * @notice Pause the contract
     * @dev Emergency circuit breaker to halt operations; only callable by owner
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     * @dev Resume normal operations after emergency pause; only callable by owner
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Whitelist or remove a Doppler Airlock that is allowed to push ETH
     * @param airlock Airlock contract address
     * @param trusted Boolean indicating whether the Airlock is trusted
     */
    function setTrustedAirlock(address airlock, bool trusted) external onlyOwner {
        if (airlock == address(0)) revert ZeroAddress();
        trustedAirlocks[airlock] = trusted;
        emit TrustedAirlockSet(airlock, trusted);
    }

    /**
     * @notice Update protocol fee (only owner)
     * @param newFeeBps New protocol fee in basis points (0-10000)
     */
    function setHolographFee(uint16 newFeeBps) external onlyOwner {
        if (newFeeBps > 10_000) revert FeeExceedsMaximum();
        uint16 oldFeeBps = holographFeeBps;
        holographFeeBps = newFeeBps;
        emit HolographFeeUpdated(oldFeeBps, newFeeBps);
    }

    /**
     * @notice Recover accumulated dust that cannot be processed
     * @param token Token address (address(0) for ETH)
     * @param amount Amount to recover
     * @dev Only callable by owner for emergency recovery
     */
    function rescueDust(address token, uint256 amount) external onlyOwner nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        
        if (token == address(0)) {
            // Recover ETH using call pattern to avoid 2300 gas limit
            (bool success,) = payable(owner()).call{value: amount}("");
            if (!success) revert EthRescueFailed();
        } else {
            // Recover ERC20 tokens
            IERC20(token).safeTransfer(owner(), amount);
        }
        
        emit DustRecovered(token, amount);
    }

    /**
     * @notice Update swap deadline buffer (only owner)
     * @param _buffer New deadline buffer in seconds
     * @dev Must be between 1 minute and 1 hour for safety
     */
    function setSwapDeadlineBuffer(uint256 _buffer) external onlyOwner {
        if (_buffer < 1 minutes || _buffer > 1 hours) revert InvalidDeadlineBuffer();
        swapDeadlineBuffer = _buffer;
        emit SwapDeadlineBufferUpdated(_buffer);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Views                                    */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Get current contract balances for monitoring
     * @return ethBalance Current ETH balance
     * @return hlgBalance Current HLG token balance (Ethereum only)
     */
    function getBalances() external view returns (uint256 ethBalance, uint256 hlgBalance) {
        ethBalance = address(this).balance;
        if (address(HLG) != address(0)) {
            hlgBalance = HLG.balanceOf(address(this));
        } else {
            hlgBalance = 0;
        }
    }

    /**
     * @notice Calculate fee split for a given amount
     * @param amount Input amount to calculate split for
     * @return protocolFee Amount that goes to protocol (configurable fee)
     * @return treasuryFee Amount that goes to treasury (remainder)
     */
    function calculateFeeSplit(uint256 amount) external view returns (uint256 protocolFee, uint256 treasuryFee) {
        protocolFee = (amount * holographFeeBps) / 10_000;
        treasuryFee = amount - protocolFee;
    }

    /**
     * @notice Quote LayerZero messaging fee for bridging
     * @param minGas Minimum gas units for lzReceive execution
     * @return nativeFee ETH amount needed for LayerZero messaging
     */
    function quoteBridgeFee(uint256 minGas) external view returns (uint256 nativeFee) {
        bytes memory payload = abi.encode(address(0), 0, 0); // Dummy payload for quote
        bytes memory options = _buildLzReceiveOption(minGas);
        
        MessagingParams memory msgParams = MessagingParams({
            dstEid: remoteEid,
            receiver: trustedRemotes[remoteEid],
            message: payload,
            options: options,
            payInLzToken: false
        });
        
        MessagingFee memory fee = lzEndpoint.quote(msgParams, payable(msg.sender));
        return fee.nativeFee;
    }

    /**
     * @notice Get current ETH reserve balance available for processing
     * @return reserveBalance Available ETH balance for conversion to HLG
     */
    function getReserveBalance() external view returns (uint256 reserveBalance) {
        return address(this).balance;
    }

    /* -------------------------------------------------------------------------- */
    /*                               ETH Receive                                 */
    /* -------------------------------------------------------------------------- */

    /// @notice Accept ETH only from trusted Airlock contracts
    receive() external payable nonReentrant {
        // Only trusted Airlocks can send ETH (msg.data is always empty for receive())
        if (!trustedAirlocks[msg.sender]) revert UntrustedSender();
    }

    /// @notice Reject all function calls with data (security measure)
    fallback() external payable {
        revert();
    }
}
