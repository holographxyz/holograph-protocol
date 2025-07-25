// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/HolographFactory.sol";
import "../src/interfaces/IAirlock.sol";
import {CreateParams} from "../src/interfaces/DopplerStructs.sol";
import {ITokenFactory} from "../src/interfaces/external/doppler/ITokenFactory.sol";
import {IGovernanceFactory} from "../src/interfaces/IGovernanceFactory.sol";
import {IPoolInitializer} from "../src/interfaces/IPoolInitializer.sol";
import {ILiquidityMigrator} from "../src/interfaces/ILiquidityMigrator.sol";

contract TestTokenCreation is Script {
    function run() external {
        // Use Base Sepolia testnet
        vm.createSelectFork("https://sepolia.base.org");

        // Doppler Airlock address - update with actual address when available
        IAirlock airlock = IAirlock(0x742D35cC6634C0532925a3b8D4014dd1C4D9dC07);

        // HolographFactory address (must be whitelisted by Doppler)
        address holographFactory = 0x5290Bee84DC83AC667cF9573eC1edC6FE38eFe50;

        // FeeRouter as integrator
        address feeRouter = 0x10F2c0fdc9799A293b4C726a1314BD73A4AB9f20;

        // Test account (replace with your actual account)
        address testAccount = 0x5f5C3548f96C7DA33A18E5F2F2f13519e1c8bD0d;

        // Prepare test token factory data for HolographERC20
        bytes memory tokenFactoryData = abi.encode(
            "Test Holograph Token",
            "THT",
            18, // decimals
            1000000 ether, // initialSupply
            new address[](0), // minters (empty)
            new uint256[](0), // mintAmounts (empty)
            "https://metadata.example.com/test-token" // tokenURI
        );

        bytes memory governanceData = abi.encode("Test Token DAO", 7200, 50_400, 0);

        uint256 currentTime = block.timestamp;
        bytes memory poolInitializerData = abi.encode(
            100 ether, // minProceeds
            10000 ether, // maxProceeds
            currentTime,
            currentTime + 3 days,
            6000, // startTick
            60000, // endTick
            400, // epochLength
            800, // gamma
            false, // isToken0
            8, // numPDSlugs
            3000, // fee
            8 // tickSpacing
        );

        CreateParams memory params = CreateParams({
            initialSupply: 1000000 ether,
            numTokensToSell: 500000 ether,
            numeraire: address(0), // ETH
            tokenFactory: ITokenFactory(holographFactory), // Use our HolographFactory
            tokenFactoryData: tokenFactoryData,
            governanceFactory: IGovernanceFactory(0x9dBFaaDC8c0cB2c34bA698DD9426555336992e20), // Doppler governance factory
            governanceFactoryData: governanceData,
            poolInitializer: IPoolInitializer(0xca2079706A4c2a4a1aA637dFB47d7f27Fe58653F), // Doppler pool initializer
            poolInitializerData: poolInitializerData,
            liquidityMigrator: ILiquidityMigrator(0x04a898f3722c38F9Def707bD17DC78920EFA977C), // Doppler migrator
            liquidityMigratorData: "",
            integrator: feeRouter, // FeeRouter as integrator
            salt: bytes32(uint256(12345)) // Test salt
        });

        vm.startPrank(testAccount);

        try airlock.create(params) returns (
            address asset, address pool, address governance, address timelock, address migrationPool
        ) {
            console.log("Token creation successful!");
            console.log("Asset (HolographERC20):", asset);
            console.log("Pool:", pool);
            console.log("Governance:", governance);
            console.log("Timelock:", timelock);
            console.log("Migration Pool:", migrationPool);
        } catch Error(string memory reason) {
            console.log("Error:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("Low level error data:");
            console.logBytes(lowLevelData);
        }

        vm.stopPrank();
    }
}
