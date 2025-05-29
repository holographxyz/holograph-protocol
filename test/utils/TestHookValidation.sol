// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Hooks as HooksLib} from "lib/doppler/lib/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "lib/doppler/lib/v4-core/src/libraries/LPFeeLibrary.sol";
import {IHooks} from "lib/doppler/lib/v4-core/src/interfaces/IHooks.sol";
import {AirlockValidatorStub} from "./AirlockValidatorStub.sol";

contract TestHookValidation is Test {
    function setUp() public {
        // No setup needed
    }

    function test_hookValidation() public {
        AirlockValidatorStub validator = new AirlockValidatorStub();

        // Test with a known valid hook address
        address validHook = makeAddr("validHook");
        // Set the correct flags - simulate what Uniswap V4 requires
        // Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_INITIALIZE_FLAG | etc.
        uint160 mask = uint160(
            HooksLib.BEFORE_INITIALIZE_FLAG |
                HooksLib.AFTER_INITIALIZE_FLAG |
                HooksLib.BEFORE_ADD_LIQUIDITY_FLAG |
                HooksLib.BEFORE_SWAP_FLAG |
                HooksLib.AFTER_SWAP_FLAG |
                HooksLib.BEFORE_DONATE_FLAG
        );

        // Modify the hook address to have the correct flags in lower bits
        validHook = address((uint160(validHook) & ~uint160(0x3FFF)) | mask);

        console.log("Testing hook address:", validHook);
        console.log("Hook address flags (lower 14 bits):", uint160(validHook) & 0x3FFF);

        // Test with dynamic fee flag set to 0 (standard pool)
        try validator.validateHook(validHook, 0) {
            console.log("Hook validation passed with fee 0!");
        } catch Error(string memory reason) {
            console.log("Hook validation failed:", reason);
        }

        // Test with LPFeeLibrary.DYNAMIC_FEE_FLAG
        try validator.validateHook(validHook, LPFeeLibrary.DYNAMIC_FEE_FLAG) {
            console.log("Hook validation passed with DYNAMIC_FEE_FLAG!");
        } catch Error(string memory reason) {
            console.log("Hook validation failed with DYNAMIC_FEE_FLAG:", reason);
        }

        // Test standard validity check using HooksLib
        bool isValidHook = HooksLib.isValidHookAddress(IHooks(validHook), 0);
        console.log("HooksLib.isValidHookAddress with fee 0:", isValidHook);

        isValidHook = HooksLib.isValidHookAddress(IHooks(validHook), LPFeeLibrary.DYNAMIC_FEE_FLAG);
        console.log("HooksLib.isValidHookAddress with DYNAMIC_FEE_FLAG:", isValidHook);
    }
}
