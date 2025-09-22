// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {StakingRewards} from "../../src/StakingRewards.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ProcessReferralCSV
 * @notice Clean, unified script for referral reward processing
 * @dev Eliminates redundancy by handling everything in Foundry - no shell script needed
 *
 * Usage:
 *   forge script script/admin/ProcessReferralCSV.s.sol --rpc-url $RPC_URL [--broadcast]
 *
 * Environment Variables (all optional with smart defaults):
 *   DRY_RUN              - true (default) for simulation, false for execution
 *   REFERRAL_CSV_PATH    - Path to CSV file (auto-detects default file)
 *   STAKING_REWARDS      - Contract address (auto-detects from chain)
 *
 * Note: DEPLOYER_PK is used by Forge (not the script) for transaction signing
 */
contract ProcessReferralCSV is Script {
    // ============================================================================
    // CONSTANTS - Single source of truth for all configuration
    // ============================================================================

    uint256 constant CHUNK_SIZE = 500; // Users per memory chunk (CSV reading optimization)
    uint256 constant BATCH_SIZE = 50; // Users per transaction (gas limit optimization)
    uint256 constant MAX_REWARD_PER_USER = 780_000 ether;
    uint256 constant MAX_TOTAL_ALLOCATION = 258_140_000 ether;

    // ============================================================================
    // STRUCTS
    // ============================================================================

    struct ReferralData {
        address user;
        uint256 amount;
    }

    struct ProcessingStats {
        uint256 totalUsers;
        uint256 totalAllocation;
        uint256 totalChunks;
        uint256 totalGas;
        uint256 startTime;
    }

    // ============================================================================
    // MAIN ENTRY POINT
    // ============================================================================

    /**
     * @notice Main function - processes entire CSV with automatic chunking
     * @dev Replaces both shell script and old Foundry functions
     */
    function run() external {
        // Load configuration
        bool isDryRun = vm.envOr("DRY_RUN", true);
        string memory csvPath = loadCSVPath();

        // Auto-detect network
        string memory networkName = getNetworkName();

        // Single CSV validation pass
        console.log("Validating CSV file...");
        (uint256 totalUsers, uint256 totalAllocation) = validateCSV(csvPath);

        // Calculate processing parameters
        uint256 totalChunks = (totalUsers + CHUNK_SIZE - 1) / CHUNK_SIZE;

        // Display execution plan
        showExecutionPlan(networkName, isDryRun, csvPath, totalUsers, totalAllocation, totalChunks);

        // Load contract addresses only if we need them for execution
        address payable stakingRewards;

        if (!isDryRun) {
            stakingRewards = payable(loadStakingRewards());
            require(stakingRewards != address(0), "StakingRewards not deployed on this chain");

            // Check deployer's HLG balance
            address deployer;
            try vm.envUint("DEPLOYER_PK") returns (uint256 pk) {
                deployer = vm.addr(pk);
            } catch {
                deployer = msg.sender;
            }
            // Get HLG token address from StakingRewards contract
            IERC20 hlgToken = StakingRewards(stakingRewards).HLG();

            console.log("\n=== BALANCE CHECK ===");
            console.log("Deployer address: %s", deployer);
            console.log("HLG token address: %s", address(hlgToken));

            // Check if HLG token contract exists
            uint256 codeSize;
            assembly {
                codeSize := extcodesize(hlgToken)
            }
            console.log("HLG token code size: %s", codeSize);

            if (codeSize == 0) {
                console.log("[ERROR] HLG token contract not found on this network!");
                revert("HLG token not deployed on this chain");
            }

            uint256 deployerBalance = hlgToken.balanceOf(deployer);
            console.log("HLG balance: %s HLG", deployerBalance / 1e18);
            console.log("Required HLG: %s HLG", totalAllocation / 1e18);

            if (deployerBalance < totalAllocation) {
                console.log("\n[ERROR] Insufficient HLG balance!");
                console.log("Need %s more HLG", (totalAllocation - deployerBalance) / 1e18);
                revert("Insufficient HLG balance");
            }

            console.log("[OK] Sufficient HLG balance confirmed");
            console.log("\nType 'CONFIRM' to proceed with REAL execution or Ctrl+C to abort:");
        }

        // Initialize stats
        ProcessingStats memory stats = ProcessingStats({
            totalUsers: totalUsers,
            totalAllocation: totalAllocation,
            totalChunks: totalChunks,
            totalGas: 0,
            startTime: block.timestamp
        });

        // Start broadcasting if not dry run
        if (!isDryRun) {
            console.log("Starting transaction broadcast...");
            vm.startBroadcast();

            // Approve StakingRewards to spend HLG tokens (must be inside broadcast)
            IERC20 hlgToken = StakingRewards(stakingRewards).HLG();
            console.log("Approving StakingRewards to spend %s HLG...", totalAllocation / 1e18);
            hlgToken.approve(stakingRewards, totalAllocation);
            console.log("[OK] Approval transaction sent");
        }

        // Process all chunks sequentially
        for (uint256 chunk = 0; chunk < totalChunks; chunk++) {
            uint256 gasUsed = processChunk(csvPath, chunk, stakingRewards, isDryRun, stats);
            stats.totalGas += gasUsed;
        }

        if (!isDryRun) {
            vm.stopBroadcast();
        }

        // Show final summary
        showFinalSummary(stats, isDryRun);
    }

    // ============================================================================
    // CSV PROCESSING
    // ============================================================================

    /**
     * @notice Process a single chunk of users
     */
    function processChunk(
        string memory csvPath,
        uint256 chunkIndex,
        address payable stakingRewards,
        bool isDryRun,
        ProcessingStats memory stats
    ) internal returns (uint256 gasUsed) {
        uint256 startIdx = chunkIndex * CHUNK_SIZE;
        uint256 remainingUsers = stats.totalUsers - startIdx;
        uint256 usersInChunk = remainingUsers < CHUNK_SIZE ? remainingUsers : CHUNK_SIZE;

        console.log("\n=== Chunk %s/%s ===", chunkIndex + 1, stats.totalChunks);
        console.log("Processing users %s to %s (%s users)", startIdx, startIdx + usersInChunk - 1, usersInChunk);

        uint256 gasStart = gasleft();

        // Load chunk data (500 users max into memory)
        ReferralData[] memory chunkData = loadChunkData(csvPath, startIdx, usersInChunk);

        if (!isDryRun) {
            // Process chunk in smaller batches (50 users per transaction)
            for (uint256 i = 0; i < chunkData.length; i += BATCH_SIZE) {
                uint256 batchEnd = i + BATCH_SIZE;
                if (batchEnd > chunkData.length) batchEnd = chunkData.length;

                // Prepare batch arrays
                address[] memory users = new address[](batchEnd - i);
                uint256[] memory amounts = new uint256[](batchEnd - i);

                for (uint256 j = i; j < batchEnd; j++) {
                    users[j - i] = chunkData[j].user;
                    amounts[j - i] = chunkData[j].amount;
                }

                // Execute single transaction for this batch (≤50 users)
                StakingRewards(stakingRewards).batchStakeFor(users, amounts, 0, users.length);
            }
        }

        gasUsed = gasStart - gasleft();

        // Show progress
        uint256 processedSoFar = startIdx + usersInChunk;
        uint256 progressPct = (processedSoFar * 100) / stats.totalUsers;

        console.log("Progress: %s%% | Gas used: %s", progressPct, gasUsed);

        return gasUsed;
    }

    /**
     * @notice Load chunk data from CSV
     */
    function loadChunkData(string memory csvPath, uint256 startIndex, uint256 count)
        internal
        view
        returns (ReferralData[] memory)
    {
        string memory csv = vm.readFile(csvPath);
        bytes memory csvBytes = bytes(csv);

        // Skip header and get to start position
        uint256 currentPos = 0;
        uint256 lineCount = 0;

        // Skip header line
        while (currentPos < csvBytes.length && csvBytes[currentPos] != 0x0A) {
            currentPos++;
        }
        if (currentPos < csvBytes.length) currentPos++; // Skip newline

        // Skip to start index
        while (lineCount < startIndex && currentPos < csvBytes.length) {
            if (csvBytes[currentPos] == 0x0A) {
                lineCount++;
            }
            currentPos++;
        }

        // Parse the chunk
        ReferralData[] memory chunkData = new ReferralData[](count);
        uint256 dataIndex = 0;

        while (dataIndex < count && currentPos < csvBytes.length) {
            (address user, uint256 amount, uint256 newPos) = parseCSVLine(csvBytes, currentPos);
            chunkData[dataIndex] = ReferralData(user, amount);
            dataIndex++;
            currentPos = newPos;
        }

        return chunkData;
    }

    /**
     * @notice Parse a single CSV line
     */
    function parseCSVLine(bytes memory csvBytes, uint256 startPos)
        internal
        pure
        returns (address user, uint256 amount, uint256 endPos)
    {
        uint256 pos = startPos;

        // Find comma
        uint256 commaPos = pos;
        while (commaPos < csvBytes.length && csvBytes[commaPos] != 0x2C) {
            commaPos++;
        }

        // Extract address
        bytes memory addressBytes = new bytes(commaPos - pos);
        for (uint256 i = 0; i < commaPos - pos; i++) {
            addressBytes[i] = csvBytes[pos + i];
        }
        user = vm.parseAddress(string(addressBytes));

        // Move past comma
        pos = commaPos + 1;

        // Find end of line
        uint256 lineEnd = pos;
        while (lineEnd < csvBytes.length && csvBytes[lineEnd] != 0x0A && csvBytes[lineEnd] != 0x0D) {
            lineEnd++;
        }

        // Extract amount
        bytes memory amountBytes = new bytes(lineEnd - pos);
        for (uint256 i = 0; i < lineEnd - pos; i++) {
            amountBytes[i] = csvBytes[pos + i];
        }
        amount = vm.parseUint(string(amountBytes)) * 1e18; // Convert to wei

        // Skip to next line
        endPos = lineEnd;
        while (endPos < csvBytes.length && (csvBytes[endPos] == 0x0A || csvBytes[endPos] == 0x0D)) {
            endPos++;
        }

        return (user, amount, endPos);
    }

    // ============================================================================
    // VALIDATION
    // ============================================================================

    /**
     * @notice Validate entire CSV file
     */
    function validateCSV(string memory csvPath) internal view returns (uint256 totalUsers, uint256 totalAllocation) {
        string memory csv = vm.readFile(csvPath);
        bytes memory csvBytes = bytes(csv);

        uint256 currentPos = 0;
        uint256 userCount = 0;
        uint256 allocationSum = 0;

        // Skip header
        while (currentPos < csvBytes.length && csvBytes[currentPos] != 0x0A) {
            currentPos++;
        }
        if (currentPos < csvBytes.length) currentPos++;

        // Process all lines
        while (currentPos < csvBytes.length) {
            (address user, uint256 amount, uint256 newPos) = parseCSVLine(csvBytes, currentPos);

            // Validate user
            require(user != address(0), "Invalid address in CSV");

            // Validate amount
            require(amount > 0, "Zero amount in CSV");
            require(amount <= MAX_REWARD_PER_USER, "Amount exceeds maximum per user");

            userCount++;
            allocationSum += amount;
            currentPos = newPos;
        }

        // Final validations
        require(userCount > 0, "No users found in CSV");
        require(allocationSum <= MAX_TOTAL_ALLOCATION, "Total allocation exceeds maximum");

        console.log("[OK] CSV validation passed");
        console.log("  Users found: %s", userCount);
        console.log("  Total allocation: %s HLG", allocationSum / 1e18);
        console.log("  Utilization: %s%%", (allocationSum * 100) / MAX_TOTAL_ALLOCATION);

        return (userCount, allocationSum);
    }

    // ============================================================================
    // CONFIGURATION HELPERS
    // ============================================================================

    /**
     * @notice Load CSV path with smart defaults
     */
    function loadCSVPath() internal view returns (string memory) {
        try vm.envString("REFERRAL_CSV_PATH") returns (string memory path) {
            return path;
        } catch {
            // Default to the known CSV file
            return "./script/csv/rewards-allocation-simple-final.csv";
        }
    }

    /**
     * @notice Load StakingRewards address
     */
    function loadStakingRewards() internal view returns (address) {
        // Try environment variable first
        try vm.envAddress("STAKING_REWARDS") returns (address addr) {
            return addr;
        } catch {
            // Chain-specific fallbacks
            if (block.chainid == 1) {
                return 0x39F2750A754aDe33CE1786dA1419cD17a41E6900;
            } else if (block.chainid == 11155111) {
                return 0x7245a2Af9635E2edfaa57Cdc7536f71504B56Be9;
            } else {
                // Unknown chain: Use zero address
                return address(0);
            }
        }
    }

    /**
     * @notice Get network name from chain ID
     */
    function getNetworkName() internal view returns (string memory) {
        if (block.chainid == 1) return "ETHEREUM MAINNET";
        if (block.chainid == 11155111) return "ETHEREUM SEPOLIA";
        return string.concat("CHAIN ", vm.toString(block.chainid));
    }

    // ============================================================================
    // DISPLAY HELPERS
    // ============================================================================

    /**
     * @notice Show execution plan
     */
    function showExecutionPlan(
        string memory networkName,
        bool isDryRun,
        string memory csvPath,
        uint256 totalUsers,
        uint256 totalAllocation,
        uint256 totalChunks
    ) internal pure {
        console.log("\n========================================================");
        console.log(" REFERRAL PROCESSING");
        console.log("========================================================");
        console.log(" Network:      %s", networkName);
        console.log(" Mode:         %s", isDryRun ? "DRY RUN" : "EXECUTE");
        console.log(" CSV:          %s", csvPath);
        console.log(" Users:        %s", totalUsers);
        console.log(" Allocation:   %s HLG", totalAllocation / 1e18);
        console.log(" Chunks:       %s x %s users", totalChunks, CHUNK_SIZE);
        console.log(" Batch size:   %s users per transaction", BATCH_SIZE);
        console.log("========================================================");

        if (isDryRun) {
            console.log("\n[DRY RUN] No transactions will be executed");
            console.log("Set DRY_RUN=false to execute for real");
        }
    }

    /**
     * @notice Show final summary
     */
    function showFinalSummary(ProcessingStats memory stats, bool isDryRun) internal view {
        uint256 elapsed = block.timestamp - stats.startTime;

        console.log("\n========================================================");
        console.log(" PROCESSING COMPLETE");
        console.log("========================================================");
        console.log(" Users processed: %s", stats.totalUsers);
        console.log(" Total gas used:  %s", stats.totalGas);
        console.log(" Execution time:  %s seconds", elapsed);
        console.log(" Status:          %s", isDryRun ? "SIMULATED" : "EXECUTED");
        console.log("========================================================");

        if (isDryRun) {
            console.log("\n[SUCCESS] Simulation successful! Ready for real execution.");
            console.log("To execute: Set DRY_RUN=false and re-run with --broadcast");
        } else {
            console.log("\n[SUCCESS] Real execution complete! Rewards distributed.");
        }
    }

    /**
     * @notice Utility function for min
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
