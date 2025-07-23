// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title DeployEthereum
 * @notice Foundry script to deploy StakingRewards and FeeRouter on Ethereum chain
 *
 * Usage examples:
 *   // Dry-run (fork)
 *   forge script script/DeployEthereum.s.sol --fork-url $ETH_RPC
 *
 *   // Broadcast (mainnet)
 *   forge script script/DeployEthereum.s.sol \
 *       --rpc-url $ETH_RPC \
 *       --broadcast \
 *       --private-key $DEPLOYER_PK
 */

import "../src/FeeRouter.sol";
import "../src/StakingRewards.sol";
import "./base/DeploymentBase.sol";

contract DeployEthereum is DeploymentBase {
    /* -------------------------------------------------------------------------- */
    /*                              Ethereum chainIds                             */
    /* -------------------------------------------------------------------------- */
    uint256 internal constant ETH_MAINNET = 1;
    uint256 internal constant ETH_SEPOLIA = 11155111;

    function run() external {
        /* ----------------------------- Chain guard ---------------------------- */
        if (block.chainid != ETH_MAINNET && block.chainid != ETH_SEPOLIA) {
            console.log("[WARNING] Deploying to non-Ethereum chainId", block.chainid);
        }
        
        // Initialize deployment configuration
        DeploymentConfig memory config = initializeDeployment();
        
        // Environment variables
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT");
        uint32 baseEid = uint32(vm.envUint("BASE_EID"));

        address hlg = vm.envAddress("HLG");
        address weth = vm.envAddress("WETH");
        address swapRouter = vm.envAddress("SWAP_ROUTER");
        address treasury = vm.envAddress("TREASURY");

        // Validation
        require(lzEndpoint != address(0), "LZ_ENDPOINT not set");
        require(baseEid != 0, "BASE_EID not set");
        require(hlg != address(0), "HLG not set");
        require(weth != address(0), "WETH not set");
        require(swapRouter != address(0), "SWAP_ROUTER not set");
        require(treasury != address(0), "TREASURY not set");
        
        // Deploy HolographDeployer using base functionality
        HolographDeployer holographDeployer = deployHolographDeployer();
        
        // Get deployment salts - use EOA address as msg.sender for HolographDeployer
        ChainConfigs.DeploymentSalts memory salts = getDeploymentSalts(config.deployer);
        
        // Initialize addresses struct
        ContractAddresses memory addresses;
        addresses.holographDeployer = address(holographDeployer);

        /* ---------------------- Deploy StakingRewards ---------------------- */
        console.log("\nDeploying StakingRewards...");
        uint256 gasStart = gasleft();
        // Deploy with temporary feeRouter = deployer
        bytes memory stakingBytecode = abi.encodePacked(
            type(StakingRewards).creationCode,
            abi.encode(hlg, config.deployer)
        );
        // Use a unique salt for StakingRewards
        bytes32 stakingSalt = bytes32(uint256(uint160(config.deployer)) << 96) | bytes32(uint256(6));
        address stakingRewards = holographDeployer.deploy(stakingBytecode, stakingSalt);
        uint256 gasStaking = gasStart - gasleft();
        console.log("StakingRewards deployed at:", stakingRewards);
        console.log("Gas used:", gasStaking);

        /* ---------------------- Deploy FeeRouter ---------------------- */
        console.log("\nDeploying FeeRouter...");
        gasStart = gasleft();
        bytes memory feeRouterBytecode = abi.encodePacked(
            type(FeeRouter).creationCode,
            abi.encode(
                lzEndpoint,
                baseEid,
                stakingRewards,
                hlg,
                weth,
                swapRouter,
                treasury,
                config.deployer // Set deployer as owner
            )
        );
        address feeRouter = holographDeployer.deploy(feeRouterBytecode, salts.feeRouter);
        uint256 gasFeeRouter = gasStart - gasleft();
        console.log("FeeRouter deployed at:", feeRouter);
        console.log("Gas used:", gasFeeRouter);

        // Update stakingRewards to use actual FeeRouter address
        StakingRewards(stakingRewards).setFeeRouter(feeRouter);
        
        // Store final addresses
        addresses.stakingRewards = stakingRewards;
        addresses.feeRouter = feeRouter;

        vm.stopBroadcast();

        // Print summary and save deployment
        printDeploymentSummary(addresses);
        saveDeployment(config, addresses);
    }
}
