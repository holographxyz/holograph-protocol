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

// ──────────────────────────────────────────────────────────────────────────
//  Contract
// ──────────────────────────────────────────────────────────────────────────
contract FeeRouter is Ownable, AccessControl, ReentrancyGuard, Pausable, ILZReceiverV2 {
    using SafeERC20 for IERC20;

    /* -------------------------------------------------------------------------- */
    /*                            Constants & Immutables                         */
    /* -------------------------------------------------------------------------- */
    uint24 public constant POOL_FEE = 3000; // Uniswap V3 fee tier 0.3%
    uint16 public constant HOLO_FEE_BPS = 150; // 1.5% protocol fee
    uint64 public constant MIN_BRIDGE_VALUE = 0.01 ether; // Skip dust amounts
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    ILZEndpointV2 public immutable lzEndpoint;
    uint32 public immutable remoteEid; // peer chain EID (Ethereum⇄Base)
    IStakingRewards public immutable stakingPool; // StakingRewards contract (Ethereum)
    IERC20 public immutable HLG; // reward + burn token
    IWETH9 public immutable WETH; // canonical WETH on Ethereum
    ISwapRouter public immutable swapRouter; // Uniswap V3 router

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */
    // Mapping of nonce per outbound EID (mirrors factory design)
    mapping(uint32 => uint64) public nonce;

    // Trusted remote addresses for LayerZero security
    mapping(uint32 => bytes32) public trustedRemotes;

    // NEW: Treasury address for 98.5% of all fees (governance-configurable)
    address public treasury;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */
    error ZeroAddress();
    error ZeroAmount();
    error NotEndpoint();
    error OnlySelf();
    error UntrustedRemote();
    error NoRoute();
    error InsufficientOutput();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */
    event FeeReceived(address indexed payer, uint256 amount);
    event SlicePulled(address indexed airlock, address indexed token, uint256 holoAmt, uint256 treasuryAmt);
    event TokenBridged(address indexed token, uint256 amount, uint64 nonce);
    event TokenReceived(address indexed sender, address indexed token, uint256 amount);
    event Swapped(uint256 ethIn, uint256 hlgOut);
    event RewardsSent(uint256 hlgAmt);
    event Burned(uint256 hlgAmt);
    event TrustedRemoteSet(uint32 indexed eid, bytes32 remote);
    event TreasuryUpdated(address indexed newTreasury);

    /* -------------------------------------------------------------------------- */
    /*                                 Constructor                                */
    /* -------------------------------------------------------------------------- */
    /**
     * @param _endpoint      LayerZero endpoint on this chain
     * @param _remoteEid     Remote chain EID (Base ⇄ Ethereum peer)
     * @param _stakingPool   StakingRewards contract (only meaningful on Ethereum)
     * @param _hlg           HLG ERC-20 token address (Ethereum)
     * @param _weth          Canonical WETH address (Ethereum)
     * @param _swapRouter    Uniswap V3 router
     * @param _treasury      Initial treasury address for fee routing
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
        stakingPool = IStakingRewards(_stakingPool); // may be 0 on Base
        HLG = IERC20(_hlg); // may be 0 on Base
        WETH = IWETH9(_weth); // may be 0 on Base
        swapRouter = ISwapRouter(_swapRouter); // may be 0 on Base
        treasury = _treasury;

        // Grant admin role to owner
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Modifiers                                 */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Modifier to ensure the caller is the contract itself
     * @dev This is used to prevent the contract from being called by any other address
     */
    modifier onlySelf() {
        if (msg.sender != address(this)) revert OnlySelf();
        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                           Fee Intake (Single-Slice Model)                 */
    /* -------------------------------------------------------------------------- */

    /** @notice Called by factory (launch ETH) - implements single-slice model */
    function receiveFee() external payable whenNotPaused {
        _takeAndSlice(address(0), msg.value);
    }

    /** @notice Legacy alias for receiveFee - maintained for compatibility */
    function routeFeeETH() external payable whenNotPaused {
        _takeAndSlice(address(0), msg.value);
    }

    /** @notice Accept ETH directly */
    receive() external payable {
        _takeAndSlice(address(0), msg.value);
    }

    /** @notice ERC-20 intake (manual route or external integration) */
    function routeFeeToken(address token, uint256 amt) external whenNotPaused {
        if (amt == 0) revert ZeroAmount();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amt);
        _takeAndSlice(token, amt);
        emit TokenReceived(msg.sender, token, amt);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Doppler Integrator Pull (Keeper)                 */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Pull accumulated fees from Doppler Airlock and process through single-slice
     * @param airlock The Airlock contract address
     * @param token The token address (address(0) for ETH)
     * @param amt The amount to pull
     */
    function pullAndSlice(address airlock, address token, uint128 amt) external onlyRole(KEEPER_ROLE) nonReentrant {
        IAirlock(airlock).collectIntegratorFees(address(this), token, amt);
        _takeAndSlice(token, amt);
    }

    /**
     * @notice Receive fees from Airlock without automatic slicing (for testing)
     * @dev This method allows MockAirlock to transfer fees without triggering receive()
     */
    function receiveAirlockFees() external payable {
        // Just receive the ETH without slicing - pullAndSlice will handle the slicing
        // This prevents double-slicing in tests
    }

    /* -------------------------------------------------------------------------- */
    /*                              Internal Slicer                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Core single-slice logic: 1.5% protocol, 98.5% treasury
     */
    function _takeAndSlice(address token, uint256 amt) internal {
        if (amt == 0) revert ZeroAmount();

        uint256 holo = (amt * HOLO_FEE_BPS) / 10_000; // 1.5%
        uint256 rest = amt - holo;

        // Send 98.5% to treasury
        if (rest > 0) {
            if (token == address(0)) {
                payable(treasury).transfer(rest);
            } else {
                IERC20(token).safeTransfer(treasury, rest);
            }
        }

        // Buffer 1.5% for bridging to Ethereum
        if (holo > 0) {
            _bufferForBridge(token, holo);
        }

        emit SlicePulled(address(0), token, holo, rest);
    }

    /**
     * @notice Buffer fees for eventual bridging (no-op, just keep in contract)
     */
    function _bufferForBridge(address token, uint256 amt) internal {
        // Fees are held in contract until keeper calls bridge/bridgeToken
        // For ETH: held as contract balance
        // For ERC-20: held as token balance
    }

    /* -------------------------------------------------------------------------- */
    /*                     Keeper-Driven Bridging (Dust Protected)               */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Bridge accumulated ETH to Ethereum (dust protection applied)
     * @param minGas Minimum gas for lzReceive on destination
     * @param minHlg Minimum HLG expected from swap (slippage protection)
     */
    function bridge(uint256 minGas, uint256 minHlg) external onlyRole(KEEPER_ROLE) nonReentrant {
        uint256 bal = address(this).balance;
        if (bal < MIN_BRIDGE_VALUE) return; // Skip dust amounts

        bytes memory payload = abi.encode(address(0), minHlg);
        bytes memory options = _buildLzReceiveOption(minGas);
        uint64 n = ++nonce[remoteEid];

        lzEndpoint.send{value: bal}(remoteEid, payload, options);
        emit TokenBridged(address(0), bal, n);
    }

    /**
     * @notice Bridge accumulated ERC-20 tokens to Ethereum
     * @param token The token address to bridge
     * @param minGas Minimum gas for lzReceive on destination
     * @param minHlg Minimum HLG expected from swap (slippage protection)
     */
    function bridgeToken(address token, uint256 minGas, uint256 minHlg) external onlyRole(KEEPER_ROLE) nonReentrant {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal < MIN_BRIDGE_VALUE) return; // Skip dust amounts

        // Approve LayerZero endpoint to spend tokens
        IERC20(token).forceApprove(address(lzEndpoint), bal);

        bytes memory payload = abi.encode(token, minHlg);
        bytes memory options = _buildLzReceiveOption(minGas);
        uint64 n = ++nonce[remoteEid];

        lzEndpoint.send(remoteEid, payload, options);
        emit TokenBridged(token, bal, n);
    }

    /* -------------------------------------------------------------------------- */
    /*                      LayerZero Receive & Swapping (Ethereum)               */
    /* -------------------------------------------------------------------------- */

    function lzReceive(
        uint32 srcEid,
        bytes calldata payload,
        address sender,
        bytes calldata /*execParams*/
    ) external payable override {
        if (msg.sender != address(lzEndpoint)) revert NotEndpoint();

        // Validate trusted remote
        bytes32 trustedRemote = trustedRemotes[srcEid];
        if (trustedRemote == bytes32(0) || trustedRemote != _addressToBytes32(sender)) {
            revert UntrustedRemote();
        }

        (address token, uint256 minHlg) = abi.decode(payload, (address, uint256));

        // Execute swap & distribution with the bridged value
        _swapAndDistribute(token, minHlg);
    }

    /**
     * @notice Internal swap and distribution logic for Ethereum chain
     */
    function _swapAndDistribute(address token, uint256 minHlg) internal {
        uint256 amtIn;

        if (token == address(0)) {
            // ETH received via msg.value in lzReceive
            amtIn = address(this).balance;
            if (amtIn > 0) {
                WETH.deposit{value: amtIn}();
                token = address(WETH);
            }
        } else {
            // ERC-20 token received via LayerZero
            amtIn = IERC20(token).balanceOf(address(this));
        }

        if (amtIn == 0) return;

        // Swap to HLG
        uint256 hlgOut = _swapExact(token, amtIn, minHlg);

        // Burn 50%, stake 50%
        _burnAndStake(hlgOut);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Swap Helpers                                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Swap exact input amount to HLG with routing logic
     */
    function _swapExact(address tokenIn, uint256 amtIn, uint256 minOut) internal returns (uint256) {
        if (amtIn == 0) return 0;
        if (tokenIn == address(HLG)) return amtIn; // Already HLG

        // Direct pool: tokenIn → HLG
        if (_poolExists(tokenIn, address(HLG))) {
            return _swapSingle(tokenIn, address(HLG), amtIn, minOut);
        }

        // Multi-hop: tokenIn → WETH → HLG
        if (_poolExists(tokenIn, address(WETH)) && _poolExists(address(WETH), address(HLG))) {
            bytes memory path = abi.encodePacked(
                tokenIn,
                uint24(POOL_FEE),
                address(WETH),
                uint24(POOL_FEE),
                address(HLG)
            );
            return _swapPath(path, amtIn, minOut);
        }

        revert NoRoute();
    }

    /**
     * @notice Execute single-hop swap via Uniswap V3
     */
    function _swapSingle(address tokenIn, address tokenOut, uint256 amtIn, uint256 minOut) internal returns (uint256) {
        IERC20(tokenIn).forceApprove(address(swapRouter), amtIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: POOL_FEE,
            recipient: address(this),
            amountIn: amtIn,
            amountOutMinimum: minOut,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = swapRouter.exactInputSingle(params);
        if (amountOut < minOut) revert InsufficientOutput();
        return amountOut;
    }

    /**
     * @notice Execute multi-hop swap via Uniswap V3
     */
    function _swapPath(bytes memory path, uint256 amtIn, uint256 minOut) internal returns (uint256) {
        // Extract first token from path for approval
        address tokenIn;
        assembly {
            tokenIn := div(mload(add(path, 0x20)), 0x1000000000000000000000000)
        }

        IERC20(tokenIn).forceApprove(address(swapRouter), amtIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            amountIn: amtIn,
            amountOutMinimum: minOut
        });

        uint256 amountOut = swapRouter.exactInput(params);
        if (amountOut < minOut) revert InsufficientOutput();
        return amountOut;
    }

    /* -------------------------------------------------------------------------- */
    /*                                Burn & Stake                                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Split HLG 50/50: burn and stake
     */
    function _burnAndStake(uint256 hlgAmt) internal {
        if (hlgAmt == 0) return;

        uint256 stakeAmt = hlgAmt / 2;
        uint256 burnAmt = hlgAmt - stakeAmt; // Handle odd amounts

        // Burn by transferring to address(0)
        if (burnAmt > 0) {
            HLG.safeTransfer(address(0), burnAmt);
            emit Burned(burnAmt);
        }

        // Send rewards to staking pool
        if (stakeAmt > 0) {
            HLG.forceApprove(address(stakingPool), stakeAmt);
            stakingPool.addRewards(stakeAmt);
            emit RewardsSent(stakeAmt);
        }

        emit Swapped(0, hlgAmt); // Log the HLG acquired
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Utilities                                 */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Check if Uniswap V3 pool exists for token pair
     */
    function _poolExists(address tokenA, address tokenB) internal view returns (bool) {
        try swapRouter.factory().getPool(tokenA, tokenB, POOL_FEE) returns (address pool) {
            return pool != address(0);
        } catch {
            return false;
        }
    }

    /**
     * @notice Convert address to bytes32 for LayerZero
     */
    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    /**
     * @notice Build LayerZero receive options with gas limit
     */
    function _buildLzReceiveOption(uint256 gasLimit) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(1), gasLimit);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Admin Functions                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Set trusted remote address for a specific chain EID
     * @param eid The endpoint ID of the remote chain
     * @param remote The trusted remote address (as bytes32)
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
     */
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /**
     * @notice Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /* -------------------------------------------------------------------------- */
    /*                              Legacy Compatibility                          */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Legacy method maintained for compatibility
     * @dev This function is only callable by the contract itself for backwards compatibility
     * @param minHlg The minimum amount of HLG to receive from the swap
     */
    function swapAndDistribute(uint256 minHlg) external onlySelf nonReentrant {
        _swapAndDistribute(address(0), minHlg);
    }
}
