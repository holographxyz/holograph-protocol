/**
 * Distribute funds from Split to Warehouse
 *
 * Moves funds from the Split contract's balance to the Warehouse,
 * allocating proportional shares to each recipient according to
 * their percentAllocation.
 *
 * After distribution:
 * - splitBalance becomes 0
 * - warehouseBalance increases for each recipient
 * - Recipients can call withdraw() to claim their shares
 */

import { type Address, formatEther } from "viem";
import {
  createSplitsClients,
  getSplitsConfigFromEnv,
  NATIVE_TOKEN_ADDRESS,
  type SplitsConfig,
} from "../lib/splits-clients.js";

interface DistributeArgs {
  split: string;
  rpc?: string;
  chainId?: string;
}

/**
 * Parse command-line arguments
 */
function parseArguments(): DistributeArgs {
  const args = process.argv.slice(2);
  const parsed: Partial<DistributeArgs> = {};

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const value = args[i + 1];

    if (!arg.startsWith("--") || !value) continue;

    const key = arg.slice(2) as keyof DistributeArgs;
    if (["split", "rpc", "chainId"].includes(key)) {
      parsed[key] = value;
      i++;
    }
  }

  if (!parsed.split) {
    console.error("Error: --split is required");
    console.log("\nUsage:");
    console.log("  npx tsx script/ts/splits/distribute.ts \\");
    console.log("    --split 0x... \\");
    console.log("    [--rpc https://...] \\");
    console.log("    [--chainId 84532]");
    process.exit(1);
  }

  return parsed as DistributeArgs;
}

async function main() {
  const args = parseArguments();

  // Override config if CLI args provided
  const config: SplitsConfig = args.rpc || args.chainId
    ? {
        rpcUrl: args.rpc || getSplitsConfigFromEnv().rpcUrl,
        chainId: args.chainId ? parseInt(args.chainId) : getSplitsConfigFromEnv().chainId,
        privateKey: process.env.PRIVATE_KEY,
        splitsApiKey: process.env.SPLITS_API_KEY,
      }
    : getSplitsConfigFromEnv();

  const { splitsClient, publicClient } = createSplitsClients(config);

  console.log(`\n📦 Distributing funds from Split to Warehouse...`);
  console.log(`   Split: ${args.split}`);
  console.log(`   Token: ETH (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)`);
  console.log(`   Chain: ${config.chainId}`);

  // Get pre-distribution balances
  console.log(`\n🔍 Pre-distribution balances:`);
  const preBalances = await splitsClient.getSplitBalance({
    splitAddress: args.split as Address,
    tokenAddress: NATIVE_TOKEN_ADDRESS,
  });

  console.log(`   Split Balance:     ${formatEther(preBalances.splitBalance)} ETH`);
  console.log(`   Warehouse Balance: ${formatEther(preBalances.warehouseBalance)} ETH`);

  if (preBalances.splitBalance === 0n) {
    console.log(`\n⚠️  No funds to distribute (splitBalance is 0)`);
    process.exit(0);
  }

  // Estimate gas
  console.log(`\n⛽ Estimating gas...`);
  try {
    const gasEstimate = await splitsClient.estimateGas.distribute({
      splitAddress: args.split as Address,
      tokenAddress: NATIVE_TOKEN_ADDRESS,
    });

    console.log(`   Estimated gas: ${gasEstimate.toString()}`);
  } catch (error) {
    console.warn("⚠️  Could not estimate gas:", (error as Error).message);
  }

  // Execute distribution
  console.log(`\n🚀 Executing distribution...`);
  const { event } = await splitsClient.distribute({
    splitAddress: args.split as Address,
    tokenAddress: NATIVE_TOKEN_ADDRESS,
  });

  console.log(`✅ Distribution complete!`);
  console.log(`   Transaction: ${event.transactionHash}`);

  // Get gas used
  const receipt = await publicClient.getTransactionReceipt({
    hash: event.transactionHash,
  });

  console.log(`\n⛽ Gas Used: ${receipt.gasUsed.toString()}`);
  console.log(`   Effective Gas Price: ${formatEther(receipt.effectiveGasPrice)} ETH/gas`);

  // Get post-distribution balances
  console.log(`\n🔍 Post-distribution balances:`);
  const postBalances = await splitsClient.getSplitBalance({
    splitAddress: args.split as Address,
    tokenAddress: NATIVE_TOKEN_ADDRESS,
  });

  console.log(`   Split Balance:     ${formatEther(postBalances.splitBalance)} ETH`);
  console.log(`   Warehouse Balance: ${formatEther(postBalances.warehouseBalance)} ETH`);

  // Show amounts moved
  const amountDistributed = preBalances.splitBalance - postBalances.splitBalance;
  const warehouseIncrease = postBalances.warehouseBalance - preBalances.warehouseBalance;

  console.log(`\n📊 Distribution Summary:`);
  console.log(`   Amount Distributed:    ${formatEther(amountDistributed)} ETH`);
  console.log(`   Warehouse Increase:    ${formatEther(warehouseIncrease)} ETH`);

  console.log(`\n✅ Funds are now in Warehouse and ready for recipient withdrawals!`);
}

main().catch((error) => {
  console.error("\n❌ Error:", error.message);
  if (error.cause) {
    console.error("   Cause:", error.cause);
  }
  process.exit(1);
});
