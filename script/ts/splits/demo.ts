/**
 * End-to-end demo of Pull-based referral splits
 *
 * Orchestrates the complete flow:
 * 1. Create a Pull split with platform + tier addresses
 * 2. Fund the split with native ETH
 * 3. Check balances (should show splitBalance > 0, warehouseBalance == 0)
 * 4. Distribute to Warehouse (should show splitBalance == 0, warehouseBalance > 0)
 * 5. Withdraw for each recipient
 * 6. Report final amounts received
 */

import { type Address, parseEther, formatEther, getAddress } from "viem";
import {
  createSplitsClients,
  getSplitsConfigFromEnv,
  NATIVE_TOKEN_ADDRESS,
} from "../lib/splits-clients.js";

interface DemoArgs {
  platform: string;
  tier1?: string;
  tier2?: string;
  tier3?: string;
  tier4?: string;
  amount: string;
  rpc?: string;
  chainId?: string;
}

const TIER_PERCENTAGES = {
  platform: 59,
  tier1: 35,
  tier2: 3,
  tier3: 2,
  tier4: 1,
} as const;

/**
 * Parse command-line arguments
 */
function parseArguments(): DemoArgs {
  const args = process.argv.slice(2);
  const parsed: Partial<DemoArgs> = {};

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const value = args[i + 1];

    if (!arg.startsWith("--") || !value) continue;

    const key = arg.slice(2) as keyof DemoArgs;
    if (["platform", "tier1", "tier2", "tier3", "tier4", "amount", "rpc", "chainId"].includes(key)) {
      parsed[key] = value;
      i++;
    }
  }

  if (!parsed.platform || !parsed.amount) {
    console.error("Error: --platform and --amount are required");
    console.log("\nUsage:");
    console.log("  npx tsx script/ts/splits/demo.ts \\");
    console.log("    --platform 0x... \\");
    console.log("    --amount 100 \\");
    console.log("    [--tier1 0x...] \\");
    console.log("    [--tier2 0x...] \\");
    console.log("    [--tier3 0x...] \\");
    console.log("    [--tier4 0x...] \\");
    console.log("    [--rpc https://...] \\");
    console.log("    [--chainId 84532]");
    process.exit(1);
  }

  return parsed as DemoArgs;
}

function buildRecipients(args: DemoArgs): { addresses: Address[]; percents: number[] } {
  const addresses: Address[] = [];
  const percents: number[] = [];

  let platformPercent = TIER_PERCENTAGES.platform;

  addresses.push(getAddress(args.platform));

  const tiers = [
    { key: "tier1" as const, addr: args.tier1 },
    { key: "tier2" as const, addr: args.tier2 },
    { key: "tier3" as const, addr: args.tier3 },
    { key: "tier4" as const, addr: args.tier4 },
  ];

  for (const tier of tiers) {
    if (tier.addr) {
      addresses.push(getAddress(tier.addr));
      percents.push(Number(TIER_PERCENTAGES[tier.key].toFixed(4)));
    } else {
      platformPercent += TIER_PERCENTAGES[tier.key];
    }
  }

  percents.unshift(Number(platformPercent.toFixed(4)));

  const total = Number(percents.reduce((sum, value) => sum + value, 0).toFixed(4));
  if (total !== 100) {
    throw new Error(`Allocation mismatch during demo setup. Got ${total}%, expected 100%.`);
  }

  if (addresses.length < 2) {
    throw new Error("Demo requires at least one tier address in addition to the platform to satisfy Splits requirements.");
  }

  return { addresses, percents };
}

/**
 * Main execution
 */
async function main() {
  const args = parseArguments();

  const config = args.rpc || args.chainId
    ? {
        rpcUrl: args.rpc || getSplitsConfigFromEnv().rpcUrl,
        chainId: args.chainId ? parseInt(args.chainId) : getSplitsConfigFromEnv().chainId,
        privateKey: process.env.PRIVATE_KEY,
        splitsApiKey: process.env.SPLITS_API_KEY,
      }
    : getSplitsConfigFromEnv();

  const { splitsClient, warehouseClient, publicClient, walletClient } = createSplitsClients(config);

  console.log(`\n🎬 Pull Splits Demo - End-to-End Flow`);
  console.log(`═══════════════════════════════════════\n`);

  // Step 1: Create Split
  console.log(`📋 STEP 1: Create Pull Split\n`);

  const { addresses: recipients, percents } = buildRecipients(args);

  console.log(`Recipients:`);
  recipients.forEach((addr, i) => {
    const percent = percents[i];
    const label = i === 0 ? "Platform" : `Tier ${i}`;
    console.log(`  ${label.padEnd(10)} ${addr} (${percent.toFixed(2)}%)`);
  });

  console.log(`\nCreating split...`);
  const { splitAddress, event: createEvent } = await splitsClient.createSplit({
    recipients: recipients.map((address, i) => ({
      address,
      percentAllocation: percents[i],
    })),
    distributorFeePercent: 0,
  });

  const splitAddr = splitAddress as Address;
  console.log(`✅ Split created: ${splitAddr}`);
  console.log(`   Transaction: ${createEvent.transactionHash}`);

  // Step 2: Fund the Split
  console.log(`\n📋 STEP 2: Fund Split with ETH\n`);

  const fundAmount = parseEther(args.amount);

  console.log(`Funding split with ${args.amount} ETH...`);
  const fundTx = await walletClient.sendTransaction({
    to: splitAddr,
    value: fundAmount,
  });

  await publicClient.waitForTransactionReceipt({ hash: fundTx });
  console.log(`✅ Transferred ${args.amount} ETH to split`);

  // Step 3: Check Balances (Pre-Distribute)
  console.log(`\n📋 STEP 3: Check Balances (Pre-Distribute)\n`);

  const preBalances = await splitsClient.getSplitBalance({
    splitAddress: splitAddr,
    tokenAddress: NATIVE_TOKEN_ADDRESS,
  });

  console.log(`Split Balance:     ${formatEther(preBalances.splitBalance)} ETH`);
  console.log(`Warehouse Balance: ${formatEther(preBalances.warehouseBalance)} ETH`);

  if (preBalances.splitBalance === 0n) {
    console.error(`\n❌ Expected splitBalance > 0, but got 0`);
    process.exit(1);
  }

  if (preBalances.warehouseBalance !== 0n) {
    console.error(`\n❌ Expected warehouseBalance == 0, but got ${preBalances.warehouseBalance}`);
    process.exit(1);
  }

  console.log(`✅ Balances are correct (split > 0, warehouse == 0)`);

  // Step 4: Distribute to Warehouse
  console.log(`\n📋 STEP 4: Distribute to Warehouse\n`);

  console.log(`Distributing...`);
  const { event: distributeEvent } = await splitsClient.distribute({
    splitAddress: splitAddr,
    tokenAddress: NATIVE_TOKEN_ADDRESS,
  });

  console.log(`✅ Distributed to Warehouse`);
  console.log(`   Transaction: ${distributeEvent.transactionHash}`);

  const postDistributeBalances = await splitsClient.getSplitBalance({
    splitAddress: splitAddr,
    tokenAddress: NATIVE_TOKEN_ADDRESS,
  });

  console.log(`\nPost-distribute balances:`);
  console.log(`Split Balance:     ${formatEther(postDistributeBalances.splitBalance)} ETH`);
  console.log(`Warehouse Balance: ${formatEther(postDistributeBalances.warehouseBalance)} ETH`);

  if (postDistributeBalances.splitBalance !== 0n) {
    console.error(`\n❌ Expected splitBalance == 0 after distribute, but got ${postDistributeBalances.splitBalance}`);
    process.exit(1);
  }

  if (postDistributeBalances.warehouseBalance === 0n) {
    console.error(`\n❌ Expected warehouseBalance > 0 after distribute, but got 0`);
    process.exit(1);
  }

  console.log(`✅ Balances are correct (split == 0, warehouse > 0)`);

  // Step 5: Withdraw for Each Recipient
  console.log(`\n📋 STEP 5: Withdraw for Each Recipient\n`);

  for (let i = 0; i < recipients.length; i++) {
    const recipient = recipients[i];
    const label = i === 0 ? "Platform" : `Tier ${i}`;

    console.log(`\n${label} (${recipient}):`);

    const {
      balance: preWithdrawBalance,
    } = await warehouseClient.balanceOf({
      ownerAddress: recipient,
      tokenAddress: NATIVE_TOKEN_ADDRESS,
    });

    console.log(`  Warehouse Balance: ${formatEther(preWithdrawBalance)} ETH`);

    if (preWithdrawBalance === 0n) {
      console.log(`  ⚠️  No balance to withdraw, skipping`);
      continue;
    }

    console.log(`  Withdrawing...`);
    const { event: withdrawEvent } = await warehouseClient.withdraw({
      ownerAddress: recipient,
      tokenAddress: NATIVE_TOKEN_ADDRESS,
    });

    console.log(`  ✅ Withdrawn to wallet`);
    console.log(`     Transaction: ${withdrawEvent.transactionHash}`);

    const {
      balance: postWithdrawBalance,
    } = await warehouseClient.balanceOf({
      ownerAddress: recipient,
      tokenAddress: NATIVE_TOKEN_ADDRESS,
    });

    const withdrawn = preWithdrawBalance - postWithdrawBalance;
    console.log(`     Amount: ${formatEther(withdrawn)} ETH`);
  }

  // Step 6: Final Summary
  console.log(`\n📋 STEP 6: Final Summary\n`);

  console.log(`✅ All steps completed successfully!\n`);
  console.log(`Summary:`);
  console.log(`  1. ✅ Created immutable Pull split: ${splitAddr}`);
  console.log(`  2. ✅ Funded with ${args.amount} ETH`);
  console.log(`  3. ✅ Verified pre-distribute balances`);
  console.log(`  4. ✅ Distributed to Warehouse`);
  console.log(`  5. ✅ Withdrew to all recipients`);
  console.log(`\n🎉 Pull-based referral split flow complete!\n`);
  console.log(`💡 Next steps:`);
  console.log(`   - Use ${splitAddr} as swapFeeRecipient in 0x Swap API v2`);
  console.log(`   - Recipients can withdraw their shares anytime from Warehouse\n`);
}

main().catch((error) => {
  console.error("\n❌ Demo failed:", error.message);
  if (error.cause) {
    console.error("   Cause:", error.cause);
  }
  process.exit(1);
});
