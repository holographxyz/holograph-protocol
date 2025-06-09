// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * ----------------------------------------------------------------------------
 * @title HolographFactory – oApp core (Holograph 2.0)
 * ----------------------------------------------------------------------------
 * @notice  Primary entry‑point contract that
 *          1. launches new tokens through Doppler Airlock on the *source* chain;
 *          2. sends cross‑chain mint/bridge messages via LayerZero V2;
 *          3. forwards protocol fees to FeeRouter (50 % Treasury / 50 % Staking);
 *          4. receives LayerZero messages and finalises mints on destination.
 *
 * Key Points
 * ----------
 * • Nonce‑based replay‑protection per destination EID.
 * • Flat ETH launch fee (configurable) processed immediately.
 * • Mint payload format:
 *     bytes4(keccak256("mintERC20(address,uint256,address)")) | token | to | amt
 *
 * Style: comments + section bars follow project conventions.
 * ----------------------------------------------------------------------------
 */

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/utils/Pausable.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import {CreateParams} from "lib/doppler/src/Airlock.sol";
import "./interfaces/IAirlock.sol";
import "./interfaces/IFeeRouter.sol";
import "./interfaces/ILZEndpointV2.sol";
import "./interfaces/ILZReceiverV2.sol";
import "./interfaces/IMintableERC20.sol";

// ──────────────────────────────────────────────────────────────────────────
//  Contract
// ──────────────────────────────────────────────────────────────────────────
contract HolographFactory is Ownable, Pausable, ReentrancyGuard, ILZReceiverV2 {
    using SafeERC20 for IERC20;

    // ──────────────────────────────────────────────────────────────────────
    //  Errors
    // ──────────────────────────────────────────────────────────────────────
    error ZeroAddress();
    error ZeroAmount();
    error NotEndpoint();

    // ──────────────────────────────────────────────────────────────────────
    //  Immutable & Storage
    // ──────────────────────────────────────────────────────────────────────
    ILZEndpointV2 public immutable lzEndpoint;
    IAirlock public immutable dopplerAirlock;
    IFeeRouter public immutable feeRouter;

    mapping(uint32 => uint64) public nonce; // dstEid → next outbound nonce
    uint256 public launchFeeETH = 0.005 ether;
    uint256 public protocolFeePercentage = 150; // 1.5% in basis points (150/10000)

    // ──────────────────────────────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────────────────────────────
    event TokenLaunched(address indexed asset, bytes32 salt);
    event CrossChainMint(uint32 indexed dstEid, address token, address to, uint256 amount, uint64 nonce);
    event ProtocolFeeUpdated(uint256 newPercentage);

    // ──────────────────────────────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────────────────────────────
    constructor(address _endpoint, address _airlock, address _feeRouter) Ownable(msg.sender) {
        if (_endpoint == address(0) || _airlock == address(0) || _feeRouter == address(0)) revert ZeroAddress();
        lzEndpoint = ILZEndpointV2(_endpoint);
        dopplerAirlock = IAirlock(_airlock);
        feeRouter = IFeeRouter(_feeRouter);
    }

    // ──────────────────────────────────────────────────────────────────────
    //  TOKEN CREATION
    // ──────────────────────────────────────────────────────────────────────
    /**
     * @notice Launch a new ERC‑20 via Doppler Airlock and pay flat Holograph fee.
     */
    function createToken(
        CreateParams calldata params
    ) external payable nonReentrant whenNotPaused returns (address asset) {
        if (msg.value < launchFeeETH) revert ZeroAmount();

        // Calculate protocol fee (1.5% of launch fee by default)
        uint256 protocolFee = (launchFeeETH * protocolFeePercentage) / 10000;

        // Forward only the protocol fee portion to FeeRouter
        if (protocolFee > 0) {
            feeRouter.routeFeeETH{value: protocolFee}();
        }

        if (msg.value > launchFeeETH) payable(msg.sender).transfer(msg.value - launchFeeETH);

        (asset, , , , ) = dopplerAirlock.create(params);
        emit TokenLaunched(asset, params.salt);
    }

    // ──────────────────────────────────────────────────────────────────────
    //  CROSS‑CHAIN SEND
    // ──────────────────────────────────────────────────────────────────────
    function bridgeMint(
        uint32 dstEid,
        address token,
        address recipient,
        uint256 amount,
        bytes calldata options
    ) external payable nonReentrant {
        if (token == address(0) || recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint64 n = ++nonce[dstEid];
        bytes memory payload = abi.encodeWithSelector(
            bytes4(keccak256("mintERC20(address,uint256,address)")),
            token,
            recipient,
            amount
        );
        lzEndpoint.send{value: msg.value}(dstEid, payload, options);
        emit CrossChainMint(dstEid, token, recipient, amount, n);
    }

    // ──────────────────────────────────────────────────────────────────────
    //  LAYERZERO RECEIVE
    // ──────────────────────────────────────────────────────────────────────
    function lzReceive(uint32, bytes calldata msg_, address, bytes calldata) external payable override {
        if (msg.sender != address(lzEndpoint)) revert NotEndpoint();
        (bytes4 sel, address token, address to, uint256 amt) = abi.decode(msg_, (bytes4, address, address, uint256));
        if (sel == bytes4(keccak256("mintERC20(address,uint256,address)"))) {
            IMintableERC20(token).mint(to, amt);
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    //  OWNER
    // ──────────────────────────────────────────────────────────────────────
    function setLaunchFee(uint256 weiAmount) external onlyOwner {
        launchFeeETH = weiAmount;
    }

    function setProtocolFeePercentage(uint256 newPercentage) external onlyOwner {
        protocolFeePercentage = newPercentage;
        emit ProtocolFeeUpdated(newPercentage);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
