/**
 * Withdraw funds from Warehouse to recipient wallet
 *
 * Pulls the entire balance of a recipient for a given token
 * from the Warehouse contract to their wallet.
 *
 * After withdrawal:
 * - Warehouse balance for recipient becomes 0
 * - Tokens are transferred to recipient's wallet
 */

import { type Address, formatEther } from "viem";
import {
  createSplitsClients,
  getSplitsConfigFromEnv,
  NATIVE_TOKEN_ADDRESS,
  type SplitsConfig,
} from "../lib/splits-clients.js";

interface WithdrawArgs {
  owner: string;
  rpc?: string;
  chainId?: string;
}

/**
 * Parse command-line arguments
 */
function parseArguments(): WithdrawArgs {
  const args = process.argv.slice(2);
  const parsed: Partial<WithdrawArgs> = {};

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const value = args[i + 1];

    if (!arg.startsWith("--") || !value) continue;

    const key = arg.slice(2) as keyof WithdrawArgs;
    if (["owner", "rpc", "chainId"].includes(key)) {
      parsed[key] = value;
      i++;
    }
  }

  if (!parsed.owner) {
    console.error("Error: --owner is required");
    console.log("\nUsage:");
    console.log("  npx tsx script/ts/splits/withdraw.ts \\");
    console.log("    --owner 0x... \\");
    console.log("    [--rpc https://...] \\");
    console.log("    [--chainId 84532]");
    process.exit(1);
  }

  return parsed as WithdrawArgs;
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

  const { warehouseClient, publicClient } = createSplitsClients(config);

  const ownerAddress = args.owner as Address;

  console.log(`\n💰 Withdrawing from Warehouse to recipient wallet...`);
  console.log(`   Owner: ${ownerAddress}`);
  console.log(`   Token: ETH (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)`);
  console.log(`   Chain: ${config.chainId}`);

  // Get pre-withdrawal balances
  console.log(`\n🔍 Pre-withdrawal balances:`);
  const { balance: preWarehouseBalance } = await warehouseClient.balanceOf({
    ownerAddress,
    tokenAddress: NATIVE_TOKEN_ADDRESS,
  });

  const preWalletBalance = await publicClient.getBalance({ address: ownerAddress });

  console.log(`   Warehouse Balance: ${formatEther(preWarehouseBalance)} ETH`);
  console.log(`   Wallet Balance:    ${formatEther(preWalletBalance)} ETH`);

  if (preWarehouseBalance === 0n) {
    console.log(`\n⚠️  No funds to withdraw (warehouse balance is 0)`);
    process.exit(0);
  }

  // Estimate gas
  console.log(`\n⛽ Estimating gas...`);
  try {
    const gasEstimate = await warehouseClient.estimateGas.withdraw({
      ownerAddress,
      tokenAddress: NATIVE_TOKEN_ADDRESS,
    });

    console.log(`   Estimated gas: ${gasEstimate.toString()}`);
  } catch (error) {
    console.warn("⚠️  Could not estimate gas:", (error as Error).message);
  }

  // Execute withdrawal
  console.log(`\n🚀 Executing withdrawal...`);
  const { event } = await warehouseClient.withdraw({
    ownerAddress,
    tokenAddress: NATIVE_TOKEN_ADDRESS,
  });

  console.log(`✅ Withdrawal complete!`);
  console.log(`   Transaction: ${event.transactionHash}`);

  // Get gas used
  const receipt = await publicClient.getTransactionReceipt({
    hash: event.transactionHash,
  });

  console.log(`\n⛽ Gas Used: ${receipt.gasUsed.toString()}`);
  console.log(`   Effective Gas Price: ${formatEther(receipt.effectiveGasPrice)} ETH/gas`);

  // Get post-withdrawal balances
  console.log(`\n🔍 Post-withdrawal balances:`);
  const { balance: postWarehouseBalance } = await warehouseClient.balanceOf({
    ownerAddress,
    tokenAddress: NATIVE_TOKEN_ADDRESS,
  });

  const postWalletBalance = await publicClient.getBalance({ address: ownerAddress });

  console.log(`   Warehouse Balance: ${formatEther(postWarehouseBalance)} ETH`);
  console.log(`   Wallet Balance:    ${formatEther(postWalletBalance)} ETH`);

  // Show amounts moved
  const amountWithdrawn = preWarehouseBalance - postWarehouseBalance;
  const walletIncrease = postWalletBalance - preWalletBalance;

  console.log(`\n📊 Withdrawal Summary:`);
  console.log(`   Amount Withdrawn:  ${formatEther(amountWithdrawn)} ETH`);
  console.log(`   Wallet Increase:   ${formatEther(walletIncrease)} ETH`);

  console.log(`\n✅ Funds successfully withdrawn to recipient wallet!`);
}

main().catch((error) => {
  console.error("\n❌ Error:", error.message);
  if (error.cause) {
    console.error("   Cause:", error.cause);
  }
  process.exit(1);
});
