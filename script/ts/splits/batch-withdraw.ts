/**
 * Batch withdraw multiple tokens from Warehouse
 *
 * Withdraws multiple token balances in a single transaction
 * for gas efficiency. Useful when a recipient has accumulated
 * balances in several different tokens.
 */

import { type Address, formatUnits, formatEther, getAddress } from "viem";
import {
  createSplitsClients,
  getSplitsConfigFromEnv,
  NATIVE_TOKEN_ADDRESS,
  type SplitsConfig,
} from "../lib/splits-clients.js";

interface BatchWithdrawArgs {
  owner: string;
  tokens?: string;
  withdrawer?: string;
  rpc?: string;
  chainId?: string;
}

/**
 * Parse command-line arguments
 */
function parseArguments(): BatchWithdrawArgs {
  const args = process.argv.slice(2);
  const parsed: Partial<BatchWithdrawArgs> = {};

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const value = args[i + 1];

    if (!arg.startsWith("--") || !value) continue;

    const key = arg.slice(2) as keyof BatchWithdrawArgs;
    if (["owner", "tokens", "withdrawer", "rpc", "chainId"].includes(key)) {
      parsed[key] = value;
      i++;
    }
  }

  if (!parsed.owner) {
    console.error("Error: --owner is required");
    console.log("\nUsage:");
    console.log("  npx tsx script/ts/splits/batch-withdraw.ts \\");
    console.log("    --owner 0x... \\");
    console.log("    [--tokens native] \\");
    console.log("    [--withdrawer 0x...] \\");
    console.log("    [--rpc https://...] \\");
    console.log("    [--chainId 84532]");
    process.exit(1);
  }

  return parsed as BatchWithdrawArgs;
}

/**
 * Get token decimals and symbol
 */
async function getTokenInfo(
  publicClient: any,
  tokenAddress: Address
): Promise<{ decimals: number; symbol: string }> {
  if (tokenAddress === NATIVE_TOKEN_ADDRESS) {
    return { decimals: 18, symbol: "ETH" };
  }

  try {
    const [decimals, symbol] = await Promise.all([
      publicClient.readContract({
        address: tokenAddress,
        abi: [
          {
            name: "decimals",
            type: "function",
            stateMutability: "view",
            inputs: [],
            outputs: [{ type: "uint8" }],
          },
        ],
        functionName: "decimals",
      }),
      publicClient.readContract({
        address: tokenAddress,
        abi: [
          {
            name: "symbol",
            type: "function",
            stateMutability: "view",
            inputs: [],
            outputs: [{ type: "string" }],
          },
        ],
        functionName: "symbol",
      }),
    ]);

    return { decimals: Number(decimals), symbol: symbol as string };
  } catch (error) {
    return { decimals: 18, symbol: "UNKNOWN" };
  }
}

function resolveToken(value: string): Address {
  const lower = value.toLowerCase();
  if (lower === "native" || lower === "eth") {
    return NATIVE_TOKEN_ADDRESS;
  }
  return getAddress(value);
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

  const { warehouseClient, publicClient } = createSplitsClients(config);

  const ownerAddress = args.owner as Address;
  const tokenStrings = (args.tokens ?? "native").split(",").map((t) => t.trim()).filter(Boolean);
  const tokenAddresses = tokenStrings.map(resolveToken);
  const withdrawerAddress = args.withdrawer ? getAddress(args.withdrawer) : ownerAddress;

  console.log(`\n💰 Batch withdrawing from Warehouse...`);
  console.log(`   Owner: ${ownerAddress}`);
  console.log(`   Tokens: ${tokenAddresses.length} token(s)`);
  console.log(`   Chain: ${config.chainId}`);
  if (withdrawerAddress.toLowerCase() !== ownerAddress.toLowerCase()) {
    console.log(`   Withdrawer: ${withdrawerAddress} (receives funds)`);
  }

  // Get pre-withdrawal balances and amounts
  console.log(`\n🔍 Fetching balances for each token...`);
  const tokenInfos = await Promise.all(
    tokenAddresses.map((addr) => getTokenInfo(publicClient, addr))
  );

  const preBalances = (await Promise.all(
    tokenAddresses.map((addr) =>
      warehouseClient.balanceOf({
        ownerAddress,
        tokenAddress: addr,
      })
    )
  )).map(({ balance }) => balance);

  console.log(`\n📋 Pre-withdrawal Warehouse balances:`);
  tokenAddresses.forEach((addr, i) => {
    const info = tokenInfos[i];
    const balance = preBalances[i];
    console.log(
      `   ${i + 1}. ${info.symbol.padEnd(8)} ${formatUnits(balance, info.decimals).padStart(20)} (${addr})`
    );
  });

  // Filter out tokens with zero balance
  const nonZeroIndices = preBalances
    .map((bal, idx) => (bal > 0n ? idx : -1))
    .filter((idx) => idx !== -1);

  if (nonZeroIndices.length === 0) {
    console.log(`\n⚠️  No tokens with non-zero balances to withdraw`);
    process.exit(0);
  }

  const tokensToWithdraw = nonZeroIndices.map((idx) => tokenAddresses[idx]);
  const amountsToWithdraw = nonZeroIndices.map((idx) => preBalances[idx]);

  console.log(`\n📦 Withdrawing ${tokensToWithdraw.length} token(s) with non-zero balances...`);

  // Estimate gas
  console.log(`\n⛽ Estimating gas...`);
  try {
    const gasEstimate = await warehouseClient.estimateGas.batchWithdraw({
      ownerAddress,
      tokensAddresses: tokensToWithdraw,
      amounts: amountsToWithdraw,
      withdrawerAddress,
    });

    console.log(`   Estimated gas: ${gasEstimate.toString()}`);
  } catch (error) {
    console.warn("⚠️  Could not estimate gas:", (error as Error).message);
  }

  // Execute batch withdrawal
  console.log(`\n🚀 Executing batch withdrawal...`);
  const { events } = await warehouseClient.batchWithdraw({
    ownerAddress,
    tokensAddresses: tokensToWithdraw,
    amounts: amountsToWithdraw,
    withdrawerAddress,
  });

  const txHash = events[0]?.transactionHash;
  console.log(`✅ Batch withdrawal complete!`);
  if (txHash) {
    console.log(`   Transaction: ${txHash}`);

    const receipt = await publicClient.getTransactionReceipt({
      hash: txHash,
    });

    console.log(`\n⛽ Gas Used: ${receipt.gasUsed.toString()}`);
    console.log(`   Effective Gas Price: ${formatEther(receipt.effectiveGasPrice)} ETH/gas`);
  } else {
    console.log("   (Transaction hash unavailable; no withdraw events were returned)");
  }

  // Get post-withdrawal balances
  console.log(`\n🔍 Fetching post-withdrawal balances...`);
  const postBalances = (await Promise.all(
    tokenAddresses.map((addr) =>
      warehouseClient.balanceOf({
        ownerAddress,
        tokenAddress: addr,
      })
    )
  )).map(({ balance }) => balance);

  console.log(`\n📋 Post-withdrawal Warehouse balances:`);
  tokenAddresses.forEach((addr, i) => {
    const info = tokenInfos[i];
    const balance = postBalances[i];
    console.log(
      `   ${i + 1}. ${info.symbol.padEnd(8)} ${formatUnits(balance, info.decimals).padStart(20)} (${addr})`
    );
  });

  // Show withdrawal summary
  console.log(`\n📊 Withdrawal Summary:`);
  nonZeroIndices.forEach((idx) => {
    const info = tokenInfos[idx];
    const withdrawn = preBalances[idx] - postBalances[idx];
    console.log(
      `   ${info.symbol.padEnd(8)} ${formatUnits(withdrawn, info.decimals)} withdrawn`
    );
  });

  console.log(`\n✅ All tokens successfully withdrawn to recipient wallet!`);
}

main().catch((error) => {
  console.error("\n❌ Error:", error.message);
  if (error.cause) {
    console.error("   Cause:", error.cause);
  }
  process.exit(1);
});
