// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {StakingRewards} from "../src/StakingRewards.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ProcessReferralCSV
 * @notice Script to process referral CSV data and execute batch staking
 * @dev Handles CSV parsing, validation, and batch execution
 */
contract ProcessReferralCSV is Script {
    // Maximum referral reward per user
    uint256 constant MAX_REWARD_PER_USER = 780_000 ether;
    // Maximum total allocation for program
    uint256 constant MAX_TOTAL_ALLOCATION = 250_000_000 ether;
    // Default batch size (can be overridden via BATCH_SIZE environment variable)
    uint256 constant DEFAULT_BATCH_SIZE = 500;

    struct ReferralData {
        address user;
        uint256 amount;
    }

    function run() external {
        // Load environment variables
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address stakingRewardsAddress = vm.envAddress("STAKING_REWARDS");
        address hlgAddress = vm.envAddress("HLG_TOKEN");
        string memory csvPath = vm.envString("REFERRAL_CSV_PATH");
        uint256 batchSize = vm.envOr("BATCH_SIZE", DEFAULT_BATCH_SIZE);
        uint256 referralResumeIndex = vm.envOr("REFERRAL_RESUME_INDEX", uint256(0));

        console.log("\n== BOOTSTRAP REFERRAL PROCESSING ==");
        console.log("CRITICAL: This script is for bootstrap phase only");
        console.log("Contract must be paused and owned by EOA before multisig handoff");

        // Safety preconditions
        validateBootstrapConditions(deployerKey, stakingRewardsAddress, batchSize, referralResumeIndex);

        // Read and parse CSV
        ReferralData[] memory referrals = parseCSV(csvPath);

        // Validate data
        validateReferralData(referrals);

        // Execute batch staking
        executeBatchStaking(deployerKey, stakingRewardsAddress, hlgAddress, referrals, batchSize, referralResumeIndex);
    }

    /**
     * @notice Validate bootstrap conditions before processing
     * @param deployerKey Private key of deployer
     * @param stakingRewardsAddress Address of StakingRewards contract
     * @param batchSize Batch size to use
     * @param referralResumeIndex Index to resume from (0 for fresh start)
     */
    function validateBootstrapConditions(
        uint256 deployerKey,
        address stakingRewardsAddress,
        uint256 batchSize,
        uint256 referralResumeIndex
    ) internal view {
        address deployer = vm.addr(deployerKey);
        StakingRewards stakingRewards = StakingRewards(payable(stakingRewardsAddress));

        console.log("\n== BOOTSTRAP SAFETY CHECKS ==");
        console.log("Deployer address:", deployer);
        console.log("Batch size:", batchSize);
        if (referralResumeIndex > 0) {
            console.log("[RESUME MODE] Starting referral distribution from user index:", referralResumeIndex);
        }

        // Check 1: Contract must be paused
        require(stakingRewards.paused(), "Contract must be paused for bootstrap operations");
        console.log("[OK] Contract is paused");

        // Check 2: Deployer must be the owner
        require(stakingRewards.owner() == deployer, "Deployer must be contract owner");
        console.log("[OK] Deployer is contract owner");

        // Check 3: Owner should be EOA (not multisig yet)
        require(deployer.code.length == 0, "Owner should be EOA during bootstrap phase");
        console.log("[OK] Owner is EOA (not multisig)");

        // Check 4: Validate batch size
        require(batchSize >= 50 && batchSize <= 1000, "Batch size must be between 50 and 1000");
        console.log("[OK] Batch size is within safe range");

        console.log("All bootstrap safety checks passed");
    }

    /**
     * @notice Parse CSV file containing referral data
     * @param csvPath Path to CSV file
     * @return Array of referral data
     */
    function parseCSV(string memory csvPath) internal view returns (ReferralData[] memory) {
        string memory csv = vm.readFile(csvPath);
        string[] memory lines = vm.split(csv, "\n");

        // Skip header row if present
        uint256 startIndex = 0;
        if (bytes(lines[0]).length > 0) {
            // Check if first line is header
            if (
                keccak256(bytes(vm.toLowercase(lines[0]))) == keccak256(bytes("address,amount"))
                    || keccak256(bytes(vm.toLowercase(lines[0]))) == keccak256(bytes("wallet,hlg_amount"))
            ) {
                startIndex = 1;
            }
        }

        uint256 dataLength = lines.length - startIndex;
        ReferralData[] memory referrals = new ReferralData[](dataLength);

        for (uint256 i = startIndex; i < lines.length; i++) {
            if (bytes(lines[i]).length == 0) continue; // Skip empty lines

            string[] memory parts = vm.split(lines[i], ",");
            require(parts.length >= 2, "Invalid CSV format");

            address user = vm.parseAddress(parts[0]);
            uint256 amount = vm.parseUint(parts[1]) * 1 ether; // Assuming CSV has values without decimals

            referrals[i - startIndex] = ReferralData({user: user, amount: amount});
        }

        return referrals;
    }

    /**
     * @notice Validate referral data against program constraints
     * @param referrals Array of referral data to validate
     */
    function validateReferralData(ReferralData[] memory referrals) internal pure {
        uint256 totalAllocation;

        for (uint256 i = 0; i < referrals.length; i++) {
            // Check individual cap
            require(
                referrals[i].amount <= MAX_REWARD_PER_USER,
                string(
                    abi.encodePacked(
                        "User ",
                        vm.toString(referrals[i].user),
                        " exceeds max reward: ",
                        vm.toString(referrals[i].amount)
                    )
                )
            );

            // Check for zero amounts
            require(referrals[i].amount > 0, "Zero amount not allowed");

            // Check for duplicate addresses (simplified check)
            for (uint256 j = i + 1; j < referrals.length; j++) {
                require(
                    referrals[i].user != referrals[j].user,
                    string(abi.encodePacked("Duplicate address: ", vm.toString(referrals[i].user)))
                );
            }

            totalAllocation += referrals[i].amount;
        }

        // Check total cap
        require(
            totalAllocation <= MAX_TOTAL_ALLOCATION,
            string(abi.encodePacked("Total allocation exceeds cap: ", vm.toString(totalAllocation)))
        );

        console.log("Validation passed:");
        console.log("- Total users:", referrals.length);
        console.log("- Total allocation:", totalAllocation / 1e18, "HLG");
    }

    /**
     * @notice Execute batch staking for all referral recipients
     * @param deployerKey Private key of deployer
     * @param stakingRewardsAddress Address of StakingRewards contract
     * @param hlgAddress Address of HLG token
     * @param referrals Array of referral data
     * @param batchSize Number of users to process per batch
     * @param referralResumeIndex Index to resume from (0 for fresh start)
     */
    function executeBatchStaking(
        uint256 deployerKey,
        address stakingRewardsAddress,
        address hlgAddress,
        ReferralData[] memory referrals,
        uint256 batchSize,
        uint256 referralResumeIndex
    ) internal {
        address deployer = vm.addr(deployerKey);
        StakingRewards stakingRewards = StakingRewards(payable(stakingRewardsAddress));
        IERC20 hlg = IERC20(hlgAddress);

        console.log("\n== BATCH STAKING EXECUTION ==");
        console.log("Deployer:", deployer);
        console.log("StakingRewards:", stakingRewardsAddress);
        console.log("HLG Token:", hlgAddress);

        // Validate resume index
        require(referralResumeIndex <= referrals.length, "Resume index exceeds total users");

        // Calculate total HLG needed (only from resume point onwards)
        uint256 totalHLG;
        for (uint256 i = referralResumeIndex; i < referrals.length; i++) {
            totalHLG += referrals[i].amount;
        }

        console.log("Total HLG needed:", totalHLG / 1e18);
        if (referralResumeIndex > 0) {
            console.log("Users to process:", referrals.length - referralResumeIndex);
            console.log("Total users in CSV:", referrals.length);
        } else {
            console.log("Users to process:", referrals.length, "(fresh start)");
        }

        // Check deployer balance
        uint256 deployerBalance = hlg.balanceOf(deployer);
        console.log("Deployer HLG balance:", deployerBalance / 1e18);
        require(deployerBalance >= totalHLG, "Insufficient HLG balance");

        // Start broadcasting transactions
        vm.startBroadcast(deployerKey);

        // Approve StakingRewards to spend HLG
        hlg.approve(stakingRewardsAddress, totalHLG);
        console.log("Approved StakingRewards to spend", totalHLG / 1e18, "HLG");

        // Prepare arrays for batch operations starting from resume index
        uint256 remainingUsers = referrals.length - referralResumeIndex;
        uint256 batches = (remainingUsers + batchSize - 1) / batchSize;
        console.log("\nProcessing", batches, "batches with batch size", batchSize);

        for (uint256 batchIndex = 0; batchIndex < batches; batchIndex++) {
            uint256 startIdx = referralResumeIndex + (batchIndex * batchSize);
            uint256 endIdx = startIdx + batchSize;
            if (endIdx > referrals.length) {
                endIdx = referrals.length;
            }

            uint256 currentBatchSize = endIdx - startIdx;
            address[] memory users = new address[](referrals.length);
            uint256[] memory amounts = new uint256[](referrals.length);

            // Fill arrays with full data (required for proper indexing)
            for (uint256 i = 0; i < referrals.length; i++) {
                users[i] = referrals[i].user;
                amounts[i] = referrals[i].amount;
            }

            // Execute batch
            console.log("\nBatch", batchIndex + 1, "of", batches);
            console.log("- Processing users", startIdx, "to", endIdx - 1);
            console.log("- Batch size:", currentBatchSize);

            stakingRewards.batchStakeFor(users, amounts, startIdx, endIdx);

            console.log("- Batch completed successfully");
        }

        vm.stopBroadcast();

        console.log("\n== EXECUTION COMPLETE ==");
        if (referralResumeIndex > 0) {
            console.log("Processed", referrals.length - referralResumeIndex, "users in resume mode");
            console.log("Total users now processed:", referrals.length);
        } else {
            console.log("All", referrals.length, "users have been initialized with staked HLG");
        }

        // Verify a few users from the processed range
        console.log("\n== VERIFICATION ==");
        uint256 verifyStart = referralResumeIndex;
        uint256 verifyEnd = referrals.length;
        for (uint256 i = verifyStart; i < verifyEnd && i < verifyStart + 3; i++) {
            uint256 balance = stakingRewards.balanceOf(referrals[i].user);
            console.log(
                string(
                    abi.encodePacked(
                        "User ", vm.toString(referrals[i].user), " balance: ", vm.toString(balance / 1e18), " HLG"
                    )
                )
            );
        }
    }
}

/**
 * @title GenerateSampleCSV
 * @notice Utility to generate a sample CSV for testing
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

        vm.writeFile("referral_sample.csv", csv);
        console.log("Generated sample CSV with", userCount, "users");
    }
}
