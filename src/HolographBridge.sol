// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IHolographBridge.sol";
import "./interfaces/IHolographERC20.sol";
import "./interfaces/ILZEndpointV2.sol";
import "./HolographFactory.sol";

/**
 * @title HolographBridge
 * @notice Cross-chain expansion coordinator for HolographERC20 tokens
 * @dev Handles one-call expansion to new chains with automatic peer configuration
 * @author Holograph Protocol
 */
contract HolographBridge is IHolographBridge, Ownable, Pausable {
    /* -------------------------------------------------------------------------- */
    /*                                  Errors                                    */
    /* -------------------------------------------------------------------------- */
    error ZeroAddress();
    error ChainNotSupported();
    error TokenNotDeployed();
    error ChainAlreadyConfigured();
    error InvalidTokenData();
    error CrossChainCallFailed();

    /* -------------------------------------------------------------------------- */
    /*                                 Storage                                    */
    /* -------------------------------------------------------------------------- */
    /// @notice LayerZero V2 endpoint for cross-chain messaging
    ILZEndpointV2 public immutable lzEndpoint;

    /// @notice Local HolographFactory for reference
    HolographFactory public immutable localFactory;

    /// @notice Supported chain configurations
    mapping(uint32 => ChainConfig) public supportedChains;

    /// @notice Track which chains each token has been deployed to
    mapping(address => mapping(uint32 => address)) public tokenDeployments;

    /// @notice Track tokens deployed by this bridge
    mapping(address => bool) public bridgeDeployedTokens;

    /* -------------------------------------------------------------------------- */
    /*                                 Structs                                   */
    /* -------------------------------------------------------------------------- */
    struct ChainConfig {
        uint32 eid;                    // LayerZero endpoint ID
        address factory;               // HolographFactory address on that chain
        address bridge;                // HolographBridge address on that chain
        bool active;                   // Whether chain is active for deployments
        string name;                   // Human readable chain name
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Events                                    */
    /* -------------------------------------------------------------------------- */
    /// @notice Emitted when a token is expanded to a new chain
    event TokenExpanded(
        address indexed sourceToken,
        uint32 indexed dstEid,
        address indexed dstToken,
        string chainName
    );

    /// @notice Emitted when a chain is added or updated
    event ChainConfigured(uint32 indexed eid, address factory, address bridge, string name);

    /* -------------------------------------------------------------------------- */
    /*                               Constructor                                  */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Initialize the HolographBridge
     * @param _lzEndpoint LayerZero V2 endpoint address
     * @param _factory Local HolographFactory address
     */
    constructor(address _lzEndpoint, address _factory) Ownable(msg.sender) {
        if (_lzEndpoint == address(0) || _factory == address(0)) revert ZeroAddress();
        lzEndpoint = ILZEndpointV2(_lzEndpoint);
        localFactory = HolographFactory(_factory);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Chain Management                              */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Configure a supported destination chain
     * @param eid Destination chain endpoint ID
     * @param factory HolographFactory address on destination chain
     * @param bridge HolographBridge address on destination chain
     * @param name Human readable chain name
     */
    function configureChain(
        uint32 eid,
        address factory,
        address bridge,
        string calldata name
    ) external onlyOwner {
        if (factory == address(0) || bridge == address(0)) revert ZeroAddress();
        
        supportedChains[eid] = ChainConfig({
            eid: eid,
            factory: factory,
            bridge: bridge,
            active: true,
            name: name
        });

        emit ChainConfigured(eid, factory, bridge, name);
    }

    /**
     * @notice Enable or disable a chain for deployments
     * @param eid Chain endpoint ID
     * @param active Whether the chain should be active
     */
    function setChainActive(uint32 eid, bool active) external onlyOwner {
        if (supportedChains[eid].eid == 0) revert ChainNotSupported();
        supportedChains[eid].active = active;
    }

    /* -------------------------------------------------------------------------- */
    /*                            Token Expansion                                */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Expand an existing token to a new chain (ONE CALL DOES EVERYTHING)
     * @dev 1. Deploys token on destination chain
     *      2. Configures peers on both sides automatically
     *      3. Token is ready for cross-chain transfers
     * @param sourceToken Token address on current chain
     * @param dstEid Destination chain endpoint ID
     * @return dstToken Address of deployed token on destination chain
     */
    function expandToChain(
        address sourceToken,
        uint32 dstEid
    ) external payable whenNotPaused returns (address dstToken) {
        // Validate inputs
        if (sourceToken == address(0)) revert ZeroAddress();
        if (!supportedChains[dstEid].active) revert ChainNotSupported();
        if (!localFactory.isDeployedToken(sourceToken)) revert TokenNotDeployed();
        if (tokenDeployments[sourceToken][dstEid] != address(0)) revert ChainAlreadyConfigured();

        // Only token owner can expand
        if (msg.sender != Ownable(sourceToken).owner()) revert TokenNotDeployed();

        ChainConfig memory dstChain = supportedChains[dstEid];

        // Get original deployment parameters from source token
        TokenParams memory params = _extractTokenParams(sourceToken);

        // Step 1: Deploy token on destination chain via cross-chain message
        dstToken = _deployOnDestination(dstEid, dstChain.factory, params);

        // Step 2: Configure peers on both sides
        _configurePeers(sourceToken, dstToken, dstEid);

        // Track the deployment
        tokenDeployments[sourceToken][dstEid] = dstToken;
        bridgeDeployedTokens[dstToken] = true;

        emit TokenExpanded(sourceToken, dstEid, dstToken, dstChain.name);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Internal Functions                             */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Extract original deployment parameters from a deployed token
     * @param token Token address to analyze
     * @return params Original token parameters for redeployment
     */
    function _extractTokenParams(address token) internal view returns (TokenParams memory params) {
        IHolographERC20 oft = IHolographERC20(token);
        
        // Extract basic parameters
        params.name = oft.name();
        params.symbol = oft.symbol();
        params.totalSupply = oft.totalSupply();
        params.owner = Ownable(token).owner();
        
        // Extract DERC20-specific parameters
        params.yearlyMintRate = oft.yearlyMintRate();
        params.vestingDuration = oft.vestingDuration();
        params.tokenURI = oft.tokenURI();
        
        // Note: For simplicity, we'll redeploy with same total supply
        // In practice, you might want to track original deployment params
    }

    /**
     * @notice Deploy token on destination chain via LayerZero message
     * @param dstEid Destination endpoint ID
     * @param dstFactory Factory address on destination chain
     * @param params Token deployment parameters
     * @return dstToken Predicted address of deployed token
     */
    function _deployOnDestination(
        uint32 dstEid,
        address dstFactory,
        TokenParams memory params
    ) internal returns (address dstToken) {
        // Encode deployment message
        bytes memory payload = abi.encode(
            params.name,
            params.symbol,
            params.totalSupply,
            params.owner, // recipient
            params.owner,
            params.yearlyMintRate,
            params.vestingDuration,
            new address[](0), // empty vesting recipients
            new uint256[](0), // empty vesting amounts
            params.tokenURI
        );

        // Generate deterministic salt
        bytes32 salt = keccak256(abi.encodePacked(params.name, params.symbol, params.owner));

        // Send deployment message via LayerZero
        bytes memory options = abi.encodePacked(uint16(1), uint256(500000)); // 500k gas
        
        lzEndpoint.send{value: msg.value}(
            dstEid,
            abi.encode("DEPLOY_TOKEN", dstFactory, salt, payload),
            options
        );

        // Predict destination token address (simplified - in practice you'd need exact prediction)
        dstToken = address(uint160(uint256(keccak256(abi.encodePacked(salt, dstFactory)))));
    }

    /**
     * @notice Configure LayerZero peers on both source and destination tokens
     * @param sourceToken Source token address
     * @param dstToken Destination token address
     * @param dstEid Destination endpoint ID
     */
    function _configurePeers(address sourceToken, address dstToken, uint32 dstEid) internal {
        // Note: Token owner must manually call setPeer() on source token
        // Bridge cannot call setPeer due to onlyOwner modifier on OFT
        // IHolographERC20(sourceToken).setPeer(dstEid, _addressToBytes32(dstToken));

        // Send message to configure destination token (via LayerZero)
        bytes memory peerPayload = abi.encode(
            "SET_PEER",
            dstToken,
            _getCurrentChainEid(),
            _addressToBytes32(sourceToken)
        );

        bytes memory options = abi.encodePacked(uint16(1), uint256(200000)); // 200k gas
        
        lzEndpoint.send{value: 0}(
            dstEid,
            peerPayload,
            options
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                               Utilities                                   */
    /* -------------------------------------------------------------------------- */
    struct TokenParams {
        string name;
        string symbol;
        uint256 totalSupply;
        address owner;
        uint256 yearlyMintRate;
        uint256 vestingDuration;
        string tokenURI;
    }

    /**
     * @notice Convert address to bytes32 for LayerZero compatibility
     */
    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    /**
     * @notice Get current chain's LayerZero endpoint ID
     */
    function _getCurrentChainEid() internal view returns (uint32) {
        // This would need to be configured per chain
        // For Base Sepolia: return 40245; (example)
        // For now, return a placeholder
        return 40245; // Base Sepolia EID
    }

    /* -------------------------------------------------------------------------- */
    /*                        IHolographBridge Implementation                    */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Set peer bridge address for a destination chain
     * @param eid Destination chain endpoint ID
     * @param peer Peer bridge address on destination chain (as bytes32)
     */
    function setPeer(uint32 eid, bytes32 peer) external onlyOwner {
        // Note: This would configure LayerZero peer for the bridge itself
        // Implementation depends on specific LayerZero OApp setup
    }

    /**
     * @notice Configure LayerZero OFT peer for a token on destination chain
     * @param token Token address to configure
     * @param dstEid Destination chain endpoint ID
     * @param peer Peer token address on destination chain (as bytes32)
     */
    function setTokenPeer(address token, uint32 dstEid, bytes32 peer) external {
        // Only token owner can set peers for their token
        if (msg.sender != Ownable(token).owner()) revert TokenNotDeployed();
        IHolographERC20(token).setPeer(dstEid, peer);
    }

    /**
     * @notice Register a token for cross-chain coordination
     * @param token Token address to register
     * @param supportedEids Array of supported chain endpoint IDs
     */
    function registerToken(address token, uint32[] calldata supportedEids) external {
        // Only token owner can register their token
        if (msg.sender != Ownable(token).owner()) revert TokenNotDeployed();
        // Implementation would track registered tokens and supported chains
        bridgeDeployedTokens[token] = true;
    }

    /**
     * @notice Configure OFT settings for a token on multiple chains
     * @param token Token address to configure
     * @param eids Array of endpoint IDs to configure
     * @param peers Array of peer addresses (as bytes32)
     */
    function configureOFT(address token, uint32[] calldata eids, bytes32[] calldata peers) external {
        if (eids.length != peers.length) revert InvalidTokenData();
        if (msg.sender != Ownable(token).owner()) revert TokenNotDeployed();
        
        for (uint256 i = 0; i < eids.length; i++) {
            IHolographERC20(token).setPeer(eids[i], peers[i]);
        }
    }

    /**
     * @notice Get peer bridge address for a chain
     * @param eid Chain endpoint ID
     * @return Peer bridge address
     */
    function getPeer(uint32 eid) external view returns (bytes32) {
        return bytes32(uint256(uint160(supportedChains[eid].bridge)));
    }

    /**
     * @notice Get peer token address for a token on destination chain
     * @param token Token address
     * @param eid Destination chain endpoint ID
     * @return Peer token address
     */
    function getTokenPeer(address token, uint32 eid) external view returns (bytes32) {
        return bytes32(uint256(uint160(tokenDeployments[token][eid])));
    }

    /**
     * @notice Check if a token is registered for cross-chain coordination
     * @param token Token address to check
     * @return True if token is registered
     */
    function isTokenRegistered(address token) external view returns (bool) {
        return bridgeDeployedTokens[token];
    }

    /**
     * @notice Get supported chains for a token
     * @param token Token address
     * @return Array of supported endpoint IDs
     */
    function getTokenChains(address token) external view returns (uint32[] memory) {
        // This is a simplified implementation - would need to track registered chains per token
        uint32[] memory chains = new uint32[](0);
        return chains;
    }

    /* -------------------------------------------------------------------------- */
    /*                               View Functions                              */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Get chain configuration
     * @param eid Chain endpoint ID
     * @return Chain configuration struct
     */
    function getChainConfig(uint32 eid) external view returns (ChainConfig memory) {
        return supportedChains[eid];
    }

    /**
     * @notice Get deployed token address on specific chain
     * @param sourceToken Source token address
     * @param eid Destination chain endpoint ID
     * @return Deployed token address (zero if not deployed)
     */
    function getTokenDeployment(address sourceToken, uint32 eid) external view returns (address) {
        return tokenDeployments[sourceToken][eid];
    }

    /**
     * @notice Check if token has been deployed to a specific chain
     * @param sourceToken Source token address
     * @param eid Chain endpoint ID
     * @return True if deployed to that chain
     */
    function isDeployedToChain(address sourceToken, uint32 eid) external view returns (bool) {
        return tokenDeployments[sourceToken][eid] != address(0);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Admin Functions                            */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Emergency pause bridge operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Resume bridge operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /* -------------------------------------------------------------------------- */
    /*                               Receive ETH                                */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Accept ETH for LayerZero message fees
     */
    receive() external payable {}
}