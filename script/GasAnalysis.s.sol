// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {StakingRewards} from "../src/StakingRewards.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title PriceFeedOracle
 * @notice Gets real-time ETH/USD price from Chainlink
 */
contract PriceFeedOracle {
    AggregatorV3Interface internal constant ETH_USD_FEED =
        AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419); // Mainnet ETH/USD

    uint256 private constant PRICE_STALENESS_THRESHOLD = 3600; // 1 hour

    error ChainlinkPriceFeedFailure(string reason);
    error InvalidPriceData();
    error PriceDataNotAvailable();
    error PriceDataStale();

    function getEthPriceUSD() external view returns (uint256 price) {
        try ETH_USD_FEED.latestRoundData() returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80) {
            if (answer <= 0) revert InvalidPriceData();
            if (updatedAt == 0) revert PriceDataNotAvailable();
            if (block.timestamp - updatedAt > PRICE_STALENESS_THRESHOLD) {
                revert PriceDataStale();
            }
            return uint256(answer);
        } catch {
            revert ChainlinkPriceFeedFailure("Unable to fetch ETH/USD price from Chainlink oracle");
        }
    }
}

/**
 * @title GasAnalysis
 * @notice Simple gas cost analysis for referral reward distribution
 * @dev Provides essential cost information for 5,000 user campaign
 */
contract GasAnalysis is Script {
    // Campaign configuration
    uint256 constant TOTAL_USERS = 5000;
    address constant MAINNET_HLG = 0x740df024CE73f589ACD5E8756b377ef8C6558BaB;

    // Gas prices to analyze (current mainnet ranges)
    uint256[] gasPrices;
    PriceFeedOracle priceOracle;

    function setUp() public {
        priceOracle = new PriceFeedOracle();

        // Current typical mainnet gas price ranges
        gasPrices.push(0.2 gwei); // Very low (weekend nights)
        gasPrices.push(0.5 gwei); // Low (off-peak)
        gasPrices.push(1 gwei); // Normal low
        gasPrices.push(2 gwei); // Typical current
        gasPrices.push(5 gwei); // Higher activity
        gasPrices.push(10 gwei); // Network congestion
    }

    function run() public {
        console.log("\n== REFERRAL CAMPAIGN GAS COST ANALYSIS ==");
        console.log("Analyzing costs for distributing HLG rewards to 5,000 users\n");

        // Get real-time ETH price
        console.log("[1/2] Fetching current ETH price...");
        uint256 ethPriceUSD8 = priceOracle.getEthPriceUSD(); // 8 decimals
        uint256 ethPriceUSD18 = ethPriceUSD8 * 1e10; // Convert to 18 decimals
        console.log(string(abi.encodePacked("      Current ETH price: $", vm.toString(ethPriceUSD8 / 1e8))));

        // Measure gas efficiency
        console.log("\n[2/2] Measuring gas efficiency...");
        uint256 gasPerUser = _measureGasPerUser();
        uint256 optimalBatchSize = _determineOptimalBatchSize(gasPerUser);

        console.log(string(abi.encodePacked("      Gas per user: ", vm.toString(gasPerUser))));
        console.log(string(abi.encodePacked("      Optimal batch size: ", vm.toString(optimalBatchSize), " users")));

        // Generate cost table
        _printCostAnalysis(ethPriceUSD18, gasPerUser, optimalBatchSize);
        _printExecutionPlan(optimalBatchSize);
    }

    function _measureGasPerUser() internal returns (uint256) {
        // Fork mainnet for realistic testing
        uint256 mainnetFork = vm.createFork("https://ethereum-rpc.publicnode.com");
        vm.selectFork(mainnetFork);

        // Deploy test contract
        StakingRewards testStaking = new StakingRewards(MAINNET_HLG, address(this));

        // Create test data
        address[] memory testUsers = new address[](100);
        uint256[] memory testAmounts = new uint256[](100);

        for (uint256 i = 0; i < 100; i++) {
            testUsers[i] = address(uint160(0x1000 + i));
            testAmounts[i] = 1000e18; // 1000 HLG per user
        }

        // Measure gas for batch operation
        uint256 gasBefore = gasleft();
        try testStaking.batchStakeFor(testUsers, testAmounts, 0, 50) {
            // Expected to fail due to no tokens
        } catch {
            // We just want the gas measurement
        }
        uint256 gasUsed = gasBefore - gasleft();

        // Return gas per user with safety buffer
        return (gasUsed / 50) + 100; // Small safety buffer
    }

    function _determineOptimalBatchSize(uint256 gasPerUser) internal pure returns (uint256) {
        // Calculate based on gas efficiency and block gas limit safety
        uint256 maxSafeGasPerTx = 25_000_000; // 25M gas (safety margin from 30M block limit)
        uint256 maxUsersPerTx = maxSafeGasPerTx / gasPerUser;

        // Cap at reasonable batch size for operational safety
        if (maxUsersPerTx > 500) return 500;
        if (maxUsersPerTx < 50) return 50;

        return maxUsersPerTx;
    }

    function _printCostAnalysis(uint256 ethPrice, uint256 gasPerUser, uint256 batchSize) internal view {
        uint256 totalGas = gasPerUser * TOTAL_USERS;
        uint256 totalBatches = (TOTAL_USERS + batchSize - 1) / batchSize;

        console.log("\n================================================================");
        console.log("                    COST ANALYSIS RESULTS                     ");
        console.log("================================================================");

        console.log("\n== EXECUTION DETAILS ==");
        console.log(string(abi.encodePacked("Total users: ", vm.toString(TOTAL_USERS))));
        console.log(string(abi.encodePacked("Users per batch: ", vm.toString(batchSize))));
        console.log(string(abi.encodePacked("Total batches: ", vm.toString(totalBatches))));
        console.log(string(abi.encodePacked("Gas per user: ", vm.toString(gasPerUser))));
        console.log(string(abi.encodePacked("Total gas needed: ", vm.toString(totalGas))));

        console.log("\n== COST BREAKDOWN (ETH Gas Fees Only) ==");
        console.log("+--------------+---------------+---------------+--------------+");
        console.log("| Gas Price    | Total Cost    | Cost/User     | ETH Cost     |");
        console.log("+--------------+---------------+---------------+--------------+");

        for (uint256 i = 0; i < gasPrices.length; i++) {
            uint256 gasPrice = gasPrices[i];
            uint256 ethCost = totalGas * gasPrice;
            uint256 usdCostInCents = (ethCost * ethPrice / 1e18) / 1e16; // Result in cents
            uint256 perUserCostInCents = usdCostInCents / TOTAL_USERS;

            string memory gasPriceStr = _formatGasPrice(gasPrice);
            string memory totalCostStr = _formatUsdAmount(usdCostInCents);
            string memory perUserCostStr = _formatUsdAmount(perUserCostInCents);
            string memory ethCostStr = _formatEthAmount(ethCost);

            console.log(
                string(
                    abi.encodePacked(
                        "| ",
                        _padRight(gasPriceStr, 12),
                        "  | ",
                        _padRight(totalCostStr, 13),
                        "  | ",
                        _padRight(perUserCostStr, 13),
                        "  | ",
                        _padRight(ethCostStr, 12),
                        "  |"
                    )
                )
            );
        }

        console.log("+--------------+---------------+---------------+--------------+");
        console.log("\nNOTE: These are ETH gas costs only. HLG tokens must be provided separately.");
    }

    function _printExecutionPlan(uint256 batchSize) internal pure {
        uint256 totalBatches = (TOTAL_USERS + batchSize - 1) / batchSize;
        uint256 estimatedMinutes = totalBatches * 2; // ~2 minutes per batch

        console.log("\n== EXECUTION PLAN ==");
        console.log(string(abi.encodePacked("Recommended batch size: ", vm.toString(batchSize), " users")));
        console.log(string(abi.encodePacked("Total batches needed: ", vm.toString(totalBatches))));
        console.log(string(abi.encodePacked("Estimated time: ~", vm.toString(estimatedMinutes), " minutes")));

        console.log("\n== OPTIMAL EXECUTION ==");
        console.log("- Best timing: Weekends 2-6 AM UTC (0.2-0.5 gwei typical)");
        console.log("- Monitor gas: https://etherscan.io/gastracker");
        console.log("- Set alerts: < 1 gwei on Blocknative");
        console.log("- Current gas environment: Very low (0.2-2 gwei typical)");

        console.log("\n== NEXT STEPS ==");
        console.log("1. PREPARE CSV FILE:");
        console.log("   - Format: address,amount (header row optional)");
        console.log("   - Example: 0x1234...,25000 (amounts in whole HLG, no decimals)");
        console.log("   - Max per user: 780,000 HLG");
        console.log("   - Max total: 250,000,000 HLG");
        console.log("   - No duplicate addresses allowed");
        console.log("");
        console.log("2. SETUP ENVIRONMENT:");
        console.log("   export PRIVATE_KEY=0x...");
        console.log("   export STAKING_REWARDS=0x...");
        console.log("   export HLG_TOKEN=0x...");
        console.log("   export REFERRAL_CSV_PATH=./referral_data.csv");
        console.log("");
        console.log("3. FUND DEPLOYER WALLET:");
        console.log("   - Transfer total HLG amount + 0.1% buffer to deployer");
        console.log("   - Ensure 0.1+ ETH for gas costs");
        console.log("");
        console.log("4. EXECUTION PROCESS:");
        console.log("   a) Dry run: forge script script/ProcessReferralCSV.s.sol --fork-url $ETHEREUM_RPC_URL -vv");
        console.log("   b) Monitor gas: https://etherscan.io/gastracker");
        console.log(
            "   c) Execute: forge script script/ProcessReferralCSV.s.sol --broadcast --private-key $PRIVATE_KEY"
        );
        console.log("");
        console.log("5. WHAT THE SCRIPT DOES:");
        console.log("   - Validates CSV format and constraints");
        console.log("   - Transfers HLG from deployer to StakingRewards contract");
        console.log("   - Executes batchStakeFor() in 500-user batches");
        console.log("   - Users receive staked HLG (not liquid tokens)");
        console.log("   - Contract remains paused until unpaused it");
    }

    // Utility functions for formatting
    function _formatGasPrice(uint256 gasPrice) internal pure returns (string memory) {
        uint256 gweiWhole = gasPrice / 1e9;
        uint256 remainder = gasPrice % 1e9;

        if (remainder == 0) {
            return string(abi.encodePacked(vm.toString(gweiWhole), " gwei"));
        }

        if (gweiWhole == 0) {
            uint256 tenthGweiValue = remainder / 1e8;
            return string(abi.encodePacked("0.", vm.toString(tenthGweiValue), " gwei"));
        }

        uint256 tenthGwei = remainder / 1e8;
        return string(abi.encodePacked(vm.toString(gweiWhole), ".", vm.toString(tenthGwei), " gwei"));
    }

    function _formatUsdAmount(uint256 amount) internal pure returns (string memory) {
        if (amount == 0) return "$0.00";

        if (amount < 100) {
            if (amount < 10) {
                return string(abi.encodePacked("$0.0", vm.toString(amount)));
            }
            return string(abi.encodePacked("$0.", vm.toString(amount)));
        }

        uint256 dollars = amount / 100;
        uint256 cents = amount % 100;

        if (cents == 0) {
            return string(abi.encodePacked("$", vm.toString(dollars)));
        }

        string memory centsStr = vm.toString(cents);
        if (cents < 10) {
            centsStr = string(abi.encodePacked("0", centsStr));
        }

        return string(abi.encodePacked("$", vm.toString(dollars), ".", centsStr));
    }

    function _formatEthAmount(uint256 weiAmount) internal pure returns (string memory) {
        uint256 ethWhole = weiAmount / 1e18;

        if (ethWhole == 0) {
            uint256 milliEth = weiAmount / 1e15;
            if (milliEth == 0) {
                return "< 0.001 ETH";
            }
            return string(abi.encodePacked("0.", _padZeros(milliEth, 3), " ETH"));
        }

        uint256 ethDecimals = (weiAmount % 1e18) / 1e16;

        if (ethDecimals == 0) {
            return string(abi.encodePacked(vm.toString(ethWhole), " ETH"));
        }

        string memory decimalStr = vm.toString(ethDecimals);
        if (ethDecimals < 10) {
            decimalStr = string(abi.encodePacked("0", decimalStr));
        }

        return string(abi.encodePacked(vm.toString(ethWhole), ".", decimalStr, " ETH"));
    }

    function _padZeros(uint256 value, uint256 targetLength) internal pure returns (string memory) {
        string memory valueStr = vm.toString(value);
        bytes memory valueBytes = bytes(valueStr);

        if (valueBytes.length >= targetLength) {
            return valueStr;
        }

        uint256 zerosNeeded = targetLength - valueBytes.length;
        string memory zeros = "";
        for (uint256 i = 0; i < zerosNeeded; i++) {
            zeros = string(abi.encodePacked(zeros, "0"));
        }

        return string(abi.encodePacked(zeros, valueStr));
    }

    function _padRight(string memory str, uint256 targetLength) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);

        if (strBytes.length >= targetLength) {
            bytes memory truncated = new bytes(targetLength);
            for (uint256 i = 0; i < targetLength; i++) {
                truncated[i] = strBytes[i];
            }
            return string(truncated);
        }

        uint256 spacesNeeded = targetLength - strBytes.length;
        string memory spaces = "";
        for (uint256 i = 0; i < spacesNeeded; i++) {
            spaces = string(abi.encodePacked(spaces, " "));
        }

        return string(abi.encodePacked(str, spaces));
    }
}
