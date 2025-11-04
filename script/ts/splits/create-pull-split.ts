/**
 * Create an immutable Pull split for referral payouts
 *
 * Creates a Splits V2 Pull split with fixed allocations:
 * - Platform: 59% (plus any missing tier percentages)
 * - Tier 1: 35%
 * - Tier 2: 3%
 * - Tier 3: 2%
 * - Tier 4: 1%
 *
 * Missing tiers roll into platform allocation.
 */

import { type Address, formatEther, getAddress } from "viem";
import {
  createSplitsClients,
  getSplitsConfigFromEnv,
  type SplitsConfig,
} from "../lib/splits-clients.js";

const TIER_PERCENTAGES = {
  platform: 59,
  tier1: 35,
  tier2: 3,
  tier3: 2,
  tier4: 1,
} as const;

interface CreateSplitArgs {
  platform: string;
  tier1?: string;
  tier2?: string;
  tier3?: string;
  tier4?: string;
  salt?: string;
  rpc?: string;
  chainId?: string;
}

/**
 * Parse command-line arguments
 */
function parseArguments(): CreateSplitArgs {
  const args = process.argv.slice(2);
  const parsed: CreateSplitArgs = { platform: "" };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const value = args[i + 1];

    if (!arg.startsWith("--") || !value) continue;

    const key = arg.slice(2) as keyof CreateSplitArgs;
    if (["platform", "tier1", "tier2", "tier3", "tier4", "salt", "rpc", "chainId"].includes(key)) {
      parsed[key] = value;
      i++;
    }
  }

  if (!parsed.platform) {
    console.error("Error: --platform address is required");
    console.log("\nUsage:");
    console.log("  npx tsx script/ts/splits/create-pull-split.ts \\");
    console.log("    --platform 0x... \\");
    console.log("    [--tier1 0x...] \\");
    console.log("    [--tier2 0x...] \\");
    console.log("    [--tier3 0x...] \\");
    console.log("    [--tier4 0x...] \\");
    console.log("    [--salt 0x...] \\");
    console.log("    [--rpc https://...] \\");
    console.log("    [--chainId 84532]");
    process.exit(1);
  }

  return parsed;
}

/**
 * Calculate recipients and allocations
 * Missing tiers roll their percentage into platform
 */
function calculateAllocations(addresses: CreateSplitArgs): {
  recipients: Address[];
  percentAllocations: number[];
} {
  const recipients: Address[] = [];
  const percentAllocations: number[] = [];

  let platformPercent = TIER_PERCENTAGES.platform;

  // Always include platform first
  recipients.push(getAddress(addresses.platform));

  const tiers = ["tier1", "tier2", "tier3", "tier4"] as const;
  for (const tier of tiers) {
    if (addresses[tier]) {
      recipients.push(getAddress(addresses[tier]!));
      percentAllocations.push(Number((TIER_PERCENTAGES[tier]).toFixed(4)));
    } else {
      platformPercent += TIER_PERCENTAGES[tier];
    }
  }

  // Insert platform allocation at the beginning to align with recipients
  percentAllocations.unshift(Number(platformPercent.toFixed(4)));

  const total = percentAllocations.reduce((sum, value) => sum + value, 0);
  const roundedTotal = Number(total.toFixed(4));

  if (roundedTotal !== 100) {
    throw new Error(
      `Allocation mismatch: got ${roundedTotal}%, expected 100%`
    );
  }

  return { recipients, percentAllocations };
}

/**
 * Main execution
 */
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

  console.log(`\n🔧 Creating Pull Split on chain ${config.chainId}...`);
  console.log(`📡 RPC: ${config.rpcUrl}`);

  // Calculate recipients and allocations
  const { recipients, percentAllocations } = calculateAllocations(args);

  if (recipients.length < 2) {
    throw new Error("Splits V2 requires at least two recipients. Provide at least one tier address in addition to platform.");
  }

  console.log(`\n📋 Split Configuration:`);
  recipients.forEach((recipient, index) => {
    const percent = percentAllocations[index];
    const label = index === 0 ? "Platform" : `Tier ${index}`;
    console.log(`  ${label}: ${recipient} (${percent.toFixed(2)}%)`);
  });

  // Predict address if salt provided
  if (args.salt) {
    try {
      const predicted = await splitsClient.predictDeterministicAddress({
        recipients: recipients.map((address, index) => ({
          address,
          percentAllocation: percentAllocations[index],
        })),
        distributorFeePercent: 0,
        salt: args.salt as `0x${string}`,
      });

      console.log(`\n🔮 Predicted Split Address: ${predicted}`);
    } catch (error) {
      console.warn("⚠️  Could not predict address:", (error as Error).message);
    }
  }

  // Estimate gas
  console.log("\n⛽ Estimating gas...");
  try {
    const gasEstimate = await splitsClient.estimateGas.createSplit({
      recipients: recipients.map((address, index) => ({
        address,
        percentAllocation: percentAllocations[index],
      })),
      distributorFeePercent: 0,
      // Owner defaults to AddressZero (immutable)
    });

    console.log(`   Estimated gas: ${gasEstimate.toString()}`);
  } catch (error) {
    console.warn("⚠️  Could not estimate gas:", (error as Error).message);
  }

  // Create the split
  console.log("\n🚀 Creating split...");
  const createArgs: any = {
    recipients: recipients.map((address, index) => ({
      address,
      percentAllocation: percentAllocations[index],
    })),
    distributorFeePercent: 0,
  };

  if (args.salt) {
    createArgs.salt = args.salt;
  }

  const result = await splitsClient.createSplit(createArgs);
  const txHash = result.event.transactionHash;

  console.log(`✅ Split created!`);
  console.log(`   Transaction: ${txHash}`);
  console.log(`   Split Address: ${result.splitAddress}`);

  // Get gas used
  const receipt = await publicClient.getTransactionReceipt({
    hash: txHash,
  });

  console.log(`\n⛽ Gas Used: ${receipt.gasUsed.toString()}`);
  console.log(`   Effective Gas Price: ${formatEther(receipt.effectiveGasPrice)} ETH/gas`);

  console.log("\n🔍 Deployment confirmed by transaction receipt.");

  console.log("\n🎉 Split creation complete!");
  console.log(`\n💡 Use this address as swapFeeRecipient in 0x Swap API v2`);
  console.log(`   Split Address: ${result.splitAddress}`);
}

main().catch((error) => {
  console.error("\n❌ Error:", error.message);
  if (error.cause) {
    console.error("   Cause:", error.cause);
  }
  process.exit(1);
});
