// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title Configure
 * @notice Post-deployment configuration for FeeRouter contracts.
 *
 * Functions performed:
 *   • setTrustedRemote on the active FeeRouter (points to the remote FeeRouter)
 *   • grantRole(KEEPER_ROLE) to keeper automation address
 *   • setTrustedAirlock() for Doppler Airlock contracts
 *
 * Usage (example for Base chain):
 *   forge script script/Configure.s.sol \
 *       --rpc-url $BASE_RPC \
 *       --broadcast \
 *       --private-key $DEPLOYER_PK
 *
 * Required ENV (executed per-chain):
 *   FEE_ROUTER          – address of FeeRouter on the chain this script is run against
 *   HOLOGRAPH_FACTORY   – address of HolographFactory on this chain
 *   REMOTE_FEE_ROUTER   – address of the FeeRouter on the opposite chain
 *   REMOTE_FACTORY      – address of HolographFactory on remote chain
 *   REMOTE_EID          – uint of remote chain LayerZero endpoint ID
 *   KEEPER_ADDRESS      – address receiving KEEPER_ROLE
 *   DOPPLER_AIRLOCK     – address of trusted Doppler Airlock contract (add more via code)
 */
import "forge-std/Script.sol";
import "../src/FeeRouter.sol";
import "../src/HolographFactory.sol";
import "./DeploymentConfig.sol";
import "forge-std/console.sol";

contract Configure is Script {
    function run() external {
        /* ------------------------------ env vars ----------------------------- */
        bool shouldBroadcast = vm.envOr("BROADCAST", false);

        // DEPLOYER_PK only required if we intend to broadcast real transactions
        uint256 deployerPk = shouldBroadcast ? vm.envUint("DEPLOYER_PK") : uint256(0);

        address payable feeRouterAddr = payable(vm.envAddress("FEE_ROUTER"));
        address factoryAddr = vm.envAddress("HOLOGRAPH_FACTORY");
        address remoteRouter = vm.envAddress("REMOTE_FEE_ROUTER");
        address remoteFactory = vm.envAddress("REMOTE_FACTORY");
        uint32 remoteEid = uint32(vm.envUint("REMOTE_EID"));
        address keeper = vm.envAddress("KEEPER_ADDRESS");
        address dopplerAirlock = vm.envAddress("DOPPLER_AIRLOCK");

        // Validation
        require(feeRouterAddr != address(0), "FEE_ROUTER env missing");
        require(factoryAddr != address(0), "HOLOGRAPH_FACTORY env missing");
        require(remoteRouter != address(0), "REMOTE_FEE_ROUTER env missing");
        require(remoteFactory != address(0), "REMOTE_FACTORY env missing");
        require(remoteEid != 0, "REMOTE_EID env missing");
        require(keeper != address(0), "KEEPER_ADDRESS env missing");
        require(dopplerAirlock != address(0), "DOPPLER_AIRLOCK env missing");

        FeeRouter router = FeeRouter(feeRouterAddr);
        HolographFactory factory = HolographFactory(factoryAddr);

        console.log("Configuring FeeRouter at", feeRouterAddr);
        console.log("Configuring HolographFactory at", factoryAddr);

        if (shouldBroadcast) {
            vm.startBroadcast(deployerPk);
        } else {
            console.log("Running in dry-run mode (no broadcast)");
            vm.startBroadcast();
        }

        /* ------------------------- Trusted Remote -------------------------- */
        bytes32 remoteBytes32 = bytes32(uint256(uint160(remoteRouter)));
        router.setTrustedRemote(remoteEid, remoteBytes32);
        console.log("Trusted remote set (eid -> addr):", remoteEid, remoteRouter);

        /* ---------------------------- KEEPER ------------------------------- */
        // Note: KEEPER_ROLE removed - all functions are now owner-only
        console.log("FeeRouter functions are owner-only, no keeper role needed");

        /* ------------------------- Trusted Airlocks ------------------------ */
        try router.setTrustedAirlock(dopplerAirlock, true) {
            console.log("Whitelisted Doppler Airlock", dopplerAirlock);
        } catch {
            console.log("[WARN] setTrustedAirlock failed - perhaps already trusted");
        }

        /* ----------------------- Factory Configuration ---------------------- */
        try factory.setAirlockAuthorization(dopplerAirlock, true) {
            console.log("Authorized Doppler Airlock for HolographFactory", dopplerAirlock);
        } catch {
            console.log("[WARN] setAirlockAuthorization failed - perhaps already authorized");
        }

        /* -------------------- LayerZero Gas Configuration ------------------- */
        configureLayerZeroGas(router, remoteEid);

        vm.stopBroadcast();
    }

    /**
     * @notice Configure LayerZero gas settings for reliable cross-chain execution
     * @param router FeeRouter instance
     * @param remoteEid Remote endpoint ID
     */
    function configureLayerZeroGas(FeeRouter router, uint32 remoteEid) internal {
        console.log("\nConfiguring LayerZero gas settings...");

        // Get recommended gas limit for the current chain
        uint256 gasLimit = DeploymentConfig.getLzReceiveGasLimit(block.chainid);

        console.log("Recommended gas limit for lzReceive:", gasLimit);
        console.log("Remote endpoint ID:", remoteEid);

        // Note: Enforced options should be configured via LayerZero endpoint
        // This is typically done in a separate DVN configuration step
        console.log("To set enforced options, use the ConfigureDVN script:");
        console.log("  forge script script/ConfigureDVN.s.sol --broadcast");

        // Log current bridge settings for verification
        try router.quoteBridgeFee(gasLimit) returns (uint256 fee) {
            console.log("Current bridge fee estimate:", fee, "wei");
        } catch {
            console.log("[INFO] Bridge fee quote not available (remote not configured)");
        }
    }
}
