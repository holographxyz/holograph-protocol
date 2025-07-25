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
import "./config/DeploymentConstants.sol";

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

        // Mainnet safety check
        if (DeploymentConstants.isMainnet(block.chainid)) {
            console.log("WARNING: You are about to deploy to MAINNET!");
            console.log("Chain ID:", block.chainid);
            require(vm.envOr("MAINNET", false), "Set MAINNET=true to deploy to mainnet");
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

        // Validate env variables
        DeploymentConstants.validateNonZeroAddress(lzEndpoint, "LZ_ENDPOINT");
        require(baseEid != 0, "BASE_EID not set");
        DeploymentConstants.validateNonZeroAddress(hlg, "HLG");
        DeploymentConstants.validateNonZeroAddress(weth, "WETH");
        DeploymentConstants.validateNonZeroAddress(swapRouter, "SWAP_ROUTER");
        DeploymentConstants.validateNonZeroAddress(treasury, "TREASURY");

        // Validate deployment account has sufficient gas
        require(gasleft() >= DeploymentConstants.MIN_DEPLOYMENT_GAS, "Insufficient gas for deployment");

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
