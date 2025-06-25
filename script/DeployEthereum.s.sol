// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/FeeRouter.sol";
import "../src/StakingRewards.sol";

contract DeployEthereum is Script {
    /* -------------------------------------------------------------------------- */
    /*                              Ethereum chainIds                             */
    /* -------------------------------------------------------------------------- */
    uint256 internal constant ETH_MAINNET = 1;
    uint256 internal constant ETH_SEPOLIA = 11155111;

    function run() external {
        /* -------------------------------- Env --------------------------------- */
        // Optional BROADCAST env var allows running the script in dry-run mode without
        // passing the `--broadcast` flag each time. When BROADCAST is set to true the
        // DEPLOYER_PK env var must also be supplied so the txs can be signed.
        bool shouldBroadcast = vm.envOr("BROADCAST", false);

        uint256 deployerPk = shouldBroadcast ? vm.envUint("DEPLOYER_PK") : uint256(0);
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

        if (block.chainid != ETH_MAINNET && block.chainid != ETH_SEPOLIA) {
            console.log("[WARNING] Deploying to non-Ethereum chainId", block.chainid);
        }

        // Deployer address is needed both for logging and as a temporary FeeRouter placeholder
        address deployer = shouldBroadcast ? vm.addr(deployerPk) : msg.sender;

        if (shouldBroadcast) {
            console.log("Broadcasting TXs as", deployer);
            vm.startBroadcast(deployerPk);
        } else {
            console.log("Running in dry-run mode (no broadcast)");
            vm.startBroadcast();
        }

        uint256 gasStart = gasleft();
        // Deploy StakingRewards first with temporary feeRouter = deployer
        StakingRewards stakingRewards = new StakingRewards(hlg, deployer);
        uint256 gasStaking = gasStart - gasleft();

        gasStart = gasleft();
        // Deploy FeeRouter with staking pool address
        FeeRouter feeRouter = new FeeRouter(
            lzEndpoint,
            baseEid,
            address(stakingRewards),
            hlg,
            weth,
            swapRouter,
            treasury
        );
        uint256 gasFeeRouter = gasStart - gasleft();

        // Update stakingRewards to use actual FeeRouter address
        stakingRewards.setFeeRouter(address(feeRouter));

        vm.stopBroadcast();

        console.log("-------------- Deployment Complete --------------");
        console.log("StakingRewards:", address(stakingRewards));
        console.log("Gas used:", gasStaking);
        console.log("FeeRouter:", address(feeRouter));
        console.log("Gas used:", gasFeeRouter);

        // Persist addresses to deployments/eth/
        string memory dir = "deployments/eth";
        vm.createDir(dir, true);
        vm.writeFile(string.concat(dir, "/StakingRewards.txt"), vm.toString(address(stakingRewards)));
        vm.writeFile(string.concat(dir, "/FeeRouter.txt"), vm.toString(address(feeRouter)));
    }
}
