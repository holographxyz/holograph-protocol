// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title DeployBase
 * @notice Foundry script to deploy FeeRouter and HolographFactory on Base chain
 *
 * Usage examples (from repository root):
 *   // Dry-run against a live fork
 *   forge script script/DeployBase.s.sol \
 *       --fork-url $BASE_RPC
 *
 *   // Broadcast real transactions (requires DEPLOYER_PK)
 *   forge script script/DeployBase.s.sol \
 *       --rpc-url $BASE_RPC \
 *       --broadcast \
 *       --private-key $DEPLOYER_PK
 *
 *   // Verify on Etherscan-style explorer (after propagation)
 *   # fee router
 *   forge verify-contract --chain-id 8453 $(cat deployments/base/FeeRouter.txt) src/FeeRouter.sol:FeeRouter $ETHERSCAN_API_KEY
 *   # erc20 implementation
 *   forge verify-contract --chain-id 8453 $(cat deployments/base/HolographERC20.txt) src/HolographERC20.sol:HolographERC20 $ETHERSCAN_API_KEY
 *   # factory implementation
 *   forge verify-contract --chain-id 8453 $(cat deployments/base/HolographFactory.txt) src/HolographFactory.sol:HolographFactory --constructor-args $(cast abi-encode "constructor(address)" $(cat deployments/base/HolographERC20.txt)) $ETHERSCAN_API_KEY
 *   # factory proxy
 *   forge verify-contract --chain-id 8453 $(cat deployments/base/HolographFactoryProxy.txt) src/HolographFactoryProxy.sol:HolographFactoryProxy --constructor-args $(cast abi-encode "constructor(address)" $(cat deployments/base/HolographFactory.txt)) $ETHERSCAN_API_KEY
 */
import "../src/FeeRouter.sol";
import "../src/HolographFactory.sol";
import "../src/HolographFactoryProxy.sol";
import "../src/HolographERC20.sol";
import "./base/DeploymentBase.sol";
import "./config/DeploymentConstants.sol";

contract DeployBase is DeploymentBase {
    /* -------------------------------------------------------------------------- */
    /*                                Constants                                   */
    /* -------------------------------------------------------------------------- */
    uint256 internal constant BASE_MAINNET = 8453;
    uint256 internal constant BASE_SEPOLIA = 84532;

    /* -------------------------------------------------------------------------- */
    /*                                   Run                                      */
    /* -------------------------------------------------------------------------- */
    function run() external {
        /* ----------------------------- Chain guard ---------------------------- */
        if (block.chainid != BASE_MAINNET && block.chainid != BASE_SEPOLIA) {
            console.log("[WARNING] Chain ID does not match known Base chains");
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
        address dopplerAirlock = vm.envAddress("DOPPLER_AIRLOCK");
        address treasury = vm.envAddress("TREASURY");
        uint32 ethEid = uint32(vm.envUint("ETH_EID"));

        // Validate env variables
        DeploymentConstants.validateNonZeroAddress(lzEndpoint, "LZ_ENDPOINT");
        DeploymentConstants.validateNonZeroAddress(dopplerAirlock, "DOPPLER_AIRLOCK");
        DeploymentConstants.validateNonZeroAddress(treasury, "TREASURY");
        require(ethEid != 0, "ETH_EID not set");

        // Validate deployment account has sufficient gas
        require(gasleft() >= DeploymentConstants.MIN_DEPLOYMENT_GAS, "Insufficient gas for deployment");

        // Gas tracking variable
        uint256 gasStart;

        // Deploy HolographDeployer using base functionality
        HolographDeployer holographDeployer = deployHolographDeployer();

        // Get deployment salts - use EOA address as msg.sender for HolographDeployer
        ChainConfigs.DeploymentSalts memory salts = getDeploymentSalts(config.deployer);

        // Initialize addresses struct
        ContractAddresses memory addresses;
        addresses.holographDeployer = address(holographDeployer);

        /* ---------------------- Deploy HolographERC20 Implementation ---------------------- */
        console.log("\nDeploying HolographERC20 implementation...");
        gasStart = gasleft();
        bytes memory erc20Bytecode = type(HolographERC20).creationCode;
        address erc20Implementation = holographDeployer.deploy(erc20Bytecode, salts.erc20Implementation);
        uint256 gasERC20 = gasStart - gasleft();
        console.log("HolographERC20 deployed at:", erc20Implementation);
        console.log("Gas used:", gasERC20);

        /* ---------------------- Deploy HolographFactory Implementation ---------------------- */
        console.log("\nDeploying HolographFactory implementation...");
        gasStart = gasleft();
        bytes memory factoryBytecode =
            abi.encodePacked(type(HolographFactory).creationCode, abi.encode(erc20Implementation));
        address factoryImpl = holographDeployer.deploy(factoryBytecode, salts.factory);
        uint256 gasFactoryImpl = gasStart - gasleft();
        console.log("HolographFactory deployed at:", factoryImpl);
        console.log("Gas used:", gasFactoryImpl);

        /* ---------------------- Deploy HolographFactory Proxy ---------------------- */
        console.log("\nDeploying HolographFactory proxy...");
        gasStart = gasleft();
        // Use a different salt for proxy to get different address
        bytes32 proxySalt = bytes32(uint256(uint160(config.deployer)) << 96) | bytes32(uint256(6));
        bytes memory proxyBytecode = abi.encodePacked(type(HolographFactoryProxy).creationCode, abi.encode(factoryImpl));
        address factoryProxy = holographDeployer.deploy(proxyBytecode, proxySalt);
        uint256 gasFactoryProxy = gasStart - gasleft();
        console.log("HolographFactory proxy deployed at:", factoryProxy);
        console.log("Gas used:", gasFactoryProxy);

        // Cast proxy to factory interface for initialization
        HolographFactory factory = HolographFactory(factoryProxy);

        // Initialize factory through proxy
        gasStart = gasleft();
        factory.initialize(config.deployer);
        uint256 gasInitialize = gasStart - gasleft();
        console.log("Factory initialized, gas used:", gasInitialize);

        /* ---------------------- Deploy FeeRouter ---------------------- */
        console.log("\nDeploying FeeRouter...");
        gasStart = gasleft();
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
                config.deployer // Set deployer as owner
            )
        );
        address feeRouter = holographDeployer.deploy(feeRouterBytecode, salts.feeRouter);
        uint256 gasFeeRouter = gasStart - gasleft();
        console.log("FeeRouter deployed at:", feeRouter);
        console.log("Gas used:", gasFeeRouter);

        // Store final addresses
        addresses.holographERC20 = erc20Implementation;
        addresses.holographFactory = factoryImpl;
        addresses.holographFactoryProxy = factoryProxy;
        addresses.feeRouter = feeRouter;

        vm.stopBroadcast();

        // Print summary and save deployment
        printDeploymentSummary(addresses);
        saveDeployment(config, addresses);
    }
}
