// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Hooks as HooksLib} from "lib/doppler/lib/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "lib/doppler/lib/v4-core/src/interfaces/IHooks.sol";
import {LPFeeLibrary} from "lib/doppler/lib/v4-core/src/libraries/LPFeeLibrary.sol";

error HookAddressNotValid(address hook);

/**
 * A stub that replicates the hook validation logic used in Uniswap V4
 */
contract AirlockValidatorStub {
    /**
     * @notice Validate if a hook address is valid for Uniswap V4
     * @param hook Address of the hook to validate
     * @param fee The fee tier to use
     */
    function validateHook(address hook, uint24 fee) external pure {
        // Check hook flags
        uint160 expectedFlags = uint160(
            HooksLib.BEFORE_INITIALIZE_FLAG |
                HooksLib.AFTER_INITIALIZE_FLAG |
                HooksLib.BEFORE_ADD_LIQUIDITY_FLAG |
                HooksLib.BEFORE_SWAP_FLAG |
                HooksLib.AFTER_SWAP_FLAG |
                HooksLib.BEFORE_DONATE_FLAG
        );

        // Validate the hook address has the correct flags in its lower bits
        uint160 hookFlags = uint160(hook) & 0x3FFF; // Get the lower 14 bits
        bool flagsValid = hookFlags == expectedFlags;

        // Also validate using the HooksLib helper
        bool hookValid = HooksLib.isValidHookAddress(IHooks(hook), fee);

        // Also check if this hook has conflicts with any dynamic fee flag
        // This seems to be a common issue with validation
        bool hasDynamicFeeFlag = (uint160(hook) & LPFeeLibrary.DYNAMIC_FEE_FLAG) != 0;

        // Must pass both validations
        if (!flagsValid || !hookValid || hasDynamicFeeFlag) {
            revert HookAddressNotValid(hook);
        }
    }
}
