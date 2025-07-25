// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title RedeployFeeRouter
 * @notice Redeploy FeeRouter with fixed ownership on Base Sepolia
 * @dev This script redeploys only the FeeRouter contract with proper owner parameter
 *
 * Usage:
 *   forge script script/RedeployFeeRouter.s.sol \
 *       --rpc-url https://sepolia.base.org \
 *       --broadcast \
 *       --private-key $DEPLOYER_PK
 */

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/FeeRouter.sol";
import "../src/deployment/HolographDeployer.sol";
import "./config/ChainConfigs.sol";

contract RedeployFeeRouter is Script {
    function run() external {
        // Chain guard
        require(block.chainid == 84532, "This script is for Base Sepolia only");
        
        // Environment variables
        bool shouldBroadcast = vm.envOr("BROADCAST", false);
        uint256 deployerPk = shouldBroadcast ? vm.envUint("DEPLOYER_PK") : uint256(0);
        address deployer = shouldBroadcast ? vm.addr(deployerPk) : address(this);
        
        // Deployment addresses (from deployment.json)  
        address holographDeployer = 0x6566750584BB5e59Be783c9B39C704e3e37Eab51;
        address treasury = deployer; // Use deployer as treasury
        
        // LayerZero endpoint for Base Sepolia
        address lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
        uint32 ethEid = 40161; // Ethereum Sepolia EID
        
        console.log("=== Redeploying FeeRouter on Base Sepolia ===");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);
        console.log("HolographDeployer:", holographDeployer);
        
        if (shouldBroadcast) {
            vm.startBroadcast(deployerPk);
        } else {
            console.log("Running in dry-run mode");
            vm.startBroadcast();
        }
        
        // Get salt for FeeRouter deployment
        ChainConfigs.DeploymentSalts memory salts = ChainConfigs.getDeploymentSalts(deployer);
        
        // Prepare FeeRouter bytecode with fixed owner parameter
        bytes memory feeRouterBytecode = abi.encodePacked(
            type(FeeRouter).creationCode,
            abi.encode(
                lzEndpoint,       // LayerZero endpoint
                ethEid,           // Remote EID (Ethereum Sepolia)
                address(0),       // stakingRewards (none on Base)
                address(0),       // HLG token (none on Base)
                address(0),       // WETH (unused on Base)
                address(0),       // SwapRouter (unused on Base)
                treasury,         // treasury address
                deployer          // owner address (fixed!)
            )
        );
        
        // Deploy through HolographDeployer
        console.log("Deploying FeeRouter with owner:", deployer);
        address newFeeRouter = HolographDeployer(holographDeployer).deploy(
            feeRouterBytecode, 
            salts.feeRouter
        );
        
        console.log("New FeeRouter deployed at:", newFeeRouter);
        
        // Verify ownership
        address owner = FeeRouter(payable(newFeeRouter)).owner();
        console.log("FeeRouter owner:", owner);
        
        if (owner == deployer) {
            console.log("[OK] FeeRouter ownership is correct!");
        } else {
            console.log("[ERROR] FeeRouter ownership is wrong!");
        }
        
        vm.stopBroadcast();
        
        console.log("=== Deployment Complete ===");
        console.log("New FeeRouter address:", newFeeRouter);
        console.log("Please manually update the deployment files:");
        console.log("- deployments/base-sepolia/deployment.json");
        console.log("- deployments/base-sepolia/FeeRouter.txt");
        console.log("Ready to run Configure script!");
    }
}