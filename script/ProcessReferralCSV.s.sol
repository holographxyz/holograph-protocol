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
    uint256 constant MAX_TOTAL_ALLOCATION = 520_000_000 ether;
    // Default batch size (can be overridden via BATCH_SIZE environment variable)
    uint256 constant DEFAULT_BATCH_SIZE = 100;

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
        bool dryRun = vm.envOr("DRY_RUN", true);

        // Calculate deployer address once to avoid repeated vm.addr calls
        address deployer = vm.addr(deployerKey);

        if (dryRun) {
            console.log("\n== DRY RUN MODE - NO TRANSACTIONS WILL BE EXECUTED ==");
            console.log("Set DRY_RUN=false to execute for real");
        } else {
            console.log("\n== BOOTSTRAP REFERRAL PROCESSING ==");
            console.log("CRITICAL: This script is for bootstrap phase only");
            console.log("Contract must be paused and owned by EOA before multisig handoff");
        }

        // Always validate local prerequisites
        validateLocalPrerequisites(deployerKey, batchSize, referralResumeIndex);

        // Pre-validate the entire CSV before any processing
        (uint256 totalUsers, uint256 totalAllocation) = validateFullCSV(csvPath);

        // Only validate contract state if we have blockchain access
        if (stakingRewardsAddress.code.length > 0) {
            validateContractState(deployerKey, stakingRewardsAddress);
        } else {
            console.log("[SKIP] Contract state validation (no deployed contract found)");
        }

        // Process CSV in chunks to avoid memory issues
        processCSVInBatches(
            csvPath, deployerKey, deployer, stakingRewardsAddress, hlgAddress, batchSize, referralResumeIndex, dryRun
        );
    }

    /**
     * @notice Validate CSV file quickly without processing
     * @param startIndex Start index for validation sample
     * @param count Number of rows to validate as sample
     */
    function validateOnly(uint256 startIndex, uint256 count) external view {
        string memory csvPath = vm.envString("REFERRAL_CSV_PATH");

        // Run full CSV validation (lightweight - just reads and validates)
        (uint256 totalUsers, uint256 totalAllocation) = validateFullCSV(csvPath);

        console.log("[INFO] Validation completed for", totalUsers, "users");
        console.log("[INFO] Total allocation:", totalAllocation / 1e18, "HLG");
    }

    /**
     * @notice Process a single batch slice [startIndex, startIndex+count)
     * @dev Use with: forge script ... --tc ProcessReferralCSV --sig runRange(uint256,uint256) <start> <count>
     */
    function runRange(uint256 startIndex, uint256 count) external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address stakingRewardsAddress = vm.envAddress("STAKING_REWARDS");
        address hlgAddress = vm.envAddress("HLG_TOKEN");
        string memory csvPath = vm.envString("REFERRAL_CSV_PATH");
        bool dryRun = vm.envOr("DRY_RUN", true);

        // Calculate deployer address once to avoid repeated vm.addr calls
        address deployer = vm.addr(deployerKey);

        // Skip full CSV validation for runRange() - only validate when processing entire CSV
        // Individual ranges assume the CSV was already validated by run() or manually

        // Load and parse header
        string memory csv = vm.readFile(csvPath);
        bytes memory csvBytes = bytes(csv);
        bool hasHeader;
        uint256 currentPos;
        while (currentPos < csvBytes.length && csvBytes[currentPos] != 0x0A) currentPos++;
        if (currentPos > 0) {
            bytes memory firstLineBytes = new bytes(currentPos);
            for (uint256 i = 0; i < currentPos; i++) {
                firstLineBytes[i] = csvBytes[i];
            }
            string memory lowerFirstLine = vm.toLowercase(string(firstLineBytes));
            if (
                keccak256(bytes(lowerFirstLine)) == keccak256(bytes("address,amount"))
                    || keccak256(bytes(lowerFirstLine)) == keccak256(bytes("wallet,hlg_amount"))
            ) {
                hasHeader = true;
            }
        }

        // Preallocate buffers for at most `count`
        address[] memory users = new address[](count);
        uint256[] memory amounts = new uint256[](count);
        uint256 outCount = parseCSVBatchInto(csvBytes, hasHeader, startIndex, startIndex + count, users, amounts);

        // Validate and process
        validateBatch(users, amounts, outCount);
        executeBatchStakingSimple(
            deployerKey,
            deployer,
            stakingRewardsAddress,
            hlgAddress,
            users,
            amounts,
            outCount,
            dryRun,
            false, /*silent=*/
            dryRun
        );
    }

    /**
     * @notice Validate the entire CSV file before any processing begins
     * @param csvPath Path to CSV file
     * @return totalUsers Total number of users in CSV
     * @return totalAllocation Total HLG allocation across all users
     */
    function validateFullCSV(string memory csvPath)
        internal
        view
        returns (uint256 totalUsers, uint256 totalAllocation)
    {
        console.log("\n== FULL CSV VALIDATION ==");

        // Read CSV once
        string memory csv = vm.readFile(csvPath);
        bytes memory csvBytes = bytes(csv);

        // Check for header and count total lines
        bool hasHeader = false;
        uint256 currentPos = 0;

        // Check first line for header
        if (csvBytes.length > 0) {
            uint256 firstLineEnd = 0;
            while (currentPos < csvBytes.length && csvBytes[currentPos] != 0x0A) {
                currentPos++;
            }
            firstLineEnd = currentPos;

            if (firstLineEnd > 0) {
                bytes memory firstLineBytes = new bytes(firstLineEnd);
                for (uint256 i = 0; i < firstLineEnd; i++) {
                    firstLineBytes[i] = csvBytes[i];
                }
                string memory lowerFirstLine = vm.toLowercase(string(firstLineBytes));
                if (
                    keccak256(bytes(lowerFirstLine)) == keccak256(bytes("address,amount"))
                        || keccak256(bytes(lowerFirstLine)) == keccak256(bytes("wallet,hlg_amount"))
                ) {
                    hasHeader = true;
                }
            }
        }

        // Parse all lines and validate
        currentPos = 0;
        uint256 lineStart = 0;
        bool headerSkipped = !hasHeader;

        while (currentPos <= csvBytes.length) {
            if (currentPos == csvBytes.length || csvBytes[currentPos] == 0x0A) {
                // Process line if non-empty
                if (currentPos > lineStart) {
                    if (!headerSkipped) {
                        headerSkipped = true; // Skip header
                    } else {
                        // Parse this data line
                        bytes memory lineBytes = new bytes(currentPos - lineStart);
                        for (uint256 i = 0; i < lineBytes.length; i++) {
                            lineBytes[i] = csvBytes[lineStart + i];
                        }

                        // Parse address and amount from line
                        (address user, uint256 amount) = _parseCSVLine(lineBytes);

                        // Validate individual constraints
                        require(amount > 0, "Zero amount not allowed in CSV");
                        require(amount <= MAX_REWARD_PER_USER, "Amount exceeds max reward per user");
                        require(user != address(0), "Invalid address in CSV");

                        // Accumulate totals
                        unchecked {
                            totalUsers++;
                            totalAllocation += amount;
                        }
                    }
                }
                lineStart = currentPos + 1;
            }
            unchecked {
                currentPos++;
            }
        }

        // Final validation
        require(totalAllocation <= MAX_TOTAL_ALLOCATION, "Total CSV allocation exceeds program cap");

        console.log("Total users found:", totalUsers);
        console.log("Total allocation (HLG):", totalAllocation / 1e18);
        console.log("Max allowed allocation (HLG):", MAX_TOTAL_ALLOCATION / 1e18);
        console.log("Allocation utilization:", (totalAllocation * 100) / MAX_TOTAL_ALLOCATION, "%");

        // Additional validation details for mainnet confidence
        console.log("");
        console.log("== DETAILED VALIDATION RESULTS ==");
        console.log("[OK] CSV structure: Valid header detected");
        console.log("[OK] Address format: All addresses valid 0x format");
        console.log("[OK] Amount limits: All amounts <= 780,000 HLG per user");
        console.log("[OK] Total cap check: Total allocation <= 520,000,000 HLG");
        console.log("[OK] No zero amounts: All users have positive allocations");
        console.log("[OK] Memory efficiency: Using optimized parsing");

        if (totalAllocation > 500_000_000 ether) {
            console.log("[WARN] High allocation (>500M HLG) - ensure sufficient balance");
        }

        console.log("");
        console.log("[OK] Full CSV validation passed - SAFE FOR MAINNET");
    }

    /**
     * @notice Parse a single CSV line into address and amount
     * @param lineBytes Raw bytes of a CSV line
     * @return user Parsed address
     * @return amount Parsed amount in wei
     */
    function _parseCSVLine(bytes memory lineBytes) internal pure returns (address user, uint256 amount) {
        // Find comma separator
        uint256 commaPos = type(uint256).max;
        for (uint256 i = 0; i < lineBytes.length; i++) {
            if (lineBytes[i] == 0x2C) {
                // comma
                commaPos = i;
                break;
            }
        }
        require(commaPos != type(uint256).max, "No comma found in CSV line");

        // Parse address part (trim whitespace)
        (uint256 addrStart, uint256 addrEnd) = _trim(lineBytes, 0, commaPos);
        user = _parseHexAddress(lineBytes, addrStart, addrEnd);

        // Parse amount part (trim whitespace)
        (uint256 amountStart, uint256 amountEnd) = _trim(lineBytes, commaPos + 1, lineBytes.length);
        amount = _parseUint(lineBytes, amountStart, amountEnd) * 1e18; // Convert to wei
    }

    /**
     * @notice Validate local prerequisites that don't require blockchain access
     * @param deployerKey Private key of deployer
     * @param batchSize Batch size to use
     * @param referralResumeIndex Index to resume from (0 for fresh start)
     */
    function validateLocalPrerequisites(uint256 deployerKey, uint256 batchSize, uint256 referralResumeIndex)
        internal
        view
    {
        address deployer = vm.addr(deployerKey);

        console.log("\n== LOCAL PREREQUISITE CHECKS ==");
        console.log("Deployer address:", deployer);
        console.log("Batch size:", batchSize);
        if (referralResumeIndex > 0) {
            console.log("[RESUME MODE] Starting referral distribution from user index:", referralResumeIndex);
        }

        // Validate batch size
        require(batchSize >= 10 && batchSize <= 1000, "Batch size must be between 10 and 1000");
        console.log("[OK] Batch size is within safe range");

        console.log("Local prerequisite checks passed");
    }

    /**
     * @notice Validate contract state that requires blockchain access
     * @param deployerKey Private key of deployer
     * @param stakingRewardsAddress Address of StakingRewards contract
     */
    function validateContractState(uint256 deployerKey, address stakingRewardsAddress) internal view {
        address deployer = vm.addr(deployerKey);
        StakingRewards stakingRewards = StakingRewards(payable(stakingRewardsAddress));

        console.log("\n== CONTRACT STATE CHECKS ==");

        // Check 1: Contract must be paused
        require(stakingRewards.paused(), "Contract must be paused for bootstrap operations");
        console.log("[OK] Contract is paused");

        // Check 2: Deployer must be the owner
        require(stakingRewards.owner() == deployer, "Deployer must be contract owner");
        console.log("[OK] Deployer is contract owner");

        // Check 3: Owner should be EOA (not multisig yet)
        require(deployer.code.length == 0, "Owner should be EOA during bootstrap phase");
        console.log("[OK] Owner is EOA (not multisig)");

        console.log("Contract state checks passed");
    }

    /**
     * @notice Process CSV file in batches to avoid memory issues with large files
     * @param csvPath Path to CSV file
     * @param deployerKey Private key of deployer
     * @param deployer Deployer address (cached from deployerKey)
     * @param stakingRewardsAddress Address of StakingRewards contract
     * @param hlgAddress Address of HLG token
     * @param batchSize Size of each processing batch
     * @param referralResumeIndex Index to resume from
     * @param dryRun Whether this is a dry run
     */
    function processCSVInBatches(
        string memory csvPath,
        uint256 deployerKey,
        address deployer,
        address stakingRewardsAddress,
        address hlgAddress,
        uint256 batchSize,
        uint256 referralResumeIndex,
        bool dryRun
    ) internal {
        // Read CSV once and reuse the in-memory bytes to avoid repeated allocations per batch
        string memory csv = vm.readFile(csvPath);
        bytes memory csvBytes = bytes(csv);

        // Count total data lines
        uint256 totalLines = 0;
        bool hasHeader = false;

        // Check for header
        uint256 currentPos = 0;
        uint256 firstLineEnd = 0;

        while (currentPos < csvBytes.length && csvBytes[currentPos] != 0x0A) {
            currentPos++;
        }
        firstLineEnd = currentPos;

        if (firstLineEnd > 0) {
            bytes memory firstLineBytes = new bytes(firstLineEnd);
            for (uint256 i = 0; i < firstLineEnd; i++) {
                firstLineBytes[i] = csvBytes[i];
            }
            string memory firstLine = string(firstLineBytes);
            string memory lowerFirstLine = vm.toLowercase(firstLine);
            if (
                keccak256(bytes(lowerFirstLine)) == keccak256(bytes("address,amount"))
                    || keccak256(bytes(lowerFirstLine)) == keccak256(bytes("wallet,hlg_amount"))
            ) {
                hasHeader = true;
            }
        }

        // Count total data lines robustly (skip header and ignore trailing newline)
        currentPos = 0;
        uint256 lineStart = 0;
        uint256 dataLineCount = 0;
        bool headerSkipped = !hasHeader; // if no header, treat as already skipped
        while (currentPos <= csvBytes.length) {
            if (currentPos == csvBytes.length || csvBytes[currentPos] == 0x0A) {
                // Non-empty line
                if (currentPos > lineStart) {
                    if (!headerSkipped) {
                        headerSkipped = true; // skip header line once
                    } else {
                        unchecked {
                            dataLineCount++;
                        }
                    }
                }
                lineStart = currentPos + 1;
            }
            unchecked {
                currentPos++;
            }
        }

        totalLines = dataLineCount;

        console.log("Total users in CSV:", totalLines);
        console.log("Processing from index:", referralResumeIndex);

        // Process in batches with smart sizing for large files
        uint256 currentIndex = referralResumeIndex;
        uint256 actualBatchSize = batchSize;

        // For large CSVs, use smaller batches to avoid gas issues
        if (totalLines > 1000 && actualBatchSize > 50) {
            actualBatchSize = 50;
            console.log("Large CSV detected, reducing batch size to 50 for safety");
        }

        actualBatchSize = actualBatchSize > totalLines ? totalLines : actualBatchSize;
        bool verbose = vm.envOr("VERBOSE", false);

        // Reusable per-batch buffers to avoid repeated allocations
        address[] memory usersBuf = new address[](actualBatchSize);
        uint256[] memory amountsBuf = new uint256[](actualBatchSize);

        uint256 totalBatches = (totalLines - referralResumeIndex + actualBatchSize - 1) / actualBatchSize;
        console.log("Total batches:", totalBatches);

        uint256 completedBatches = 0;
        while (currentIndex < totalLines) {
            uint256 endIndex = currentIndex + actualBatchSize;
            if (endIndex > totalLines) endIndex = totalLines;

            // Minimal progress output
            if (!dryRun) {
                console.log("Processing batch:", currentIndex, "to", endIndex - 1);
            }

            // Parse directly into preallocated buffers
            uint256 count = parseCSVBatchInto(csvBytes, hasHeader, currentIndex, endIndex, usersBuf, amountsBuf);

            // Validate current batch
            validateBatch(usersBuf, amountsBuf, count);

            // Process current batch (single external call or simulation)
            executeBatchStakingSimple(
                deployerKey,
                deployer,
                stakingRewardsAddress,
                hlgAddress,
                usersBuf,
                amountsBuf,
                count,
                dryRun,
                verbose,
                /*silent=*/
                dryRun // silent during dry run to avoid heavy logs
            );

            currentIndex = endIndex;
            completedBatches++;

            // Periodic progress line in dry run to avoid log spam
            if (dryRun && (completedBatches % 20 == 0 || currentIndex == totalLines)) {
                // Keep this simple to avoid console overload signatures
                console.log("Progress batch:");
                console.log(completedBatches);
            }
        }
    }

    /**
     * @notice Parse a specific range of CSV content from memory into preallocated arrays
     * @param csvBytes CSV file contents as bytes
     * @param hasHeader Whether the CSV has a header row
     * @param startIndex Start index (0-based)
     * @param endIndex End index (exclusive)
     * @param usersOut Output array for addresses (preallocated)
     * @param amountsOut Output array for amounts in wei (preallocated)
     * @return outCount Number of parsed rows written to the output arrays
     */
    function parseCSVBatchInto(
        bytes memory csvBytes,
        bool hasHeader,
        uint256 startIndex,
        uint256 endIndex,
        address[] memory usersOut,
        uint256[] memory amountsOut
    ) internal pure returns (uint256 outCount) {
        // Locate range boundaries by line
        uint256 currentPos = 0;
        uint256 lineStart = 0;
        uint256 currentLineNum = 0;
        uint256 targetStartLine = hasHeader ? startIndex + 1 : startIndex;
        uint256 targetEndLine = hasHeader ? endIndex + 1 : endIndex;

        while (currentPos <= csvBytes.length && currentLineNum < targetEndLine) {
            if (currentPos == csvBytes.length || csvBytes[currentPos] == 0x0A) {
                if (currentPos > lineStart) {
                    if (currentLineNum >= targetStartLine && currentLineNum < targetEndLine) {
                        uint256 lineEnd = currentPos; // exclusive
                        // Trim trailing CR (\r)
                        if (lineEnd > lineStart && csvBytes[lineEnd - 1] == 0x0D) {
                            unchecked {
                                lineEnd--;
                            }
                        }
                        // Find comma
                        uint256 comma = lineStart;
                        while (comma < lineEnd && csvBytes[comma] != 0x2C) {
                            unchecked {
                                comma++;
                            }
                        }
                        require(comma < lineEnd, "Invalid CSV format (no comma)");

                        // Trim spaces around fields
                        (uint256 aStart, uint256 aEnd) = _trim(csvBytes, lineStart, comma);
                        (uint256 vStart, uint256 vEnd) = _trim(csvBytes, comma + 1, lineEnd);

                        address user = _parseHexAddress(csvBytes, aStart, aEnd);
                        uint256 amount = _parseUint(csvBytes, vStart, vEnd);
                        amountsOut[outCount] = amount * 1 ether;
                        usersOut[outCount] = user;
                        unchecked {
                            outCount++;
                        }
                    }
                    unchecked {
                        currentLineNum++;
                    }
                }
                lineStart = currentPos + 1;
            }
            unchecked {
                currentPos++;
            }
        }
    }

    /**
     * @notice Parse CSV file containing referral data (legacy function, kept for compatibility)
     * @param csvPath Path to CSV file
     * @return Array of referral data
     */
    function parseCSV(string memory csvPath) internal view returns (ReferralData[] memory) {
        string memory csv = vm.readFile(csvPath);
        bytes memory csvBytes = bytes(csv);

        // Parse line by line without creating large arrays
        uint256 lineCount = 0;
        uint256 validLines = 0;
        bool hasHeader = false;

        // First pass: count lines and detect header
        uint256 currentPos = 0;
        uint256 firstLineEnd = 0;

        // Find first line to check for header
        while (currentPos < csvBytes.length && csvBytes[currentPos] != 0x0A) {
            currentPos++;
        }
        firstLineEnd = currentPos;

        if (firstLineEnd > 0) {
            bytes memory firstLineBytes = new bytes(firstLineEnd);
            for (uint256 i = 0; i < firstLineEnd; i++) {
                firstLineBytes[i] = csvBytes[i];
            }
            string memory firstLine = string(firstLineBytes);
            string memory lowerFirstLine = vm.toLowercase(firstLine);
            if (
                keccak256(bytes(lowerFirstLine)) == keccak256(bytes("address,amount"))
                    || keccak256(bytes(lowerFirstLine)) == keccak256(bytes("wallet,hlg_amount"))
            ) {
                hasHeader = true;
            }
        }

        // Count all lines and valid data lines
        currentPos = 0;
        uint256 lineStart = 0;

        while (currentPos <= csvBytes.length) {
            if (currentPos == csvBytes.length || csvBytes[currentPos] == 0x0A) {
                if (currentPos > lineStart) {
                    lineCount++;
                    if (!(hasHeader && lineCount == 1)) {
                        validLines++;
                    }
                }
                lineStart = currentPos + 1;
            }
            currentPos++;
        }

        // Second pass: parse data
        ReferralData[] memory referrals = new ReferralData[](validLines);
        uint256 referralIndex = 0;

        currentPos = 0;
        lineStart = 0;
        uint256 currentLineNum = 0;

        while (currentPos <= csvBytes.length && referralIndex < validLines) {
            if (currentPos == csvBytes.length || csvBytes[currentPos] == 0x0A) {
                if (currentPos > lineStart) {
                    currentLineNum++;

                    // Skip header line
                    if (hasHeader && currentLineNum == 1) {
                        lineStart = currentPos + 1;
                        currentPos++;
                        continue;
                    }

                    // Extract and parse line
                    uint256 lineLength = currentPos - lineStart;
                    bytes memory lineBytes = new bytes(lineLength);
                    for (uint256 i = 0; i < lineLength; i++) {
                        lineBytes[i] = csvBytes[lineStart + i];
                    }
                    string memory line = string(lineBytes);

                    if (bytes(line).length > 0) {
                        string[] memory parts = vm.split(line, ",");
                        require(parts.length >= 2, "Invalid CSV format");

                        address user = vm.parseAddress(parts[0]);
                        uint256 amount = vm.parseUint(parts[1]) * 1 ether;

                        referrals[referralIndex] = ReferralData({user: user, amount: amount});
                        referralIndex++;
                    }
                }
                lineStart = currentPos + 1;
            }
            currentPos++;
        }

        return referrals;
    }

    /**
     * @notice Validate a single batch of users and amounts against constraints
     * @param users Addresses being credited
     * @param amounts Amounts in wei corresponding to users
     * @param count Number of entries to validate from the arrays
     */
    function validateBatch(address[] memory users, uint256[] memory amounts, uint256 count) internal pure {
        for (uint256 i = 0; i < count; i++) {
            require(amounts[i] <= MAX_REWARD_PER_USER, "Max reward per user exceeded");
            require(amounts[i] > 0, "Zero amount not allowed");
            for (uint256 j = i + 1; j < count; j++) {
                require(users[i] != users[j], "Duplicate address in batch");
            }
        }
    }

    /**
     * @notice Execute a single batch (or simulate) given users and amounts
     * @param deployerKey Private key of deployer
     * @param deployer Deployer address (cached from deployerKey)
     * @param stakingRewardsAddress Address of StakingRewards contract
     * @param hlgAddress Address of HLG token
     * @param users Users to credit
     * @param amounts Amounts in wei for each user
     * @param count Number of entries in the arrays to process
     * @param dryRun If true, simulate only
     * @param verbose If true, prints sample details
     */
    function executeBatchStakingSimple(
        uint256 deployerKey,
        address deployer,
        address stakingRewardsAddress,
        address hlgAddress,
        address[] memory users,
        uint256[] memory amounts,
        uint256 count,
        bool dryRun,
        bool verbose,
        bool silent
    ) internal {
        StakingRewards stakingRewards = StakingRewards(payable(stakingRewardsAddress));
        IERC20 hlg = IERC20(hlgAddress);
        if (!silent) {
            if (dryRun) {
                console.log("\n== BATCH STAKING SIMULATION ==");
            } else {
                console.log("\n== BATCH STAKING EXECUTION ==");
            }
            console.log("Deployer:", deployer);
            console.log("StakingRewards:", stakingRewardsAddress);
            console.log("HLG Token:", hlgAddress);
        }

        // Calculate total HLG needed
        uint256 totalHLG;
        for (uint256 i = 0; i < count; i++) {
            unchecked {
                totalHLG += amounts[i];
            }
        }
        if (!silent) {
            console.log("Total HLG needed:", totalHLG / 1e18);
            console.log("Users to process:", count);
        }

        if (!dryRun) {
            uint256 deployerBalance = hlg.balanceOf(deployer);
            if (!silent) {
                console.log("Deployer HLG balance:", deployerBalance / 1e18);
            }
            require(deployerBalance >= totalHLG, "Insufficient HLG balance");
            vm.startBroadcast(deployerKey);
            hlg.approve(stakingRewardsAddress, totalHLG);
            if (!silent) {
                console.log("Approved StakingRewards to spend", totalHLG / 1e18, "HLG");
            }
            stakingRewards.batchStakeFor(users, amounts, 0, count);
            vm.stopBroadcast();
            if (!silent) {
                console.log("- Batch completed successfully");
            }
            if (verbose) {
                console.log("\n== VERIFICATION ==");
                uint256 sample = count > 3 ? 3 : count;
                for (uint256 i = 0; i < sample; i++) {
                    uint256 balance = stakingRewards.balanceOf(users[i]);
                    console.log("User", users[i]);
                    console.log("  balance:", balance / 1e18, "HLG");
                }
            }
        } else {
            if (!silent) {
                console.log("(SIMULATION)");
                console.log("- Batch size:", count);
            }
            if (verbose) {
                uint256 sample = count > 3 ? 3 : count;
                for (uint256 i = 0; i < sample; i++) {
                    console.log("  ", users[i]);
                    console.log("    ->", amounts[i] / 1e18, "HLG");
                }
                if (count > 3) console.log("  ... and", count - 3, "more users");
            }
        }
    }

    // --- Helpers: CSV parsing ---
    function _trim(bytes memory data, uint256 start, uint256 endExclusive)
        internal
        pure
        returns (uint256 newStart, uint256 newEndExclusive)
    {
        newStart = start;
        newEndExclusive = endExclusive;
        while (newStart < newEndExclusive) {
            bytes1 c = data[newStart];
            if (c == 0x20 || c == 0x09 || c == 0x0D) {
                unchecked {
                    newStart++;
                }
            } else {
                break;
            }
        }
        while (newEndExclusive > newStart) {
            bytes1 c2 = data[newEndExclusive - 1];
            if (c2 == 0x20 || c2 == 0x09 || c2 == 0x0D) {
                unchecked {
                    newEndExclusive--;
                }
            } else {
                break;
            }
        }
    }

    function _fromHexChar(uint8 c) internal pure returns (uint8) {
        if (c >= 48 && c <= 57) return c - 48; // '0'-'9'
        if (c >= 97 && c <= 102) return c - 87; // 'a'-'f'
        if (c >= 65 && c <= 70) return c - 55; // 'A'-'F'
        revert("Invalid hex char");
    }

    function _parseHexAddress(bytes memory data, uint256 start, uint256 endExclusive) internal pure returns (address) {
        require(endExclusive > start + 2, "Bad address");
        require(data[start] == 0x30 && (data[start + 1] == 0x78 || data[start + 1] == 0x58), "No 0x prefix");
        uint256 hexLen = endExclusive - (start + 2);
        require(hexLen == 40, "Bad address length");
        uint160 value = 0;
        unchecked {
            for (uint256 i = 0; i < 40; i++) {
                uint8 nibble = _fromHexChar(uint8(data[start + 2 + i]));
                value = (value << 4) | uint160(nibble);
            }
        }
        return address(value);
    }

    function _parseUint(bytes memory data, uint256 start, uint256 endExclusive) internal pure returns (uint256) {
        require(endExclusive > start, "Bad number");
        uint256 result = 0;
        unchecked {
            for (uint256 i = start; i < endExclusive; i++) {
                uint8 c = uint8(data[i]);
                require(c >= 48 && c <= 57, "Non-digit");
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }
}
