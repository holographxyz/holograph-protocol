// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * ----------------------------------------------------------------------------
 * @title FeeRouter (Omnichain) – Holograph 2.0
 * ----------------------------------------------------------------------------
 * Omnichain router that:
 *   • Collects ETH protocol fees on Base
 *   • Bridges them to Ethereum via LayerZero V2
 *   • Wraps to WETH, swaps WETH→HLG on Uniswap V3 (0.3% pool)
 *   • Burns 50% of acquired HLG
 *   • Forwards 50% of HLG to the StakingRewards contract
 *
 * The contract is deployed with the same address on all chains using
 * deterministic deployments so that trusted remote checks can rely on
 * msg.sender == address(this) on the peer chain.
 *
 * For security, only the LayerZero endpoint may call lzReceive. Bridging is
 * initiated via bridge() by an authorized keeper or governance.
 * ----------------------------------------------------------------------------
 */

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";
import "@openzeppelin/utils/Pausable.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ILZEndpointV2.sol";
import "./interfaces/ILZReceiverV2.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IStakingRewards.sol";

// ──────────────────────────────────────────────────────────────────────────
//  Contract
// ──────────────────────────────────────────────────────────────────────────
contract FeeRouter is Ownable, ReentrancyGuard, Pausable, ILZReceiverV2 {
    using SafeERC20 for IERC20;

    /* -------------------------------------------------------------------------- */
    /*                            Constants & Immutables                         */
    /* -------------------------------------------------------------------------- */
    uint24 public constant POOL_FEE = 3000; // Uniswap V3 fee tier 0.3 %

    ILZEndpointV2 public immutable lzEndpoint;
    uint32 public immutable remoteEid; // peer chain EID (Ethereum⇄Base)
    address public immutable stakingPool; // StakingRewards contract (Ethereum)
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

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */
    error ZeroAddress();
    error ZeroAmount();
    error NotEndpoint();
    error OnlySelf();
    error UntrustedRemote();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */
    event FeeReceived(address indexed payer, uint256 amount);
    event FeesBridged(uint256 ethAmt, uint64 nonce);
    event Swapped(uint256 ethIn, uint256 hlgOut);
    event RewardsSent(uint256 hlgAmt);
    event Burned(uint256 hlgAmt);
    event TrustedRemoteSet(uint32 indexed eid, bytes32 remote);

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
     */
    constructor(
        address _endpoint,
        uint32 _remoteEid,
        address _stakingPool,
        address _hlg,
        address _weth,
        address _swapRouter
    ) Ownable(msg.sender) {
        if (_endpoint == address(0) || _remoteEid == 0) revert ZeroAddress();
        lzEndpoint = ILZEndpointV2(_endpoint);
        remoteEid = _remoteEid;

        stakingPool = _stakingPool; // may be 0 on Base
        HLG = IERC20(_hlg); // may be 0 on Base
        WETH = IWETH9(_weth); // may be 0 on Base
        swapRouter = ISwapRouter(_swapRouter); // may be 0 on Base
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
    /*                          Fee Collection – Base chain                      */
    /* -------------------------------------------------------------------------- */
    /** @notice Receive ETH fees from HolographFactory. Alias for receiveFee. */
    function routeFeeETH() external payable whenNotPaused {
        _receiveFee();
    }

    /** @notice Preferred canonical entry-point for fee deposits. */
    function receiveFee() external payable whenNotPaused {
        _receiveFee();
    }

    function _receiveFee() internal {
        if (msg.value == 0) revert ZeroAmount();
        emit FeeReceived(msg.sender, msg.value);
    }

    /* -------------------------------------------------------------------------- */
    /*                        Bridge ETH → Ethereum (callable on Base)           */
    /* -------------------------------------------------------------------------- */
    /**
     * @param minGas   Minimum gas to attach for the receive on destination
     * @param minHlg   Minimum HLG expected from the WETH→HLG swap (slippage protection)
     */
    function bridge(uint256 minGas, uint256 minHlg) external nonReentrant whenNotPaused {
        uint256 bal = address(this).balance;
        if (bal == 0) revert ZeroAmount();

        uint64 n = ++nonce[remoteEid];

        // encode payload carrying the minHlg slippage parameter
        bytes memory payload = abi.encode(minHlg);

        // Proper LayerZero V2 options encoding for lzReceive gas
        bytes memory options = _buildLzReceiveOption(minGas);

        lzEndpoint.send{value: bal}(remoteEid, payload, options);

        emit FeesBridged(bal, n);
    }

    /* -------------------------------------------------------------------------- */
    /*                      LayerZero Receive – executes on Ethereum             */
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

        uint256 minHlg = abi.decode(payload, (uint256));

        // Execute swap & distribution with the bridged ETH (msg.value)
        // Ensure this is executed in the same tx by making an internal call.
        this.swapAndDistribute(minHlg);
    }

    /* -------------------------------------------------------------------------- */
    /*                       Swap & Distribute – Ethereum only                    */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Swap the bridged ETH for HLG and distribute the rewards
     * @dev This function is only callable by the contract itself
     * @param minHlg The minimum amount of HLG to receive from the swap
     */
    function swapAndDistribute(uint256 minHlg) external onlySelf nonReentrant {
        uint256 ethBal = address(this).balance;
        if (ethBal == 0) revert ZeroAmount();

        // Wrap to WETH
        WETH.deposit{value: ethBal}();

        // Swap WETH → HLG on Uniswap V3
        IWETH9(WETH).approve(address(swapRouter), ethBal);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(HLG),
            fee: POOL_FEE,
            recipient: address(this),
            amountIn: ethBal,
            amountOutMinimum: minHlg,
            sqrtPriceLimitX96: 0
        });

        uint256 hlgOut = swapRouter.exactInputSingle(params);
        emit Swapped(ethBal, hlgOut);

        // Split 50 / 50
        uint256 stakeAmt = hlgOut / 2;
        uint256 burnAmt = hlgOut - stakeAmt; // handles odd

        // Burn by transferring to address(0)
        HLG.safeTransfer(address(0), burnAmt);
        emit Burned(burnAmt);

        // Send rewards to staking pool
        HLG.safeIncreaseAllowance(stakingPool, stakeAmt);
        IStakingRewards(stakingPool).addRewards(stakeAmt);
        emit RewardsSent(stakeAmt);
    }

    /* -------------------------------------------------------------------------- */
    /*                   Fallback – allows contract to receive ETH               */
    /* -------------------------------------------------------------------------- */
    receive() external payable {
        // Accept ether – no action (handled on explicit calls)
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
     * @notice Check if an address is a trusted remote for a specific EID
     * @param eid The endpoint ID of the remote chain
     * @param remote The address to check
     * @return True if the address is trusted for the EID
     */
    function isTrustedRemote(uint32 eid, address remote) external view returns (bool) {
        return trustedRemotes[eid] == _addressToBytes32(remote);
    }

    /**
     * @notice Pause the contract (emergency stop)
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

    /**
     * @notice Helper to convert address to bytes32 for LayerZero compatibility
     */
    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    /**
     * @notice Helper to convert bytes32 to address
     */
    function _bytes32ToAddress(bytes32 b) internal pure returns (address) {
        return address(uint160(uint256(b)));
    }

    /**
     * @notice Build LayerZero V2 options for lzReceive execution
     * @param gasLimit Gas limit for lzReceive execution on destination
     */
    function _buildLzReceiveOption(uint256 gasLimit) internal pure returns (bytes memory) {
        // LayerZero V2 options format: TYPE_3 + OPTION_TYPE_LZRECEIVE + gas + value
        // TYPE_3 = 0x0003
        // OPTION_TYPE_LZRECEIVE = 0x01
        // gas = uint128 (16 bytes)
        // value = uint128 (16 bytes) - set to 0 for no msg.value
        return
            abi.encodePacked(
                uint16(3), // TYPE_3
                uint8(1), // OPTION_TYPE_LZRECEIVE
                uint8(16), // length of gas param (16 bytes for uint128)
                uint128(gasLimit), // gas limit as uint128
                uint128(0) // msg.value as uint128 (0 for no value)
            );
    }
}
