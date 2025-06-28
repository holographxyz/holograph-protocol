// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/HolographFactory.sol";
import {CreateParams} from "../src/interfaces/DopplerStructs.sol";
import "../src/interfaces/ITokenFactory.sol";
import "../src/interfaces/IGovernanceFactory.sol";
import "../src/interfaces/IPoolInitializer.sol";
import "../src/interfaces/ILiquidityMigrator.sol";

contract TestTokenCreation is Script {
    function run() external {
        // Use Base Sepolia testnet
        vm.createSelectFork("https://sepolia.base.org");

        // Deployed HolographFactory address
        HolographFactory factory = HolographFactory(0x5290Bee84DC83AC667cF9573eC1edC6FE38eFe50);

        // Test account (replace with your actual account)
        address testAccount = 0x5f5C3548f96C7DA33A18E5F2F2f13519e1c8bD0d;

        // Prepare test data similar to the script
        bytes memory tokenFactoryData = abi.encode(
            "Standard Token",
            "STD",
            0,
            0,
            new address[](0),
            new uint256[](0),
            "TOKEN_URI"
        );

        bytes memory governanceData = abi.encode("Standard Token DAO", 7200, 50_400, 0);

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
            initialSupply: 100000 ether,
            numTokensToSell: 100000 ether,
            numeraire: address(0),
            tokenFactory: ITokenFactory(0xAd62fc9eEbbDC2880c0d4499B0660928d13405cE),
            tokenFactoryData: tokenFactoryData,
            governanceFactory: IGovernanceFactory(0xff02a43A90c25941f8c5f4917eaD79EB33C3011C),
            governanceFactoryData: governanceData,
            poolInitializer: IPoolInitializer(0x511b44b4cC8Cb80223F203E400309b010fEbFAec),
            poolInitializerData: poolInitializerData,
            liquidityMigrator: ILiquidityMigrator(0x8f4814999D2758ffA69689A37B0ce225C1eEcBFf),
            liquidityMigratorData: "",
            integrator: address(0),
            salt: bytes32(uint256(10422))
        });

        vm.startPrank(testAccount);

        try factory.createToken(params) returns (address asset) {
            console.log("Token created successfully at:", asset);
        } catch Error(string memory reason) {
            console.log("Error:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("Low level error data:");
            console.logBytes(lowLevelData);
        }

        vm.stopPrank();
    }
}
