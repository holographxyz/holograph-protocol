// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title GenerateSampleCSV
 * @notice Utility to generate a sample CSV for testing referral operations
 */
contract GenerateSampleCSV is Script {
    function run() external {
        uint256 userCount = 100;
        string memory csv = "address,amount\n";

        for (uint256 i = 0; i < userCount; i++) {
            address user = address(uint160(0x1000 + i));
            uint256 amount = 20000 + (i * 1000); // 20k to 120k HLG
            if (amount > 780000) amount = 780000; // Cap at max

            csv = string(abi.encodePacked(csv, vm.toString(user), ",", vm.toString(amount), "\n"));
        }

        // Write to deployments directory (allowed by foundry.toml)
        vm.writeFile("deployments/referral_sample.csv", csv);
        console.log("Generated sample CSV with", userCount, "users at deployments/referral_sample.csv");
    }
}
