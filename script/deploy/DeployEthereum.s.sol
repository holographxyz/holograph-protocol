// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

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
import "../../src/FeeRouter.sol";
import "../../src/StakingRewards.sol";
import "../DeploymentBase.sol";
import "../DeploymentConfig.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployEthereum is DeploymentBase {
    /* -------------------------------------------------------------------------- */
    /*                              Ethereum chainIds                             */
    /* -------------------------------------------------------------------------- */
    // Chain IDs moved to DeploymentConfig

    function run() external {
        /* ----------------------------- Chain guard ---------------------------- */
        if (block.chainid != DeploymentConfig.ETHEREUM_MAINNET && block.chainid != DeploymentConfig.ETHEREUM_SEPOLIA) {
            console.log("[WARNING] Deploying to non-Ethereum chainId", block.chainid);
        }

        // Mainnet safety check
        if (DeploymentConfig.isMainnet(block.chainid)) {
            console.log("WARNING: You are about to deploy to MAINNET!");
            console.log("Chain ID:", block.chainid);
            require(vm.envOr("MAINNET", false), "Set MAINNET=true to deploy to mainnet");
        }

        // Initialize deployment configuration
        BaseDeploymentConfig memory config = initializeDeployment();

        // Environment variables
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT");
        uint32 baseEid = uint32(vm.envUint("BASE_EID"));

        address hlg = vm.envAddress("HLG");
        address weth = vm.envAddress("WETH");
        address swapRouter = vm.envAddress("SWAP_ROUTER");
        address treasury = vm.envAddress("TREASURY");

        // Validate env variables
        DeploymentConfig.validateNonZeroAddress(lzEndpoint, "LZ_ENDPOINT");
        require(baseEid != 0, "BASE_EID not set");
        DeploymentConfig.validateNonZeroAddress(hlg, "HLG");
        DeploymentConfig.validateNonZeroAddress(weth, "WETH");
        DeploymentConfig.validateNonZeroAddress(swapRouter, "SWAP_ROUTER");
        DeploymentConfig.validateNonZeroAddress(treasury, "TREASURY");

        // Validate deployment account has sufficient gas
        require(gasleft() >= DeploymentConfig.MIN_DEPLOYMENT_GAS, "Insufficient gas for deployment");

        // Deploy HolographDeployer using base functionality
        HolographDeployer holographDeployer = deployHolographDeployer();

        // Get deployment salts - use EOA address as msg.sender for HolographDeployer
        // Generate universal deployment salt
        bytes32 salt = DeploymentConfig.generateSalt(config.deployer);

        // Initialize addresses struct
        ContractAddresses memory addresses;
        addresses.holographDeployer = address(holographDeployer);

        /* ---------------------- Deploy StakingRewards (UUPS Proxy) ---------------------- */
        console.log("\nDeploying StakingRewards implementation...");
        uint256 gasStart = gasleft();

        // Deploy implementation (no constructor args needed)
        bytes memory stakingImplBytecode = abi.encodePacked(type(StakingRewards).creationCode);
        address stakingImpl = holographDeployer.deploy(stakingImplBytecode, salt);
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
        address stakingProxy = holographDeployer.deploy(proxyBytecode, salt);
        uint256 gasProxy = gasStart - gasleft();
        address stakingRewards = stakingProxy; // Use proxy as the main contract address
        console.log("StakingRewards proxy deployed at:", stakingRewards);
        console.log("Gas used for proxy:", gasProxy);
        console.log("Total StakingRewards gas:", gasImpl + gasProxy);

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
        address feeRouter = holographDeployer.deploy(feeRouterBytecode, salt);
        uint256 gasFeeRouter = gasStart - gasleft();
        console.log("FeeRouter deployed at:", feeRouter);
        console.log("Gas used:", gasFeeRouter);

        // Update stakingRewards to use actual FeeRouter address
        StakingRewards(payable(stakingRewards)).setFeeRouter(feeRouter);

        // NOTE: StakingRewards remains paused after deployment
        // Run `cast send <stakingRewards> "unpause()" --private-key <owner_key>` to activate

        // Store final addresses
        addresses.stakingRewards = stakingRewards; // This is the proxy address
        addresses.stakingRewardsImpl = stakingImpl; // Store implementation address separately
        addresses.feeRouter = feeRouter;

        vm.stopBroadcast();

        // Print summary and save deployment
        printDeploymentSummary(addresses);
        saveDeployment(config, addresses);
    }
}
