// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title VerifyAddresses
 * @notice Verify Holograph deployments across chains have consistent addresses
 * @dev Reads deployment files and checks that addresses match across all chains
 *
 * Usage:
 *   forge script script/VerifyAddresses.s.sol
 */
import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/deployment/HolographDeployer.sol";
import "./DeploymentConfig.sol";

contract VerifyAddresses is Script {
    /* -------------------------------------------------------------------------- */
    /*                                   Types                                    */
    /* -------------------------------------------------------------------------- */

    struct ChainDeployment {
        string chainName;
        address holographDeployer;
        address holographERC20;
        address holographFactory;
        address holographFactoryProxy;
        address feeRouter;
        address stakingRewards;
        bool exists;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Run                                      */
    /* -------------------------------------------------------------------------- */
    function run() external view {
        console.log("========================================");
        console.log("Verifying Holograph Deployment Addresses");
        console.log("========================================\n");

        // Check all supported chains
        ChainDeployment[] memory deployments = new ChainDeployment[](6);

        // Ethereum
        deployments[0] = readDeployment("ethereum", false);
        deployments[1] = readDeployment("ethereum-sepolia", true);

        // Base
        deployments[2] = readDeployment("base", false);
        deployments[3] = readDeployment("base-sepolia", true);

        // Unichain
        deployments[4] = readDeployment("unichain", false);
        deployments[5] = readDeployment("unichain-sepolia", true);

        // Display deployment summary
        displaySummary(deployments);

        // Check address consistency
        checkConsistency(deployments);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Helper Functions                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Read deployment addresses from files
     * @param chainDir The directory name for the chain
     * @param isTestnet Whether this is a testnet deployment
     * @return deployment The deployment info
     */
    function readDeployment(string memory chainDir, bool isTestnet)
        internal
        view
        returns (ChainDeployment memory deployment)
    {
        deployment.chainName = chainDir;

        string memory basePath = string.concat("deployments/", chainDir, "/");

        // First try to read from JSON deployment file
        (bool jsonSuccess, ChainDeployment memory jsonDeployment) = readFromJson(basePath, deployment);
        if (jsonSuccess) {
            console.log("Successfully read from JSON for:", chainDir);
            return jsonDeployment;
        }

        // Fallback to reading individual text files for backward compatibility
        console.log("Falling back to text files for:", chainDir);
        deployment = readFromTextFiles(basePath, deployment);

        return deployment;
    }

    /**
     * @notice Try to read deployment from JSON file
     * @param basePath The base path to deployment directory
     * @param deployment The deployment struct to populate
     * @return success Whether the JSON file was successfully read
     */
    function readFromJson(string memory basePath, ChainDeployment memory deployment)
        internal
        view
        returns (bool success, ChainDeployment memory)
    {
        string memory jsonPath = string.concat(vm.projectRoot(), "/", basePath, "deployment.json");

        try vm.readFile(jsonPath) returns (string memory jsonContent) {
            console.log("Successfully read JSON file:", jsonPath);

            // Try to parse each field individually
            try vm.parseJsonAddress(jsonContent, ".holographDeployer") returns (address addr) {
                deployment.holographDeployer = addr;
                deployment.exists = true;
                console.log("Found holographDeployer:", addr);
            } catch {
                console.log("Failed to parse holographDeployer");
            }

            try vm.parseJsonAddress(jsonContent, ".holographERC20") returns (address addr) {
                deployment.holographERC20 = addr;
                deployment.exists = true;
                console.log("Found holographERC20:", addr);
            } catch {
                console.log("Failed to parse holographERC20");
            }

            try vm.parseJsonAddress(jsonContent, ".holographFactory") returns (address addr) {
                deployment.holographFactory = addr;
                deployment.exists = true;
                console.log("Found holographFactory:", addr);
            } catch {
                console.log("Failed to parse holographFactory");
            }

            try vm.parseJsonAddress(jsonContent, ".holographFactoryProxy") returns (address addr) {
                deployment.holographFactoryProxy = addr;
                deployment.exists = true;
                console.log("Found holographFactoryProxy:", addr);
            } catch {
                console.log("Failed to parse holographFactoryProxy");
            }

            try vm.parseJsonAddress(jsonContent, ".feeRouter") returns (address addr) {
                deployment.feeRouter = addr;
                deployment.exists = true;
                console.log("Found feeRouter:", addr);
            } catch {
                console.log("Failed to parse feeRouter");
            }

            try vm.parseJsonAddress(jsonContent, ".stakingRewards") returns (address addr) {
                deployment.stakingRewards = addr;
                deployment.exists = true;
                console.log("Found stakingRewards:", addr);
            } catch {
                console.log("Failed to parse stakingRewards");
            }

            return (true, deployment);
        } catch {
            console.log("Failed to read JSON file:", jsonPath);
            return (false, deployment);
        }
    }

    /**
     * @notice Read deployment from individual text files (backward compatibility)
     * @param basePath The base path to deployment directory
     * @param deployment The deployment struct to populate
     * @return Updated deployment struct
     */
    function readFromTextFiles(string memory basePath, ChainDeployment memory deployment)
        internal
        view
        returns (ChainDeployment memory)
    {
        string memory projectRoot = vm.projectRoot();

        // Try to read each file - if it doesn't exist, the address will be 0x0
        try vm.readFile(string.concat(projectRoot, "/", basePath, "HolographDeployer.txt")) returns (string memory addr)
        {
            deployment.holographDeployer = vm.parseAddress(addr);
            deployment.exists = true;
        } catch {}

        try vm.readFile(string.concat(projectRoot, "/", basePath, "HolographERC20.txt")) returns (string memory addr) {
            deployment.holographERC20 = vm.parseAddress(addr);
            deployment.exists = true;
        } catch {}

        try vm.readFile(string.concat(projectRoot, "/", basePath, "HolographFactory.txt")) returns (string memory addr)
        {
            deployment.holographFactory = vm.parseAddress(addr);
            deployment.exists = true;
        } catch {}

        try vm.readFile(string.concat(projectRoot, "/", basePath, "HolographFactoryProxy.txt")) returns (
            string memory addr
        ) {
            deployment.holographFactoryProxy = vm.parseAddress(addr);
            deployment.exists = true;
        } catch {}

        try vm.readFile(string.concat(projectRoot, "/", basePath, "FeeRouter.txt")) returns (string memory addr) {
            deployment.feeRouter = vm.parseAddress(addr);
            deployment.exists = true;
        } catch {}

        try vm.readFile(string.concat(projectRoot, "/", basePath, "StakingRewards.txt")) returns (string memory addr) {
            deployment.stakingRewards = vm.parseAddress(addr);
            deployment.exists = true;
        } catch {}

        return deployment;
    }

    /**
     * @notice Display deployment summary
     * @param deployments Array of deployments to display
     */
    function displaySummary(ChainDeployment[] memory deployments) internal view {
        console.log("Deployment Summary:");
        console.log("==================\n");

        for (uint256 i = 0; i < deployments.length; i++) {
            if (!deployments[i].exists) {
                console.log("%s: [NOT DEPLOYED]", deployments[i].chainName);
                continue;
            }

            console.log("%s:", deployments[i].chainName);

            if (deployments[i].holographDeployer != address(0)) {
                console.log("  HolographDeployer:      %s", deployments[i].holographDeployer);
            }
            if (deployments[i].holographERC20 != address(0)) {
                console.log("  HolographERC20:         %s", deployments[i].holographERC20);
            }
            if (deployments[i].holographFactory != address(0)) {
                console.log("  HolographFactory:       %s", deployments[i].holographFactory);
            }
            if (deployments[i].holographFactoryProxy != address(0)) {
                console.log("  HolographFactory Proxy: %s", deployments[i].holographFactoryProxy);
            }
            if (deployments[i].feeRouter != address(0)) {
                console.log("  FeeRouter:              %s", deployments[i].feeRouter);
            }
            if (deployments[i].stakingRewards != address(0)) {
                console.log("  StakingRewards:         %s", deployments[i].stakingRewards);
            }
            console.log("");
        }
    }

    /**
     * @notice Check address consistency across chains
     * @param deployments Array of deployments to check
     */
    function checkConsistency(ChainDeployment[] memory deployments) internal view {
        console.log("\nAddress Consistency Check:");
        console.log("=========================\n");

        // Reference addresses (first deployed chain)
        address refDeployer;
        address refERC20;
        address refFactory;
        address refFeeRouter;

        // Find first deployed chain as reference
        for (uint256 i = 0; i < deployments.length; i++) {
            if (deployments[i].exists) {
                refDeployer = deployments[i].holographDeployer;
                refERC20 = deployments[i].holographERC20;
                refFactory = deployments[i].holographFactory;
                refFeeRouter = deployments[i].feeRouter;
                break;
            }
        }

        // Check each contract type
        uint256 issues = 0;

        // Check HolographDeployer
        console.log("HolographDeployer:");
        issues += checkContract(deployments, refDeployer, 0);

        // Check HolographERC20
        console.log("\nHolographERC20:");
        issues += checkContract(deployments, refERC20, 1);

        // Check HolographFactory
        console.log("\nHolographFactory:");
        issues += checkContract(deployments, refFactory, 2);

        // Check FeeRouter
        console.log("\nFeeRouter:");
        issues += checkContract(deployments, refFeeRouter, 3);

        // Summary
        console.log("\n========================================");
        if (issues == 0) {
            console.log("[SUCCESS] All addresses are consistent!");
        } else {
            console.log("[WARNING] Found %s inconsistencies", issues);
        }
        console.log("========================================");
    }

    /**
     * @notice Check a specific contract's consistency
     * @param deployments Array of deployments
     * @param refAddress Reference address to compare against
     * @param contractType 0=Deployer, 1=ERC20, 2=Factory, 3=FeeRouter
     * @return issues Number of inconsistencies found
     */
    function checkContract(ChainDeployment[] memory deployments, address refAddress, uint256 contractType)
        internal
        view
        returns (uint256 issues)
    {
        bool hasInconsistency = false;
        uint256 deployedCount = 0;

        for (uint256 i = 0; i < deployments.length; i++) {
            if (!deployments[i].exists) continue;

            address addr;
            if (contractType == 0) addr = deployments[i].holographDeployer;
            else if (contractType == 1) addr = deployments[i].holographERC20;
            else if (contractType == 2) addr = deployments[i].holographFactory;
            else if (contractType == 3) addr = deployments[i].feeRouter;

            if (addr != address(0)) {
                deployedCount++;
                if (addr != refAddress && refAddress != address(0)) {
                    hasInconsistency = true;
                    console.log("  [ERROR] %s: %s (expected: %s)", deployments[i].chainName, addr, refAddress);
                    issues++;
                }
            }
        }

        if (!hasInconsistency && deployedCount > 0) {
            console.log("  [OK] Consistent address: %s", refAddress);
            console.log("       Deployed on %s chains", deployedCount);
        } else if (deployedCount == 0) {
            console.log("  [INFO] Not deployed on any chain");
        }

        return issues;
    }
}
