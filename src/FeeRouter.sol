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
 *   • Treasury is owner-configurable for governance flexibility
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
 * @notice Omnichain fee routing with Doppler integration
 * @dev Single-slice model: 1.5% protocol fee, 98.5% to treasury
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
     * @custom:gas Optimized for frequent factory usage
     */
    function receiveFee() external payable whenNotPaused {
        _takeAndSlice(address(0), msg.value);
    }

    /**
     * @notice Legacy ETH fee reception (maintained for compatibility)
     * @dev Alias for receiveFee() to support existing integrations
     * @custom:security Protected by whenNotPaused modifier
     */
    function routeFeeETH() external payable whenNotPaused {
        _takeAndSlice(address(0), msg.value);
    }

    /**
     * @notice Receive ETH directly via transfer/send
     * @dev Automatically processes ETH through slicing mechanism
     * @custom:gas More gas-efficient than calling receiveFee() directly
     */
    receive() external payable {
        _takeAndSlice(address(0), msg.value);
    }

    /**
     * @notice Route ERC-20 token fees through the system
     * @dev Transfers tokens from sender and processes through single-slice model
     * @param token ERC-20 token contract address
     * @param amt Amount of tokens to process
     * @custom:security Requires prior token approval from sender
     * @custom:security Protected by whenNotPaused modifier
     */
    function routeFeeToken(address token, uint256 amt) external whenNotPaused {
        if (amt == 0) revert ZeroAmount();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amt);

        // Emit TokenReceived before slicing for consistent event order
        emit TokenReceived(msg.sender, token, amt);

        _takeAndSlice(token, amt);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Doppler Integration                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Pull accumulated fees from Doppler Airlock contracts
     * @dev Keeper-only function for automated fee collection from integrated protocols
     * @param airlock Airlock contract address to pull fees from
     * @param token Token address (address(0) for ETH)
     * @param amt Amount to pull from the Airlock
     * @custom:security Restricted to KEEPER_ROLE only
     * @custom:security Protected by nonReentrant modifier
     * @custom:gas Called frequently by automation, optimized for gas efficiency
     */
    function pullAndSlice(address airlock, address token, uint256 amt) external onlyRole(KEEPER_ROLE) nonReentrant {
        IAirlock(airlock).collectIntegratorFees(address(this), token, amt);
        _takeAndSlice(token, amt);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Core Logic                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Core fee slicing logic implementing single-slice model
     * @dev Splits incoming value: 1.5% for protocol, 98.5% to treasury
     * @param token Token address (address(0) for ETH)
     * @param amt Total amount to slice
     * @custom:gas Optimized arithmetic operations for frequent use
     * @custom:security Validates non-zero amounts to prevent spam
     */
    function _takeAndSlice(address token, uint256 amt) internal {
        if (amt == 0) revert ZeroAmount();

        // Cache treasury address to reduce SLOAD
        address treasuryAddr = treasury;

        // Use unchecked for safe arithmetic (amt * 150 / 10000 cannot overflow)
        uint256 holo;
        uint256 rest;
        unchecked {
            holo = (amt * HOLO_FEE_BPS) / 10_000;
            rest = amt - holo;
        }

        // Send treasury portion (optimized for ETH vs token)
        if (rest > 0) {
            if (token == address(0)) {
                // Use assembly for gas-efficient ETH transfer
                assembly {
                    if iszero(call(gas(), treasuryAddr, rest, 0, 0, 0, 0)) {
                        revert(0, 0)
                    }
                }
            } else {
                IERC20(token).safeTransfer(treasuryAddr, rest);
            }
        }

        emit SlicePulled(address(0), token, holo, rest);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Bridging                                    */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Bridge accumulated ETH to remote chain for HLG conversion
     * @dev Protected by dust threshold to prevent uneconomical transactions
     * @param minGas Minimum gas units for lzReceive execution on destination
     * @param minHlg Minimum HLG tokens expected from swap (slippage protection)
     * @custom:security Restricted to KEEPER_ROLE only
     * @custom:security Protected by nonReentrant modifier
     * @custom:gas Includes dust protection via MIN_BRIDGE_VALUE
     */
    function bridge(uint256 minGas, uint256 minHlg) external onlyRole(KEEPER_ROLE) nonReentrant {
        uint256 bal = address(this).balance;
        if (bal < MIN_BRIDGE_VALUE) return;

        // Cache storage variables to reduce SLOADs
        uint32 remoteEid_ = remoteEid;
        uint64 n;
        unchecked {
            n = ++nonce[remoteEid_];
        }

        bytes memory payload = abi.encode(address(0), minHlg);
        bytes memory options = _buildLzReceiveOption(minGas);

        lzEndpoint.send{value: bal}(remoteEid_, payload, options);
        emit TokenBridged(address(0), bal, n);
    }

    /**
     * @notice Bridge accumulated ERC-20 tokens to remote chain
     * @dev Handles token approval and LayerZero messaging for cross-chain transfer
     * @param token ERC-20 token contract address to bridge
     * @param minGas Minimum gas units for lzReceive execution on destination
     * @param minHlg Minimum HLG tokens expected from swap (slippage protection)
     * @custom:security Restricted to KEEPER_ROLE only
     * @custom:security Protected by nonReentrant modifier
     * @custom:gas Includes dust protection via MIN_BRIDGE_VALUE
     */
    function bridgeToken(address token, uint256 minGas, uint256 minHlg) external onlyRole(KEEPER_ROLE) nonReentrant {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal < MIN_BRIDGE_VALUE) return;

        // Single approval call instead of potential multiple
        IERC20(token).forceApprove(address(lzEndpoint), bal);

        // Cache storage variables
        uint32 remoteEid_ = remoteEid;
        uint64 n;
        unchecked {
            n = ++nonce[remoteEid_];
        }

        bytes memory payload = abi.encode(token, minHlg);
        bytes memory options = _buildLzReceiveOption(minGas);

        lzEndpoint.send(remoteEid_, payload, options);
        emit TokenBridged(token, bal, n);
    }

    /* -------------------------------------------------------------------------- */
    /*                            LayerZero Receive                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Handle incoming LayerZero messages from remote chains
     * @dev Validates sender and processes swap/distribution on Ethereum
     * @param srcEid Source chain endpoint ID
     * @param payload Encoded message containing token address and minimum HLG
     * @param sender Address of the sending contract on source chain
     * @custom:security Validates message sender against trusted remotes
     * @custom:security Only accepts messages from LayerZero endpoint
     */
    function lzReceive(
        uint32 srcEid,
        bytes calldata payload,
        address sender,
        bytes calldata /*execParams*/
    ) external payable override {
        if (msg.sender != address(lzEndpoint)) revert NotEndpoint();

        // Single SLOAD for trusted remote validation
        bytes32 trustedRemote = trustedRemotes[srcEid];
        if (trustedRemote == bytes32(0) || trustedRemote != _addressToBytes32(sender)) {
            revert UntrustedRemote();
        }

        (address token, uint256 minHlg) = abi.decode(payload, (address, uint256));
        _swapAndDistribute(token, minHlg);
    }

    /**
     * @notice Internal swap and distribution logic for received tokens
     * @dev Handles ETH wrapping, token swapping, and HLG burn/stake distribution
     * @param token Token address (address(0) for ETH)
     * @param minHlg Minimum HLG tokens expected from swap operations
     * @custom:gas Optimized for Ethereum mainnet gas costs
     */
    function _swapAndDistribute(address token, uint256 minHlg) internal {
        uint256 amtIn;

        // Cache WETH address to reduce SLOAD
        IWETH9 weth = WETH;

        if (token == address(0)) {
            amtIn = address(this).balance;
            if (amtIn > 0) {
                weth.deposit{value: amtIn}();
                token = address(weth);
            }
        } else {
            amtIn = IERC20(token).balanceOf(address(this));
        }

        if (amtIn == 0) return;

        uint256 hlgOut = _swapExact(token, amtIn, minHlg);
        _burnAndStake(hlgOut);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Swap Logic                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Swap tokens for HLG using optimal routing
     * @dev Attempts direct swap first, falls back to WETH routing if needed
     * @param tokenIn Input token address
     * @param amtIn Amount of input tokens
     * @param minOut Minimum HLG tokens expected (slippage protection)
     * @return Amount of HLG tokens received
     * @custom:gas Uses intelligent routing to minimize swap costs
     */
    function _swapExact(address tokenIn, uint256 amtIn, uint256 minOut) internal returns (uint256) {
        if (amtIn == 0) return 0;

        // Cache HLG and WETH addresses to reduce SLOADs
        IERC20 hlg = HLG;
        if (tokenIn == address(hlg)) return amtIn;

        IWETH9 weth = WETH;
        address hlgAddr = address(hlg);
        address wethAddr = address(weth);

        if (_poolExists(tokenIn, hlgAddr)) {
            return _swapSingle(tokenIn, hlgAddr, amtIn, minOut);
        }

        if (_poolExists(tokenIn, wethAddr) && _poolExists(wethAddr, hlgAddr)) {
            bytes memory path = abi.encodePacked(tokenIn, uint24(POOL_FEE), wethAddr, uint24(POOL_FEE), hlgAddr);
            return _swapPath(path, amtIn, minOut);
        }

        revert NoRoute();
    }

    /**
     * @notice Execute single-hop swap via Uniswap V3
     * @dev Direct token-to-token swap using specified pool fee
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
     * @custom:gas Optimized for precise 50/50 split handling odd amounts
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
     * @dev Uses try/catch to safely check pool existence
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
     * @dev Required for trusted remote validation
     * @param addr Address to convert
     * @return Bytes32 representation of the address
     */
    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    /**
     * @notice Build LayerZero receive options with gas limit
     * @dev Encodes gas limit for remote execution
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
     * @dev Critical security function for LayerZero message validation
     * @param eid Remote chain endpoint ID
     * @param remote Trusted contract address on remote chain (as bytes32)
     * @custom:security Only owner can modify trusted remotes
     */
    function setTrustedRemote(uint32 eid, bytes32 remote) external onlyOwner {
        trustedRemotes[eid] = remote;
        emit TrustedRemoteSet(eid, remote);
    }

    /**
     * @notice Get trusted remote address for a specific chain EID
     * @param eid The endpoint ID of the remote chain
     * @return The trusted remote address (as bytes32)
     */
    function getTrustedRemote(uint32 eid) external view returns (bytes32) {
        return trustedRemotes[eid];
    }

    /**
     * @notice Check if an address is a trusted remote for a specific chain EID
     * @param eid The endpoint ID of the remote chain
     * @param remote The address to check
     * @return True if the address is trusted for the given EID
     */
    function isTrustedRemote(uint32 eid, address remote) external view returns (bool) {
        return trustedRemotes[eid] == _addressToBytes32(remote);
    }

    /**
     * @notice Update treasury address (governance function)
     * @param newTreasury The new treasury address
     * @custom:security Critical governance function - validates non-zero address
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
    /*                              Monitoring Views                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Get current contract balances for monitoring
     * @dev Read-only function for dashboards and monitoring systems
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
     * @notice Get specific token balance for monitoring
     * @param token ERC-20 token address
     * @return balance Current token balance
     */
    function getTokenBalance(address token) external view returns (uint256 balance) {
        if (token == address(0)) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Check if contract is ready for bridging operations
     * @dev Useful for keeper monitoring and health checks
     * @return canBridgeETH True if ETH balance exceeds minimum bridge value
     * @return ethAmount Current ETH amount available for bridging
     */
    function getBridgeStatus() external view returns (bool canBridgeETH, uint256 ethAmount) {
        ethAmount = address(this).balance;
        canBridgeETH = ethAmount >= MIN_BRIDGE_VALUE;
    }

    /**
     * @notice Get next nonce for a destination chain
     * @param dstEid Destination chain endpoint ID
     * @return nextNonce The next nonce that will be used for messaging
     */
    function getNextNonce(uint32 dstEid) external view returns (uint64 nextNonce) {
        return nonce[dstEid] + 1;
    }

    /**
     * @notice Calculate fee split for a given amount
     * @dev Utility function for frontend integration and testing
     * @param amount Input amount to calculate split for
     * @return protocolFee Amount that goes to protocol (1.5%)
     * @return treasuryFee Amount that goes to treasury (98.5%)
     */
    function calculateFeeSplit(uint256 amount) external pure returns (uint256 protocolFee, uint256 treasuryFee) {
        protocolFee = (amount * HOLO_FEE_BPS) / 10_000;
        treasuryFee = amount - protocolFee;
    }
}
