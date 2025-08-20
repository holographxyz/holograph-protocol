/**
 * Centralized configuration management for multisig CLI operations
 * 
 * This module handles environment variable parsing, validation, and provides
 * typed configuration objects for all services.
 */

import { getAddress } from "viem";
import { 
  EnvironmentConfig, 
  NetworkAddresses, 
  TenderlyConfig, 
  MultisigConfig,
  SafeConfig,
  ExecutionMode,
  MultisigCliError 
} from "../types/index.js";

// ============================================================================
// Network Addresses (Ethereum Sepolia Testnet)
// ============================================================================

/**
 * Verified Uniswap V3 and protocol addresses on Sepolia testnet
 * These addresses are from official Uniswap documentation
 */
export const SEPOLIA_ADDRESSES: NetworkAddresses = {
  FACTORY: "0x0227628f3F023bb0B980b67D528571c95c6DaC1c",
  WETH: "0xfff9976782d46cc05630d1f6ebab18b2324d6b14",
  SWAP_ROUTER: "0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E", // SwapRouter02
  QUOTER_V2: "0xEd1f6473345F45b75F8179591dd5bA1888cf2FB3",
  HLG: "0x5ff07042d14e60ec1de7a860bbe968344431baa1",
  STAKING_REWARDS: "0xff5CEBc016f50d40D4C1eCaDB7427c5F3E3c3f97",  // Latest deployment
  FEE_ROUTER: "0xA042bd2391a2756907AFf8e2837E30b70A2743C5",  // Latest deployment
};

// ============================================================================
// Configuration Parsing and Validation
// ============================================================================

/**
 * Parse and validate Tenderly configuration from environment variables
 * Supports multiple environment variable naming conventions
 */
function parseTenderlyConfig(): TenderlyConfig {
  const account = process.env.TENDERLY_ACCOUNT || 
                 process.env.TENDERLY_USER || 
                 process.env.TENDERLY_USERNAME;
  
  const project = process.env.TENDERLY_PROJECT || 
                 process.env.TENDERLY_PROJECT_SLUG;
  
  const accessKey = process.env.TENDERLY_ACCESS_KEY || 
                   process.env.TENDERLY_TOKEN;

  if (!account || !project || !accessKey) {
    const missing = [
      !account && "TENDERLY_ACCOUNT",
      !project && "TENDERLY_PROJECT", 
      !accessKey && "TENDERLY_ACCESS_KEY"
    ].filter(Boolean).join(", ");
    
    throw new MultisigCliError(
      `Missing required Tenderly environment variables: ${missing}`,
      "MISSING_TENDERLY_CONFIG"
    );
  }

  return { account, project, accessKey };
}

/**
 * Parse and validate multisig configuration from environment variables
 */
function parseMultisigConfig(): MultisigConfig {
  const address = process.env.MULTISIG_ADDRESS || "0x8FE61F653450051cEcbae12475BA2b8fbA628c7A";
  const ownerAddress = process.env.SAFE_OWNER_ADDRESS || 
                      process.env.MULTISIG_OWNER_ADDRESS ||
                      "0x1ef43b825f6d1c3bfa93b3951e711f5d64550bda";
  
  const ownerAddress2 = process.env.SAFE_OWNER_ADDRESS_2 || 
                       process.env.SAFE_SECOND_OWNER ||
                       "0x2ef43b825f6d1c3bfa93b3951e711f5d64550bdb";

  const slippageBps = BigInt(parseInt(process.env.SLIPPAGE_BPS || "5000", 10));

  // Validate addresses
  try {
    getAddress(address);
    getAddress(ownerAddress);
    getAddress(ownerAddress2);
  } catch (error) {
    throw new MultisigCliError(
      "Invalid multisig address configuration",
      "INVALID_ADDRESS_CONFIG",
      error as Error
    );
  }

  return {
    address,
    ownerAddress,
    ownerAddress2,
    slippageBps
  };
}

/**
 * Parse Safe SDK configuration from environment variables
 */
function parseSafeConfig(): SafeConfig | undefined {
  const privateKey = process.env.SAFE_PRIVATE_KEY;
  const signerAddress = process.env.SAFE_SIGNER_ADDRESS;
  const transactionServiceUrl = process.env.SAFE_TRANSACTION_SERVICE_URL || 
                                process.env.SAFE_SERVICE_URL;
  const defaultExecutionMode = (process.env.DEFAULT_EXECUTION_MODE as ExecutionMode) || "json";

  // If no Safe-specific config is provided, return undefined
  if (!privateKey && !transactionServiceUrl) {
    return undefined;
  }

  const config: SafeConfig = {
    defaultExecutionMode
  };

  if (privateKey) {
    config.privateKey = privateKey;
    
    // If private key is provided but no signer address, we'll derive it later
    if (signerAddress) {
      try {
        config.signerAddress = getAddress(signerAddress);
      } catch (error) {
        console.warn("Invalid SAFE_SIGNER_ADDRESS provided, will derive from private key");
      }
    }
  }

  if (transactionServiceUrl) {
    config.transactionServiceUrl = transactionServiceUrl;
  }

  return config;
}

/**
 * Get complete environment configuration with validation
 */
export function getEnvironmentConfig(): EnvironmentConfig {
  try {
    const tenderly = parseTenderlyConfig();
    const multisig = parseMultisigConfig();
    const safe = parseSafeConfig();
    
    const requiredFeeTier = process.env.REQUIRED_FEE_TIER ? 
      parseInt(process.env.REQUIRED_FEE_TIER, 10) : undefined;
    
    const preferFeeTier = process.env.PREFER_FEE_TIER ? 
      parseInt(process.env.PREFER_FEE_TIER, 10) : undefined;

    // Default to Sepolia testnet (chain ID 11155111)
    const chainId = parseInt(process.env.CHAIN_ID || "11155111", 10);

    return {
      networkAddresses: SEPOLIA_ADDRESSES,
      tenderly,
      multisig,
      safe,
      chainId,
      requiredFeeTier,
      preferFeeTier
    };
  } catch (error) {
    if (error instanceof MultisigCliError) {
      throw error;
    }
    throw new MultisigCliError(
      "Failed to parse environment configuration",
      "CONFIG_PARSE_ERROR",
      error as Error
    );
  }
}

/**
 * Get Tenderly configuration with fallback to manual simulation links
 */
export function getTenderlyConfigOrFallback(): { config: TenderlyConfig | null; fallbackAddress: string } {
  try {
    const config = parseTenderlyConfig();
    const multisig = parseMultisigConfig();
    return { config, fallbackAddress: multisig.ownerAddress };
  } catch (error) {
    // Return fallback info for manual simulation links
    const multisig = parseMultisigConfig();
    return { config: null, fallbackAddress: multisig.ownerAddress };
  }
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Validate that a fee tier is supported
 */
export function validateFeeTier(fee: number): fee is 500 | 3000 | 10000 {
  return [500, 3000, 10000].includes(fee);
}

/**
 * Get tick spacing for a given fee tier
 */
export function getTickSpacing(fee: number): number {
  switch (fee) {
    case 500: return 10;
    case 3000: return 60;
    case 10000: return 200;
    default:
      throw new MultisigCliError(
        `Unsupported fee tier: ${fee}. Supported tiers: 500, 3000, 10000`,
        "UNSUPPORTED_FEE_TIER"
      );
  }
}

/**
 * Create manual Tenderly simulation URL for fallback
 */
export function createManualTenderlyUrl(
  fromAddress: string,
  toAddress: string,
  value: string,
  data: string
): string {
  const encodedData = encodeURIComponent(data);
  return `https://dashboard.tenderly.co/simulator/new?network=11155111&from=${getAddress(fromAddress)}&to=${getAddress(toAddress)}&value=${value}&input=${encodedData}`;
}

// ============================================================================
// Constants
// ============================================================================

export const CONSTANTS = {
  CHAIN_ID: "11155111", // Sepolia
  MULTISEND_CALL_ONLY: "0x40A2aCCbd92BCA938b02010E17A5b8929b49130D", // Canonical Safe MultiSendCallOnly
  INDEX_PRECISION: 1_000_000_000_000n, // 1e12 for staking calculations
  DEFAULT_GAS_LIMIT: 3_000_000,
  DEFAULT_GAS_PRICE: "1000000000", // 1 gwei
  SIMULATION_TIMEOUT: 30000, // 30 seconds
} as const;