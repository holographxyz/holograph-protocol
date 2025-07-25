// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../src/deployment/HolographDeployer.sol";
import "../config/ChainConfigs.sol";

/**
 * @title DeploymentBase
 * @notice Base contract for Holograph deployment scripts
 * @dev Provides common functionality and JSON output for all deployments
 *
 * Salt Generation Strategy:
 * - Uses deterministic salts based on deployer address and contract type
 * - Ensures consistent addresses across different chains
 * - First 20 bytes of salt must match the deployer address (HolographDeployer requirement)
 * - Remaining 12 bytes are used for contract-specific identification
 *
 * Environment Variables Required:
 * - DEPLOYER_PK: Private key for deployment (required when BROADCAST=true)
 * - BROADCAST: Set to true to execute transactions (default: false for dry-run)
 * - Chain-specific variables are defined in individual deployment scripts
 */
abstract contract DeploymentBase is Script {
    /* -------------------------------------------------------------------------- */
    /*                                Constants                                   */
    /* -------------------------------------------------------------------------- */

    // Deterministic deployer salt
    bytes32 internal constant DEPLOYER_SALT = keccak256("HOLOGRAPH_DEPLOYER_V1");

    // Standard CREATE2 deployer address
    address internal constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    /* -------------------------------------------------------------------------- */
    /*                                Structs                                     */
    /* -------------------------------------------------------------------------- */

    struct DeploymentConfig {
        bool shouldBroadcast;
        uint256 deployerPk;
        address deployer;
        uint256 chainId;
        string chainName;
    }

    struct ContractAddresses {
        address holographDeployer;
        address holographERC20;
        address holographFactory;
        address holographFactoryProxy;
        address feeRouter;
        address stakingRewards; // Ethereum only
    }

    /* -------------------------------------------------------------------------- */
    /*                           Setup Functions                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Initialize deployment configuration from environment
     */
    function initializeDeployment() internal returns (DeploymentConfig memory config) {
        config.shouldBroadcast = vm.envOr("BROADCAST", false);
        config.deployerPk = config.shouldBroadcast ? vm.envUint("DEPLOYER_PK") : uint256(0);
        config.deployer = vm.addr(config.deployerPk != 0 ? config.deployerPk : 1);
        config.chainId = block.chainid;
        config.chainName = getChainName(config.chainId);

        console.log("Deploying to", config.chainName, "- Chain ID:", config.chainId);

        if (config.shouldBroadcast) {
            console.log("Broadcasting TXs as", config.deployer);
            vm.startBroadcast(config.deployerPk);
        } else {
            console.log("Running in dry-run mode (no broadcast)");
            vm.startBroadcast();
        }
    }

    /**
     * @notice Deploy HolographDeployer using standard CREATE2 deployer
     * @dev Uses the canonical CREATE2 deployer at 0x4e59b44847b379578588920cA78FbF26c0B4956C
     *      This ensures the HolographDeployer has the same address on all chains
     *      The DEPLOYER_SALT constant ensures deterministic deployment
     * @return holographDeployer The HolographDeployer instance
     */
    function deployHolographDeployer() internal returns (HolographDeployer holographDeployer) {
        bytes memory deployerBytecode = type(HolographDeployer).creationCode;

        address expectedDeployerAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(bytes1(0xff), CREATE2_DEPLOYER, DEPLOYER_SALT, keccak256(deployerBytecode))
                    )
                )
            )
        );

        if (expectedDeployerAddress.code.length == 0) {
            console.log("Deploying HolographDeployer...");
            uint256 gasStart = gasleft();

            bytes32 salt = DEPLOYER_SALT;
            address deployedAddress;
            assembly {
                deployedAddress := create2(0, add(deployerBytecode, 0x20), mload(deployerBytecode), salt)
                if iszero(deployedAddress) { revert(0, 0) }
            }

            uint256 gasUsed = gasStart - gasleft();
            console.log("HolographDeployer deployed at:", expectedDeployerAddress);
            console.log("Gas used:", gasUsed);
        } else {
            console.log("HolographDeployer already deployed at:", expectedDeployerAddress);
        }

        holographDeployer = HolographDeployer(expectedDeployerAddress);
    }

    /* -------------------------------------------------------------------------- */
    /*                         JSON Output Functions                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Save deployment addresses to JSON file
     * @param config Deployment configuration
     * @param addresses Contract addresses
     */
    function saveDeployment(DeploymentConfig memory config, ContractAddresses memory addresses) internal {
        string memory dir = getDeploymentDir(config.chainId);
        vm.createDir(dir, true);

        string memory json = "deployment";

        // Basic deployment info
        vm.serializeUint(json, "chainId", config.chainId);
        vm.serializeString(json, "chainName", config.chainName);
        vm.serializeAddress(json, "deployer", config.deployer);
        vm.serializeUint(json, "deployedAt", block.timestamp);
        vm.serializeUint(json, "blockNumber", block.number);

        // Contract addresses
        vm.serializeAddress(json, "holographDeployer", addresses.holographDeployer);
        if (addresses.holographERC20 != address(0)) {
            vm.serializeAddress(json, "holographERC20", addresses.holographERC20);
        }
        if (addresses.holographFactory != address(0)) {
            vm.serializeAddress(json, "holographFactory", addresses.holographFactory);
        }
        if (addresses.holographFactoryProxy != address(0)) {
            vm.serializeAddress(json, "holographFactoryProxy", addresses.holographFactoryProxy);
        }
        if (addresses.feeRouter != address(0)) {
            vm.serializeAddress(json, "feeRouter", addresses.feeRouter);
        }
        if (addresses.stakingRewards != address(0)) {
            vm.serializeAddress(json, "stakingRewards", addresses.stakingRewards);
        }

        string memory finalJson = vm.serializeString(json, "version", "1.0");

        string memory filePath = string.concat(dir, "/deployment.json");
        vm.writeJson(finalJson, filePath);

        console.log("Deployment saved to:", filePath);

        // Also save individual address files for backward compatibility
        saveIndividualAddressFiles(dir, addresses);
    }

    /**
     * @notice Save individual address files for backward compatibility
     */
    function saveIndividualAddressFiles(string memory dir, ContractAddresses memory addresses) internal {
        vm.writeFile(string.concat(dir, "/HolographDeployer.txt"), vm.toString(addresses.holographDeployer));

        if (addresses.holographERC20 != address(0)) {
            vm.writeFile(string.concat(dir, "/HolographERC20.txt"), vm.toString(addresses.holographERC20));
        }
        if (addresses.holographFactory != address(0)) {
            vm.writeFile(string.concat(dir, "/HolographFactory.txt"), vm.toString(addresses.holographFactory));
        }
        if (addresses.holographFactoryProxy != address(0)) {
            vm.writeFile(string.concat(dir, "/HolographFactoryProxy.txt"), vm.toString(addresses.holographFactoryProxy));
        }
        if (addresses.feeRouter != address(0)) {
            vm.writeFile(string.concat(dir, "/FeeRouter.txt"), vm.toString(addresses.feeRouter));
        }
        if (addresses.stakingRewards != address(0)) {
            vm.writeFile(string.concat(dir, "/StakingRewards.txt"), vm.toString(addresses.stakingRewards));
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                            Helper Functions                               */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Get chain name for display
     */
    function getChainName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 1) return "Ethereum Mainnet";
        if (chainId == 11155111) return "Ethereum Sepolia";
        if (chainId == 8453) return "Base Mainnet";
        if (chainId == 84532) return "Base Sepolia";
        if (chainId == 1301) return "Unichain Mainnet";
        return string.concat("Chain ", vm.toString(chainId));
    }

    /**
     * @notice Get deployment directory based on chain ID
     */
    function getDeploymentDir(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 1) return "deployments/ethereum";
        if (chainId == 11155111) return "deployments/ethereum-sepolia";
        if (chainId == 8453) return "deployments/base";
        if (chainId == 84532) return "deployments/base-sepolia";
        if (chainId == 1301) return "deployments/unichain";
        return string.concat("deployments/chain-", vm.toString(chainId));
    }

    /**
     * @notice Print deployment summary
     */
    function printDeploymentSummary(ContractAddresses memory addresses) internal view {
        console.log("\n========================================");
        console.log("Deployment Summary");
        console.log("========================================");
        console.log("HolographDeployer:", addresses.holographDeployer);

        if (addresses.holographERC20 != address(0)) {
            console.log("HolographERC20:", addresses.holographERC20);
        }
        if (addresses.holographFactory != address(0)) {
            console.log("HolographFactory:", addresses.holographFactory);
        }
        if (addresses.holographFactoryProxy != address(0)) {
            console.log("HolographFactory Proxy:", addresses.holographFactoryProxy);
        }
        if (addresses.feeRouter != address(0)) {
            console.log("FeeRouter:", addresses.feeRouter);
        }
        if (addresses.stakingRewards != address(0)) {
            console.log("StakingRewards:", addresses.stakingRewards);
        }

        console.log("========================================");
    }

    /**
     * @notice Get deployment salts for consistent addresses
     * @dev Generates deterministic salts where:
     *      - First 20 bytes: deployer address (required by HolographDeployer)
     *      - Last 12 bytes: contract-specific identifier
     *      This ensures each contract type has a unique but predictable address
     * @param deployer The address that will deploy the contracts
     * @return DeploymentSalts struct containing salts for each contract type
     */
    function getDeploymentSalts(address deployer) internal pure returns (ChainConfigs.DeploymentSalts memory) {
        return ChainConfigs.getDeploymentSalts(deployer);
    }
}
