// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

/**
 * @title HolographFactory
 * @notice Token launch factory with Doppler integration
 * @dev Entry point for creating and bridging omnichain tokens via Doppler Airlock
 * @author Holograph Protocol
 */
contract HolographFactory is Ownable, Pausable, ReentrancyGuard, ILZReceiverV2 {
    using SafeERC20 for IERC20;

    /* -------------------------------------------------------------------------- */
    /*                                  Errors                                    */
    /* -------------------------------------------------------------------------- */
    error ZeroAddress();
    error ZeroAmount();
    error NotEndpoint();

    /* -------------------------------------------------------------------------- */
    /*                                 Storage                                    */
    /* -------------------------------------------------------------------------- */
    /// @notice LayerZero V2 endpoint for cross-chain messaging
    ILZEndpointV2 public immutable lzEndpoint;

    /// @notice Doppler Airlock contract for token creation
    IAirlock public immutable dopplerAirlock;

    /// @notice FeeRouter contract for fee processing
    IFeeRouter public immutable feeRouter;

    /// @notice Nonce tracking for cross-chain message ordering
    mapping(uint32 => uint64) public nonce;

    /// @notice ETH fee required for token launches
    uint256 public launchFeeETH = 0.005 ether;

    /// @notice Legacy protocol fee percentage (deprecated - kept for reference)
    /// @dev No longer used in single-slice model, all fees routed to FeeRouter
    uint256 public protocolFeePercentage = 150;

    /* -------------------------------------------------------------------------- */
    /*                                  Events                                    */
    /* -------------------------------------------------------------------------- */
    /// @notice Emitted when a new token is successfully launched
    event TokenLaunched(address indexed asset, bytes32 salt);

    /// @notice Emitted when tokens are bridged to destination chain
    event CrossChainMint(uint32 indexed dstEid, address token, address to, uint256 amount, uint64 nonce);

    /// @notice Emitted when protocol fee percentage is updated
    event ProtocolFeeUpdated(uint256 newPercentage);

    /* -------------------------------------------------------------------------- */
    /*                               Constructor                                  */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Initialize the HolographFactory with required contract addresses
     * @dev Validates all addresses to prevent deployment with zero addresses
     * @param _endpoint LayerZero V2 endpoint for cross-chain messaging
     * @param _airlock Doppler Airlock contract for token creation
     * @param _feeRouter FeeRouter contract for fee processing and distribution
     * @custom:security All addresses must be non-zero for proper functionality
     */
    constructor(address _endpoint, address _airlock, address _feeRouter) Ownable(msg.sender) {
        if (_endpoint == address(0) || _airlock == address(0) || _feeRouter == address(0)) revert ZeroAddress();
        lzEndpoint = ILZEndpointV2(_endpoint);
        dopplerAirlock = IAirlock(_airlock);
        feeRouter = IFeeRouter(_feeRouter);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Token Launch                                 */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Launch a new omnichain token via Doppler Airlock
     * @dev Forwards all ETH to FeeRouter and sets FeeRouter as integrator for fee collection
     * @param params Doppler CreateParams containing token configuration
     * @return asset Address of the newly created token
     * @custom:security Protected by nonReentrant and whenNotPaused modifiers
     * @custom:gas Refunds excess ETH beyond launchFeeETH to sender
     */
    function createToken(
        CreateParams calldata params
    ) external payable nonReentrant whenNotPaused returns (address asset) {
        if (msg.value < launchFeeETH) revert ZeroAmount();

        // Forward all ETH to FeeRouter for single-slice processing
        if (msg.value > 0) {
            feeRouter.receiveFee{value: msg.value}();
        }

        // Refund excess
        if (msg.value > launchFeeETH) {
            payable(msg.sender).transfer(msg.value - launchFeeETH);
        }

        // Set FeeRouter as integrator for Doppler
        CreateParams memory modifiedParams = params;
        modifiedParams.integrator = address(feeRouter);

        (asset, , , , ) = dopplerAirlock.create(modifiedParams);
        emit TokenLaunched(asset, params.salt);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Cross-Chain Bridge                             */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Bridge tokens to destination chain and mint to recipient
     * @dev Sends LayerZero message with mint instruction to destination factory
     * @param dstEid Destination chain endpoint ID
     * @param token Token contract address to mint on destination
     * @param recipient Address to receive minted tokens on destination
     * @param amount Amount of tokens to mint on destination
     * @param options LayerZero execution options (gas limits, etc.)
     * @custom:security Protected by nonReentrant modifier
     * @custom:gas Caller pays for LayerZero messaging costs
     */
    function bridgeToken(
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

    /* -------------------------------------------------------------------------- */
    /*                            LayerZero Receive                              */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Handle incoming LayerZero messages for token minting
     * @dev Decodes message and mints tokens to specified recipient
     * @param msg_ Encoded message containing mint instruction and parameters
     * @custom:security Only accepts messages from LayerZero endpoint
     * @custom:gas Execution gas provided by LayerZero message sender
     */
    function lzReceive(uint32, bytes calldata msg_, address, bytes calldata) external payable override {
        if (msg.sender != address(lzEndpoint)) revert NotEndpoint();
        (bytes4 sel, address token, address to, uint256 amt) = abi.decode(msg_, (bytes4, address, address, uint256));
        if (sel == bytes4(keccak256("mintERC20(address,uint256,address)"))) {
            IMintableERC20(token).mint(to, amt);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Admin                                     */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Update the ETH fee required for token launches
     * @dev Governance function to adjust launch costs based on gas prices
     * @param weiAmount New launch fee in wei
     * @custom:security Only owner can modify launch fees
     */
    function setLaunchFee(uint256 weiAmount) external onlyOwner {
        launchFeeETH = weiAmount;
    }

    /**
     * @notice Update the protocol fee percentage (legacy function)
     * @dev Kept for compatibility but not used in single-slice model
     * @param newPercentage New fee percentage in basis points
     * @custom:security Only owner can modify fee percentages
     * @custom:deprecated This value is not used in current fee routing
     */
    function setProtocolFeePercentage(uint256 newPercentage) external onlyOwner {
        protocolFeePercentage = newPercentage;
        emit ProtocolFeeUpdated(newPercentage);
    }

    /**
     * @notice Emergency pause of factory operations
     * @dev Prevents new token launches during emergencies
     * @custom:security Only owner can pause factory operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Resume factory operations after emergency pause
     * @dev Re-enables token launches and bridging
     * @custom:security Only owner can unpause factory operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
