// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title DeployFeeRouterFix
 * @notice Deploy a new FeeRouter with correct owner to fix ownership issue
 * 
 * Usage:
 *   BROADCAST=true forge script script/DeployFeeRouterFix.s.sol \
 *     --rpc-url https://sepolia.base.org \
 *     --broadcast \
 *     --private-key $DEPLOYER_PK
 */

import "../src/FeeRouter.sol";
import "./base/DeploymentBase.sol";

contract DeployFeeRouterFix is DeploymentBase {
    function run() external {
        // Initialize deployment configuration
        DeploymentConfig memory config = initializeDeployment();
        
        // Environment variables
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT");
        address treasury = vm.envAddress("TREASURY");
        uint32 ethEid = uint32(vm.envUint("ETH_EID"));

        // Quick sanity checks
        require(lzEndpoint != address(0), "LZ_ENDPOINT not set");
        require(treasury != address(0), "TREASURY not set");
        require(ethEid != 0, "ETH_EID not set");
        
        // Use hardcoded HolographDeployer address from deployment.json
        address holographDeployer = 0x6566750584BB5e59Be783c9B39C704e3e37Eab51;
        
        console.log("Using existing HolographDeployer:", holographDeployer);
        console.log("Deploying new FeeRouter with correct owner:", config.deployer);
        
        // Use same salt as original - bytecode is different due to owner change
        ChainConfigs.DeploymentSalts memory salts = getDeploymentSalts(config.deployer);
        
        // Deploy new FeeRouter with correct owner
        uint256 gasStart = gasleft();
        bytes memory feeRouterBytecode = abi.encodePacked(
            type(FeeRouter).creationCode,
            abi.encode(
                lzEndpoint, // LayerZero endpoint for fee bridging
                ethEid,
                address(0), // stakingRewards (none on Base)
                address(0), // HLG token (none on Base)
                address(0), // WETH (unused on Base for this contract)
                address(0), // SwapRouter (unused)
                treasury,
                config.deployer // Set deployer as owner (FIXED!)
            )
        );
        
        address newFeeRouter = HolographDeployer(holographDeployer).deploy(feeRouterBytecode, salts.feeRouter);
        uint256 gasUsed = gasStart - gasleft();
        
        vm.stopBroadcast();
        
        console.log("\n=== FeeRouter Fix Deployment Complete ===");
        console.log("New FeeRouter deployed at:", newFeeRouter);
        console.log("Owner:", config.deployer);
        console.log("Gas used:", gasUsed);
        console.log("Salt used:", vm.toString(salts.feeRouter));
        
        // Verify owner is correct
        address actualOwner = FeeRouter(payable(newFeeRouter)).owner();
        console.log("Verified owner:", actualOwner);
        require(actualOwner == config.deployer, "Owner verification failed");
        
        console.log("\n=== Next Steps ===");
        console.log("1. Update deployment.json with new FeeRouter address");
        console.log("2. Configure new FeeRouter to trust Doppler Airlock");
        console.log("3. Update create-token.ts to use new FeeRouter address");
    }
}