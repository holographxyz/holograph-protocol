// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title DeploymentConfig
 * @notice Consolidated configuration for Holograph protocol deployments
 * @dev Combines chain constants, LayerZero configuration, and deployment settings
 */
library DeploymentConfig {
    /* -------------------------------------------------------------------------- */
    /*                              Chain Identifiers                             */
    /* -------------------------------------------------------------------------- */

    // Mainnet chain IDs
    uint256 internal constant ETHEREUM_MAINNET = 1;
    uint256 internal constant BASE_MAINNET = 8453;
    uint256 internal constant UNICHAIN_MAINNET = 1301;

    // Testnet chain IDs
    uint256 internal constant ETHEREUM_SEPOLIA = 11155111;
    uint256 internal constant BASE_SEPOLIA = 84532;

    /* -------------------------------------------------------------------------- */
    /*                          LayerZero Configuration                           */
    /* -------------------------------------------------------------------------- */

    // LayerZero V2 Endpoint IDs
    uint32 internal constant ETHEREUM_MAINNET_EID = 30101;
    uint32 internal constant ETHEREUM_SEPOLIA_EID = 40161;
    uint32 internal constant BASE_MAINNET_EID = 30184;
    uint32 internal constant BASE_SEPOLIA_EID = 40245;
    uint32 internal constant UNICHAIN_MAINNET_EID = 30328; // TODO: Verify
    
    // LayerZero V2 Endpoint Addresses
    address internal constant LZ_ENDPOINT_MAINNET = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal constant LZ_ENDPOINT_SEPOLIA = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    // LayerZero Labs DVN addresses
    address internal constant LAYERZERO_LABS_DVN_ETHEREUM_MAINNET = 0xF4DA94b4EE9D8e209e3bf9f469221CE2731A7112;
    address internal constant LAYERZERO_LABS_DVN_ETHEREUM_SEPOLIA = 0x53f488E93b4f1b60E8E83aa374dBe1780A1EE8a8;
    
    // Base DVN addresses
    // TODO: Update Base mainnet address when LayerZero publishes official DVN
    // Currently using Dead DVN as fallback: https://docs.layerzero.network/v2/deployments/dvn-addresses
    address internal constant LAYERZERO_LABS_DVN_BASE_MAINNET = 0x6498b0632f3834D7647367334838111c8C889703; // Dead DVN (temporary)
    address internal constant LAYERZERO_LABS_DVN_BASE_SEPOLIA = 0x53f488E93b4f1b60E8E83aa374dBe1780A1EE8a8;

    // Block confirmation requirements per chain
    uint64 internal constant ETHEREUM_BLOCK_CONFIRMATIONS = 15; // ~3 minutes at 12s blocks
    uint64 internal constant BASE_BLOCK_CONFIRMATIONS = 15; // ~30 seconds at 2s blocks

    // Gas limits for cross-chain execution
    uint256 internal constant DEFAULT_LZ_RECEIVE_GAS_LIMIT = 200_000;
    uint256 internal constant ETHEREUM_LZ_RECEIVE_GAS_LIMIT = 250_000; // Higher for Uniswap operations
    uint256 internal constant BASE_LZ_RECEIVE_GAS_LIMIT = 150_000; // Lower gas costs on L2

    /* -------------------------------------------------------------------------- */
    /*                           Protocol Configuration                           */
    /* -------------------------------------------------------------------------- */

    // Fee configuration
    uint256 internal constant HOLOGRAPH_FEE_BPS = 5000; // 50% protocol fee
    uint256 internal constant MIN_BRIDGE_AMOUNT = 0.01 ether; // Mainnet minimum
    uint256 internal constant TESTNET_MIN_BRIDGE_AMOUNT = 0.001 ether; // Testnet minimum

    // Deployment validation
    uint256 internal constant MIN_DEPLOYMENT_GAS = 10_000_000; // Minimum gas for safe deployment

    // Zero address constant for validation
    address internal constant ZERO_ADDRESS = address(0);

    /* -------------------------------------------------------------------------- */
    /*                              Helper Functions                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Check if a chain ID represents a mainnet
     * @param chainId The chain ID to check
     * @return true if the chain ID is a mainnet
     */
    function isMainnet(uint256 chainId) internal pure returns (bool) {
        return chainId == ETHEREUM_MAINNET || chainId == BASE_MAINNET || chainId == UNICHAIN_MAINNET;
    }

    /**
     * @notice Check if a chain ID represents a testnet
     * @param chainId The chain ID to check
     * @return true if the chain ID is a testnet
     */
    function isTestnet(uint256 chainId) internal pure returns (bool) {
        return chainId == ETHEREUM_SEPOLIA || chainId == BASE_SEPOLIA;
    }

    /**
     * @notice Get the chain name for logging
     * @param chainId The chain ID
     * @return name The chain name
     */
    function getChainName(uint256 chainId) internal pure returns (string memory name) {
        if (chainId == ETHEREUM_MAINNET) return "Ethereum Mainnet";
        if (chainId == ETHEREUM_SEPOLIA) return "Ethereum Sepolia";
        if (chainId == BASE_MAINNET) return "Base Mainnet";
        if (chainId == BASE_SEPOLIA) return "Base Sepolia";
        if (chainId == UNICHAIN_MAINNET) return "Unichain Mainnet";
        return "Unknown Chain";
    }

    /**
     * @notice Get the LayerZero endpoint address for a chain
     * @param chainId The chain ID
     * @return The LayerZero endpoint address
     */
    function getLzEndpoint(uint256 chainId) internal pure returns (address) {
        if (isMainnet(chainId)) {
            return LZ_ENDPOINT_MAINNET;
        } else if (isTestnet(chainId)) {
            return LZ_ENDPOINT_SEPOLIA;
        }
        revert("LayerZero endpoint not configured for this chain");
    }

    /**
     * @notice Get the LayerZero endpoint ID for a chain
     * @param chainId The chain ID
     * @return The LayerZero endpoint ID
     */
    function getLzEndpointId(uint256 chainId) internal pure returns (uint32) {
        if (chainId == ETHEREUM_MAINNET) return ETHEREUM_MAINNET_EID;
        if (chainId == ETHEREUM_SEPOLIA) return ETHEREUM_SEPOLIA_EID;
        if (chainId == BASE_MAINNET) return BASE_MAINNET_EID;
        if (chainId == BASE_SEPOLIA) return BASE_SEPOLIA_EID;
        if (chainId == UNICHAIN_MAINNET) return UNICHAIN_MAINNET_EID;
        revert("LayerZero endpoint ID not configured for this chain");
    }

    /**
     * @notice Get the LayerZero Labs DVN address for a given chain
     * @param chainId The chain ID to get the DVN address for
     * @return dvnAddress The LayerZero Labs DVN address for the chain
     */
    function getLayerZeroLabsDVN(uint256 chainId) internal pure returns (address dvnAddress) {
        if (chainId == ETHEREUM_MAINNET) return LAYERZERO_LABS_DVN_ETHEREUM_MAINNET;
        if (chainId == ETHEREUM_SEPOLIA) return LAYERZERO_LABS_DVN_ETHEREUM_SEPOLIA;
        if (chainId == BASE_MAINNET) return LAYERZERO_LABS_DVN_BASE_MAINNET;
        if (chainId == BASE_SEPOLIA) return LAYERZERO_LABS_DVN_BASE_SEPOLIA;
        revert("LayerZero Labs DVN not configured for this chain");
    }

    /**
     * @notice Get the recommended block confirmations for a given chain
     * @param chainId The chain ID to get block confirmations for
     * @return confirmations The number of block confirmations
     */
    function getBlockConfirmations(uint256 chainId) internal pure returns (uint64 confirmations) {
        if (chainId == ETHEREUM_MAINNET || chainId == ETHEREUM_SEPOLIA) {
            return ETHEREUM_BLOCK_CONFIRMATIONS;
        }
        if (chainId == BASE_MAINNET || chainId == BASE_SEPOLIA) {
            return BASE_BLOCK_CONFIRMATIONS;
        }
        revert("Block confirmations not configured for this chain");
    }

    /**
     * @notice Get the recommended gas limit for lzReceive on a given chain
     * @param chainId The chain ID to get gas limit for
     * @return gasLimit The recommended gas limit
     */
    function getLzReceiveGasLimit(uint256 chainId) internal pure returns (uint256 gasLimit) {
        if (chainId == ETHEREUM_MAINNET || chainId == ETHEREUM_SEPOLIA) {
            return ETHEREUM_LZ_RECEIVE_GAS_LIMIT;
        }
        if (chainId == BASE_MAINNET || chainId == BASE_SEPOLIA) {
            return BASE_LZ_RECEIVE_GAS_LIMIT;
        }
        return DEFAULT_LZ_RECEIVE_GAS_LIMIT;
    }

    /**
     * @notice Get the minimum bridge amount for a chain
     * @param chainId The chain ID
     * @return The minimum bridge amount
     */
    function getMinBridgeAmount(uint256 chainId) internal pure returns (uint256) {
        return isTestnet(chainId) ? TESTNET_MIN_BRIDGE_AMOUNT : MIN_BRIDGE_AMOUNT;
    }

    /**
     * @notice Validate that an address is not zero
     * @param addr The address to validate
     * @param name The name of the address for error messages
     */
    function validateNonZeroAddress(address addr, string memory name) internal pure {
        require(addr != ZERO_ADDRESS, string.concat(name, " cannot be zero address"));
    }

    /**
     * @notice Generate deterministic salts for deployment
     * @dev First 20 bytes must be the deployer address for HolographDeployer validation
     * @param deployer The deployer address
     * @param index The contract index (unique identifier)
     * @return salt The generated salt
     */
    function generateSalt(address deployer, uint96 index) internal pure returns (bytes32 salt) {
        // First 20 bytes: deployer address (left-aligned)
        // Last 12 bytes: contract index
        salt = bytes32(uint256(uint160(deployer)) << 96) | bytes32(uint256(index));
    }
}