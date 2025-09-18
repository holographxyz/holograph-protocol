// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title DeployEthereumStakingRewards
 * @notice Deploy only StakingRewards (with audit changes) to Ethereum chains
 *
 * Usage:
 *   // Sepolia deployment
 *   forge script script/deploy/DeployEthereumStakingRewards.s.sol \
 *       --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
 *       --broadcast \
 *       --private-key $DEPLOYER_PK \
 *       --verify
 */
import "../../src/StakingRewards.sol";
import "../DeploymentBase.sol";
import "../DeploymentConfig.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployEthereumStakingRewards is DeploymentBase {
    function run() external {
        // Initialize deployment configuration
        BaseDeploymentConfig memory config = initializeDeployment();

        // Environment variables
        address hlg = vm.envAddress("HLG");

        // Validate env variables
        DeploymentConfig.validateNonZeroAddress(hlg, "HLG");

        // Deploy HolographDeployer using base functionality
        HolographDeployer holographDeployer = deployHolographDeployer();

        // Generate deployment salts
        bytes32 stakingImplSalt = DeploymentConfig.generateSalt(config.deployer, 16); // Use different salt
        bytes32 stakingProxySalt = DeploymentConfig.generateSalt(config.deployer, 17);

        /* ---------------------- Deploy StakingRewards (UUPS Proxy) ---------------------- */
        console.log("\nDeploying StakingRewards implementation...");
        uint256 gasStart = gasleft();

        // Deploy implementation
        bytes memory stakingImplBytecode = abi.encodePacked(type(StakingRewards).creationCode);
        address stakingImpl = holographDeployer.deploy(stakingImplBytecode, stakingImplSalt);
        uint256 gasImpl = gasStart - gasleft();
        console.log("StakingRewards implementation deployed at:", stakingImpl);
        console.log("Gas used for implementation:", gasImpl);

        console.log("\nDeploying StakingRewards proxy...");
        gasStart = gasleft();

        // Deploy proxy with initialization data
        bytes memory proxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(stakingImpl, abi.encodeCall(StakingRewards.initialize, (hlg, config.deployer)))
        );
        address stakingProxy = holographDeployer.deploy(proxyBytecode, stakingProxySalt);
        uint256 gasProxy = gasStart - gasleft();
        address stakingRewards = stakingProxy;
        console.log("StakingRewards proxy deployed at:", stakingRewards);
        console.log("Gas used for proxy:", gasProxy);
        console.log("Total StakingRewards gas:", gasImpl + gasProxy);

        vm.stopBroadcast();

        // Print summary
        console.log("\n=== STAKING REWARDS DEPLOYMENT SUMMARY ===");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", config.deployer);
        console.log("HLG Token:", hlg);
        console.log("StakingRewards (Proxy):", stakingRewards);
        console.log("StakingRewards (Implementation):", stakingImpl);
        console.log("Total Gas Used:", gasImpl + gasProxy);
        console.log("\nNOTE: Contract starts PAUSED. Use 'unpause()' when ready.");
        console.log("NOTE: No FeeRouter set. Use 'setFeeRouter()' if needed later.");

        // Save deployment info
        string memory deploymentDir = getDeploymentDir(block.chainid);

        // Create directory and save addresses
        string[] memory createDirCmd = new string[](3);
        createDirCmd[0] = "mkdir";
        createDirCmd[1] = "-p";
        createDirCmd[2] = deploymentDir;
        vm.ffi(createDirCmd);

        vm.writeFile(string.concat(deploymentDir, "/StakingRewards.txt"), vm.toString(stakingRewards));
        vm.writeFile(string.concat(deploymentDir, "/StakingRewardsImpl.txt"), vm.toString(stakingImpl));
    }
}
