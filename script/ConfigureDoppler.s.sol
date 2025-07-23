// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ConfigureDoppler
 * @notice Configure HolographFactory for Doppler Airlock integration
 * @dev Sets up Doppler Airlock authorization for token creation
 *
 * Usage:
 *   forge script script/ConfigureDoppler.s.sol \
 *       --rpc-url https://sepolia.base.org \
 *       --broadcast \
 *       --private-key $DEPLOYER_PK
 */

import "forge-std/Script.sol";
import "../src/HolographFactory.sol";
import "forge-std/console.sol";

contract ConfigureDoppler is Script {
    function run() external {
        // Environment variables
        bool shouldBroadcast = vm.envOr("BROADCAST", false);
        uint256 deployerPk = shouldBroadcast ? vm.envUint("DEPLOYER_PK") : uint256(0);
        
        // Contract addresses from deployment
        address factoryAddr = 0x47ca9bEa164E94C38Ec52aB23377dC2072356D10; // HolographFactory proxy
        address dopplerAirlock = 0x3411306Ce66c9469BFF1535BA955503c4Bde1C6e; // Doppler Airlock on Base Sepolia
        
        console.log("=== Configuring Doppler Integration ===");
        console.log("Chain ID:", block.chainid);
        console.log("HolographFactory:", factoryAddr);
        console.log("Doppler Airlock:", dopplerAirlock);
        
        HolographFactory factory = HolographFactory(factoryAddr);
        
        // Check current owner
        address currentOwner = factory.owner();
        console.log("Factory owner:", currentOwner);
        
        if (shouldBroadcast) {
            address deployer = vm.addr(deployerPk);
            console.log("Deployer:", deployer);
            require(currentOwner == deployer, "Deployer is not the factory owner");
            vm.startBroadcast(deployerPk);
        } else {
            console.log("Running in dry-run mode");
            vm.startBroadcast();
        }
        
        // Authorize Doppler Airlock for factory usage
        try factory.setAirlockAuthorization(dopplerAirlock, true) {
            console.log("[OK] Authorized Doppler Airlock for HolographFactory");
        } catch {
            console.log("[WARN] setAirlockAuthorization failed - perhaps already authorized");
        }
        
        // Verify authorization
        bool isAuthorized = factory.authorizedAirlocks(dopplerAirlock);
        console.log("Airlock authorization status:", isAuthorized);
        
        vm.stopBroadcast();
        
        if (isAuthorized) {
            console.log("=== Configuration Complete ===");
            console.log("[OK] HolographFactory is ready for Doppler integration");
            console.log("Next: Test token creation through Doppler Airlock");
        } else {
            console.log("[ERROR] Airlock authorization failed");
        }
    }
}