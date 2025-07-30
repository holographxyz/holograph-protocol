// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title DeploymentConstants
 * @notice Constants used across deployment scripts for network validation and configuration
 */
library DeploymentConstants {
    // Mainnet chain IDs - deployment to these requires explicit confirmation
    uint256 internal constant ETHEREUM_MAINNET = 1;
    uint256 internal constant BASE_MAINNET = 8453;
    uint256 internal constant UNICHAIN_MAINNET = 1301;

    // Testnet chain IDs
    uint256 internal constant ETHEREUM_SEPOLIA = 11155111;
    uint256 internal constant BASE_SEPOLIA = 84532;

    // Deployment validation
    uint256 internal constant MIN_DEPLOYMENT_GAS = 10_000_000; // Minimum gas for safe deployment

    // Zero address constant for validation
    address internal constant ZERO_ADDRESS = address(0);

    /* -------------------------------------------------------------------------- */
    /*                             DVN Configuration                             */
    /* -------------------------------------------------------------------------- */

    // LayerZero Labs DVN addresses (primary DVN for production)
    address internal constant LAYERZERO_LABS_DVN_ETHEREUM_MAINNET = 0xF4DA94b4EE9D8e209e3bf9f469221CE2731A7112;
    address internal constant LAYERZERO_LABS_DVN_ETHEREUM_SEPOLIA = 0x53f488E93b4f1b60E8E83aa374dBe1780A1EE8a8;
    
    // TODO: Update with official LayerZero Labs DVN addresses for Base
    // Verify at: https://docs.layerzero.network/v2/deployments/dvn-addresses
    address internal constant LAYERZERO_LABS_DVN_BASE_MAINNET = address(0); // NEEDS UPDATE
    address internal constant LAYERZERO_LABS_DVN_BASE_SEPOLIA = address(0); // NEEDS UPDATE

    // Polyhedra zkBridge DVN addresses (secondary DVN option)
    address internal constant POLYHEDRA_DVN_ETHEREUM_MAINNET = 0x8ddF05F9A5c488b4973897E278B58895bF87Cb24;
    address internal constant POLYHEDRA_DVN_ETHEREUM_SEPOLIA = 0x8ddF05F9A5c488b4973897E278B58895bF87Cb24;
    address internal constant POLYHEDRA_DVN_BASE_MAINNET = 0x8ddF05F9A5c488b4973897E278B58895bF87Cb24;  
    address internal constant POLYHEDRA_DVN_BASE_SEPOLIA = 0x8ddF05F9A5c488b4973897E278B58895bF87Cb24;

    // Block confirmation requirements per chain
    uint64 internal constant ETHEREUM_BLOCK_CONFIRMATIONS = 15; // ~3 minutes at 12s blocks
    uint64 internal constant BASE_BLOCK_CONFIRMATIONS = 15; // ~30 seconds at 2s blocks

    // Gas limits for cross-chain execution
    uint256 internal constant DEFAULT_LZ_RECEIVE_GAS_LIMIT = 200_000;
    uint256 internal constant ETHEREUM_LZ_RECEIVE_GAS_LIMIT = 250_000; // Higher for Uniswap operations
    uint256 internal constant BASE_LZ_RECEIVE_GAS_LIMIT = 150_000; // Lower gas costs on L2

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
     * @notice Validate that an address is not zero
     * @param addr The address to validate
     * @param name The name of the address for error messages
     */
    function validateNonZeroAddress(address addr, string memory name) internal pure {
        require(addr != ZERO_ADDRESS, string.concat(name, " cannot be zero address"));
    }

    /* -------------------------------------------------------------------------- */
    /*                          DVN Helper Functions                            */
    /* -------------------------------------------------------------------------- */

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
     * @notice Get the Polyhedra zkBridge DVN address for a given chain
     * @param chainId The chain ID to get the DVN address for
     * @return dvnAddress The Polyhedra DVN address for the chain
     */
    function getPolyhedraDVN(uint256 chainId) internal pure returns (address dvnAddress) {
        if (chainId == ETHEREUM_MAINNET) return POLYHEDRA_DVN_ETHEREUM_MAINNET;
        if (chainId == ETHEREUM_SEPOLIA) return POLYHEDRA_DVN_ETHEREUM_SEPOLIA;
        if (chainId == BASE_MAINNET) return POLYHEDRA_DVN_BASE_MAINNET;
        if (chainId == BASE_SEPOLIA) return POLYHEDRA_DVN_BASE_SEPOLIA;
        revert("Polyhedra DVN not configured for this chain");
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
}
