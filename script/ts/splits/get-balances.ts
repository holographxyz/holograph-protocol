/**
 * Get split and warehouse ETH balances
 *
 * Shows the ETH balance in both locations:
 * - splitBalance: ETH in the Split contract (not yet distributed)
 * - warehouseBalance: ETH in Warehouse (ready to withdraw)
 */

import { type Address, formatEther } from "viem";
import {
  createSplitsClients,
  getSplitsConfigFromEnv,
  NATIVE_TOKEN_ADDRESS,
  type SplitsConfig,
} from "../lib/splits-clients.js";

interface GetBalancesArgs {
  split: string;
  rpc?: string;
  chainId?: string;
}

/**
 * Parse command-line arguments
 */
function parseArguments(): GetBalancesArgs {
  const args = process.argv.slice(2);
  const parsed: Partial<GetBalancesArgs> = {};

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const value = args[i + 1];

    if (!arg || !arg.startsWith("--") || !value) continue;

    const key = arg.slice(2) as keyof GetBalancesArgs;
    if (["split", "rpc", "chainId"].includes(key)) {
      parsed[key] = value;
      i++;
    }
  }

  if (!parsed.split) {
    console.error("Error: --split is required");
    console.log("\nUsage:");
    console.log("  npm run splits:balances -- --split 0x...");
    console.log("\nOptions:");
    console.log("  --rpc       Override RPC URL");
    console.log("  --chainId   Override chain ID (8453 or 84532)");
    process.exit(1);
  }

  return parsed as GetBalancesArgs;
}

/**
 * Main execution
 */
async function main() {
  const args = parseArguments();

  const config: SplitsConfig = args.rpc || args.chainId
    ? {
        rpcUrl: args.rpc || getSplitsConfigFromEnv().rpcUrl,
        chainId: args.chainId ? parseInt(args.chainId) : getSplitsConfigFromEnv().chainId,
        privateKey: process.env.PRIVATE_KEY,
        splitsApiKey: process.env.SPLITS_API_KEY,
      }
    : getSplitsConfigFromEnv();

  const { splitsClient } = createSplitsClients(config);

  console.log(`\n🔍 Fetching ETH balances...`);
  console.log(`   Split: ${args.split}`);
  console.log(`   Chain: ${config.chainId}`);

  // Get ETH balances
  const { splitBalance, warehouseBalance } = await splitsClient.getSplitBalance({
    splitAddress: args.split as Address,
    tokenAddress: NATIVE_TOKEN_ADDRESS,
  });

  console.log(`\n📊 ETH Balances:`);
  console.log(`   Split Balance:     ${formatEther(splitBalance)} ETH`);
  console.log(`   Warehouse Balance: ${formatEther(warehouseBalance)} ETH`);
  console.log(`   Total:             ${formatEther(splitBalance + warehouseBalance)} ETH`);

  console.log(`\n🔢 Raw Values:`);
  console.log(`   Split Balance:     ${splitBalance.toString()} wei`);
  console.log(`   Warehouse Balance: ${warehouseBalance.toString()} wei`);

  console.log(`\n💡 Status:`);
  if (splitBalance > 0n && warehouseBalance === 0n) {
    console.log(`   ⏳ ETH in Split. Run distribute to move to Warehouse.`);
  } else if (splitBalance === 0n && warehouseBalance > 0n) {
    console.log(`   ✅ ETH in Warehouse. Recipients can withdraw.`);
  } else if (splitBalance > 0n && warehouseBalance > 0n) {
    console.log(`   🔄 ETH in both locations. Some distributed, some pending.`);
  } else {
    console.log(`   📭 No ETH in either location.`);
  }
}

main().catch((error) => {
  console.error("\n❌ Error:", error.message);
  if (error.cause) {
    console.error("   Cause:", error.cause);
  }
  process.exit(1);
});
