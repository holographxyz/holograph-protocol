#!/usr/bin/env node

/**
 * StakingRewards Balance Tracker
 *
 * Fetches all staker balances from the StakingRewards contract on Ethereum mainnet.
 * Provides detailed staking data including balances, pending rewards, and statistics.
 */

import { createPublicClient, http, type Address, parseAbi, formatEther } from "viem";
import { mainnet } from "viem/chains";
import * as fs from "fs";
import * as path from "path";

// StakingRewards contract address on Ethereum mainnet
const STAKING_REWARDS_ADDRESS: Address = "0x39F2750A754aDe33CE1786dA1419cD17a41E6900";

// Contract deployment block (adjust if known)
const DEPLOYMENT_BLOCK = 21377000n; // Approximate deployment block

// StakingRewards ABI (relevant functions)
const STAKING_REWARDS_ABI = parseAbi([
  "function balanceOf(address account) view returns (uint256)",
  "function pendingRewards(address account) view returns (uint256)",
  "function totalStaked() view returns (uint256)",
  "function totalStakers() view returns (uint256)",
  "function balanceWithPendingRewards(address user) view returns (uint256)",
  "function getUserShareBps(address user) view returns (uint256)",
  "function unallocatedRewards() view returns (uint256)",
  "function globalRewardIndex() view returns (uint256)",
  "function userIndexSnapshot(address user) view returns (uint256)",
  "function stakingCooldown() view returns (uint256)",
  "function lastStakeTimestamp(address user) view returns (uint256)",
  "function canUnstake(address user) view returns (bool)",
  "function getCooldownTimeRemaining(address user) view returns (uint256)",
  "event Staked(address indexed user, uint256 amount)",
  "event Unstaked(address indexed user, uint256 amount)",
  "event RewardsCompounded(address indexed user, uint256 rewardAmount)",
  "event EmergencyExit(address indexed user, uint256 amount)",
]);

// Data interfaces
interface StakerData {
  address: Address;
  balance: bigint;
  balanceFormatted: string;
  pendingRewards: bigint;
  pendingRewardsFormatted: string;
  totalBalance: bigint;
  totalBalanceFormatted: string;
  sharePercentage: number;
  canUnstake: boolean;
  cooldownRemaining: bigint;
  lastStakeTimestamp: bigint;
}

interface StakingStats {
  totalStakers: number;
  activeStakers: number;
  totalStaked: bigint;
  totalStakedFormatted: string;
  unallocatedRewards: bigint;
  unallocatedRewardsFormatted: string;
  globalRewardIndex: bigint;
  averageStake: bigint;
  averageStakeFormatted: string;
  medianStake: bigint;
  medianStakeFormatted: string;
  largestStake: bigint;
  largestStakeFormatted: string;
  smallestStake: bigint;
  smallestStakeFormatted: string;
  top10Percentage: number;
  stakingCooldown: bigint;
  stakingCooldownDays: number;
}

interface StakingReport {
  timestamp: string;
  contractAddress: Address;
  stats: StakingStats;
  stakers: StakerData[];
}

/**
 * Formats a BigInt token amount to human-readable string
 */
function formatTokenAmount(amount: bigint): string {
  return formatEther(amount);
}

/**
 * Prints a section header
 */
function printSection(title: string, number?: number) {
  const line = "=".repeat(80);
  console.log(line);
  if (number) {
    console.log(`${number}. ${title}`);
  } else {
    console.log(`                          ${title}`);
  }
  console.log(line);
  console.log();
}

/**
 * Gets unique staker addresses from events
 */
async function getUniqueStakers(client: any): Promise<Set<Address>> {
  const stakers = new Set<Address>();

  console.log("Fetching Staked events...");

  try {
    // Get all Staked events
    const stakedLogs = await client.getLogs({
      address: STAKING_REWARDS_ADDRESS,
      event: {
        type: "event",
        name: "Staked",
        inputs: [
          { type: "address", name: "user", indexed: true },
          { type: "uint256", name: "amount", indexed: false },
        ],
      },
      fromBlock: DEPLOYMENT_BLOCK,
      toBlock: "latest",
    });

    for (const log of stakedLogs) {
      stakers.add(log.args.user as Address);
    }

    console.log(`Found ${stakedLogs.length} stake events from ${stakers.size} unique addresses`);

    // Also check Unstaked events to catch any stakers who fully exited
    const unstakedLogs = await client.getLogs({
      address: STAKING_REWARDS_ADDRESS,
      event: {
        type: "event",
        name: "Unstaked",
        inputs: [
          { type: "address", name: "user", indexed: true },
          { type: "uint256", name: "amount", indexed: false },
        ],
      },
      fromBlock: DEPLOYMENT_BLOCK,
      toBlock: "latest",
    });

    for (const log of unstakedLogs) {
      stakers.add(log.args.user as Address);
    }

    // Check EmergencyExit events as well
    const exitLogs = await client.getLogs({
      address: STAKING_REWARDS_ADDRESS,
      event: {
        type: "event",
        name: "EmergencyExit",
        inputs: [
          { type: "address", name: "user", indexed: true },
          { type: "uint256", name: "amount", indexed: false },
        ],
      },
      fromBlock: DEPLOYMENT_BLOCK,
      toBlock: "latest",
    });

    for (const log of exitLogs) {
      stakers.add(log.args.user as Address);
    }

    console.log(`Total unique addresses found: ${stakers.size}`);

  } catch (error) {
    console.error("Error fetching events:", error);
    throw error;
  }

  return stakers;
}

/**
 * Fetches staker data for a single address
 */
async function getStakerData(client: any, address: Address): Promise<StakerData | null> {
  try {
    // First check if the account has any balance
    const balance = await client.readContract({
      address: STAKING_REWARDS_ADDRESS,
      abi: STAKING_REWARDS_ABI,
      functionName: "balanceOf",
      args: [address],
    });

    // Skip if balance is 0
    if (balance === 0n) {
      return null;
    }

    // Fetch remaining data only for addresses with balance
    // Use sequential calls with error handling for each
    let pendingRewards = 0n;
    let totalBalance = balance;
    let sharePercentage = 0n;
    let canUnstake = false;
    let cooldownRemaining = 0n;
    let lastStakeTimestamp = 0n;

    try {
      pendingRewards = await client.readContract({
        address: STAKING_REWARDS_ADDRESS,
        abi: STAKING_REWARDS_ABI,
        functionName: "pendingRewards",
        args: [address],
      });
      totalBalance = balance + pendingRewards;
    } catch (e) {
      // Use balance as totalBalance if pendingRewards fails
    }

    try {
      sharePercentage = await client.readContract({
        address: STAKING_REWARDS_ADDRESS,
        abi: STAKING_REWARDS_ABI,
        functionName: "getUserShareBps",
        args: [address],
      });
    } catch (e) {
      // Continue with 0 share percentage
    }

    try {
      canUnstake = await client.readContract({
        address: STAKING_REWARDS_ADDRESS,
        abi: STAKING_REWARDS_ABI,
        functionName: "canUnstake",
        args: [address],
      });
    } catch (e) {
      // Continue with false
    }

    try {
      cooldownRemaining = await client.readContract({
        address: STAKING_REWARDS_ADDRESS,
        abi: STAKING_REWARDS_ABI,
        functionName: "getCooldownTimeRemaining",
        args: [address],
      });
    } catch (e) {
      // Continue with 0
    }

    try {
      lastStakeTimestamp = await client.readContract({
        address: STAKING_REWARDS_ADDRESS,
        abi: STAKING_REWARDS_ABI,
        functionName: "lastStakeTimestamp",
        args: [address],
      });
    } catch (e) {
      // Continue with 0
    }

    return {
      address,
      balance,
      balanceFormatted: formatTokenAmount(balance),
      pendingRewards,
      pendingRewardsFormatted: formatTokenAmount(pendingRewards),
      totalBalance,
      totalBalanceFormatted: formatTokenAmount(totalBalance),
      sharePercentage: Number(sharePercentage) / 100,
      canUnstake,
      cooldownRemaining,
      lastStakeTimestamp,
    };
  } catch (error: any) {
    // Only log non-timeout errors briefly
    if (!error.message?.includes("timeout")) {
      console.error(`Error fetching balance for ${address}: ${error.message?.slice(0, 100)}`);
    }
    return null;
  }
}

/**
 * Fetches global staking statistics
 */
async function getStakingStats(client: any, stakerData: StakerData[]): Promise<StakingStats> {
  const [
    totalStakers,
    totalStaked,
    unallocatedRewards,
    globalRewardIndex,
    stakingCooldown,
  ] = await Promise.all([
    client.readContract({
      address: STAKING_REWARDS_ADDRESS,
      abi: STAKING_REWARDS_ABI,
      functionName: "totalStakers",
    }),
    client.readContract({
      address: STAKING_REWARDS_ADDRESS,
      abi: STAKING_REWARDS_ABI,
      functionName: "totalStaked",
    }),
    client.readContract({
      address: STAKING_REWARDS_ADDRESS,
      abi: STAKING_REWARDS_ABI,
      functionName: "unallocatedRewards",
    }),
    client.readContract({
      address: STAKING_REWARDS_ADDRESS,
      abi: STAKING_REWARDS_ABI,
      functionName: "globalRewardIndex",
    }),
    client.readContract({
      address: STAKING_REWARDS_ADDRESS,
      abi: STAKING_REWARDS_ABI,
      functionName: "stakingCooldown",
    }),
  ]);

  // Calculate statistics
  const activeStakers = stakerData.length;
  const balances = stakerData.map(s => s.balance).sort((a, b) => Number(a - b));

  const averageStake = activeStakers > 0 ? totalStaked / BigInt(activeStakers) : 0n;
  const medianStake = activeStakers > 0 ? balances[Math.floor(activeStakers / 2)] : 0n;
  const largestStake = activeStakers > 0 ? balances[balances.length - 1] : 0n;
  const smallestStake = activeStakers > 0 ? balances[0] : 0n;

  // Calculate top 10% concentration
  const sortedByBalance = [...stakerData].sort((a, b) => Number(b.balance - a.balance));
  const top10Count = Math.ceil(activeStakers * 0.1);
  const top10Balance = sortedByBalance.slice(0, top10Count).reduce((sum, s) => sum + s.balance, 0n);
  const top10Percentage = totalStaked > 0n ? Number((top10Balance * 10000n) / totalStaked) / 100 : 0;

  const stakingCooldownDays = Number(stakingCooldown) / (24 * 60 * 60);

  return {
    totalStakers: Number(totalStakers),
    activeStakers,
    totalStaked,
    totalStakedFormatted: formatTokenAmount(totalStaked),
    unallocatedRewards,
    unallocatedRewardsFormatted: formatTokenAmount(unallocatedRewards),
    globalRewardIndex,
    averageStake,
    averageStakeFormatted: formatTokenAmount(averageStake),
    medianStake,
    medianStakeFormatted: formatTokenAmount(medianStake),
    largestStake,
    largestStakeFormatted: formatTokenAmount(largestStake),
    smallestStake,
    smallestStakeFormatted: formatTokenAmount(smallestStake),
    top10Percentage,
    stakingCooldown,
    stakingCooldownDays,
  };
}

/**
 * Exports data to CSV format
 */
function exportToCSV(report: StakingReport, filename: string) {
  const headers = [
    "Address",
    "Balance",
    "Pending Rewards",
    "Total Balance",
    "Share %",
    "Can Unstake",
    "Cooldown Remaining (seconds)",
    "Last Stake Timestamp",
  ];

  const rows = report.stakers.map(s => [
    s.address,
    s.balanceFormatted,
    s.pendingRewardsFormatted,
    s.totalBalanceFormatted,
    s.sharePercentage.toFixed(4),
    s.canUnstake ? "Yes" : "No",
    s.cooldownRemaining.toString(),
    s.lastStakeTimestamp.toString(),
  ]);

  const csv = [
    headers.join(","),
    ...rows.map(row => row.join(",")),
  ].join("\n");

  fs.writeFileSync(filename, csv);
  console.log(`CSV exported to: ${filename}`);
}

/**
 * Exports data to JSON format
 */
function exportToJSON(report: StakingReport, filename: string) {
  const jsonData = {
    ...report,
    stakers: report.stakers.map(s => ({
      ...s,
      balance: s.balance.toString(),
      pendingRewards: s.pendingRewards.toString(),
      totalBalance: s.totalBalance.toString(),
      cooldownRemaining: s.cooldownRemaining.toString(),
      lastStakeTimestamp: s.lastStakeTimestamp.toString(),
    })),
    stats: {
      ...report.stats,
      totalStaked: report.stats.totalStaked.toString(),
      unallocatedRewards: report.stats.unallocatedRewards.toString(),
      globalRewardIndex: report.stats.globalRewardIndex.toString(),
      averageStake: report.stats.averageStake.toString(),
      medianStake: report.stats.medianStake.toString(),
      largestStake: report.stats.largestStake.toString(),
      smallestStake: report.stats.smallestStake.toString(),
      stakingCooldown: report.stats.stakingCooldown.toString(),
    },
  };

  fs.writeFileSync(filename, JSON.stringify(jsonData, null, 2));
  console.log(`JSON exported to: ${filename}`);
}

/**
 * Main function to generate staking report
 */
export async function generateStakingReport(options: {
  minBalance?: bigint;
  exportCSV?: boolean;
  exportJSON?: boolean;
  outputDir?: string;
}): Promise<StakingReport> {
  const timestamp = new Date().toISOString();
  const { minBalance = 0n, exportCSV = false, exportJSON = false, outputDir = "./output" } = options;

  printSection("STAKING REWARDS BALANCE TRACKER");
  console.log(`[TIMESTAMP: ${timestamp}]`);
  console.log();

  // 1. Configuration
  printSection("CONFIGURATION", 1);
  console.log(`• StakingRewards Contract: ${STAKING_REWARDS_ADDRESS}`);
  console.log(`• Network: Ethereum Mainnet`);
  console.log(`• RPC URL: ${process.env.ETHEREUM_RPC_URL || "https://eth-mainnet.g.alchemy.com/v2/..."}`);
  console.log(`• Minimum Balance Filter: ${minBalance > 0n ? formatTokenAmount(minBalance) : "None"}`);
  console.log();

  // 2. Connect to Ethereum
  console.log("Connecting to Ethereum mainnet...");
  const client = createPublicClient({
    chain: mainnet,
    transport: http(
      process.env.ETHEREUM_RPC_URL ||
      "https://eth-mainnet.g.alchemy.com/v2/DeCLfqjc03L7P9CmtSHSmFQlD4sR3hFQ"
    ),
  });
  console.log("Connected successfully");
  console.log();

  // 3. Get unique stakers
  printSection("FETCHING STAKER ADDRESSES", 2);
  const uniqueStakers = await getUniqueStakers(client);
  const stakerAddresses = Array.from(uniqueStakers);
  console.log(`Found ${stakerAddresses.length} unique addresses to check`);
  console.log();

  // 4. Fetch staker data
  printSection("FETCHING STAKER BALANCES", 3);

  // Process in smaller batches to avoid rate limiting
  const batchSize = 3; // Reduced batch size for better stability
  const allStakerData: StakerData[] = [];

  for (let i = 0; i < stakerAddresses.length; i += batchSize) {
    const batch = stakerAddresses.slice(i, i + batchSize);
    const batchPromises = batch.map(address => getStakerData(client, address));

    try {
      const results = await Promise.all(batchPromises);
      const validResults = results.filter((s): s is StakerData => s !== null && s.balance >= minBalance);
      allStakerData.push(...validResults);
      console.log(`Processed ${Math.min(i + batchSize, stakerAddresses.length)}/${stakerAddresses.length} addresses (${allStakerData.length} active stakers found)`);

      // Add a small delay between batches to avoid rate limiting
      if (i + batchSize < stakerAddresses.length) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    } catch (error) {
      console.error(`Error processing batch starting at index ${i}:`, error);
      // Continue with next batch even if one fails
    }
  }

  console.log(`Found ${allStakerData.length} active stakers with balance >= ${formatTokenAmount(minBalance)}`);
  console.log();

  // 5. Get staking statistics
  printSection("STAKING STATISTICS", 4);
  const stats = await getStakingStats(client, allStakerData);

  console.log("Global Statistics:");
  console.log(`• Total Stakers (contract):     ${stats.totalStakers}`);
  console.log(`• Active Stakers (with balance): ${stats.activeStakers}`);
  console.log(`• Total Staked:                  ${stats.totalStakedFormatted} tokens`);
  console.log(`• Unallocated Rewards:           ${stats.unallocatedRewardsFormatted} tokens`);
  console.log(`• Global Reward Index:           ${stats.globalRewardIndex}`);
  console.log(`• Staking Cooldown:              ${stats.stakingCooldownDays} days`);
  console.log();
  console.log("Distribution Statistics:");
  console.log(`• Average Stake:                 ${stats.averageStakeFormatted} tokens`);
  console.log(`• Median Stake:                  ${stats.medianStakeFormatted} tokens`);
  console.log(`• Largest Stake:                 ${stats.largestStakeFormatted} tokens`);
  console.log(`• Smallest Stake:                ${stats.smallestStakeFormatted} tokens`);
  console.log(`• Top 10% Control:               ${stats.top10Percentage.toFixed(2)}% of total`);
  console.log();

  // 6. Display top stakers
  printSection("TOP 10 STAKERS", 5);
  const sortedStakers = [...allStakerData].sort((a, b) => Number(b.balance - a.balance));
  const top10 = sortedStakers.slice(0, 10);

  console.log("Rank | Address                                    | Balance         | Share % | Rewards Pending");
  console.log("-----|--------------------------------------------|-----------------|---------|-----------------");
  top10.forEach((staker, index) => {
    const rank = (index + 1).toString().padStart(4);
    const address = staker.address.slice(0, 42);
    const balance = staker.balanceFormatted.padStart(15);
    const share = staker.sharePercentage.toFixed(2).padStart(7);
    const rewards = staker.pendingRewardsFormatted.padStart(15);
    console.log(`${rank} | ${address} | ${balance} | ${share}% | ${rewards}`);
  });
  console.log();

  // 7. Cooldown Analysis
  printSection("COOLDOWN ANALYSIS", 6);
  const canUnstakeCount = allStakerData.filter(s => s.canUnstake).length;
  const inCooldownCount = allStakerData.filter(s => !s.canUnstake).length;

  console.log(`• Can unstake now:     ${canUnstakeCount} stakers (${(canUnstakeCount / allStakerData.length * 100).toFixed(1)}%)`);
  console.log(`• In cooldown period:  ${inCooldownCount} stakers (${(inCooldownCount / allStakerData.length * 100).toFixed(1)}%)`);

  const stakersInCooldown = allStakerData.filter(s => !s.canUnstake && s.cooldownRemaining > 0n);
  if (stakersInCooldown.length > 0) {
    const avgCooldown = stakersInCooldown.reduce((sum, s) => sum + s.cooldownRemaining, 0n) / BigInt(stakersInCooldown.length);
    console.log(`• Average cooldown remaining: ${Number(avgCooldown) / (60 * 60)} hours`);
  }
  console.log();

  // Prepare report
  const report: StakingReport = {
    timestamp,
    contractAddress: STAKING_REWARDS_ADDRESS,
    stats,
    stakers: sortedStakers,
  };

  // 8. Export data if requested
  if (exportCSV || exportJSON) {
    printSection("EXPORTING DATA", 7);

    // Create output directory if it doesn't exist
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    const dateStr = new Date().toISOString().split("T")[0];

    if (exportCSV) {
      const csvFile = path.join(outputDir, `staking-balances-${dateStr}.csv`);
      exportToCSV(report, csvFile);
    }

    if (exportJSON) {
      const jsonFile = path.join(outputDir, `staking-balances-${dateStr}.json`);
      exportToJSON(report, jsonFile);
    }

    console.log();
  }

  printSection("END OF REPORT");

  return report;
}

/**
 * CLI interface
 */
async function main() {
  const args = process.argv.slice(2);

  if (args.includes("--help") || args.includes("-h")) {
    console.log(`
StakingRewards Balance Tracker

Usage: npm run get-staking-balances [options]

Options:
  --min-balance <amount>  Minimum balance filter (in tokens, e.g., "100")
  --export-csv            Export data to CSV file
  --export-json           Export data to JSON file
  --output <dir>          Output directory for exports (default: ./output)
  --help, -h              Show this help message

Examples:
  npm run get-staking-balances
  npm run get-staking-balances --export-csv --export-json
  npm run get-staking-balances --min-balance 1000 --export-csv
  npx tsx script/ts/get-staking-balances.ts --export-json --output ./reports
    `);
    process.exit(0);
  }

  try {
    // Parse command line options
    const options: any = {
      exportCSV: args.includes("--export-csv"),
      exportJSON: args.includes("--export-json"),
    };

    const minBalanceIndex = args.indexOf("--min-balance");
    if (minBalanceIndex !== -1 && args[minBalanceIndex + 1]) {
      const minBalanceStr = args[minBalanceIndex + 1];
      options.minBalance = BigInt(Math.floor(parseFloat(minBalanceStr) * 1e18));
    }

    const outputIndex = args.indexOf("--output");
    if (outputIndex !== -1 && args[outputIndex + 1]) {
      options.outputDir = args[outputIndex + 1];
    }

    await generateStakingReport(options);
  } catch (error) {
    console.error("Failed to generate staking report:", error);
    process.exit(1);
  }
}

// Run CLI if this file is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}