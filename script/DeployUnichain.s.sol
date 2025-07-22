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

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/HolographFactory.sol";
import "../src/HolographFactoryProxy.sol";
import "../src/HolographERC20.sol";

contract DeployUnichain is Script {
    /* -------------------------------------------------------------------------- */
    /*                                Constants                                   */
    /* -------------------------------------------------------------------------- */
    uint256 internal constant UNICHAIN_MAINNET = 1301;
    uint256 internal constant UNICHAIN_SEPOLIA = 1301;  // Update when Unichain Sepolia is available
    

    /* -------------------------------------------------------------------------- */
    /*                                   Run                                      */
    /* -------------------------------------------------------------------------- */
    function run() external {
        /* -------------------------------- Env --------------------------------- */
        // Toggle on-chain broadcasting via env var so we don't need to pass `--broadcast` every run
        bool shouldBroadcast = vm.envOr("BROADCAST", false);

        // Only require / read the private key if we intend to broadcast
        uint256 deployerPk = shouldBroadcast ? vm.envUint("DEPLOYER_PK") : uint256(0);

        // Quick sanity checks

        /* ----------------------------- Chain guard ---------------------------- */
        if (block.chainid != UNICHAIN_MAINNET && block.chainid != UNICHAIN_SEPOLIA) {
            console.log("[WARNING] Chain ID does not match known Unichain chains");
        }

        console.log("Deploying to chainId", block.chainid);
        if (shouldBroadcast) {
            console.log("Broadcasting TXs as", vm.addr(deployerPk));
            vm.startBroadcast(deployerPk);
        } else {
            console.log("Running in dry-run mode (no broadcast)");
            vm.startBroadcast();
        }

        // Get the deployer address (works for both broadcast and dry-run)
        address deployer = vm.addr(deployerPk != 0 ? deployerPk : 1);

        uint256 gasStart = gasleft();
        // Deploy HolographERC20 implementation (for cloning)
        HolographERC20 erc20Implementation = new HolographERC20();
        uint256 gasERC20 = gasStart - gasleft();

        gasStart = gasleft();
        // Deploy HolographFactory implementation with ERC20 implementation address
        HolographFactory factoryImpl = new HolographFactory(address(erc20Implementation));
        uint256 gasFactoryImpl = gasStart - gasleft();

        gasStart = gasleft();
        // Deploy HolographFactoryProxy pointing to implementation
        HolographFactoryProxy factoryProxy = new HolographFactoryProxy(address(factoryImpl));
        uint256 gasFactoryProxy = gasStart - gasleft();

        // Cast proxy to factory interface for initialization
        HolographFactory factory = HolographFactory(address(factoryProxy));
        
        gasStart = gasleft();
        // Initialize factory through proxy
        factory.initialize(deployer);
        uint256 gasInitialize = gasStart - gasleft();


        vm.stopBroadcast();

        console.log("---------------- Deployment Complete ----------------");
        console.log("HolographERC20 implementation:", address(erc20Implementation));
        console.log("Gas used:", gasERC20);
        console.log("");
        console.log("HolographFactory implementation:", address(factoryImpl));
        console.log("Gas used:", gasFactoryImpl);
        console.log("");
        console.log("HolographFactory proxy:", address(factoryProxy));
        console.log("Gas used:", gasFactoryProxy);
        console.log("Initialize gas used:", gasInitialize);

        /* ----------------------- Persist addresses locally -------------------- */
        // Creates simple text files with addresses under deployments/unichain/
        string memory dir = "deployments/unichain";
        vm.createDir(dir, true);
        vm.writeFile(string.concat(dir, "/HolographERC20.txt"), vm.toString(address(erc20Implementation)));
        vm.writeFile(string.concat(dir, "/HolographFactory.txt"), vm.toString(address(factoryImpl)));
        vm.writeFile(string.concat(dir, "/HolographFactoryProxy.txt"), vm.toString(address(factoryProxy)));
    }
}