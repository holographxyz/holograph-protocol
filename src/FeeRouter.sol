// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/LayerZero-v2/packages/layerzero-v2/evm/protocol/contracts/interfaces/ILayerZeroEndpointV2.sol";
import "../lib/LayerZero-v2/packages/layerzero-v2/evm/protocol/contracts/interfaces/ILayerZeroReceiver.sol";
import "../lib/LayerZero-v2/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OptionsBuilder.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IStakingRewards.sol";
import "./interfaces/IAirlock.sol";

/**
 * @title FeeRouter
 * @notice Cross-chain fee router that accepts ETH or ERC-20, bridges via LayerZero V2, swaps WETH→HLG on a fixed 0.3% Uniswap V3 pool, then burns 50% and stakes 50%.
 * @author Holograph Protocol
 */
contract FeeRouter is Ownable, ReentrancyGuard, ILayerZeroReceiver {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                 Constants                                  */
    /* -------------------------------------------------------------------------- */

    /// @notice Current protocol fee in basis points (50% = 5000 bps, settable by owner)
    uint16 public holographFeeBps = 5000;

    /// @notice Minimum value required to bridge (dust protection)
    uint256 public constant MIN_BRIDGE_VALUE = 0.01 ether;

    /// @notice Swap deadline buffer (configurable by owner)
    uint256 public swapDeadlineBuffer = 15 minutes;

    /// @notice Maximum allowed gas limit for LayerZero bridging
    uint256 public constant MAX_BRIDGE_GAS_LIMIT = 2_000_000;

    /// @notice Default slippage protection in basis points (3%)
    uint256 public constant DEFAULT_SLIPPAGE_BPS = 300;

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
    error InternalCall();
    error InvalidDeadlineBuffer();
    error InvalidRemoteEid();
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

        swapRouter = ISwapRouter(_swapRouter);
        treasury = _treasury;
    }

    /* -------------------------------------------------------------------------- */
    /*                           Integrator Pull (Owner)                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Collect accumulated fees from a Doppler Airlock
     * @dev Owner-only function that pulls integrator fees from completed auctions
     * @param airlock Airlock contract address
     * @param token Token contract address
     * @param amt Amount to collect
     */
    function collectAirlockFees(address airlock, address token, uint256 amt) external onlyOwner nonReentrant {
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
            _splitFee(airlock, token, received);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                               Core Slicing                                 */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Unified fee splitter (configurable protocol fee / remainder to treasury)
     * @param airlock Airlock address for event emission
     * @param token Token address (address(0) for ETH)
     * @param amount Total amount to split
     */
    function _splitFee(address airlock, address token, uint256 amount) internal {
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

        emit SlicePulled(airlock, token, protocolFee, treasuryFee);
    }

    /**
     * @notice Convert ETH or ERC-20 to HLG and distribute (50% burn, 50% stake)
     * @param token Input token (address(0) for ETH, HLG for direct distribution, or any ERC-20)
     * @param amount Amount of the input token
     * @param minOut Minimum HLG expected from final swap
     */
    function _convertToHLG(address token, uint256 amount, uint256 minOut) internal {
        if (token == address(HLG)) {
            _distribute(amount);
            return;
        }

        // Handle three input modes: ETH, WETH, or arbitrary ERC-20
        if (token == address(0)) {
            // ETH: wrap to WETH
            WETH.deposit{value: amount}();
            token = address(WETH);
        } else if (token != address(WETH)) {
            // Arbitrary ERC-20: swap to WETH first
            try this._internalSwapTokenToWeth(token, amount, (amount * (10_000 - DEFAULT_SLIPPAGE_BPS)) / 10_000)
            returns (uint256 wethAmount) {
                amount = wethAmount;
            } catch {
                // If swap fails (no pool), accumulate as dust
                emit Accumulated(token, amount);
                return;
            }
        }
        // If token is already WETH, no conversion needed

        // Swap WETH to HLG using fixed 0.3% pool
        uint256 finalMinOut = minOut > 0 ? minOut : (amount * (10_000 - DEFAULT_SLIPPAGE_BPS)) / 10_000;
        amount = _swapWethToHlg(amount, finalMinOut);

        _distribute(amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Bridge Functions                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Bridge accumulated ETH to remote chain for HLG conversion
     * @param minGas Minimum gas units for lzReceive execution
     * @param minHlg Minimum HLG tokens expected from swap
     */
    function bridge(uint256 minGas, uint256 minHlg) external onlyOwner nonReentrant {
        if (minGas > MAX_BRIDGE_GAS_LIMIT) revert GasLimitExceeded(MAX_BRIDGE_GAS_LIMIT, minGas);
        _bridge(minGas, minHlg);
    }

    /**
     * @notice Bridge specific ERC-20 token to remote chain for HLG conversion
     * @param token ERC-20 token address to bridge
     * @param minGas Minimum gas units for lzReceive execution
     * @param minHlg Minimum HLG tokens expected from swap
     */
    function bridgeToken(address token, uint256 minGas, uint256 minHlg) external onlyOwner nonReentrant {
        if (minGas > MAX_BRIDGE_GAS_LIMIT) revert GasLimitExceeded(MAX_BRIDGE_GAS_LIMIT, minGas);
        if (token == address(0)) revert ZeroAddress(); // Use bridge() for ETH
        _bridgeToken(token, minGas, minHlg);
    }

    /**
     * @notice Internal implementation of bridge functionality
     * @param minGas Minimum gas units for lzReceive execution
     * @param minHlg Minimum HLG tokens expected from swap
     */
    function _bridge(uint256 minGas, uint256 minHlg) internal {
        _bridgeToken(address(0), minGas, minHlg);
    }

    /**
     * @notice Bridge specific token to remote chain for HLG conversion
     * @param token Token to bridge (address(0) for ETH)
     * @param minGas Minimum gas units for lzReceive execution
     * @param minHlg Minimum HLG tokens expected from swap
     */
    function _bridgeToken(address token, uint256 minGas, uint256 minHlg) internal {
        // Validate inputs before any processing (fail-fast)
        if (remoteEid == 0) revert InvalidRemoteEid();
        if (trustedRemotes[remoteEid] == bytes32(0)) revert TrustedRemoteNotSet();

        uint256 amount;
        if (token == address(0)) {
            // ETH bridging
            amount = address(this).balance;
            if (amount < MIN_BRIDGE_VALUE) revert InsufficientBalance();
        } else {
            // ERC-20 bridging
            amount = IERC20(token).balanceOf(address(this));
            if (amount == 0) revert InsufficientBalance();
        }

        // Prepare message payload
        bytes memory payload = abi.encode(token, amount, minHlg);
        bytes memory options = _buildLzReceiveOption(minGas);

        // Build LayerZero V2 messaging parameters
        MessagingParams memory msgParams = MessagingParams({
            dstEid: remoteEid,
            receiver: trustedRemotes[remoteEid],
            message: payload,
            options: options,
            payInLzToken: false
        });

        // Calculate LayerZero messaging fee (paid in ETH)
        MessagingFee memory fee = lzEndpoint.quote(msgParams, payable(msg.sender));
        uint256 lzFee = fee.nativeFee;

        uint256 bridgedAmount;
        if (token == address(0)) {
            // For ETH, deduct LZ fee from bridged amount
            if (amount <= lzFee) revert InsufficientForBridging();
            bridgedAmount = amount - lzFee;

            // Update payload with actual bridged amount
            payload = abi.encode(token, bridgedAmount, minHlg);
            msgParams.message = payload;
        } else {
            // For ERC-20, bridge full amount (LZ fee paid separately in ETH)
            if (address(this).balance < lzFee) revert InsufficientForBridging();
            bridgedAmount = amount;
        }

        // Send LayerZero message (LZ fee always paid in ETH)
        MessagingReceipt memory receipt = lzEndpoint.send{value: lzFee}(msgParams, payable(msg.sender));
        emit TokenBridged(token, bridgedAmount, receipt.nonce);
    }

    /**
     * @notice Process accumulated ETH dust; ERC-20 dust is bridged via bridgeToken
     * @param minGas Minimum gas units for lzReceive execution
     */
    function processDustBatch(uint256 minGas) external onlyOwner nonReentrant {
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
     * @notice Handle incoming protocol fees from remote chain
     * @param _origin Message origin information
     * @param _message Encoded token, amount, and slippage protection data
     */
    function lzReceive(
        Origin calldata _origin,
        bytes32, // _guid
        bytes calldata _message,
        address, // _executor
        bytes calldata // _extraData
    ) external payable override nonReentrant {
        _enforceEndpointAndRemote(_origin.srcEid);

        // Decode the message payload (3-field format only)
        (address token, uint256 amount, uint256 minHlg) = abi.decode(_message, (address, uint256, uint256));

        // Process both ETH and ERC-20 tokens
        uint256 localBalance;
        if (token == address(0)) {
            // ETH case - use contract's ETH balance
            localBalance = address(this).balance;
        } else {
            // ERC-20 case - check token balance
            localBalance = IERC20(token).balanceOf(address(this));
        }

        if (localBalance >= amount) {
            _convertToHLG(token, amount, minHlg);
        } else {
            // Insufficient balance - emit events and process available amount
            emit LowReserves(localBalance, amount);
            emit Accumulated(token, amount - localBalance);

            if (localBalance > 0) {
                _convertToHLG(token, localBalance, minHlg);
            }
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
     * @notice Swap any ERC-20 token to WETH using fixed 0.3% fee tier
     * @param tokenIn Input ERC-20 token address
     * @param amtIn Input token amount
     * @param minOut Minimum WETH expected
     * @return amountOut WETH received from swap
     */
    function _swapTokenToWeth(address tokenIn, uint256 amtIn, uint256 minOut) internal returns (uint256) {
        if (address(swapRouter) == address(0)) revert SwapRouterNotSet();

        IERC20(tokenIn).forceApprove(address(swapRouter), amtIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: address(WETH),
            fee: 3000, // Fixed 0.3% fee tier
            recipient: address(this),
            deadline: block.timestamp + swapDeadlineBuffer,
            amountIn: amtIn,
            amountOutMinimum: minOut,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = swapRouter.exactInputSingle(params);
        if (amountOut < minOut) revert InsufficientOutput(minOut, amountOut);

        emit Swapped(tokenIn, address(WETH), amtIn, amountOut);
        return amountOut;
    }

    /**
     * @notice External wrapper for _swapTokenToWeth (used with try/catch)
     * @param tokenIn Input ERC-20 token address
     * @param amtIn Input token amount
     * @param minOut Minimum WETH expected
     * @return amountOut WETH received from swap
     */
    function _internalSwapTokenToWeth(address tokenIn, uint256 amtIn, uint256 minOut) external returns (uint256) {
        if (msg.sender != address(this)) revert InternalCall();
        return _swapTokenToWeth(tokenIn, amtIn, minOut);
    }

    /**
     * @notice Swap WETH to HLG using fixed 0.3% fee tier
     * @param amtIn WETH amount to swap
     * @param minOut Minimum HLG expected
     * @return amountOut HLG received from swap
     */
    function _swapWethToHlg(uint256 amtIn, uint256 minOut) internal returns (uint256) {
        if (address(swapRouter) == address(0)) revert SwapRouterNotSet();

        IERC20(address(WETH)).forceApprove(address(swapRouter), amtIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(HLG),
            fee: 3000, // Fixed 0.3% fee tier for HLG/WETH pool
            recipient: address(this),
            deadline: block.timestamp + swapDeadlineBuffer,
            amountIn: amtIn,
            amountOutMinimum: minOut,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = swapRouter.exactInputSingle(params);
        if (amountOut < minOut) revert InsufficientOutput(minOut, amountOut);

        emit Swapped(address(WETH), address(HLG), amtIn, amountOut);
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
    function rescueDust(address token, uint256 amount) external onlyOwner nonReentrant {
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
    receive() external payable {
        // Only trusted Airlocks can send ETH (msg.data is always empty for receive())
        if (!trustedAirlocks[msg.sender]) revert UntrustedSender();
    }

    /// @notice Reject all function calls with data (security measure)
    fallback() external payable {
        revert();
    }
}
