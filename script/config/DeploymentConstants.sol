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
    
    /**
     * @notice Check if a chain ID represents a mainnet
     * @param chainId The chain ID to check
     * @return true if the chain ID is a mainnet
     */
    function isMainnet(uint256 chainId) internal pure returns (bool) {
        return chainId == ETHEREUM_MAINNET || 
               chainId == BASE_MAINNET || 
               chainId == UNICHAIN_MAINNET;
    }
    
    /**
     * @notice Check if a chain ID represents a testnet
     * @param chainId The chain ID to check
     * @return true if the chain ID is a testnet
     */
    function isTestnet(uint256 chainId) internal pure returns (bool) {
        return chainId == ETHEREUM_SEPOLIA || 
               chainId == BASE_SEPOLIA;
    }
    
    /**
     * @notice Validate that an address is not zero
     * @param addr The address to validate
     * @param name The name of the address for error messages
     */
    function validateNonZeroAddress(address addr, string memory name) internal pure {
        require(addr != ZERO_ADDRESS, string.concat(name, " cannot be zero address"));
    }
}