/**
 * SafeExecutionService - Direct Safe transaction execution using Safe SDK
 * 
 * This service provides direct transaction submission to Safe wallets,
 * eliminating the need for manual JSON import. Supports both single-signer
 * execution and multi-signature proposal workflows.
 */

import Safe from "@safe-global/protocol-kit";
import SafeApiKit from "@safe-global/api-kit";
import type { SafeTransactionDataPartial } from "@safe-global/safe-core-sdk-types";
import { getEnvironmentConfig } from "../lib/config.js";
import { SafeTransactionBuilderBatch } from "../types/index.js";

export interface ExecutionResult {
  success: boolean;
  transactionHash?: string;
  safeTxHash?: string;
  message: string;
  explorerUrl?: string;
}

export interface ProposeResult {
  success: boolean;
  safeTxHash?: string;
  message: string;
  requiresSignatures?: number;
  currentSignatures?: number;
}

export class SafeExecutionService {
  private config = getEnvironmentConfig();
  private safeApiKit?: SafeApiKit;
  private protocolKit?: Safe;

  constructor() {
    // Initialize API Kit if environment is configured
    if (this.config.safe?.transactionServiceUrl) {
      this.safeApiKit = new SafeApiKit({
        txServiceUrl: this.config.safe.transactionServiceUrl,
        // ethAdapter not needed for API Kit initialization
      });
    }
  }

  /**
   * Initialize Safe Protocol Kit with signer
   */
  private async initializeProtocolKit(): Promise<Safe> {
    if (this.protocolKit) {
      return this.protocolKit;
    }

    if (!this.config.safe?.privateKey) {
      throw new Error("SAFE_PRIVATE_KEY is required for direct Safe execution");
    }

    if (!this.config.multisig?.address) {
      throw new Error("MULTISIG_ADDRESS is required for Safe operations");
    }

    try {
      // For now, we'll implement a simplified version that focuses on JSON mode
      // The Safe SDK integration will need proper ethers adapter setup
      throw new Error("Safe SDK direct execution not yet implemented. Use JSON mode (default).");

      return this.protocolKit;
    } catch (error) {
      throw new Error(`Failed to initialize Safe Protocol Kit: ${(error as Error).message}`);
    }
  }

  /**
   * Convert Safe Transaction Builder batch to Safe transactions
   */
  private convertBatchToSafeTransactions(batch: SafeTransactionBuilderBatch): SafeTransactionDataPartial[] {
    return batch.transactions.map(tx => ({
      to: tx.to,
      value: tx.value,
      data: tx.data || "0x",
      operation: 0, // CALL operation
    }));
  }

  /**
   * Execute transaction directly (for single-signer Safes)
   */
  async executeTransaction(batch: SafeTransactionBuilderBatch): Promise<ExecutionResult> {
    try {
      console.log("🚀 Executing Safe transaction directly...");
      
      const protocolKit = await this.initializeProtocolKit();
      const transactions = this.convertBatchToSafeTransactions(batch);

      // Create Safe transaction
      const safeTransaction = await protocolKit.createTransaction({
        transactions,
      });

      // Check if we can execute directly (threshold = 1)
      const threshold = await protocolKit.getThreshold();
      if (threshold > 1) {
        return {
          success: false,
          message: `Cannot execute directly: Safe requires ${threshold} signatures. Use --propose instead.`,
        };
      }

      // Sign the transaction
      const signedTransaction = await protocolKit.signTransaction(safeTransaction);

      // Execute the transaction
      const executeTxResponse = await protocolKit.executeTransaction(signedTransaction);
      
      const explorerUrl = this.getExplorerUrl(executeTxResponse.hash);
      
      console.log("✅ Transaction executed successfully!");
      console.log(`📝 Transaction Hash: ${executeTxResponse.hash}`);
      if (explorerUrl) {
        console.log(`🔗 Explorer: ${explorerUrl}`);
      }

      return {
        success: true,
        transactionHash: executeTxResponse.hash,
        message: "Transaction executed successfully",
        explorerUrl,
      };

    } catch (error) {
      console.error("❌ Transaction execution failed:", (error as Error).message);
      
      return {
        success: false,
        message: `Execution failed: ${(error as Error).message}`,
      };
    }
  }

  /**
   * Propose transaction for multi-signature approval
   */
  async proposeTransaction(batch: SafeTransactionBuilderBatch): Promise<ProposeResult> {
    try {
      console.log("📝 Proposing Safe transaction for multi-sig approval...");
      
      if (!this.safeApiKit) {
        return {
          success: false,
          message: "Safe Transaction Service not configured. Set SAFE_TRANSACTION_SERVICE_URL.",
        };
      }

      const protocolKit = await this.initializeProtocolKit();
      const transactions = this.convertBatchToSafeTransactions(batch);

      // Create Safe transaction
      const safeTransaction = await protocolKit.createTransaction({
        transactions,
      });

      // Get transaction hash
      const safeTxHash = await protocolKit.getTransactionHash(safeTransaction);
      
      // Sign the transaction  
      const signature = await protocolKit.signTransaction(safeTransaction);

      // Propose to Safe Transaction Service
      await this.safeApiKit.proposeTransaction({
        safeAddress: this.config.multisig.address!,
        safeTransactionData: safeTransaction.data,
        safeTxHash,
        senderAddress: this.config.safe?.signerAddress || "",
        senderSignature: signature.data,
      });

      const threshold = await protocolKit.getThreshold();
      
      console.log("✅ Transaction proposed successfully!");
      console.log(`📝 Safe Transaction Hash: ${safeTxHash}`);
      console.log(`📊 Signatures required: 1/${threshold}`);
      console.log("🔗 Check Safe web app for approval");

      return {
        success: true,
        safeTxHash,
        message: "Transaction proposed successfully",
        requiresSignatures: threshold,
        currentSignatures: 1,
      };

    } catch (error) {
      console.error("❌ Transaction proposal failed:", (error as Error).message);
      
      return {
        success: false,
        message: `Proposal failed: ${(error as Error).message}`,
      };
    }
  }

  /**
   * Get transaction status from Safe Transaction Service
   */
  async getTransactionStatus(safeTxHash: string): Promise<{
    isExecuted: boolean;
    signatures: number;
    threshold: number;
  } | null> {
    if (!this.safeApiKit) {
      return null;
    }

    try {
      const txDetails = await this.safeApiKit.getTransaction(safeTxHash);
      return {
        isExecuted: txDetails.isExecuted,
        signatures: txDetails.confirmations?.length || 0,
        threshold: txDetails.confirmationsRequired || 1,
      };
    } catch (error) {
      console.warn("Could not fetch transaction status:", (error as Error).message);
      return null;
    }
  }

  /**
   * Get blockchain explorer URL for transaction
   */
  private getExplorerUrl(txHash: string): string | undefined {
    const baseUrls: Record<number, string> = {
      1: "https://etherscan.io/tx/",
      11155111: "https://sepolia.etherscan.io/tx/",
      8453: "https://basescan.org/tx/",
      84532: "https://sepolia.basescan.org/tx/",
    };

    const baseUrl = baseUrls[this.config.chainId];
    return baseUrl ? `${baseUrl}${txHash}` : undefined;
  }

  /**
   * Check if Safe execution is properly configured
   */
  isConfigured(): boolean {
    return !!(
      this.config.safe?.privateKey &&
      this.config.multisig?.address
    );
  }

  /**
   * Get execution mode recommendation based on Safe configuration
   */
  async getRecommendedMode(): Promise<"execute" | "propose" | "json"> {
    if (!this.isConfigured()) {
      return "json";
    }

    try {
      const protocolKit = await this.initializeProtocolKit();
      const threshold = await protocolKit.getThreshold();
      
      return threshold === 1 ? "execute" : "propose";
    } catch (error) {
      console.warn("Could not determine Safe threshold, defaulting to JSON mode");
      return "json";
    }
  }
}