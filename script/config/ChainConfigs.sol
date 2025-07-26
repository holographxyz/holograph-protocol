// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title ChainConfigs
 * @notice Chain-specific configuration for Holograph protocol deployments
 * @dev Maintains consistent configuration across all supported chains
 */
library ChainConfigs {
    /* -------------------------------------------------------------------------- */
    /*                              Chain Identifiers                             */
    /* -------------------------------------------------------------------------- */

    // Mainnets
    uint256 constant ETHEREUM_MAINNET = 1;
    uint256 constant BASE_MAINNET = 8453;
    uint256 constant UNICHAIN_MAINNET = 1301;

    // Testnets
    uint256 constant ETHEREUM_SEPOLIA = 11155111;
    uint256 constant BASE_SEPOLIA = 84532;
    uint256 constant UNICHAIN_SEPOLIA = 1301; // TODO: Update when Unichain Sepolia is available

    /* -------------------------------------------------------------------------- */
    /*                          LayerZero Endpoint IDs                            */
    /* -------------------------------------------------------------------------- */

    struct EndpointIds {
        uint32 ethereum;
        uint32 base;
        uint32 unichain;
    }

    function getMainnetEndpointIds() internal pure returns (EndpointIds memory) {
        return EndpointIds({
            ethereum: 30101, // Ethereum mainnet
            base: 30184, // Base mainnet
            unichain: 30328 // Unichain mainnet (TODO: Verify endpoint ID)
        });
    }

    function getTestnetEndpointIds() internal pure returns (EndpointIds memory) {
        return EndpointIds({
            ethereum: 40161, // Ethereum Sepolia
            base: 40245, // Base Sepolia
            unichain: 40328 // Unichain Sepolia
        });
    }

    /* -------------------------------------------------------------------------- */
    /*                            Chain Configuration                             */
    /* -------------------------------------------------------------------------- */

    struct ChainConfig {
        uint256 chainId;
        string name;
        string currency;
        uint32 lzEndpointId;
        address lzEndpoint;
        bool isTestnet;
    }

    /**
     * @notice Get configuration for Ethereum mainnet
     */
    function getEthereumMainnet() internal pure returns (ChainConfig memory) {
        return ChainConfig({
            chainId: ETHEREUM_MAINNET,
            name: "Ethereum",
            currency: "ETH",
            lzEndpointId: 30101,
            lzEndpoint: 0x1a44076050125825900e736c501f859c50fE728c,
            isTestnet: false
        });
    }

    /**
     * @notice Get configuration for Base mainnet
     */
    function getBaseMainnet() internal pure returns (ChainConfig memory) {
        return ChainConfig({
            chainId: BASE_MAINNET,
            name: "Base",
            currency: "ETH",
            lzEndpointId: 30184,
            lzEndpoint: 0x1a44076050125825900e736c501f859c50fE728c,
            isTestnet: false
        });
    }

    /**
     * @notice Get configuration for Ethereum Sepolia
     */
    function getEthereumSepolia() internal pure returns (ChainConfig memory) {
        return ChainConfig({
            chainId: ETHEREUM_SEPOLIA,
            name: "Ethereum Sepolia",
            currency: "ETH",
            lzEndpointId: 40161,
            lzEndpoint: 0x6EDCE65403992e310A62460808c4b910D972f10f,
            isTestnet: true
        });
    }

    /**
     * @notice Get configuration for Base Sepolia
     */
    function getBaseSepolia() internal pure returns (ChainConfig memory) {
        return ChainConfig({
            chainId: BASE_SEPOLIA,
            name: "Base Sepolia",
            currency: "ETH",
            lzEndpointId: 40245,
            lzEndpoint: 0x6EDCE65403992e310A62460808c4b910D972f10f,
            isTestnet: true
        });
    }

    /**
     * @notice Get configuration for Unichain mainnet
     */
    function getUnichainMainnet() internal pure returns (ChainConfig memory) {
        return ChainConfig({
            chainId: UNICHAIN_MAINNET,
            name: "Unichain",
            currency: "ETH",
            lzEndpointId: 30328, // TODO: Verify endpoint ID
            lzEndpoint: 0x1a44076050125825900e736c501f859c50fE728c, // TODO: Verify endpoint address
            isTestnet: false
        });
    }

    /**
     * @notice Get configuration for Unichain Sepolia
     */
    function getUnichainSepolia() internal pure returns (ChainConfig memory) {
        return ChainConfig({
            chainId: UNICHAIN_SEPOLIA,
            name: "Unichain Sepolia",
            currency: "ETH",
            lzEndpointId: 40328,
            lzEndpoint: 0x6EDCE65403992e310A62460808c4b910D972f10f, // TODO: Verify endpoint address
            isTestnet: true
        });
    }

    /**
     * @notice Get configuration for a specific chain ID
     * @param chainId The chain ID to get configuration for
     * @return config The chain configuration
     */
    function getChainConfig(uint256 chainId) internal pure returns (ChainConfig memory config) {
        if (chainId == ETHEREUM_MAINNET) {
            return getEthereumMainnet();
        } else if (chainId == BASE_MAINNET) {
            return getBaseMainnet();
        } else if (chainId == UNICHAIN_MAINNET) {
            return getUnichainMainnet();
        } else if (chainId == ETHEREUM_SEPOLIA) {
            return getEthereumSepolia();
        } else if (chainId == BASE_SEPOLIA) {
            return getBaseSepolia();
        } else if (chainId == UNICHAIN_SEPOLIA) {
            return getUnichainSepolia();
        } else {
            revert("ChainConfigs: Unsupported chain");
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                          Protocol Configuration                            */
    /* -------------------------------------------------------------------------- */

    struct ProtocolConfig {
        address treasury;
        address stakingRewards;
        address hlgToken;
        uint256 holographFeeBps;
        uint256 minBridgeAmount;
    }

    /**
     * @notice Get protocol configuration for mainnet
     */
    function getMainnetProtocolConfig() internal pure returns (ProtocolConfig memory) {
        return ProtocolConfig({
            treasury: address(0), // TODO: Set mainnet treasury
            stakingRewards: address(0), // TODO: Set mainnet staking rewards
            hlgToken: address(0), // TODO: Set mainnet HLG token
            holographFeeBps: 150, // 1.5%
            minBridgeAmount: 0.01 ether
        });
    }

    /**
     * @notice Get protocol configuration for testnet
     */
    function getTestnetProtocolConfig() internal pure returns (ProtocolConfig memory) {
        return ProtocolConfig({
            treasury: 0x0000000000000000000000000000000000001111, // Test treasury
            stakingRewards: address(0), // No staking on testnet
            hlgToken: address(0), // No HLG on testnet
            holographFeeBps: 150, // 1.5%
            minBridgeAmount: 0.001 ether
        });
    }

    /* -------------------------------------------------------------------------- */
    /*                         Deployment Configuration                           */
    /* -------------------------------------------------------------------------- */

    struct DeploymentSalts {
        bytes32 deployer;
        bytes32 config;
        bytes32 factory;
        bytes32 feeRouter;
        bytes32 erc20Implementation;
    }

    /**
     * @notice Get consistent salts for deterministic deployment
     * @dev These salts ensure same addresses across all chains
     * @dev First 20 bytes (160 bits) must be the deployer address for HolographDeployer validation
     */
    function getDeploymentSalts(address deployer) internal pure returns (DeploymentSalts memory) {
        // Generate deterministic salts with deployer address in first 20 bytes (left-aligned)
        // This ensures HolographDeployer.deploy() salt validation passes
        bytes32 deployerPrefix = bytes32(uint256(uint160(deployer)) << 96);

        return DeploymentSalts({
            deployer: deployerPrefix | bytes32(uint256(1)),
            config: deployerPrefix | bytes32(uint256(2)),
            factory: deployerPrefix | bytes32(uint256(3)),
            feeRouter: deployerPrefix | bytes32(uint256(4)),
            erc20Implementation: deployerPrefix | bytes32(uint256(5))
        });
    }

    /* -------------------------------------------------------------------------- */
    /*                              Helper Functions                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Check if a chain ID represents a testnet
     * @param chainId The chain ID to check
     * @return True if testnet, false if mainnet
     */
    function isTestnet(uint256 chainId) internal pure returns (bool) {
        return chainId == ETHEREUM_SEPOLIA || chainId == BASE_SEPOLIA || chainId == UNICHAIN_SEPOLIA;
    }

    /**
     * @notice Get the LayerZero endpoint address for a chain
     * @param chainId The chain ID
     * @return The LayerZero endpoint address
     */
    function getLzEndpoint(uint256 chainId) internal pure returns (address) {
        ChainConfig memory config = getChainConfig(chainId);
        return config.lzEndpoint;
    }

    /**
     * @notice Get the LayerZero endpoint ID for a chain
     * @param chainId The chain ID
     * @return The LayerZero endpoint ID
     */
    function getLzEndpointId(uint256 chainId) internal pure returns (uint32) {
        ChainConfig memory config = getChainConfig(chainId);
        return config.lzEndpointId;
    }
}
