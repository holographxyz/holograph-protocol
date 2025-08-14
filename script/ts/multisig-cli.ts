#!/usr/bin/env tsx
/**
 * Holograph Multisig CLI - Main entry point for Safe batch operations
 * 
 * This CLI tool generates Gnosis Safe Transaction Builder compatible JSON
 * for common operations in the Holograph protocol, including:
 * 
 * - ETH → WETH → HLG → StakingRewards batch transactions
 * - Direct HLG deposits to StakingRewards  
 * - StakingRewards ownership management
 * - Tenderly simulation integration for pre-execution validation
 * 
 * Usage Examples:
 *   npm run multisig-cli 0.5                    # Convert 0.5 ETH to HLG and stake
 *   npm run multisig-cli --hlg 1000             # Direct deposit 1000 HLG 
 *   npm run multisig-cli --simulate-only 0.1    # Simulate without JSON output
 *   npm run multisig-cli --transfer-ownership   # Start ownership transfer
 *   npm run multisig-cli --accept-ownership     # Complete ownership transfer
 */

import "dotenv/config";
import { parseEther, formatEther } from "viem";
import { 
  CliOptions,
  BatchTransactionParams,
  DirectHLGDepositParams,
  MultisigCliError 
} from "./types/index.js";
import { getEnvironmentConfig } from "./lib/config.js";
import { TenderlyService } from "./services/TenderlyService.js";
import { UniswapService } from "./services/UniswapService.js";
import { StakingService } from "./services/StakingService.js";
import { SafeTransactionBuilder } from "./services/SafeTransactionBuilder.js";

// ============================================================================
// Main CLI Class
// ============================================================================

export class MultisigCLI {
  private tenderlyService: TenderlyService;
  private uniswapService: UniswapService;
  private stakingService: StakingService;
  private safeBuilder: SafeTransactionBuilder;
  private config = getEnvironmentConfig();

  constructor() {
    this.tenderlyService = new TenderlyService();
    this.uniswapService = new UniswapService();
    this.stakingService = new StakingService();
    this.safeBuilder = new SafeTransactionBuilder();
  }

  /**
   * Generate ETH → HLG → StakingRewards batch transaction
   * 
   * This is the main operation flow for fee distribution:
   * 1. Gets optimal Uniswap quote across fee tiers
   * 2. Calculates minimum HLG needed to avoid RewardTooSmall error
   * 3. Auto-scales ETH amount if needed to meet threshold
   * 4. Simulates transaction with Tenderly for validation
   * 5. Outputs Safe Transaction Builder compatible JSON
   */
  async generateBatchTransaction(ethAmount: string, simulateOnly: boolean = false): Promise<void> {
    try {
      let amount = parseEther(ethAmount);
      const multisigAddress = this.config.multisig.address;

      console.log(`🚀 Generating batch transaction for ${ethAmount} ETH`);
      console.log(`📍 Multisig Address: ${multisigAddress}`);

      // Get current staking state to determine minimum requirements
      console.log("\n📊 Checking staking requirements...");
      const stakingInfo = await this.stakingService.getStakingInfo();
      const minHlgNeeded = this.stakingService.calculateMinHLGToAvoidRewardTooSmall(
        stakingInfo.activeStaked,
        stakingInfo.burnBps
      );

      console.log(await this.stakingService.getStakingSummary());

      // Get optimal Uniswap quote
      console.log("💱 Getting optimal Uniswap quote...");
      let { amountOut: expectedHlgOut, fee: poolFee } = await this.uniswapService.getOptimalQuote(amount);
      
      let slippageBps = this.config.multisig.slippageBps;
      let minHlgOut = (expectedHlgOut * (10_000n - slippageBps)) / 10_000n;

      console.log(`Expected HLG: ${formatEther(expectedHlgOut)}`);
      console.log(`Min HLG (${Number(slippageBps) / 100}% slippage): ${formatEther(minHlgOut)}`);

      // Auto-scale if needed to meet RewardTooSmall threshold
      if (minHlgNeeded > 0n && minHlgOut < minHlgNeeded) {
        console.log("\n⚡ Auto-scaling ETH amount to meet RewardTooSmall threshold...");
        amount = await this.autoScaleForThreshold(amount, minHlgNeeded, slippageBps);
        
        // Recalculate with scaled amount
        const newQuote = await this.uniswapService.getOptimalQuote(amount);
        expectedHlgOut = newQuote.amountOut;
        poolFee = newQuote.fee;
        minHlgOut = (expectedHlgOut * (10_000n - slippageBps)) / 10_000n;
        
        console.log(`✅ Scaled to ${formatEther(amount)} ETH`);
        console.log(`New expected HLG: ${formatEther(expectedHlgOut)}`);
      }

      // Create the Safe batch transaction
      console.log("\n🏗️  Building Safe batch transaction...");
      const batch = this.safeBuilder.createBatchTransaction(
        {
          ethAmount: formatEther(amount),
          multisigAddress,
          slippageBps
        },
        expectedHlgOut,
        minHlgOut,
        poolFee
      );

      // Simulate with Tenderly
      await this.simulateBatchTransaction(batch, multisigAddress, amount, expectedHlgOut);

      // Output the final JSON only if not simulate-only mode
      if (!simulateOnly) {
        this.safeBuilder.displayInstructions(batch);
      } else {
        console.log("\n✅ Simulation completed successfully! (simulate-only mode)");
      }

    } catch (error) {
      this.handleError("Failed to generate batch transaction", error);
    }
  }

  /**
   * Generate direct HLG deposit transaction
   * 
   * For cases where the Safe already holds HLG tokens and wants to
   * deposit them directly without swapping.
   */
  async generateDirectHLGDeposit(hlgAmount: string): Promise<void> {
    try {
      const multisigAddress = this.config.multisig.address;
      
      console.log(`🎯 Generating direct HLG deposit for ${hlgAmount} HLG`);
      console.log(`📍 Multisig Address: ${multisigAddress}`);
      console.log(`⚠️  Reminder: Safe must hold at least ${hlgAmount} HLG balance`);

      // Check if this amount meets threshold
      const stakingInfo = await this.stakingService.getStakingInfo();
      const amount = parseEther(hlgAmount);
      const minHlgNeeded = this.stakingService.calculateMinHLGToAvoidRewardTooSmall(
        stakingInfo.activeStaked,
        stakingInfo.burnBps
      );

      if (minHlgNeeded > 0n && amount < minHlgNeeded) {
        console.log(`⚠️  Warning: Deposit amount ${formatEther(amount)} is below minimum required ${formatEther(minHlgNeeded)}`);
        console.log("Consider increasing the amount or waiting for more stakers to join.");
      }

      console.log(await this.stakingService.getStakingSummary());

      // Create the direct deposit batch
      const batch = this.safeBuilder.createDirectHLGDeposit({
        hlgAmount,
        multisigAddress
      });

      this.safeBuilder.displayInstructions(batch);

    } catch (error) {
      this.handleError("Failed to generate direct HLG deposit", error);
    }
  }

  /**
   * Handle StakingRewards ownership transfer initiation
   * 
   * Provides instructions for the current owner to transfer ownership
   * to the Safe, and for the Safe to accept it.
   */
  async transferStakingRewardsOwnership(): Promise<void> {
    try {
      const stakingRewardsAddress = this.config.networkAddresses.STAKING_REWARDS;
      const safeAddress = this.config.multisig.address;
      
      console.log("=== StakingRewards Ownership Transfer ===");
      console.log(`StakingRewards: ${stakingRewardsAddress}`);
      console.log(`Target Safe: ${safeAddress}`);
      
      // Check current ownership state
      const currentOwner = await this.stakingService.getCurrentOwner();
      console.log(`Current owner: ${currentOwner}`);
      
      if (currentOwner.toLowerCase() === safeAddress.toLowerCase()) {
        console.log("✅ Safe is already the owner!");
        return;
      }
      
      // Check for pending transfer
      const pendingOwner = await this.stakingService.getPendingOwner();
      if (pendingOwner?.toLowerCase() === safeAddress.toLowerCase()) {
        console.log("⏳ Ownership transfer already initiated. Safe needs to call acceptOwnership()");
        console.log("\nNext steps:");
        console.log("1. Execute this transaction from the Safe:");
        console.log(`   - To: ${stakingRewardsAddress}`);
        console.log(`   - Data: ${this.stakingService.generateAcceptOwnershipData()}`);
        console.log("\nOr run: npm run accept-staking-ownership");
        return;
      }
      
      // Generate transfer instructions
      const transferData = this.stakingService.generateTransferOwnershipData(safeAddress);
      
      console.log("\n=== Step 1: Current Owner Must Execute ===");
      console.log("The current owner must execute this transaction:");
      console.log(`To: ${stakingRewardsAddress}`);
      console.log(`Data: ${transferData}`);
      console.log(`\nOr using cast:`);
      console.log(`cast send ${stakingRewardsAddress} 'transferOwnership(address)' ${safeAddress} --private-key $DEPLOYER_PK --rpc-url $ETHEREUM_SEPOLIA_RPC_URL`);
      
      console.log("\n=== Step 2: Safe Must Accept ===");
      console.log("After step 1, the Safe must execute this transaction:");
      console.log(`To: ${stakingRewardsAddress}`);
      console.log(`Data: ${this.stakingService.generateAcceptOwnershipData()}`);
      
      console.log("\n=== Alternative: Complete Both Steps ===");
      console.log("Or run: npm run transfer-staking-ownership && npm run accept-staking-ownership");

    } catch (error) {
      this.handleError("Failed to process ownership transfer", error);
    }
  }

  /**
   * Generate Safe transaction to accept StakingRewards ownership
   */
  async generateAcceptOwnershipTransaction(): Promise<void> {
    try {
      const multisigAddress = this.config.multisig.address;
      
      console.log("=== Accept StakingRewards Ownership ===");
      
      const batch = this.safeBuilder.createAcceptOwnershipTransaction(multisigAddress);
      
      this.safeBuilder.displayInstructions(batch);

    } catch (error) {
      this.handleError("Failed to generate accept ownership transaction", error);
    }
  }

  /**
   * Display educational information about the CLI and concepts
   */
  displayHelp(): void {
    console.log(`
🔧 Holograph Multisig CLI

This tool generates Safe Transaction Builder compatible JSON for Holograph protocol operations.

📚 **Key Concepts:**

${this.uniswapService.explainFeeTierStrategy()}

${this.stakingService.explainStakingMechanics()}

🎯 **Usage Examples:**

  npm run multisig-cli 0.5                    # Convert 0.5 ETH to HLG and stake
  npm run multisig-cli --hlg 1000             # Direct deposit 1000 HLG 
  npm run multisig-cli --simulate-only 0.1    # Simulate without JSON output
  npm run multisig-cli --transfer-ownership   # Start ownership transfer
  npm run multisig-cli --accept-ownership     # Complete ownership transfer

🔧 **Environment Variables:**

  MULTISIG_ADDRESS              # Safe contract address
  SAFE_OWNER_ADDRESS            # Primary Safe owner for simulation
  SAFE_OWNER_ADDRESS_2          # Secondary Safe owner  
  SLIPPAGE_BPS                  # Slippage tolerance (default: 5000 = 50%)
  TENDERLY_ACCOUNT              # Tenderly account name
  TENDERLY_PROJECT              # Tenderly project name
  TENDERLY_ACCESS_KEY           # Tenderly API access key
  REQUIRED_FEE_TIER             # Force specific Uniswap fee tier
  PREFER_FEE_TIER               # Prefer specific fee tier with fallback

📖 **Documentation:** See docs/multisig-cli.md for detailed usage guide
    `);
  }

  // ========================================================================
  // Private Helper Methods
  // ========================================================================

  /**
   * Auto-scale ETH amount to meet RewardTooSmall threshold
   */
  private async autoScaleForThreshold(
    initialAmount: bigint,
    minHlgNeeded: bigint,
    slippageBps: bigint
  ): Promise<bigint> {
    let amount = initialAmount;
    let attempts = 0;
    const maxAttempts = 6;

    while (attempts < maxAttempts) {
      const quote = await this.uniswapService.getOptimalQuote(amount);
      const minHlgOut = (quote.amountOut * (10_000n - slippageBps)) / 10_000n;
      
      if (minHlgOut >= minHlgNeeded) {
        // Binary search refinement for 2 iterations to optimize amount
        let low = initialAmount;
        let high = amount;
        
        for (let i = 0; i < 2; i++) {
          const mid = (low + high) / 2n;
          const midQuote = await this.uniswapService.getOptimalQuote(mid);
          const midMinOut = (midQuote.amountOut * (10_000n - slippageBps)) / 10_000n;
          
          if (midMinOut >= minHlgNeeded) {
            high = mid;
          } else {
            low = mid + 1n;
          }
        }
        
        return high;
      }

      // Exponential scaling with safety limits
      const ratio = Number(minHlgNeeded) / Math.max(1, Number(minHlgOut));
      const factor = Math.min(2.0, Math.max(1.15, ratio * 1.05));
      amount = BigInt(Math.ceil(Number(amount) * factor));
      attempts++;
    }

    console.log(`⚠️  Warning: Could not scale to meet threshold after ${maxAttempts} attempts`);
    return amount;
  }

  /**
   * Simulate batch transaction with Tenderly
   */
  private async simulateBatchTransaction(
    batch: any,
    multisigAddress: string,
    amount: bigint,
    expectedHlgOut: bigint
  ): Promise<void> {
    console.log("\n🧪 Tenderly Simulation");
    
    try {
      // Create multisend calldata for simulation
      const { multisendAddress, calldata } = this.safeBuilder.createMultisendCalldata(batch.transactions);
      
      // Try bundle simulation first (full Safe workflow)
      try {
        const bundleUrl = await this.tenderlyService.simulateSafeBundle(
          multisigAddress,
          multisendAddress,
          calldata,
          this.config.multisig.ownerAddress,
          this.config.multisig.ownerAddress2!
        );
        if (bundleUrl) {
          console.log(`🔗 Bundle simulation: ${bundleUrl}`);
        }
      } catch {
        // Non-fatal: continue with single simulation
      }

      // Create Safe execTransaction data (like the original working script)
      const safeExecCalldata = this.tenderlyService.createSafeExecutionData(
        multisendAddress,
        "0", 
        calldata,
        1 // DELEGATECALL for multisend
      );

      // Simulate Safe calling itself with execTransaction (original approach)
      const result = await this.tenderlyService.simulateTransaction(
        multisigAddress,
        multisigAddress,  // Safe calling itself 
        safeExecCalldata, // execTransaction data
        "0",
        undefined,        // Use default from address
        {
          [this.config.networkAddresses.WETH]: amount * 2n,
          [this.config.networkAddresses.HLG]: expectedHlgOut * 10n,
        }
      );

      if (result.transaction.status) {
        console.log("✅ Simulation SUCCESS!");
      } else {
        console.log("❌ Simulation FAILED");
        console.log("Error:", result.transaction.error_message || "Unknown error");
        console.log("\n⚠️  Transaction failed simulation but JSON is generated below for investigation:");
      }

    } catch (error) {
      console.log("❌ Simulation request failed:", (error as Error).message);
      console.log("\n⚠️  Proceeding without simulation...");
    }
  }

  /**
   * Handle errors with appropriate logging and context
   */
  private handleError(message: string, error: unknown): void {
    console.error(`\n❌ ${message}`);
    
    if (error instanceof MultisigCliError) {
      console.error(`Code: ${error.code}`);
      console.error(`Details: ${error.message}`);
      if (error.cause) {
        console.error(`Cause: ${error.cause.message}`);
      }
    } else if (error instanceof Error) {
      console.error(`Details: ${error.message}`);
    } else {
      console.error(`Details: ${String(error)}`);
    }
    
    console.error("\n💡 For help, run: npm run multisig-cli --help");
    process.exit(1);
  }
}

// ============================================================================
// CLI Argument Parsing and Main Execution
// ============================================================================

/**
 * Parse command line arguments into typed options
 */
function parseCliArgs(): CliOptions {
  const args = process.argv.slice(2);
  const options: CliOptions = {};

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    switch (arg) {
      case "--help":
      case "-h":
        return { help: true };
        
      case "--simulate-only":
        options.simulateOnly = true;
        break;
        
      case "--transfer-ownership":
        options.transferOwnership = true;
        break;
        
      case "--accept-ownership":
        options.acceptOwnership = true;
        break;
        
      case "--amount":
      case "--eth":
      case "-a":
        const ethValue = args[i + 1];
        if (ethValue && !ethValue.startsWith("-")) {
          options.ethAmount = ethValue;
          i++;
        }
        break;
        
      case "--hlg":
      case "--direct-hlg":
        const hlgValue = args[i + 1];
        if (hlgValue && !hlgValue.startsWith("-")) {
          options.hlgAmount = hlgValue;
          i++;
        }
        break;
        
      default:
        // Positional argument - treat as ETH amount
        if (!arg.startsWith("-")) {
          options.ethAmount = arg;
        }
        break;
    }
  }

  return options;
}

/**
 * Main CLI execution function
 */
async function main(): Promise<void> {
  try {
    const options = parseCliArgs();
    const cli = new MultisigCLI();

    // Handle special operations first
    if (options.help) {
      cli.displayHelp();
      return;
    }

    if (options.transferOwnership) {
      await cli.transferStakingRewardsOwnership();
      return;
    }

    if (options.acceptOwnership) {
      await cli.generateAcceptOwnershipTransaction();
      return;
    }

    // Handle main operations
    if (options.hlgAmount) {
      await cli.generateDirectHLGDeposit(options.hlgAmount);
    } else {
      const ethAmount = options.ethAmount || "0.6"; // Default amount
      await cli.generateBatchTransaction(ethAmount, options.simulateOnly);
    }

  } catch (error) {
    console.error("❌ CLI execution failed:");
    console.error(error);
    process.exit(1);
  }
}

// Execute if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(console.error);
}

// Export for testing and programmatic use