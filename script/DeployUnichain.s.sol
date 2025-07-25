// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title DeployUnichain
 * @notice Foundry script to deploy HolographFactory on Unichain
 * @dev Deploys factory with proxy pattern for token creation
 *
 * Usage examples (from repository root):
 *   // Dry-run against a live fork
 *   forge script script/DeployUnichain.s.sol \
 *       --fork-url $UNICHAIN_RPC
 *
 *   // Broadcast real transactions (requires DEPLOYER_PK)
 *   forge script script/DeployUnichain.s.sol \
 *       --rpc-url $UNICHAIN_RPC \
 *       --broadcast \
 *       --private-key $DEPLOYER_PK
 *
 *   // Verify on explorer (after propagation)
 *   # erc20 implementation
 *   forge verify-contract --chain-id 1301 $(cat deployments/unichain/HolographERC20.txt) src/HolographERC20.sol:HolographERC20 $UNISCAN_API_KEY
 *   # factory implementation
 *   forge verify-contract --chain-id 1301 $(cat deployments/unichain/HolographFactory.txt) src/HolographFactory.sol:HolographFactory --constructor-args $(cast abi-encode "constructor(address)" $(cat deployments/unichain/HolographERC20.txt)) $UNISCAN_API_KEY
 *   # factory proxy
 *   forge verify-contract --chain-id 1301 $(cat deployments/unichain/HolographFactoryProxy.txt) src/HolographFactoryProxy.sol:HolographFactoryProxy --constructor-args $(cast abi-encode "constructor(address)" $(cat deployments/unichain/HolographFactory.txt)) $UNISCAN_API_KEY
 */
import "../src/HolographFactory.sol";
import "../src/HolographFactoryProxy.sol";
import "../src/HolographERC20.sol";
import "./base/DeploymentBase.sol";

contract DeployUnichain is DeploymentBase {
    /* -------------------------------------------------------------------------- */
    /*                                Constants                                   */
    /* -------------------------------------------------------------------------- */
    uint256 internal constant UNICHAIN_MAINNET = 1301;
    uint256 internal constant UNICHAIN_SEPOLIA = 1301; // Update when Unichain Sepolia is available

    /* -------------------------------------------------------------------------- */
    /*                                   Run                                      */
    /* -------------------------------------------------------------------------- */
    function run() external {
        /* ----------------------------- Chain guard ---------------------------- */
        if (block.chainid != UNICHAIN_MAINNET && block.chainid != UNICHAIN_SEPOLIA) {
            console.log("[WARNING] Chain ID does not match known Unichain chains");
        }

        // Initialize deployment configuration
        DeploymentConfig memory config = initializeDeployment();

        // Deploy HolographDeployer using base functionality
        HolographDeployer holographDeployer = deployHolographDeployer();

        // Get deployment salts - use EOA address as msg.sender for HolographDeployer
        ChainConfigs.DeploymentSalts memory salts = getDeploymentSalts(config.deployer);

        // Initialize addresses struct
        ContractAddresses memory addresses;
        addresses.holographDeployer = address(holographDeployer);

        /* ---------------------- Deploy HolographERC20 Implementation ---------------------- */
        console.log("\nDeploying HolographERC20 implementation...");
        uint256 gasStart = gasleft();
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

        // Store final addresses
        addresses.holographERC20 = erc20Implementation;
        addresses.holographFactory = factoryImpl;
        addresses.holographFactoryProxy = factoryProxy;

        vm.stopBroadcast();

        // Print summary and save deployment
        printDeploymentSummary(addresses);
        saveDeployment(config, addresses);
    }
}
