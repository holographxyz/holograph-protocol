// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Hooks} from "lib/doppler/lib/v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "lib/doppler/lib/v4-core/src/PoolManager.sol";
import {ITokenFactory} from "src/interfaces/ITokenFactory.sol";
import {IPoolInitializer} from "src/interfaces/IPoolInitializer.sol";
import {DERC20} from "lib/doppler/src/DERC20.sol";
import {Doppler} from "lib/doppler/src/Doppler.sol";
import {Airlock} from "lib/doppler/src/Airlock.sol";

// mask to slice out the bottom 14 bit of the address
uint160 constant FLAG_MASK = 0x3FFF;

// Maximum number of iterations to find a salt, avoid infinite loops
uint256 constant MAX_LOOP = 1_000_000;

uint160 constant flags = uint160(
    Hooks.BEFORE_INITIALIZE_FLAG |
        Hooks.AFTER_INITIALIZE_FLAG |
        Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
        Hooks.BEFORE_SWAP_FLAG |
        Hooks.AFTER_SWAP_FLAG |
        Hooks.BEFORE_DONATE_FLAG
);

struct MineV4Params {
    address airlock;
    address poolManager;
    uint256 initialSupply;
    uint256 numTokensToSell;
    address numeraire;
    ITokenFactory tokenFactory;
    bytes tokenFactoryData;
    IPoolInitializer poolInitializer; // Changed from UniswapV4Initializer to IPoolInitializer
    bytes poolInitializerData;
}

interface IDeployer {
    function deployer() external view returns (address);
}

function mineV4Local(MineV4Params memory params) view returns (bytes32, address, address) {
    (
        uint256 minimumProceeds,
        uint256 maximumProceeds,
        uint256 startingTime,
        uint256 endingTime,
        int24 startingTick,
        int24 endingTick,
        uint256 epochLength,
        int24 gamma,
        bool isToken0,
        uint256 numPDSlugs,
        uint24 lpFee,
        int24 tickSpacing
    ) = abi.decode(
            params.poolInitializerData,
            (uint256, uint256, uint256, uint256, int24, int24, uint256, int24, bool, uint256, uint24, int24)
        );

    bytes32 dopplerInitHash = keccak256(
        abi.encodePacked(
            type(Doppler).creationCode,
            abi.encode(
                params.poolManager,
                params.numTokensToSell,
                minimumProceeds,
                maximumProceeds,
                startingTime,
                endingTime,
                startingTick,
                endingTick,
                epochLength,
                gamma,
                isToken0,
                numPDSlugs,
                params.poolInitializer,
                lpFee,
                false, // beforeSwapReturnDelta permission (unused in hash mining)
                false // afterSwapReturnDelta permission (unused in hash mining)
            )
        )
    );

    (
        string memory name,
        string memory symbol,
        uint256 yearlyMintCap,
        uint256 vestingDuration,
        address[] memory recipients,
        uint256[] memory amounts,
        string memory tokenURI
    ) = abi.decode(params.tokenFactoryData, (string, string, uint256, uint256, address[], uint256[], string));

    bytes32 tokenInitHash = keccak256(
        abi.encodePacked(
            type(DERC20).creationCode,
            abi.encode(
                name,
                symbol,
                params.initialSupply,
                params.airlock,
                params.airlock,
                yearlyMintCap,
                vestingDuration,
                recipients,
                amounts,
                tokenURI
            )
        )
    );

    for (uint256 salt; salt < MAX_LOOP; ++salt) {
        address hook = computeCreate2Address(
            bytes32(salt),
            dopplerInitHash,
            address(IDeployer(address(params.poolInitializer)).deployer()) // Use IDeployer to get deployer address
        );
        address asset = computeCreate2Address(bytes32(salt), tokenInitHash, address(params.tokenFactory));

        if (
            uint160(hook) & FLAG_MASK == flags &&
            hook.code.length == 0 &&
            ((isToken0 && asset < params.numeraire) || (!isToken0 && asset > params.numeraire))
        ) {
            console.log("Found salt: %s", salt);
            return (bytes32(salt), hook, asset);
        }
    }

    revert("AirlockMiner: could not find salt");
}

function computeCreate2Address(bytes32 salt, bytes32 initCodeHash, address deployer) pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));
}
