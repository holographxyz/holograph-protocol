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
import { formatCompactEther, formatAmount, formatPercent } from "./lib/format.js";
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

      console.log(`Expected HLG: ${formatCompactEther(expectedHlgOut)}`);
      console.log(`Min HLG (${formatPercent(Number(slippageBps) / 100)} slippage): ${formatCompactEther(minHlgOut)}`);

      // Auto-scale if needed to meet RewardTooSmall threshold
      if (minHlgNeeded > 0n && minHlgOut < minHlgNeeded) {
        console.log("\n⚡ Auto-scaling ETH amount to meet RewardTooSmall threshold...");
        amount = await this.autoScaleForThreshold(amount, minHlgNeeded, slippageBps);
        
        // Recalculate with scaled amount
        const newQuote = await this.uniswapService.getOptimalQuote(amount);
        expectedHlgOut = newQuote.amountOut;
        poolFee = newQuote.fee;
        minHlgOut = (expectedHlgOut * (10_000n - slippageBps)) / 10_000n;
        
        console.log(`✅ Scaled to ${formatAmount(amount, "ETH")}`);
        console.log(`New expected HLG: ${formatCompactEther(expectedHlgOut)} HLG`);
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
      const simulationSuccess = await this.simulateBatchTransaction(batch, multisigAddress, amount, expectedHlgOut);

      // Output the final JSON only if not simulate-only mode
      if (!simulateOnly) {
        this.safeBuilder.displayInstructions(batch);
      } else if (simulationSuccess) {
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
        console.log(`⚠️  Warning: Deposit amount ${formatCompactEther(amount)} HLG is below minimum required ${formatCompactEther(minHlgNeeded)} HLG`);
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
  displayHelp(subcommand?: string): void {
    if (subcommand) {
      this.displaySubcommandHelp(subcommand);
      return;
    }

    console.log(`
🔧 Holograph Multisig CLI

This tool generates Safe Transaction Builder compatible JSON for Holograph protocol operations.

📚 **Key Concepts:**

${this.uniswapService.explainFeeTierStrategy()}

${this.stakingService.explainStakingMechanics()}

🎯 **Commands:**

  batch                    Convert ETH to HLG and stake in StakingRewards
  deposit                  Direct HLG deposit to StakingRewards
  transfer-ownership       Start StakingRewards ownership transfer
  accept-ownership         Complete StakingRewards ownership transfer
  help                     Show this help message

🚀 **Usage Examples:**

  npm run multisig-cli -- batch --eth 0.5                  # Convert 0.5 ETH to HLG and stake
  npm run multisig-cli -- deposit --hlg 1000               # Direct deposit 1000 HLG 
  npm run multisig-cli -- batch --amount 0.1 --simulate-only  # Simulate batch without JSON output
  npm run multisig-cli -- transfer-ownership               # Start ownership transfer
  npm run multisig-cli -- accept-ownership --simulate-only # Simulate ownership acceptance

📋 **Convenient Script Aliases:**

  npm run multisig-batch -- --eth 0.5                      # Same as: npm run multisig-cli -- batch --eth 0.5
  npm run multisig-deposit -- --hlg 1000                   # Same as: npm run multisig-cli -- deposit --hlg 1000
  npm run multisig-transfer-ownership                      # Same as: npm run multisig-cli -- transfer-ownership
  npm run multisig-accept-ownership                        # Same as: npm run multisig-cli -- accept-ownership

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

📖 **Get detailed help for any command:**
  npm run multisig-cli                         # Show this help (no args)
  npm run multisig-help                        # Show this help (alias)
  npm run multisig-cli:help                    # Show this help (npm style)
  npm run multisig-cli -- batch --help         # Batch command help
  npm run multisig-batch:help                  # Batch command help (alias)

📖 **Documentation:** See docs/multisig-cli.md for detailed usage guide
    `);
  }

  /**
   * Display help for a specific subcommand
   */
  private displaySubcommandHelp(subcommand: string): void {
    switch (subcommand) {
      case "batch":
        console.log(`
🎯 **batch** - Convert ETH to HLG and stake in StakingRewards

This is the main operation for fee distribution:
1. Wraps ETH to WETH
2. Swaps WETH to HLG via Uniswap V3 (finds best price across fee tiers)
3. Approves and deposits HLG to StakingRewards
4. Automatically handles RewardTooSmall threshold scaling

**Usage:**
  npm run multisig-cli -- batch --eth <amount> [--simulate-only]
  npm run multisig-cli -- batch --amount <amount> [--simulate-only]

**Examples:**
  npm run multisig-cli -- batch --eth 0.5
  npm run multisig-cli -- batch --amount 1.0 --simulate-only
  npm run multisig-batch -- --eth 0.25

**Flags:**
  --eth, --amount <value>    ETH amount to convert (required)
  --simulate-only           Simulate transaction without generating JSON
  --help                    Show this help message

📖 **Get help:**
  npm run multisig-cli -- batch --help                    # This help message
  npm run multisig-cli -- help                            # Global help
        `);
        break;

      case "deposit":
        console.log(`
🎯 **deposit** - Direct HLG deposit to StakingRewards

For cases where the Safe already holds HLG tokens and wants to
deposit them directly without swapping.

**Usage:**
  npm run multisig-cli -- deposit --hlg <amount> [--simulate-only]

**Examples:**
  npm run multisig-cli -- deposit --hlg 1000
  npm run multisig-cli -- deposit --hlg 500 --simulate-only
  npm run multisig-deposit -- --hlg 2000

**Flags:**
  --hlg <value>             HLG amount to deposit (required)
  --simulate-only           Simulate transaction without generating JSON
  --help                    Show this help message

📖 **Get help:**
  npm run multisig-cli -- deposit --help                  # This help message
  npm run multisig-cli -- help                            # Global help

**Note:** Safe must already hold the specified HLG amount.
        `);
        break;

      case "transfer-ownership":
        console.log(`
🎯 **transfer-ownership** - Start StakingRewards ownership transfer

Provides instructions for the current owner to initiate ownership
transfer to the Safe multisig.

**Usage:**
  npm run multisig-cli -- transfer-ownership [--simulate-only]

**Examples:**
  npm run multisig-cli -- transfer-ownership
  npm run multisig-transfer-ownership

**Flags:**
  --simulate-only           Information mode only
  --help                    Show this help message

📖 **Get help:**
  npm run multisig-cli -- transfer-ownership --help       # This help message
  npm run multisig-cli -- help                            # Global help

**Note:** This provides instructions rather than generating a transaction.
The current owner must execute the transfer before the Safe can accept.
        `);
        break;

      case "accept-ownership":
        console.log(`
🎯 **accept-ownership** - Complete StakingRewards ownership transfer

Generates Safe transaction to accept ownership after transfer has been
initiated by the current owner.

**Usage:**
  npm run multisig-cli -- accept-ownership [--simulate-only]

**Examples:**
  npm run multisig-cli -- accept-ownership
  npm run multisig-accept-ownership -- --simulate-only

**Flags:**
  --simulate-only           Simulate transaction without generating JSON
  --help                    Show this help message

📖 **Get help:**
  npm run multisig-cli -- accept-ownership --help         # This help message
  npm run multisig-cli -- help                            # Global help

**Note:** Can only be called after transfer-ownership has been executed.
        `);
        break;

      default:
        console.log(`❌ Unknown subcommand: ${subcommand}`);
        console.log("Run 'npm run multisig-cli help' for available commands.");
    }
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
   * @returns true if simulation succeeded, false otherwise
   */
  private async simulateBatchTransaction(
    batch: any,
    multisigAddress: string,
    amount: bigint,
    expectedHlgOut: bigint
  ): Promise<boolean> {
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
        return true;
      } else {
        console.log("❌ Simulation FAILED");
        console.log("Error:", result.transaction.error_message || "Unknown error");
        console.log("\n⚠️  Transaction failed simulation but JSON is generated below for investigation:");
        return false;
      }

    } catch (error) {
      console.log("❌ Simulation request failed:", (error as Error).message);
      console.log("\n⚠️  Proceeding without simulation...");
      return false;
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
 * Parse command line arguments into typed options with subcommand structure
 */
function parseCliArgs(): CliOptions {
  const args = process.argv.slice(2);
  const options: CliOptions = {};

  if (args.length === 0) {
    return { help: true };
  }

  const subcommand = args[0];
  const subArgs = args.slice(1);

  // Handle global help or subcommand
  if (subcommand === "help" || subcommand === "--help" || subcommand === "-h") {
    return { help: true };
  }

  // Parse subcommand
  switch (subcommand) {
    case "batch":
      options.command = "batch";
      break;
    case "deposit":
      options.command = "deposit";
      break;
    case "transfer-ownership":
      options.command = "transfer-ownership";
      options.transferOwnership = true;
      break;
    case "accept-ownership":
      options.command = "accept-ownership";
      options.acceptOwnership = true;
      break;
    default:
      console.error(`❌ Unknown subcommand: ${subcommand}`);
      console.error("Run 'npm run multisig-cli help' for usage information.");
      process.exit(1);
  }

  // Parse subcommand flags
  for (let i = 0; i < subArgs.length; i++) {
    const arg = subArgs[i];

    switch (arg) {
      case "--help":
      case "-h":
        return { help: true, command: options.command };
        
      case "--simulate-only":
        options.simulateOnly = true;
        break;
        
      case "--eth":
      case "--amount":
        const ethValue = subArgs[i + 1];
        if (ethValue && !ethValue.startsWith("-")) {
          options.ethAmount = ethValue;
          i++;
        } else {
          console.error(`❌ ${arg} requires a value`);
          process.exit(1);
        }
        break;
        
      case "--hlg":
        const hlgValue = subArgs[i + 1];
        if (hlgValue && !hlgValue.startsWith("-")) {
          options.hlgAmount = hlgValue;
          i++;
        } else {
          console.error(`❌ ${arg} requires a value`);
          process.exit(1);
        }
        break;
        
      default:
        console.error(`❌ Unknown flag: ${arg}`);
        console.error(`Run 'npm run multisig-cli ${options.command} --help' for usage information.`);
        process.exit(1);
    }
  }

  // Validate required arguments for each subcommand
  if (options.command === "batch" && !options.ethAmount) {
    console.error("❌ batch command requires --eth or --amount flag");
    console.error("Example: npm run multisig-cli batch --eth 0.5");
    process.exit(1);
  }

  if (options.command === "deposit" && !options.hlgAmount) {
    console.error("❌ deposit command requires --hlg flag");
    console.error("Example: npm run multisig-cli deposit --hlg 1000");
    process.exit(1);
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

    // Handle help first
    if (options.help) {
      cli.displayHelp(options.command);
      return;
    }

    // Execute based on subcommand
    switch (options.command) {
      case "batch":
        await cli.generateBatchTransaction(options.ethAmount!, options.simulateOnly);
        break;

      case "deposit":
        await cli.generateDirectHLGDeposit(options.hlgAmount!);
        break;

      case "transfer-ownership":
        await cli.transferStakingRewardsOwnership();
        break;

      case "accept-ownership":
        await cli.generateAcceptOwnershipTransaction();
        break;

      default:
        console.error("❌ No subcommand specified");
        console.error("Run 'npm run multisig-cli help' for available commands.");
        process.exit(1);
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