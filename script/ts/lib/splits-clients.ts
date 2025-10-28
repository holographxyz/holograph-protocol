/**
 * Splits V2 and Warehouse client configuration
 *
 * This module provides configured clients for interacting with Splits Protocol V2
 * and the Warehouse contract for pull-based fee distribution.
 */

import { createPublicClient, createWalletClient, http, type Address } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { base, baseSepolia } from "viem/chains";
import { SplitV2Client, WarehouseClient } from "@0xsplits/splits-sdk";

export interface SplitsConfig {
  rpcUrl: string;
  chainId: number;
  privateKey?: string;
  splitsApiKey?: string;
}

export interface SplitsClients {
  publicClient: ReturnType<typeof createPublicClient>;
  walletClient: ReturnType<typeof createWalletClient>;
  splitsClient: SplitV2Client;
  warehouseClient: WarehouseClient;
}

/**
 * Get viem chain object from chain ID
 */
function getChain(chainId: number) {
  switch (chainId) {
    case 8453:
      return base;
    case 84532:
      return baseSepolia;
    default:
      throw new Error(`Unsupported chain ID: ${chainId}. Supported: 8453 (Base), 84532 (Base Sepolia)`);
  }
}

/**
 * Native ETH address constant used by Splits V2
 * This special address (0xEeee...EEeE) is the standard convention
 * used by Splits Protocol to represent native ETH on any chain
 */
export const NATIVE_TOKEN_ADDRESS: Address = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

/**
 * Parse Splits configuration from environment variables
 */
export function getSplitsConfigFromEnv(): SplitsConfig {
  const chainIdStr = process.env.BASE_CHAIN_ID || process.env.CHAIN_ID || "84532";
  const chainId = parseInt(chainIdStr, 10);

  let rpcUrl: string;
  if (chainId === 8453) {
    rpcUrl = process.env.BASE_RPC_URL || "https://mainnet.base.org";
  } else if (chainId === 84532) {
    rpcUrl = process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org";
  } else {
    throw new Error(`Unsupported chain ID: ${chainId}`);
  }

  const privateKey = process.env.PRIVATE_KEY;
  const splitsApiKey = process.env.SPLITS_API_KEY;

  return {
    rpcUrl,
    chainId,
    privateKey,
    splitsApiKey,
  };
}

/**
 * Create configured Splits V2 and Warehouse clients
 */
export function createSplitsClients(config: SplitsConfig): SplitsClients {
  const chain = getChain(config.chainId);

  const publicClient = createPublicClient({
    chain,
    transport: http(config.rpcUrl),
  });

  if (!config.privateKey) {
    throw new Error(
      "Private key required for wallet client. Set PRIVATE_KEY in .env",
    );
  }

  const account = privateKeyToAccount(config.privateKey as `0x${string}`);

  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(config.rpcUrl),
  });

  const baseConfig = {
    chainId: config.chainId,
    publicClient,
    walletClient,
  };

  const splitsClient = new SplitV2Client(
    config.splitsApiKey
      ? { ...baseConfig, apiConfig: { apiKey: config.splitsApiKey } }
      : baseConfig
  );

  const warehouseClient = new WarehouseClient(
    config.splitsApiKey
      ? { ...baseConfig, apiConfig: { apiKey: config.splitsApiKey } }
      : baseConfig
  );

  return {
    publicClient,
    walletClient,
    splitsClient,
    warehouseClient,
  };
}
