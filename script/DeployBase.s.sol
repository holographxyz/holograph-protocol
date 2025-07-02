// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
 *   # factory
 *   forge verify-contract --chain-id 8453 $(cat deployments/base/HolographFactory.txt) src/HolographFactory.sol:HolographFactory $ETHERSCAN_API_KEY
 */

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/FeeRouter.sol";
import "../src/HolographFactory.sol";

contract DeployBase is Script {
    /* -------------------------------------------------------------------------- */
    /*                                Constants                                   */
    /* -------------------------------------------------------------------------- */
    uint256 internal constant BASE_MAINNET = 8453;
    uint256 internal constant BASE_SEPOLIA = 84532;

    /* -------------------------------------------------------------------------- */
    /*                                   Run                                      */
    /* -------------------------------------------------------------------------- */
    function run() external {
        /* -------------------------------- Env --------------------------------- */
        // Toggle on-chain broadcasting via env var so we don't need to pass `--broadcast` every run
        bool shouldBroadcast = vm.envOr("BROADCAST", false);

        // Only require / read the private key if we intend to broadcast
        uint256 deployerPk = shouldBroadcast ? vm.envUint("DEPLOYER_PK") : uint256(0);

        address lzEndpoint = vm.envAddress("LZ_ENDPOINT");
        address dopplerAirlock = vm.envAddress("DOPPLER_AIRLOCK");
        address treasury = vm.envAddress("TREASURY");
        uint32 ethEid = uint32(vm.envUint("ETH_EID"));

        // Quick sanity checks
        require(lzEndpoint != address(0), "LZ_ENDPOINT not set");
        require(dopplerAirlock != address(0), "DOPPLER_AIRLOCK not set");
        require(treasury != address(0), "TREASURY not set");
        require(ethEid != 0, "ETH_EID not set");

        /* ----------------------------- Chain guard ---------------------------- */
        if (block.chainid != BASE_MAINNET && block.chainid != BASE_SEPOLIA) {
            console.log("[WARNING] Chain ID does not match known Base chains");
        }

        console.log("Deploying to chainId", block.chainid);
        if (shouldBroadcast) {
            console.log("Broadcasting TXs as", vm.addr(deployerPk));
            vm.startBroadcast(deployerPk);
        } else {
            console.log("Running in dry-run mode (no broadcast)");
            vm.startBroadcast();
        }

        uint256 gasStart = gasleft();
        // Deploy FeeRouter – on Base chain we pass zero addresses for Ethereum-specific params
        FeeRouter feeRouter = new FeeRouter(
            lzEndpoint,
            ethEid,
            address(0), // stakingRewards (none on Base)
            address(0), // HLG token (none on Base)
            address(0), // WETH (unused on Base for this contract)
            address(0), // SwapRouter (unused)
            treasury
        );
        uint256 gasFeeRouter = gasStart - gasleft();

        gasStart = gasleft();
        // Deploy HolographFactory – sets FeeRouter as integrator automatically
        HolographFactory factory = new HolographFactory(lzEndpoint, dopplerAirlock, address(feeRouter));
        uint256 gasFactory = gasStart - gasleft();

        vm.stopBroadcast();

        console.log("---------------- Deployment Complete ----------------");
        console.log("FeeRouter deployed at:", address(feeRouter));
        console.log("Gas used:", gasFeeRouter);
        console.log("HolographFactory deployed at:", address(factory));
        console.log("Gas used:", gasFactory);

        /* ----------------------- Persist addresses locally -------------------- */
        // Creates simple text files with addresses under deployments/base/
        string memory dir = "deployments/base";
        vm.createDir(dir, true);
        vm.writeFile(string.concat(dir, "/FeeRouter.txt"), vm.toString(address(feeRouter)));
        vm.writeFile(string.concat(dir, "/HolographFactory.txt"), vm.toString(address(factory)));
    }
}
