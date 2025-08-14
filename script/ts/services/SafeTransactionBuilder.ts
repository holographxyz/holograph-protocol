/**
 * SafeTransactionBuilder - Creates Safe Transaction Builder compatible JSON
 * 
 * This service creates properly formatted batch transactions for the Gnosis Safe
 * Transaction Builder interface, ensuring compatibility with the Safe web app.
 * 
 * Transaction Builder format differs from Safe SDK format:
 * - Includes contractMethod metadata for UI display
 * - Requires specific JSON structure with version and meta fields
 * - Uses checksum for integrity verification
 */

import { encodeFunctionData, parseAbi, parseEther } from "viem";
import { 
  SafeTransactionBuilderTransaction,
  SafeTransactionBuilderBatch,
  BatchTransactionParams,
  DirectHLGDepositParams,
  EnvironmentConfig 
} from "../types/index.js";
import { getEnvironmentConfig, CONSTANTS } from "../lib/config.js";

export class SafeTransactionBuilder {
  private config: EnvironmentConfig;

  constructor() {
    this.config = getEnvironmentConfig();
  }

  /**
   * Create a complete ETH → WETH → HLG → StakingRewards batch transaction
   * 
   * This is our main operation flow:
   * 1. Wrap ETH to WETH (deposit function, sends ETH value)
   * 2. Approve WETH for SwapRouter (standard ERC20 approval)
   * 3. Swap WETH → HLG via Uniswap V3 (exactInputSingle, no deadline in V2)
   * 4. Approve HLG for StakingRewards (with buffer for slippage)
   * 5. Deposit HLG to StakingRewards (applies burn/reward split)
   * 
   * @param params - Batch transaction parameters
   * @param expectedHlgOut - Expected HLG from swap
   * @param minHlgOut - Minimum HLG with slippage protection
   * @param poolFee - Optimal fee tier from UniswapService
   * @returns SafeTransactionBuilderBatch - Complete batch for Safe Transaction Builder
   */
  createBatchTransaction(
    params: BatchTransactionParams,
    expectedHlgOut: bigint,
    minHlgOut: bigint,
    poolFee: number
  ): SafeTransactionBuilderBatch {
    const { ethAmount, multisigAddress } = params;
    const amount = parseEther(ethAmount);
    const { networkAddresses } = this.config;

    const transactions: SafeTransactionBuilderTransaction[] = [
      // 1. Wrap ETH to WETH
      {
        to: networkAddresses.WETH,
        value: amount.toString(),
        data: null, // deposit() has no parameters
        contractMethod: {
          inputs: [],
          name: "deposit",
          payable: true,
        },
        contractInputsValues: null,
      },

      // 2. Approve WETH for SwapRouter
      {
        to: networkAddresses.WETH,
        value: "0",
        data: encodeFunctionData({
          abi: parseAbi(["function approve(address,uint256)"]),
          functionName: "approve",
          args: [networkAddresses.SWAP_ROUTER as `0x${string}`, amount],
        }),
        contractMethod: {
          inputs: [
            { name: "spender", type: "address" },
            { name: "amount", type: "uint256" },
          ],
          name: "approve",
          payable: false,
        },
        contractInputsValues: {
          spender: networkAddresses.SWAP_ROUTER,
          amount: amount.toString(),
        },
      },

      // 3. Swap WETH to HLG (SwapRouter02 interface - no deadline parameter)
      {
        to: networkAddresses.SWAP_ROUTER,
        value: "0",
        data: encodeFunctionData({
          abi: parseAbi([
            "function exactInputSingle((address tokenIn, address tokenOut, uint24 fee, address recipient, uint256 amountIn, uint256 amountOutMinimum, uint160 sqrtPriceLimitX96)) returns (uint256 amountOut)",
          ]),
          functionName: "exactInputSingle",
          args: [
            {
              tokenIn: networkAddresses.WETH as `0x${string}`,
              tokenOut: networkAddresses.HLG as `0x${string}`,
              fee: poolFee,
              recipient: multisigAddress as `0x${string}`,
              amountIn: amount,
              amountOutMinimum: minHlgOut,
              sqrtPriceLimitX96: 0n, // No price limit
            },
          ],
        }),
        contractMethod: {
          inputs: [
            {
              name: "params",
              type: "tuple",
              components: [
                { name: "tokenIn", type: "address" },
                { name: "tokenOut", type: "address" },
                { name: "fee", type: "uint24" },
                { name: "recipient", type: "address" },
                { name: "amountIn", type: "uint256" },
                { name: "amountOutMinimum", type: "uint256" },
                { name: "sqrtPriceLimitX96", type: "uint160" },
              ],
            },
          ],
          name: "exactInputSingle",
          payable: false,
        },
        contractInputsValues: {
          params: {
            tokenIn: networkAddresses.WETH,
            tokenOut: networkAddresses.HLG,
            fee: poolFee,
            recipient: multisigAddress,
            amountIn: amount.toString(),
            amountOutMinimum: minHlgOut.toString(),
            sqrtPriceLimitX96: "0",
          },
        },
      },

      // 4. Approve HLG for StakingRewards (with generous buffer)
      {
        to: networkAddresses.HLG,
        value: "0",
        data: encodeFunctionData({
          abi: parseAbi(["function approve(address,uint256)"]),
          functionName: "approve",
          args: [networkAddresses.STAKING_REWARDS as `0x${string}`, expectedHlgOut * 2n],
        }),
        contractMethod: {
          inputs: [
            { name: "spender", type: "address" },
            { name: "amount", type: "uint256" },
          ],
          name: "approve",
          payable: false,
        },
        contractInputsValues: {
          spender: networkAddresses.STAKING_REWARDS,
          amount: (expectedHlgOut * 2n).toString(),
        },
      },

      // 5. Deposit to StakingRewards
      {
        to: networkAddresses.STAKING_REWARDS,
        value: "0",
        data: encodeFunctionData({
          abi: parseAbi(["function depositAndDistribute(uint256)"]),
          functionName: "depositAndDistribute",
          args: [minHlgOut], // Use conservative amount to guarantee threshold
        }),
        contractMethod: {
          inputs: [{ name: "amount", type: "uint256" }],
          name: "depositAndDistribute",
          payable: false,
        },
        contractInputsValues: {
          amount: minHlgOut.toString(),
        },
      },
    ];

    return this.createSafeBatch(
      transactions,
      "HLG Fee Distribution Batch",
      `Convert ${ethAmount} ETH to HLG and stake in StakingRewards contract`,
      multisigAddress
    );
  }

  /**
   * Create a direct HLG deposit transaction (no swapping)
   * 
   * For cases where the Safe already holds HLG and wants to deposit directly.
   * This bypasses the ETH → WETH → HLG conversion steps.
   * 
   * @param params - Direct deposit parameters
   * @returns SafeTransactionBuilderBatch - Direct deposit batch
   */
  createDirectHLGDeposit(params: DirectHLGDepositParams): SafeTransactionBuilderBatch {
    const { hlgAmount, multisigAddress } = params;
    const amount = parseEther(hlgAmount);
    const { networkAddresses } = this.config;

    const transactions: SafeTransactionBuilderTransaction[] = [
      // 1. Approve StakingRewards to pull HLG from the Safe
      {
        to: networkAddresses.HLG,
        value: "0",
        data: encodeFunctionData({
          abi: parseAbi(["function approve(address,uint256)"]),
          functionName: "approve",
          args: [networkAddresses.STAKING_REWARDS as `0x${string}`, amount],
        }),
        contractMethod: {
          inputs: [
            { name: "spender", type: "address" },
            { name: "amount", type: "uint256" },
          ],
          name: "approve",
          payable: false,
        },
        contractInputsValues: {
          spender: networkAddresses.STAKING_REWARDS,
          amount: amount.toString(),
        },
      },

      // 2. Deposit and distribute
      {
        to: networkAddresses.STAKING_REWARDS,
        value: "0",
        data: encodeFunctionData({
          abi: parseAbi(["function depositAndDistribute(uint256)"]),
          functionName: "depositAndDistribute",
          args: [amount],
        }),
        contractMethod: {
          inputs: [{ name: "amount", type: "uint256" }],
          name: "depositAndDistribute",
          payable: false,
        },
        contractInputsValues: {
          amount: amount.toString(),
        },
      },
    ];

    return this.createSafeBatch(
      transactions,
      "Direct HLG Deposit",
      `Deposit ${hlgAmount} HLG into StakingRewards (burn/reward split applied)`,
      multisigAddress
    );
  }

  /**
   * Create ownership acceptance transaction
   * 
   * For completing the two-step ownership transfer process.
   * 
   * @param multisigAddress - Safe address that will accept ownership
   * @returns SafeTransactionBuilderBatch - Ownership acceptance transaction
   */
  createAcceptOwnershipTransaction(multisigAddress: string): SafeTransactionBuilderBatch {
    const { networkAddresses } = this.config;

    const acceptOwnershipData = encodeFunctionData({
      abi: parseAbi(["function acceptOwnership()"]),
      functionName: "acceptOwnership",
    });

    const transaction: SafeTransactionBuilderTransaction = {
      to: networkAddresses.STAKING_REWARDS,
      value: "0",
      data: acceptOwnershipData,
      contractMethod: {
        inputs: [],
        name: "acceptOwnership",
        payable: false,
      },
      contractInputsValues: {},
    };

    return this.createSafeBatch(
      [transaction],
      "Accept StakingRewards Ownership",
      "Accept ownership of StakingRewards contract",
      multisigAddress
    );
  }

  /**
   * Create the Safe Transaction Builder batch structure
   * 
   * @param transactions - Array of individual transactions
   * @param name - Batch name for UI display
   * @param description - Batch description
   * @param safeAddress - Safe address creating the batch
   * @returns SafeTransactionBuilderBatch - Complete batch structure
   */
  private createSafeBatch(
    transactions: SafeTransactionBuilderTransaction[],
    name: string,
    description: string,
    safeAddress: string
  ): SafeTransactionBuilderBatch {
    // Generate simplified checksum (in practice, use proper hash)
    const checksum = `0x${Buffer.from(JSON.stringify(transactions)).toString("hex").slice(0, 64)}`;

    return {
      version: "1.0",
      chainId: CONSTANTS.CHAIN_ID,
      createdAt: Date.now(),
      meta: {
        name,
        description,
        txBuilderVersion: "1.17.1",
        createdFromSafeAddress: safeAddress,
        createdFromOwnerAddress: "", // Left empty for compatibility
        checksum,
      },
      transactions,
    };
  }

  /**
   * Create multisend calldata for Tenderly simulation
   * 
   * This creates the raw multisend calldata that the Safe will execute
   * via DELEGATECALL to MultiSendCallOnly.
   * 
   * @param transactions - Safe Transaction Builder transactions
   * @returns object - Multisend address and encoded calldata
   */
  createMultisendCalldata(transactions: SafeTransactionBuilderTransaction[]): {
    multisendAddress: string;
    calldata: `0x${string}`;
  } {
    const multisendAddress = CONSTANTS.MULTISEND_CALL_ONLY;
    let multisendData = ""; // Build raw hex without 0x prefix

    for (const tx of transactions) {
      const operation = "00"; // 0 = CALL
      const to = tx.to.slice(2).padStart(40, "0");
      const value = BigInt(tx.value).toString(16).padStart(64, "0");
      const dataLength = tx.data ? (tx.data.slice(2).length / 2).toString(16).padStart(64, "0") : "0".padStart(64, "0");
      const data = tx.data ? tx.data.slice(2) : "";

      multisendData += operation + to + value + dataLength + data;
    }

    // Encode the multisend call
    const calldata = encodeFunctionData({
      abi: parseAbi(["function multiSend(bytes transactions)"]),
      functionName: "multiSend",
      args: [`0x${multisendData}` as `0x${string}`],
    });

    return { multisendAddress, calldata };
  }

  /**
   * Display formatted instructions for using the generated JSON
   * 
   * @param batch - The generated Safe batch
   */
  displayInstructions(batch: SafeTransactionBuilderBatch): void {
    console.log("\n=== Safe Transaction Builder JSON ===\n");
    console.log(JSON.stringify(batch, null, 2));

    console.log("\n=== Instructions ===");
    console.log("1. Copy the JSON above");
    console.log("2. Go to your Safe web app");
    console.log("3. Navigate to Transaction Builder");
    console.log('4. Click "Import JSON" or drag & drop the JSON file');
    console.log("5. Review and execute the batch transaction");
    console.log("\n💡 The transaction will automatically be formatted correctly in the Safe UI");
  }

  /**
   * Get network addresses for current configuration
   */
  getNetworkAddresses() {
    return this.config.networkAddresses;
  }
}