/**
 * TypeScript type definitions for Holograph multisig CLI operations
 * 
 * This file centralizes all types used across our multisig batch transaction
 * and Uniswap V3 pool management operations.
 */

// ============================================================================
// Tenderly Simulation Types
// ============================================================================

export interface TenderlySimulation {
  network_id: string;
  save: boolean;
  save_if_fails: boolean;
  transaction: {
    from: string;
    to: string;
    gas: number;
    gas_price: string;
    value: string;
    input: string;
  };
}

export interface TenderlyResponse {
  transaction: {
    status: boolean;
    error_message?: string;
    error_info?: any;
    call_trace?: any[];
  };
  simulation: {
    id: string;
    status: boolean;
  };
}

export interface TenderlyBundleResponse {
  simulations: Array<{
    id: string;
    status: boolean;
    transaction: { status: boolean; error_message?: string };
  }>;
}

// ============================================================================
// Safe Transaction Builder Types
// ============================================================================

export interface SafeTransactionBuilderTransaction {
  to: string;
  value: string;
  data: string | null;
  contractMethod?: {
    inputs: any[];
    name: string;
    payable: boolean;
  };
  contractInputsValues?: any;
}

export interface SafeTransactionBuilderBatch {
  version: string;
  chainId: string;
  createdAt: number;
  meta: {
    name: string;
    description: string;
    txBuilderVersion: string;
    createdFromSafeAddress: string;
    createdFromOwnerAddress: string;
    checksum: string;
  };
  transactions: SafeTransactionBuilderTransaction[];
}

// ============================================================================
// Uniswap V3 Types
// ============================================================================

/**
 * Supported Uniswap V3 fee tiers for HLG/WETH trading
 * 
 * Fee tiers determine both the swap fee and tick spacing:
 * - 500 (0.05%): tick spacing 10, for stable pairs
 * - 3000 (0.3%): tick spacing 60, for standard pairs  
 * - 10000 (1%): tick spacing 200, for exotic pairs
 */
export interface FeeTierInfo {
  fee: 500 | 3000 | 10000;
  tickSpacing: 10 | 60 | 200;
  description: string;
}

export const FEE_TIERS: Record<number, FeeTierInfo> = {
  500: { fee: 500, tickSpacing: 10, description: "0.05% - Stable pairs" },
  3000: { fee: 3000, tickSpacing: 60, description: "0.3% - Most pairs" },
  10000: { fee: 10000, tickSpacing: 200, description: "1% - Volatile pairs" }
};

export interface UniswapQuoteResult {
  amountOut: bigint;
  fee: number;
}

export interface UniswapQuoteParams {
  tokenIn: string;
  tokenOut: string;
  amountIn: bigint;
  fee: number;
  sqrtPriceLimitX96: bigint;
}

// ============================================================================
// Staking Service Types
// ============================================================================

export interface StakingInfo {
  activeStaked: bigint;
  burnBps: number;
}

export interface RewardCalculation {
  minHlgNeeded: bigint;
  expectedHlgOut: bigint;
  minHlgOut: bigint;
  scaledAmount: bigint;
}

// ============================================================================
// Configuration Types
// ============================================================================

export interface NetworkAddresses {
  FACTORY: string;
  WETH: string;
  SWAP_ROUTER: string;
  QUOTER_V2: string;
  HLG: string;
  STAKING_REWARDS: string;
}

export interface TenderlyConfig {
  account: string;
  project: string;
  accessKey: string;
}

export interface MultisigConfig {
  address: string;
  ownerAddress: string;
  ownerAddress2?: string;
  slippageBps: bigint;
}

export interface EnvironmentConfig {
  networkAddresses: NetworkAddresses;
  tenderly: TenderlyConfig;
  multisig: MultisigConfig;
  requiredFeeTier: number | undefined;
  preferFeeTier: number | undefined;
}

// ============================================================================
// CLI Operation Types
// ============================================================================

export interface CliOptions {
  command?: string;
  ethAmount?: string;
  hlgAmount?: string;
  simulateOnly?: boolean;
  transferOwnership?: boolean;
  acceptOwnership?: boolean;
  help?: boolean;
}

export interface BatchTransactionParams {
  ethAmount: string;
  multisigAddress: string;
  slippageBps: bigint;
}

export interface DirectHLGDepositParams {
  hlgAmount: string;
  multisigAddress: string;
}

// ============================================================================
// Error Types
// ============================================================================

export class MultisigCliError extends Error {
  constructor(
    message: string,
    public code: string,
    public override cause?: Error
  ) {
    super(message);
    this.name = 'MultisigCliError';
  }
}

export class TenderlySimulationError extends MultisigCliError {
  constructor(message: string, cause?: Error) {
    super(message, 'TENDERLY_SIMULATION_ERROR', cause);
  }
}

export class UniswapQuoteError extends MultisigCliError {
  constructor(message: string, cause?: Error) {
    super(message, 'UNISWAP_QUOTE_ERROR', cause);
  }
}

export class StakingCalculationError extends MultisigCliError {
  constructor(message: string, cause?: Error) {
    super(message, 'STAKING_CALCULATION_ERROR', cause);
  }
}