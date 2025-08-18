/**
 * TenderlyService - Handles all Tenderly simulation operations
 * 
 * This service provides a clean interface for simulating Safe transactions
 * using the Tenderly API, with proper error handling and fallback options.
 */

import { createPublicClient, http, parseAbi, encodeFunctionData, parseEther, getAddress } from "viem";
import { sepolia } from "viem/chains";
import { 
  TenderlyResponse, 
  TenderlyBundleResponse,
  TenderlyConfig,
  TenderlySimulationError
} from "../types/index.js";
import { getTenderlyConfigOrFallback, createManualTenderlyUrl, CONSTANTS } from "../lib/config.js";

export class TenderlyService {
  private config: TenderlyConfig | null;
  private fallbackAddress: string;

  constructor() {
    const { config, fallbackAddress } = getTenderlyConfigOrFallback();
    this.config = config;
    this.fallbackAddress = fallbackAddress;
  }

  /**
   * Simulate a single transaction with Tenderly
   * 
   * @param safeAddress - The Safe contract address
   * @param to - Transaction target address
   * @param data - Transaction calldata
   * @param value - ETH value to send (default: "0")
   * @param fromOverride - Override the 'from' address for simulation
   * @param fundBalances - Additional token balances to set in simulation
   */
  async simulateTransaction(
    safeAddress: string,
    to: string,
    data: string,
    value: string = "0",
    fromOverride?: string,
    fundBalances?: Record<string, bigint>
  ): Promise<TenderlyResponse> {
    if (!this.config) {
      const manualUrl = createManualTenderlyUrl(this.fallbackAddress, to, value, data);
      console.log(`⚠️  Missing Tenderly credentials. Manual simulation link:\n🔗 ${manualUrl}`);
      throw new TenderlySimulationError("Missing Tenderly credentials");
    }

    console.log(`📝 Using Tenderly: ${this.config.account}/${this.config.project}`);

    const simulateUrl = `https://api.tenderly.co/api/v1/account/${this.config.account}/project/${this.config.project}/simulate`;

    const fromAddress = fromOverride ? getAddress(fromOverride) : getAddress(this.fallbackAddress);
    const fromAddressLower = fromAddress.toLowerCase() as `0x${string}`;
    const fundBalanceHex = parseEther("10").toString(16);

    // Optionally disable Safe signature checks for easier simulation
    const safeStorageOverride = await this.createSafeStorageOverride(safeAddress);

    const simulation = {
      network_id: CONSTANTS.CHAIN_ID,
      save: true,
      save_if_fails: true,
      from: fromAddressLower,
      to: getAddress(to),
      input: data,
      gas: CONSTANTS.DEFAULT_GAS_LIMIT,
      gas_price: CONSTANTS.DEFAULT_GAS_PRICE,
      value: value,
      state_objects: {
        [fromAddressLower]: {
          balance: `0x${fundBalanceHex}`,
        },
        ...(safeStorageOverride ? {
          [getAddress(safeAddress).toLowerCase()]: {
            storage: safeStorageOverride,
            balance: `0x${parseEther("0").toString(16)}`, // Zero balance - rely on storage overrides
          }
        } : {}),
        ...(fundBalances ? Object.fromEntries(
          Object.entries(fundBalances).map(([addr, bal]) => [
            getAddress(addr as `0x${string}`).toLowerCase(),
            { balance: `0x${bal.toString(16)}` }
          ])
        ) : {})
      }
    } as const;

    // Debug logging (can be enabled with environment variable)
    const debugMode = process.env.TENDERLY_DEBUG === "true";
    if (debugMode) {
      console.log("🔍 Debugging Tenderly request:");
      console.log("URL:", simulateUrl);
      console.log("From:", fromAddressLower);
      console.log("To:", getAddress(to));
      console.log("Data length:", data.length);
    }

    try {
      const response = await fetch(simulateUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          Authorization: `Bearer ${this.config.accessKey}`,
          "X-Access-Key": this.config.accessKey,
        },
        body: JSON.stringify(simulation),
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.log(`❌ Tenderly API Error ${response.status}: ${errorText}`);
        
        try {
          const errorJson = JSON.parse(errorText);
          console.log("Error details:", JSON.stringify(errorJson, null, 2));
        } catch {
          console.log("Raw error text:", errorText);
        }
        
        throw new TenderlySimulationError(`Tenderly API error: ${response.status} ${response.statusText}`);
      }

      const result = (await response.json()) as TenderlyResponse;
      
      // Log simulation URL for convenience
      const simId = result?.simulation?.id;
      if (simId) {
        const viewUrl = `https://dashboard.tenderly.co/${this.config.account}/${this.config.project}/simulator/${simId}`;
        console.log(`🔎 Tenderly simulation ready: ${viewUrl}`);
      }
      
      return result;
    } catch (error) {
      // Provide manual simulation link as fallback
      const manualUrl = createManualTenderlyUrl(fromAddress, to, value, data);
      console.log(`\n🔗 Manual Tenderly simulation: ${manualUrl}`);
      
      if (error instanceof TenderlySimulationError) {
        throw error;
      }
      throw new TenderlySimulationError("Failed to simulate transaction", error as Error);
    }
  }

  /**
   * Simulate a 3-step Safe bundle: ownerA.approveHash, ownerB.approveHash, then Safe.execTransaction
   */
  async simulateSafeBundle(
    safeAddress: string,
    multisendAddress: string,
    multisendCalldata: `0x${string}`,
    ownerA: string,
    ownerB: string
  ): Promise<string | undefined> {
    if (!this.config) return undefined;

    const client = createPublicClient({ chain: sepolia, transport: http() });
    
    // Read current Safe nonce
    const nonce = (await client.readContract({
      address: safeAddress as `0x${string}`,
      abi: parseAbi(["function nonce() view returns (uint256)"]),
      functionName: "nonce",
    })) as bigint;

    // Compute tx hash using contract helper
    const safeTxHash = (await client.readContract({
      address: safeAddress as `0x${string}`,
      abi: parseAbi([
        "function getTransactionHash(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) view returns (bytes32)",
      ]),
      functionName: "getTransactionHash",
      args: [
        multisendAddress as `0x${string}`,
        0n,
        multisendCalldata,
        1, // DELEGATECALL
        0n, 0n, 0n,
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        nonce,
      ],
    })) as `0x${string}`;

    const approveHashData = encodeFunctionData({
      abi: parseAbi(["function approveHash(bytes32 hashToApprove)"]),
      functionName: "approveHash",
      args: [safeTxHash],
    });

    const execData = this.createSafeExecutionData(multisendAddress, "0", multisendCalldata, 1);

    const simulateUrl = `https://api.tenderly.co/api/v1/account/${this.config.account}/project/${this.config.project}/simulate-bundle`;
    const body = {
      network_id: CONSTANTS.CHAIN_ID,
      save: true,
      save_if_fails: true,
      simulations: [
        {
          from: getAddress(ownerA).toLowerCase(),
          to: getAddress(safeAddress),
          input: approveHashData,
          gas: 2_000_000,
          gas_price: CONSTANTS.DEFAULT_GAS_PRICE,
          value: "0",
        },
        {
          from: getAddress(ownerB).toLowerCase(),
          to: getAddress(safeAddress),
          input: approveHashData,
          gas: 2_000_000,
          gas_price: CONSTANTS.DEFAULT_GAS_PRICE,
          value: "0",
        },
        {
          from: getAddress(ownerA).toLowerCase(),
          to: getAddress(safeAddress),
          input: execData,
          gas: CONSTANTS.DEFAULT_GAS_LIMIT,
          gas_price: CONSTANTS.DEFAULT_GAS_PRICE,
          value: "0",
        },
      ],
      state_objects: {
        [getAddress(ownerA).toLowerCase()]: { balance: `0x${parseEther("1").toString(16)}` },
        [getAddress(ownerB).toLowerCase()]: { balance: `0x${parseEther("1").toString(16)}` },
        [getAddress(safeAddress).toLowerCase()]: { balance: `0x${parseEther("1").toString(16)}` },
      },
    };

    try {
      const response = await fetch(simulateUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          Authorization: `Bearer ${this.config.accessKey}`,
          "X-Access-Key": this.config.accessKey,
        },
        body: JSON.stringify(body),
      });
      
      if (!response.ok) return undefined;
      
      const result = (await response.json()) as TenderlyBundleResponse;
      const last = result.simulations[result.simulations.length - 1];
      if (!last) return undefined;
      
      return `https://dashboard.tenderly.co/${this.config.account}/${this.config.project}/simulator/${last.id}`;
    } catch {
      return undefined;
    }
  }

  /**
   * Create Safe storage override to bypass signature checks in simulation
   */
  private async createSafeStorageOverride(safeAddress: string): Promise<Record<string, string> | undefined> {
    const disableSigChecks = (process.env.SIM_DISABLE_SIG_CHECKS ?? "true").toLowerCase() !== "false";
    if (!disableSigChecks) return undefined;

    try {
      const client = createPublicClient({ chain: sepolia, transport: http() });
      const currentThreshold = (await client.readContract({
        address: safeAddress as `0x${string}`,
        abi: parseAbi(["function getThreshold() view returns (uint256)"]),
        functionName: "getThreshold",
      })) as bigint;

      if (currentThreshold <= 1n) {
        return undefined;
      }

      // Find storage slot that holds the threshold value by scanning early slots
      const desiredHex = `0x${currentThreshold.toString(16)}`;
      
      for (let i = 0; i < 100; i += 1) {
        const slot = `0x${i.toString(16).padStart(64, "0")}` as `0x${string}`;
        const raw = await client.getStorageAt({ address: safeAddress as `0x${string}`, slot });
        
        if (raw && raw !== "0x" && raw.toLowerCase().replace(/^0x0+/, "0x") === desiredHex.toLowerCase()) {
          // Override to 1 for simulation (32-byte padded)
          const onePadded = `0x${(1n).toString(16).padStart(64, "0")}` as `0x${string}`;
          return { [slot]: onePadded };
        }
      }
    } catch (error) {
      console.log("⚠️  Storage override failed:", (error as Error).message);
      // Non-fatal: if we can't determine, we'll proceed without override
    }

    return undefined;
  }

  /**
   * Create Safe execution data for simulation
   */
  createSafeExecutionData(
    to: string,
    value: string,
    data: string,
    operation: number = 1
  ): string {
    // Build concatenated pre-validated signatures (v=1)
    const ownerA = (process.env.SAFE_OWNER_ADDRESS || "0x1ef43b825f6d1c3bfa93b3951e711f5d64550bda").toLowerCase();
    const ownerB = (process.env.SAFE_OWNER_ADDRESS_2 || "0x2ef43b825f6d1c3bfa93b3951e711f5d64550bdb").toLowerCase();

    const packPrevalidated = (owner: string) =>
      `000000000000000000000000${owner.slice(2)}`.padEnd(64, "0") +
      `0000000000000000000000000000000000000000000000000000000000000000` +
      `01`;

    // Sort by owner address ascending as Safe expects sorted signatures
    const ordered = [ownerA, ownerB].sort();
    const signatures = (`0x` + ordered.map(packPrevalidated).join("")) as `0x${string}`;

    return encodeFunctionData({
      abi: parseAbi([
        "function execTransaction(address to, uint256 value, bytes data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, bytes signatures) returns (bool)",
      ]),
      functionName: "execTransaction",
      args: [
        to as `0x${string}`,
        BigInt(value),
        data as `0x${string}`,
        operation,
        0n, 0n, 0n,
        "0x0000000000000000000000000000000000000000" as `0x${string}`,
        "0x0000000000000000000000000000000000000000" as `0x${string}`,
        signatures as `0x${string}`,
      ],
    });
  }
}