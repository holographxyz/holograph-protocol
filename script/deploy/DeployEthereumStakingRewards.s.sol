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
    /**
     * @notice Get HLG token address with network-specific defaults
     * @return HLG token address for current network
     */
    function getHLGAddress() internal view returns (address) {
        // Try environment variable first
        try vm.envAddress("HLG") returns (address hlg) {
            return hlg;
        } catch {
            // Network-specific defaults
            if (block.chainid == 1) {
                // Ethereum Mainnet
                return 0x740df024CE73f589ACD5E8756b377ef8C6558BaB;
            } else if (block.chainid == 11155111) {
                // Ethereum Sepolia
                return 0x5Ff07042d14E60EC1de7a860BBE968344431BaA1;
            } else {
                // Unknown network - revert with helpful message
                revert(string.concat("No HLG address configured for chain ID: ", vm.toString(block.chainid)));
            }
        }
    }

    function run() external {
        // Initialize deployment configuration
        BaseDeploymentConfig memory config = initializeDeployment();

        // Get HLG address with network-specific defaults
        address hlg = getHLGAddress();

        // Validate HLG address
        DeploymentConfig.validateNonZeroAddress(hlg, "HLG");

        // Deploy HolographDeployer using base functionality
        HolographDeployer holographDeployer = deployHolographDeployer();

        // Generate universal deployment salt
        bytes32 salt = DeploymentConfig.generateSalt(config.deployer);

        /* ---------------------- Deploy StakingRewards (UUPS Proxy) ---------------------- */

        // Try to deploy implementation, reuse if already exists
        bytes memory stakingImplBytecode = abi.encodePacked(type(StakingRewards).creationCode);
        address stakingImpl;
        uint256 gasImpl;

        try holographDeployer.deploy(stakingImplBytecode, salt) returns (address impl) {
            console.log("\nStakingRewards implementation deployed at:", impl);
            stakingImpl = impl;
            gasImpl = 50000; // Approximate gas cost
        } catch {
            // Implementation already exists, calculate address
            stakingImpl = address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff), address(holographDeployer), salt, keccak256(stakingImplBytecode)
                            )
                        )
                    )
                )
            );
            console.log("\nUsing existing StakingRewards implementation at:", stakingImpl);
            gasImpl = 0;
        }

        // Try to deploy proxy with initialization data
        bytes memory proxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(stakingImpl, abi.encodeCall(StakingRewards.initialize, (hlg, config.deployer)))
        );

        address stakingProxy;
        uint256 gasProxy;
        uint256 gasStart = gasleft();

        try holographDeployer.deploy(proxyBytecode, salt) returns (address proxy) {
            gasProxy = gasStart - gasleft();
            stakingProxy = proxy;
            console.log("\nStakingRewards proxy deployed at:", stakingProxy);
            console.log("Gas used for proxy:", gasProxy);
        } catch {
            // Proxy already exists, calculate address
            stakingProxy = address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(bytes1(0xff), address(holographDeployer), salt, keccak256(proxyBytecode))
                        )
                    )
                )
            );
            console.log("\nUsing existing StakingRewards proxy at:", stakingProxy);
            gasProxy = 0;
        }

        address stakingRewards = stakingProxy;
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
