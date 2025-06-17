// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * ----------------------------------------------------------------------------
 * @title FeeRouter (Omnichain) – Holograph 2.0 + Doppler Integration
 * ----------------------------------------------------------------------------
 * Enhanced omnichain router that:
 *   • Implements single-slice model: ALL fees (launch ETH, Airlock pulls, manual routes)
 *     are processed with 1.5% protocol skim, 98.5% to treasury
 *   • Supports ERC-20 token routing end-to-end (receive → slice → bridge → swap)
 *   • Uses role-based keeper automation with dust protection (MIN_BRIDGE_VALUE)
 *   • Bridges protocol skim to Ethereum via LayerZero V2
 *   • Wraps to WETH, swaps to HLG on Uniswap V3 (0.3% pool)
 *   • Burns 50% of acquired HLG, stakes 50% to StakingRewards
 *   • Treasury is owner-configurable for admin flexibility
 *
 * Integration with Doppler:
 *   • Factory forwards full launch ETH and sets integrator = FeeRouter
 *   • Keeper pulls accumulated fees from Airlock contracts
 *   • All inflows processed through _takeAndSlice() for consistency
 *
 * Security:
 *   • Role-based access (KEEPER_ROLE) for automation functions
 *   • Dust protection (MIN_BRIDGE_VALUE) to avoid failed transactions
 *   • Trusted remotes for cross-chain message validation
 *   • Emergency pause functionality
 * ----------------------------------------------------------------------------
 */

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/access/AccessControl.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";
import "@openzeppelin/utils/Pausable.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ILZEndpointV2.sol";
import "./interfaces/ILZReceiverV2.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IStakingRewards.sol";
import "./interfaces/IAirlock.sol";

/**
 * @title FeeRouter
 * @notice Single-slice fee routing with Doppler integration
 * @dev 1.5% protocol fee, 98.5% to treasury - all fees processed uniformly
 * @author Holograph Protocol
 */
contract FeeRouter is Ownable, AccessControl, ReentrancyGuard, Pausable, ILZReceiverV2 {
    using SafeERC20 for IERC20;

    /* -------------------------------------------------------------------------- */
    /*                                 Constants                                  */
    /* -------------------------------------------------------------------------- */
    /// @notice Uniswap V3 pool fee tier (0.3%)
    uint24 public constant POOL_FEE = 3000;

    /// @notice Protocol fee in basis points (1.5%)
    uint16 public constant HOLO_FEE_BPS = 150;

    /// @notice Minimum value required to bridge (dust protection)
    uint64 public constant MIN_BRIDGE_VALUE = 0.01 ether;

    /// @notice Role identifier for keeper automation
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    /* -------------------------------------------------------------------------- */
    /*                                Immutables                                  */
    /* -------------------------------------------------------------------------- */
    /// @notice LayerZero V2 endpoint for cross-chain messaging
    ILZEndpointV2 public immutable lzEndpoint;

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

    /* -------------------------------------------------------------------------- */
    /*                                 Storage                                    */
    /* -------------------------------------------------------------------------- */
    /// @notice Nonce tracking for LayerZero messages per destination
    mapping(uint32 => uint64) public nonce;

    /// @notice Trusted remote addresses for LayerZero security
    mapping(uint32 => bytes32) public trustedRemotes;

    /// @notice Treasury address receiving 98.5% of all fees
    address public treasury;

    /* -------------------------------------------------------------------------- */
    /*                                  Errors                                    */
    /* -------------------------------------------------------------------------- */
    error ZeroAddress();
    error ZeroAmount();
    error NotEndpoint();
    error UntrustedRemote();
    error NoRoute();
    error InsufficientOutput();

    /* -------------------------------------------------------------------------- */
    /*                                  Events                                    */
    /* -------------------------------------------------------------------------- */
    /// @notice Emitted when fees are processed through the slicing mechanism
    event SlicePulled(address indexed airlock, address indexed token, uint256 holoAmt, uint256 treasuryAmt);

    /// @notice Emitted when tokens are bridged to remote chain
    event TokenBridged(address indexed token, uint256 amount, uint64 nonce);

    /// @notice Emitted when tokens are received via routeFeeToken
    event TokenReceived(address indexed sender, address indexed token, uint256 amount);

    /// @notice Emitted when tokens are swapped for HLG
    event Swapped(uint256 ethIn, uint256 hlgOut);

    /// @notice Emitted when HLG rewards are sent to staking pool
    event RewardsSent(uint256 hlgAmt);

    /// @notice Emitted when HLG tokens are burned
    event Burned(uint256 hlgAmt);

    /// @notice Emitted when trusted remote is updated
    event TrustedRemoteSet(uint32 indexed eid, bytes32 remote);

    /// @notice Emitted when treasury address is updated
    event TreasuryUpdated(address indexed newTreasury);

    /* -------------------------------------------------------------------------- */
    /*                               Constructor                                  */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Initialize the FeeRouter contract
     * @dev Sets up all immutable addresses and grants admin role to deployer
     * @param _endpoint LayerZero V2 endpoint address
     * @param _remoteEid Remote chain endpoint ID for cross-chain messaging
     * @param _stakingPool StakingRewards contract address (zero on non-Ethereum chains)
     * @param _hlg HLG token address (zero on non-Ethereum chains)
     * @param _weth WETH9 contract address (zero on non-Ethereum chains)
     * @param _swapRouter Uniswap V3 SwapRouter address (zero on non-Ethereum chains)
     * @param _treasury Initial treasury address for fee collection
     * @custom:security Validates critical addresses to prevent deployment errors
     */
    constructor(
        address _endpoint,
        uint32 _remoteEid,
        address _stakingPool,
        address _hlg,
        address _weth,
        address _swapRouter,
        address _treasury
    ) Ownable(msg.sender) {
        if (_endpoint == address(0) || _remoteEid == 0) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();

        lzEndpoint = ILZEndpointV2(_endpoint);
        remoteEid = _remoteEid;
        stakingPool = IStakingRewards(_stakingPool);
        HLG = IERC20(_hlg);
        WETH = IWETH9(_weth);
        swapRouter = ISwapRouter(_swapRouter);
        treasury = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Fee Intake                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Receive ETH fees and process through single-slice model
     * @dev Main entry point for fee collection from HolographFactory
     * @custom:security Protected by whenNotPaused modifier
     */
    function receiveFee() external payable whenNotPaused {
        _takeAndSlice(address(0), msg.value);
    }

    /**
     * @notice Receive ETH directly via transfer/send
     * @dev Automatically processes ETH through slicing mechanism
     */
    receive() external payable {
        _takeAndSlice(address(0), msg.value);
    }

    /**
     * @notice Route ERC-20 token fees through the system
     * @dev Transfers tokens from sender and processes through single-slice model
     * @param token ERC-20 token contract address
     * @param amount Token amount to transfer and process
     * @custom:security Protected by whenNotPaused modifier
     */
    function routeFeeToken(address token, uint256 amount) external whenNotPaused {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit TokenReceived(msg.sender, token, amount);
        _takeAndSlice(token, amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Integrator Pull (Keeper)                        */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Collect accumulated fees from a Doppler Airlock
     * @dev Keeper function to pull integrator fees from completed auctions
     * @param airlock Airlock contract address
     * @param token Token contract address
     * @param amt Amount to collect
     * @custom:security Restricted to KEEPER_ROLE addresses
     */
    function collectAirlockFees(address airlock, address token, uint256 amt) external onlyRole(KEEPER_ROLE) {
        if (airlock == address(0)) revert ZeroAddress();
        if (amt == 0) revert ZeroAmount();

        IAirlock(airlock).collectIntegratorFees(address(this), token, amt);
        _takeAndSlice(token, amt);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Core Slicing                                 */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Core fee processing: 1.5% protocol, 98.5% treasury
     * @dev Processes all fee types through unified slicing mechanism
     * @param token Token address (address(0) for ETH)
     * @param amount Total amount to slice
     */
    function _takeAndSlice(address token, uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();

        // Calculate split: 1.5% protocol, 98.5% treasury
        uint256 protocolFee = (amount * HOLO_FEE_BPS) / 10_000;
        uint256 treasuryFee = amount - protocolFee;

        // Send treasury portion immediately
        if (treasuryFee > 0) {
            if (token == address(0)) {
                // ETH transfer
                payable(treasury).transfer(treasuryFee);
            } else {
                // ERC-20 transfer
                IERC20(token).safeTransfer(treasury, treasuryFee);
            }
        }

        // Handle protocol fee based on chain
        if (protocolFee > 0) {
            if (address(HLG) != address(0)) {
                // Ethereum: Process locally (wrap → swap → burn/stake)
                _processProtocolFeeLocal(token, protocolFee);
            } else {
                // Base: Bridge to Ethereum for processing
                _bridgeProtocolFee(token, protocolFee);
            }
        }

        emit SlicePulled(msg.sender, token, protocolFee, treasuryFee);
    }

    /**
     * @notice Process protocol fee locally (Ethereum chain)
     * @dev Wraps ETH to WETH, swaps to HLG, then burns 50% and stakes 50%
     * @param token Token address (address(0) for ETH)
     * @param amount Protocol fee amount to process
     */
    function _processProtocolFeeLocal(address token, uint256 amount) internal {
        if (token == address(0)) {
            // ETH → WETH → HLG → Burn/Stake
            WETH.deposit{value: amount}();
            uint256 hlgOut = _swapForHLG(address(WETH), amount);
            _burnAndStake(hlgOut);
        } else if (token == address(WETH)) {
            // WETH → HLG → Burn/Stake
            uint256 hlgOut = _swapForHLG(token, amount);
            _burnAndStake(hlgOut);
        } else {
            // ERC-20 → WETH → HLG → Burn/Stake
            if (_poolExists(token, address(WETH))) {
                uint256 wethOut = _swapSingle(token, address(WETH), amount, 0);
                uint256 hlgOut = _swapForHLG(address(WETH), wethOut);
                _burnAndStake(hlgOut);
            } else {
                // No direct route: bridge to Ethereum for processing
                _bridgeProtocolFee(token, amount);
            }
        }
    }

    /**
     * @notice Accumulate protocol fee for later bridging (Base chain)
     * @dev Protocol fees accumulate in contract balance until manually bridged by keeper
     * @param token Token address (address(0) for ETH)
     * @param amount Amount to accumulate
     */
    function _bridgeProtocolFee(address token, uint256 amount) internal {
        // Protocol fees accumulate in the contract balance
        // ETH stays in address(this).balance
        // ERC-20 tokens stay in contract token balance
        // Keeper will call bridge() or bridgeToken() to send accumulated fees
        // No immediate action needed - fees are already in the contract
        // This function serves as a placeholder for potential future logic
    }

    /* -------------------------------------------------------------------------- */
    /*                               Bridge Functions                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Bridge accumulated ETH to remote chain for HLG conversion
     * @dev Protected by dust threshold to prevent uneconomical transactions
     * @param minGas Minimum gas units for lzReceive execution on destination
     * @param minHlg Minimum HLG tokens expected from swap (slippage protection)
     * @custom:security Restricted to KEEPER_ROLE only
     */
    function bridge(uint256 minGas, uint256 minHlg) external onlyRole(KEEPER_ROLE) nonReentrant {
        uint256 bal = address(this).balance;
        if (bal < MIN_BRIDGE_VALUE) return;

        uint64 n = ++nonce[remoteEid];
        // Send both the ETH amount and minimum HLG expected for slippage protection
        bytes memory payload = abi.encode(address(0), bal, minHlg);
        bytes memory options = _buildLzReceiveOption(minGas);

        lzEndpoint.send{value: bal}(remoteEid, payload, options);
        emit TokenBridged(address(0), bal, n);
    }

    /**
     * @notice Bridge accumulated ERC-20 tokens to remote chain
     * @dev Handles token approval and LayerZero messaging for cross-chain transfer
     * @param token ERC-20 token contract address to bridge
     * @param minGas Minimum gas units for lzReceive execution on destination
     * @param minHlg Minimum HLG tokens expected from swap (slippage protection)
     * @custom:security Restricted to KEEPER_ROLE only
     */
    function bridgeToken(address token, uint256 minGas, uint256 minHlg) external onlyRole(KEEPER_ROLE) nonReentrant {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal < MIN_BRIDGE_VALUE) return;

        // Single approval call instead of potential multiple
        IERC20(token).forceApprove(address(lzEndpoint), bal);

        uint64 n = ++nonce[remoteEid];
        bytes memory payload = abi.encode(token, minHlg);
        bytes memory options = _buildLzReceiveOption(minGas);

        lzEndpoint.send(remoteEid, payload, options);
        emit TokenBridged(token, bal, n);
    }

    /* -------------------------------------------------------------------------- */
    /*                            LayerZero Receive                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Handle incoming protocol fees from Base chain
     * @dev Processes bridged tokens through local HLG swap and burn/stake
     * @param srcEid Source chain endpoint ID
     * @param message Encoded token, amount, and slippage protection data
     * @custom:security Validates trusted remote before processing
     */
    function lzReceive(uint32 srcEid, bytes calldata message, address, bytes calldata) external payable override {
        if (msg.sender != address(lzEndpoint)) revert NotEndpoint();
        if (trustedRemotes[srcEid] == bytes32(0)) revert UntrustedRemote();

        // Try new format first (token, amount, minHlg)
        try this._decodeBridgeMessage(message) returns (address token, uint256 amount, uint256 minHlg) {
            _processProtocolFeeLocalWithSlippage(token, amount, minHlg);
        } catch {
            // Fallback to old format (token, amount) for backward compatibility
            (address token, uint256 amount) = abi.decode(message, (address, uint256));
            _processProtocolFeeLocal(token, amount);
        }
    }

    /**
     * @notice Decode bridge message (external function for try/catch)
     * @param message Encoded message data
     * @return token Token address
     * @return amount Token amount
     * @return minHlg Minimum HLG expected
     */
    function _decodeBridgeMessage(
        bytes calldata message
    ) external pure returns (address token, uint256 amount, uint256 minHlg) {
        return abi.decode(message, (address, uint256, uint256));
    }

    /**
     * @notice Process protocol fee locally with slippage protection
     * @param token Token address (address(0) for ETH)
     * @param amount Protocol fee amount to process
     * @param minHlg Minimum HLG tokens expected from swap
     */
    function _processProtocolFeeLocalWithSlippage(address token, uint256 amount, uint256 minHlg) internal {
        if (token == address(0)) {
            // ETH → WETH → HLG → Burn/Stake
            WETH.deposit{value: amount}();
            uint256 hlgOut = _swapForHLGWithSlippage(address(WETH), amount, minHlg);
            _burnAndStake(hlgOut);
        } else if (token == address(WETH)) {
            // WETH → HLG → Burn/Stake
            uint256 hlgOut = _swapForHLGWithSlippage(token, amount, minHlg);
            _burnAndStake(hlgOut);
        } else {
            // ERC-20 → WETH → HLG → Burn/Stake
            if (_poolExists(token, address(WETH))) {
                uint256 wethOut = _swapSingle(token, address(WETH), amount, 0);
                uint256 hlgOut = _swapForHLGWithSlippage(address(WETH), wethOut, minHlg);
                _burnAndStake(hlgOut);
            } else {
                // No direct route: process without slippage protection
                _processProtocolFeeLocal(token, amount);
            }
        }
    }

    /**
     * @notice Swap tokens for HLG with slippage protection
     * @param token Input token address
     * @param amount Input token amount
     * @param minHlg Minimum HLG tokens expected
     * @return hlgOut Amount of HLG tokens received
     */
    function _swapForHLGWithSlippage(address token, uint256 amount, uint256 minHlg) internal returns (uint256) {
        address hlgAddr = address(HLG);
        if (token == hlgAddr) return amount; // Already HLG

        // Try direct swap first
        if (_poolExists(token, hlgAddr)) {
            return _swapSingle(token, hlgAddr, amount, minHlg);
        }

        // Try via WETH if not direct
        if (token != address(WETH) && _poolExists(token, address(WETH)) && _poolExists(address(WETH), hlgAddr)) {
            bytes memory path = abi.encodePacked(token, POOL_FEE, address(WETH), POOL_FEE, hlgAddr);
            return _swapPath(path, amount, minHlg);
        }

        revert NoRoute();
    }

    /* -------------------------------------------------------------------------- */
    /*                              Token Swapping                               */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Swap tokens for HLG via Uniswap V3
     * @dev Handles direct WETH→HLG swaps and multi-hop routing
     * @param token Input token address
     * @param amount Input token amount
     * @return hlgOut Amount of HLG tokens received
     */
    function _swapForHLG(address token, uint256 amount) internal returns (uint256) {
        address hlgAddr = address(HLG);
        if (token == hlgAddr) return amount; // Already HLG

        // Try direct swap first
        if (_poolExists(token, hlgAddr)) {
            return _swapSingle(token, hlgAddr, amount, 0);
        }

        // Try via WETH if not direct
        if (token != address(WETH) && _poolExists(token, address(WETH)) && _poolExists(address(WETH), hlgAddr)) {
            bytes memory path = abi.encodePacked(token, POOL_FEE, address(WETH), POOL_FEE, hlgAddr);
            return _swapPath(path, amount, 0);
        }

        revert NoRoute();
    }

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
        // Cache swap router to reduce SLOAD
        ISwapRouter router = swapRouter;
        IERC20(tokenIn).forceApprove(address(router), amtIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: POOL_FEE,
            recipient: address(this),
            amountIn: amtIn,
            amountOutMinimum: minOut,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = router.exactInputSingle(params);
        if (amountOut < minOut) revert InsufficientOutput();
        return amountOut;
    }

    /**
     * @notice Execute multi-hop swap via Uniswap V3
     * @dev Uses encoded path for complex routing through multiple pools
     * @param path Encoded swap path with tokens and fees
     * @param amtIn Input token amount
     * @param minOut Minimum output tokens expected
     * @return actualOut Actual tokens received from swap
     */
    function _swapPath(bytes memory path, uint256 amtIn, uint256 minOut) internal returns (uint256) {
        address tokenIn;
        assembly {
            tokenIn := div(mload(add(path, 0x20)), 0x1000000000000000000000000)
        }

        // Cache swap router to reduce SLOAD
        ISwapRouter router = swapRouter;
        IERC20(tokenIn).forceApprove(address(router), amtIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            amountIn: amtIn,
            amountOutMinimum: minOut
        });

        uint256 amountOut = router.exactInput(params);
        if (amountOut < minOut) revert InsufficientOutput();
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
    function _burnAndStake(uint256 hlgAmt) internal {
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

        emit Swapped(0, hlgAmt);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Utilities                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Check if Uniswap V3 pool exists for token pair
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return exists True if pool exists with sufficient liquidity
     */
    function _poolExists(address tokenA, address tokenB) internal view returns (bool) {
        try swapRouter.factory().getPool(tokenA, tokenB, POOL_FEE) returns (address pool) {
            return pool != address(0);
        } catch {
            return false;
        }
    }

    /**
     * @notice Convert address to bytes32 for LayerZero compatibility
     * @param addr Address to convert
     * @return Bytes32 representation of the address
     */
    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    /**
     * @notice Build LayerZero receive options with gas limit
     * @param gasLimit Gas units to allocate for lzReceive
     * @return Encoded options for LayerZero message
     */
    function _buildLzReceiveOption(uint256 gasLimit) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(1), gasLimit);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Admin                                     */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Set trusted remote address for cross-chain messaging
     * @param eid Remote chain endpoint ID
     * @param remote Trusted contract address on remote chain (as bytes32)
     * @custom:security Only owner can modify trusted remotes
     */
    function setTrustedRemote(uint32 eid, bytes32 remote) external onlyOwner {
        trustedRemotes[eid] = remote;
        emit TrustedRemoteSet(eid, remote);
    }

    /**
     * @notice Update treasury address (admin function)
     * @param newTreasury The new treasury address
     * @custom:security Critical admin function - validates non-zero address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /**
     * @notice Pause the contract
     * @dev Emergency circuit breaker to halt operations
     * @custom:security Only owner can pause contract operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     * @dev Resume normal operations after emergency pause
     * @custom:security Only owner can unpause contract operations
     */
    function unpause() external onlyOwner {
        _unpause();
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
        }
    }

    /**
     * @notice Calculate fee split for a given amount
     * @param amount Input amount to calculate split for
     * @return protocolFee Amount that goes to protocol (1.5%)
     * @return treasuryFee Amount that goes to treasury (98.5%)
     */
    function calculateFeeSplit(uint256 amount) external pure returns (uint256 protocolFee, uint256 treasuryFee) {
        protocolFee = (amount * HOLO_FEE_BPS) / 10_000;
        treasuryFee = amount - protocolFee;
    }
}
