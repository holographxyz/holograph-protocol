/**
 * StakingService - Handles StakingRewards contract interactions and calculations
 * 
 * This service manages all operations related to the HLG staking contract,
 * including reward calculations, threshold validation, and ownership management.
 * 
 * Key concepts:
 * - RewardTooSmall error: Occurs when (rewardAmount * 1e12) / activeStaked < 1
 * - Burn percentage: Configurable percentage of deposited HLG that gets burned
 * - Active staked: Total staked minus unallocated rewards
 */

import { createPublicClient, http, parseAbi, encodeFunctionData } from "viem";
import { sepolia } from "viem/chains";
import { 
  StakingInfo, 
  RewardCalculation,
  StakingCalculationError,
  EnvironmentConfig 
} from "../types/index.js";
import { getEnvironmentConfig, CONSTANTS } from "../lib/config.js";
import { formatCompactEther, formatPercent } from "../lib/format.js";

export class StakingService {
  private config: EnvironmentConfig;
  private client = createPublicClient({ chain: sepolia, transport: http() });

  constructor() {
    this.config = getEnvironmentConfig();
  }

  /**
   * Get current staking information from the contract
   * 
   * This includes:
   * - Total staked amount
   * - Unallocated rewards (rewards deposited but not yet distributed)
   * - Burn percentage (how much of deposits get burned vs distributed)
   * - Active staked (total - unallocated, used for threshold calculations)
   * 
   * @returns Promise<StakingInfo> - Current staking state
   */
  async getStakingInfo(): Promise<StakingInfo> {
    const { networkAddresses } = this.config;

    try {
      const [totalStaked, unallocatedRewards, burnPercentage] = await Promise.all([
        this.client.readContract({
          address: networkAddresses.STAKING_REWARDS as `0x${string}`,
          abi: parseAbi(["function totalStaked() view returns (uint256)"]),
          functionName: "totalStaked",
        }),
        this.client.readContract({
          address: networkAddresses.STAKING_REWARDS as `0x${string}`,
          abi: parseAbi(["function unallocatedRewards() view returns (uint256)"]),
          functionName: "unallocatedRewards",
        }),
        this.client.readContract({
          address: networkAddresses.STAKING_REWARDS as `0x${string}`,
          abi: parseAbi(["function burnPercentage() view returns (uint256)"]),
          functionName: "burnPercentage",
        }),
      ]) as [bigint, bigint, bigint];

      const activeStaked = totalStaked - unallocatedRewards;
      const burnBps = Number(burnPercentage);

      return { activeStaked, burnBps };
    } catch (error) {
      throw new StakingCalculationError("Failed to fetch staking info", error as Error);
    }
  }

  /**
   * Calculate minimum HLG needed to avoid RewardTooSmall error
   * 
   * The StakingRewards contract enforces a minimum reward threshold:
   * (rewardAmount * INDEX_PRECISION) / activeStaked >= 1
   * 
   * Where:
   * - rewardAmount = depositAmount * (1 - burnBps/10000)
   * - INDEX_PRECISION = 1e12
   * - activeStaked = totalStaked - unallocatedRewards
   * 
   * This ensures meaningful reward distribution and prevents dust attacks.
   * 
   * @param activeStaked - Current active staked amount
   * @param burnBps - Burn percentage in basis points (e.g., 5000 = 50%)
   * @returns bigint - Minimum HLG deposit amount to avoid RewardTooSmall
   */
  calculateMinHLGToAvoidRewardTooSmall(activeStaked: bigint, burnBps: number): bigint {
    if (activeStaked <= 0n) {
      return 0n; // No stakers means function will be no-op
    }

    // Calculate minimum reward needed: ceil(activeStaked / 1e12)
    const minReward = (activeStaked + CONSTANTS.INDEX_PRECISION - 1n) / CONSTANTS.INDEX_PRECISION;
    
    // Account for burn: depositAmount * (1 - burnBps/10000) >= minReward
    // Therefore: depositAmount >= minReward * 10000 / (10000 - burnBps)
    const numerator = minReward * 10_000n;
    const denominator = BigInt(10_000 - burnBps);
    
    // Use ceiling division to ensure we meet the threshold
    return (numerator + denominator - 1n) / denominator;
  }

  /**
   * Calculate optimal reward distribution for a given deposit
   * 
   * @param stakingInfo - Current staking state
   * @param depositAmount - Amount of HLG to deposit
   * @returns RewardCalculation - Detailed breakdown of the distribution
   */
  calculateRewardDistribution(stakingInfo: StakingInfo, depositAmount: bigint): RewardCalculation {
    const { activeStaked, burnBps } = stakingInfo;
    
    // Calculate actual reward amount after burn
    const burnAmount = (depositAmount * BigInt(burnBps)) / 10_000n;
    const _rewardAmount = depositAmount - burnAmount; // Computed for reference but not currently used
    
    // Check if this meets the minimum threshold
    const minHlgNeeded = this.calculateMinHLGToAvoidRewardTooSmall(activeStaked, burnBps);
    const _meetsThreshold = depositAmount >= minHlgNeeded; // Computed for reference but not currently used
    
    return {
      minHlgNeeded,
      expectedHlgOut: depositAmount,
      minHlgOut: depositAmount, // For direct deposits, these are the same
      scaledAmount: depositAmount
    };
  }

  /**
   * Get current contract owner
   * 
   * @returns Promise<string> - Current owner address
   */
  async getCurrentOwner(): Promise<string> {
    const { networkAddresses } = this.config;

    try {
      const owner = await this.client.readContract({
        address: networkAddresses.STAKING_REWARDS as `0x${string}`,
        abi: parseAbi(["function owner() view returns (address)"]),
        functionName: "owner",
      }) as string;

      return owner;
    } catch (error) {
      throw new StakingCalculationError("Failed to get current owner", error as Error);
    }
  }

  /**
   * Get pending owner (if ownership transfer is in progress)
   * 
   * @returns Promise<string | null> - Pending owner address or null
   */
  async getPendingOwner(): Promise<string | null> {
    const { networkAddresses } = this.config;

    try {
      const pendingOwner = await this.client.readContract({
        address: networkAddresses.STAKING_REWARDS as `0x${string}`,
        abi: parseAbi(["function pendingOwner() view returns (address)"]),
        functionName: "pendingOwner",
      }) as string;

      return pendingOwner === "0x0000000000000000000000000000000000000000" ? null : pendingOwner;
    } catch {
      // pendingOwner() might not exist if no transfer is pending
      return null;
    }
  }

  /**
   * Generate transaction data for transferring ownership
   * 
   * @param newOwner - Address to transfer ownership to
   * @returns string - Encoded transaction data
   */
  generateTransferOwnershipData(newOwner: string): string {
    return encodeFunctionData({
      abi: parseAbi(["function transferOwnership(address newOwner)"]),
      functionName: "transferOwnership",
      args: [newOwner as `0x${string}`],
    });
  }

  /**
   * Generate transaction data for accepting ownership
   * 
   * @returns string - Encoded transaction data
   */
  generateAcceptOwnershipData(): string {
    return encodeFunctionData({
      abi: parseAbi(["function acceptOwnership()"]),
      functionName: "acceptOwnership",
    });
  }

  /**
   * Generate transaction data for depositAndDistribute
   * 
   * @param amount - Amount of HLG to deposit and distribute
   * @returns string - Encoded transaction data
   */
  generateDepositAndDistributeData(amount: bigint): string {
    return encodeFunctionData({
      abi: parseAbi(["function depositAndDistribute(uint256)"]),
      functionName: "depositAndDistribute",
      args: [amount],
    });
  }

  /**
   * Provide educational explanation of staking mechanics
   * 
   * @returns string - Detailed explanation of staking concepts
   */
  explainStakingMechanics(): string {
    return `
🎓 HLG Staking Mechanics Explained:

📊 **Core Concepts:**
   • Total Staked: All HLG currently staked by users
   • Unallocated Rewards: Rewards deposited but not yet distributed
   • Active Staked: Total - Unallocated (basis for reward calculations)
   • Burn Percentage: % of deposits burned (default 50%)

⚡ **RewardTooSmall Protection:**
   • Prevents dust attacks and meaningless distributions
   • Formula: (rewardAmount × 1e12) ÷ activeStaked ≥ 1
   • Example: With 1M HLG staked, minimum reward = 1 wei
   • Scales automatically with total staked amount

🔥 **Burn/Reward Split:**
   • Default: 50% burned, 50% distributed as rewards
   • Burned tokens are permanently removed from supply
   • Remaining tokens boost rewards for all stakers
   • Split is configurable by contract owner

💡 **For Batch Operations:**
   • Auto-scaling ensures we always meet minimum threshold
   • Larger stakes = higher absolute minimum deposits
   • Monitor activeStaked before large operations
   • Consider timing around major stake/unstake events
    `;
  }

  /**
   * Get network addresses for current configuration
   */
  getNetworkAddresses() {
    return this.config.networkAddresses;
  }

  /**
   * Get logging-friendly summary of staking state
   */
  async getStakingSummary(): Promise<string> {
    try {
      const info = await this.getStakingInfo();
      const minDeposit = this.calculateMinHLGToAvoidRewardTooSmall(info.activeStaked, info.burnBps);
      
      return `
📊 Current Staking State:
   • Active Staked: ${formatCompactEther(info.activeStaked)} HLG
   • Burn Percentage: ${formatPercent(info.burnBps / 100)}
   • Min Deposit (RewardTooSmall): ${formatCompactEther(minDeposit)} HLG
      `;
    } catch (error) {
      return "❌ Failed to fetch staking summary";
    }
  }
}