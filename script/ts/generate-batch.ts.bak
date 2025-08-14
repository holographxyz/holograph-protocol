import "dotenv/config";
import { createPublicClient, http, parseAbi, encodeFunctionData, parseEther, formatEther, getAddress } from "viem";
import { sepolia } from "viem/chains";

// Tenderly simulation types
interface TenderlySimulation {
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

interface TenderlyResponse {
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

interface TenderlyBundleResponse {
  simulations: Array<{
    id: string;
    status: boolean;
    transaction: { status: boolean; error_message?: string };
  }>;
}

// Types for Safe Transaction Builder
interface SafeTransactionBuilderTransaction {
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

interface SafeTransactionBuilderBatch {
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

// Ethereum Sepolia testnet addresses (verified from Uniswap docs)
const ADDRESSES = {
  FACTORY: "0x0227628f3F023bb0B980b67D528571c95c6DaC1c",
  WETH: "0xfff9976782d46cc05630d1f6ebab18b2324d6b14",
  // Uniswap V3 SwapRouter02 on Sepolia
  SWAP_ROUTER: "0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E",
  QUOTER_V2: "0xEd1f6473345F45b75F8179591dd5bA1888cf2FB3",
  HLG: "0x5Ff07042d14E60EC1de7a860BBE968344431BaA1",
  STAKING_REWARDS: "0x50D5972b1ACc89F8433E70C7c8C044100E211081",
};

// On-chain staking info to compute minimum reward bump that avoids RewardTooSmall
async function getStakingInfo() {
  const client = createPublicClient({ chain: sepolia, transport: http() });
  const [totalStaked, unallocatedRewards, burnPercentage] = (await Promise.all([
    client.readContract({
      address: ADDRESSES.STAKING_REWARDS as `0x${string}`,
      abi: parseAbi(["function totalStaked() view returns (uint256)"]),
      functionName: "totalStaked",
    }),
    client.readContract({
      address: ADDRESSES.STAKING_REWARDS as `0x${string}`,
      abi: parseAbi(["function unallocatedRewards() view returns (uint256)"]),
      functionName: "unallocatedRewards",
    }),
    client.readContract({
      address: ADDRESSES.STAKING_REWARDS as `0x${string}`,
      abi: parseAbi(["function burnPercentage() view returns (uint256)"]),
      functionName: "burnPercentage",
    }),
  ])) as [bigint, bigint, bigint];

  const activeStaked = totalStaked - unallocatedRewards;
  return { activeStaked, burnBps: Number(burnPercentage) };
}

// Compute minimum HLG that must be received by StakingRewards so that
// (rewardAmount * 1e12) / activeStaked >= 1. rewardAmount = receivedHLG * (1 - burnBps/10000)
function computeMinHLGToDepositToAvoidRewardTooSmall(activeStaked: bigint, burnBps: number): bigint {
  if (activeStaked <= 0n) return 0n; // no stakers -> function is no-op
  const INDEX_PRECISION = 1_000_000_000_000n; // 1e12
  const minReward = (activeStaked + INDEX_PRECISION - 1n) / INDEX_PRECISION; // ceil(activeStaked / 1e12)
  const numerator = minReward * 10_000n;
  const denominator = BigInt(10_000 - burnBps);
  return (numerator + denominator - 1n) / denominator; // ceil divide to account for burn
}

async function getQuote(ethAmount: bigint): Promise<{ amountOut: bigint; fee: number }> {
  const client = createPublicClient({ chain: sepolia, transport: http() });
  // Allow forcing a specific fee tier via env
  const forcedFee: number | null = process.env.REQUIRED_FEE_TIER ? parseInt(process.env.REQUIRED_FEE_TIER, 10) : null;
  const preferFee: number | null = process.env.PREFER_FEE_TIER ? parseInt(process.env.PREFER_FEE_TIER, 10) : null;

  const feesBase = [500, 3000, 10000];
  const fees = forcedFee !== null
    ? [forcedFee]
    : preferFee !== null
      ? [preferFee, ...feesBase.filter((f) => f !== preferFee)]
      : feesBase;

  let bestOut = 0n;
  let bestFee = fees[0] ?? 3000;
  for (const fee of fees) {
    try {
      const res = (await client.readContract({
        address: ADDRESSES.QUOTER_V2 as `0x${string}`,
        abi: parseAbi([
          "function quoteExactInputSingle((address tokenIn, address tokenOut, uint256 amountIn, uint24 fee, uint160 sqrtPriceLimitX96)) returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate)",
        ]),
        functionName: "quoteExactInputSingle",
        args: [
          {
            tokenIn: ADDRESSES.WETH as `0x${string}`,
            tokenOut: ADDRESSES.HLG as `0x${string}`,
            amountIn: ethAmount,
            fee,
            sqrtPriceLimitX96: 0n,
          },
        ],
      })) as [bigint, bigint, number, bigint];
      const amountOut = res[0];
      if (amountOut > bestOut) {
        bestOut = amountOut;
        bestFee = fee;
      }
    } catch {}
  }
  return { amountOut: bestOut, fee: bestFee };
}

// Simulate transaction with Tenderly
async function simulateWithTenderly(
  safeAddress: string,
  to: string,
  data: string,
  value: string = "0",
  fromOverride?: string,
  fundBalances?: Record<string, bigint>,
): Promise<TenderlyResponse> {
  // Resolve Tenderly credentials from env
  const tenderlyAccount = process.env.TENDERLY_ACCOUNT || process.env.TENDERLY_USER || process.env.TENDERLY_USERNAME;
  const tenderlyProject = process.env.TENDERLY_PROJECT || process.env.TENDERLY_PROJECT_SLUG;
  const tenderlyAccessKey = process.env.TENDERLY_ACCESS_KEY || process.env.TENDERLY_TOKEN;

  if (!tenderlyAccount || !tenderlyProject || !tenderlyAccessKey) {
    const missing = [
      !tenderlyAccount && "TENDERLY_ACCOUNT",
      !tenderlyProject && "TENDERLY_PROJECT",
      !tenderlyAccessKey && "TENDERLY_ACCESS_KEY",
    ]
      .filter(Boolean)
      .join(", ");
    const fromForLink = getAddress(
      process.env.SAFE_OWNER_ADDRESS ||
        process.env.MULTISIG_OWNER_ADDRESS ||
        process.env.SIMULATION_FROM ||
        safeAddress,
    );
    const cleanUrl = `https://dashboard.tenderly.co/simulator/new?network=11155111&from=${fromForLink}&to=${getAddress(
      to,
    )}&value=${value}&input=${encodeURIComponent(data)}`;
    console.log(`⚠️  Missing Tenderly env vars (${missing}). Falling back to manual simulator link:\n🔗 ${cleanUrl}`);
    throw new Error("Missing Tenderly credentials");
  }

  console.log(`📝 Using Tenderly: ${tenderlyAccount}/${tenderlyProject}`);
  
  // Use the correct Tenderly API endpoint format
  const simulateUrl = `https://api.tenderly.co/api/v1/account/${tenderlyAccount}/project/${tenderlyProject}/simulate`;

  const fromAddress = fromOverride
    ? getAddress(fromOverride)
    : getAddress(
        process.env.SAFE_OWNER_ADDRESS ||
          process.env.MULTISIG_OWNER_ADDRESS ||
          process.env.SIMULATION_FROM ||
          // Fallback to previously hardcoded EOA
          "0x1eF43B825f6D1c3BfA93B3951e711F5d64550BDA",
      );
  const fromAddressLower = fromAddress.toLowerCase() as `0x${string}`;
  const fundBalanceHex = (parseEther("10")).toString(16);

  // Optionally weaken Safe signature checks by overriding threshold to 1 in sim
  const disableSigChecks = (process.env.SIM_DISABLE_SIG_CHECKS ?? "true").toLowerCase() !== "false";
  let safeStorageOverride: Record<string, string> | undefined;
  if (disableSigChecks) {
    try {
      const client = createPublicClient({ chain: sepolia, transport: http() });
      const currentThreshold = (await client.readContract({
        address: safeAddress as `0x${string}`,
        abi: parseAbi(["function getThreshold() view returns (uint256)"]),
        functionName: "getThreshold",
      })) as bigint;

      if (currentThreshold > 1n) {
        // Find storage slot that holds the threshold value by scanning early slots
        const desiredHex = `0x${currentThreshold.toString(16)}`;
        for (let i = 0; i < 100; i += 1) {
          const slot = `0x${i.toString(16).padStart(64, "0")}` as `0x${string}`;
          const raw = await client.getStorageAt({ address: safeAddress as `0x${string}`, slot });
          if (raw && raw !== "0x" && raw.toLowerCase().replace(/^0x0+/, "0x") === desiredHex.toLowerCase()) {
            // Override to 1 for simulation (32-byte padded)
            const onePadded = `0x${(1n).toString(16).padStart(64, "0")}` as `0x${string}`;
            safeStorageOverride = { [slot]: onePadded };
            break;
          }
        }
      }
    } catch (e) {
      // Non-fatal: if we can't determine, we'll proceed without override
    }
  }

  // Build request per Tenderly public simulate API (top-level fields)
  const simulation = {
    network_id: "11155111", // Sepolia chain ID
    save: true,
    save_if_fails: true,
    from: fromAddressLower,
    to: getAddress(to),
    input: data,
    gas: 3_000_000,
    gas_price: "1000000000",
    value: value,
    state_objects: {
      [fromAddressLower]: {
        balance: `0x${fundBalanceHex}`,
      },
      ...(safeStorageOverride
        ? {
            [getAddress(safeAddress).toLowerCase()]: {
              storage: safeStorageOverride,
              // When overriding storage, we must also preserve/set balance
              // Otherwise Tenderly might reset it to 0
              balance: `0x${parseEther("0.6").toString(16)}`, // Match Safe's actual balance
            },
          }
        : {}),
      ...(fundBalances
        ? Object.fromEntries(
            Object.entries(fundBalances).map(([addr, bal]) => [
              getAddress(addr as `0x${string}`).toLowerCase(),
              { balance: `0x${bal.toString(16)}` },
            ]),
          )
        : {}),
    },
  } as const;

  // Debug logging
  console.log("🔍 Debugging Tenderly request:");
  console.log("URL:", simulateUrl);
  console.log("Raw addresses:");
  console.log("  safeAddress:", safeAddress);
  console.log("  to:", to);
  console.log("Checksummed addresses:");
  console.log("  from:", fromAddressLower);
  console.log("  to:", getAddress(to));
  console.log("Payload:", JSON.stringify(simulation, null, 2));
  console.log("Data length:", data.length);
  console.log("Data preview:", data.substring(0, 100) + "...");

  try {
    const response = await fetch(simulateUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        Authorization: `Bearer ${tenderlyAccessKey}`,
        "X-Access-Key": tenderlyAccessKey,
      },
      body: JSON.stringify(simulation),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.log(`❌ Tenderly API Error ${response.status}: ${errorText}`);
      console.log("Response headers:", Object.fromEntries(response.headers.entries()));
      
      // Try to get more detailed error info
      try {
        const errorJson = JSON.parse(errorText);
        console.log("Error details:", JSON.stringify(errorJson, null, 2));
      } catch {
        console.log("Raw error text:", errorText);
      }
      
      throw new Error(`Tenderly API error: ${response.status} ${response.statusText}`);
    }

    const result = (await response.json()) as TenderlyResponse;
    // Attach URL hint for convenience
    const simId = result?.simulation?.id;
    if (simId) {
      const viewUrl = `https://dashboard.tenderly.co/${tenderlyAccount}/${tenderlyProject}/simulator/${simId}`;
      console.log(`🔎 Tenderly simulation ready: ${viewUrl}`);
    }
    return result;
  } catch (error) {
    // Provide manual simulation link as fallback
    const cleanUrl = `https://dashboard.tenderly.co/simulator/new?network=11155111&from=${fromAddress}&to=${getAddress(
      to,
    )}&value=${value}&input=${encodeURIComponent(data)}`;
    console.log(`\n🔗 Manual Tenderly simulation: ${cleanUrl}`);
    throw error;
  }
}

// Simulate a 3-step bundle: ownerA.approveHash, ownerB.approveHash, then Safe.execTransaction
async function simulateSafeBundle(
  safeAddress: string,
  multisendAddress: string,
  multisendCalldata: `0x${string}`,
  ownerA: string,
  ownerB: string,
): Promise<string | undefined> {
  const tenderlyAccount = process.env.TENDERLY_ACCOUNT || process.env.TENDERLY_USER || process.env.TENDERLY_USERNAME;
  const tenderlyProject = process.env.TENDERLY_PROJECT || process.env.TENDERLY_PROJECT_SLUG;
  const tenderlyAccessKey = process.env.TENDERLY_ACCESS_KEY || process.env.TENDERLY_TOKEN;
  if (!tenderlyAccount || !tenderlyProject || !tenderlyAccessKey) return undefined;

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
      0n,
      0n,
      0n,
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

  const execData = createSafeExecutionData(multisendAddress, "0", multisendCalldata, 1);

  const simulateUrl = `https://api.tenderly.co/api/v1/account/${tenderlyAccount}/project/${tenderlyProject}/simulate-bundle`;
  const body = {
    network_id: "11155111",
    save: true,
    save_if_fails: true,
    // Run two approvals then the execution
    simulations: [
      {
        from: getAddress(ownerA).toLowerCase(),
        to: getAddress(safeAddress),
        input: approveHashData,
        gas: 2_000_000,
        gas_price: "1000000000",
        value: "0",
      },
      {
        from: getAddress(ownerB).toLowerCase(),
        to: getAddress(safeAddress),
        input: approveHashData,
        gas: 2_000_000,
        gas_price: "1000000000",
        value: "0",
      },
      {
        from: getAddress(ownerA).toLowerCase(),
        to: getAddress(safeAddress),
        input: execData,
        gas: 3_000_000,
        gas_price: "1000000000",
        value: "0",
      },
    ],
    state_objects: {
      [getAddress(ownerA).toLowerCase()]: { balance: `0x${parseEther("1").toString(16)}` },
      [getAddress(ownerB).toLowerCase()]: { balance: `0x${parseEther("1").toString(16)}` },
      [getAddress(safeAddress).toLowerCase()]: { balance: `0x${parseEther("1").toString(16)}` },
    },
  };

  const response = await fetch(simulateUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      Authorization: `Bearer ${tenderlyAccessKey}`,
      "X-Access-Key": tenderlyAccessKey,
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) return undefined;
  const result = (await response.json()) as TenderlyBundleResponse;
  const last = result.simulations[result.simulations.length - 1];
  if (!last) return undefined;
  return `https://dashboard.tenderly.co/${tenderlyAccount}/${tenderlyProject}/simulator/${last.id}`;
}

// Create Safe execution data for simulation
function createSafeExecutionData(
  to: string,
  value: string,
  data: string,
  operation: number = 1, // 1 = DELEGATECALL for multisend
): string {
  // Build concatenated pre-validated signatures (v=1). At least one owner should match msg.sender.
  const ownerA = (process.env.SAFE_OWNER_ADDRESS ||
    "0x1ef43b825f6d1c3bfa93b3951e711f5d64550bda").toLowerCase();
  const ownerB = (process.env.SAFE_OWNER_ADDRESS_2 ||
    process.env.SAFE_SECOND_OWNER ||
    "0x2ef43b825f6d1c3bfa93b3951e711f5d64550bdb").toLowerCase();

  const packPrevalidated = (owner: string) =>
    // r = owner padded to 32 bytes, s = 0, v = 1
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
      0n, // safeTxGas
      0n, // baseGas
      0n, // gasPrice
      "0x0000000000000000000000000000000000000000" as `0x${string}`, // gasToken
      "0x0000000000000000000000000000000000000000" as `0x${string}`, // refundReceiver
      signatures as `0x${string}`,
    ],
  });
}

// Transfer ownership of StakingRewards contract to the Safe
export async function transferStakingRewardsOwnership() {
  const stakingRewardsAddress = ADDRESSES.STAKING_REWARDS;
  const safeAddress = process.env.MULTISIG_ADDRESS || "0x8FE61F653450051cEcbae12475BA2b8fbA628c7A";
  
  console.log("=== StakingRewards Ownership Transfer ===");
  console.log(`StakingRewards: ${stakingRewardsAddress}`);
  console.log(`Target Safe: ${safeAddress}`);
  
  // Check current owner
  const client = createPublicClient({ chain: sepolia, transport: http() });
  const currentOwner = (await client.readContract({
    address: stakingRewardsAddress as `0x${string}`,
    abi: parseAbi(["function owner() view returns (address)"]),
    functionName: "owner",
  })) as `0x${string}`;
  
  console.log(`Current owner: ${currentOwner}`);
  
  if (currentOwner.toLowerCase() === safeAddress.toLowerCase()) {
    console.log("✅ Safe is already the owner!");
    return;
  }
  
  // Check if there's a pending transfer
  try {
    const pendingOwner = (await client.readContract({
      address: stakingRewardsAddress as `0x${string}`,
      abi: parseAbi(["function pendingOwner() view returns (address)"]),
      functionName: "pendingOwner",
    })) as `0x${string}`;
    
    if (pendingOwner.toLowerCase() === safeAddress.toLowerCase()) {
      console.log("⏳ Ownership transfer already initiated. Safe needs to call acceptOwnership()");
      console.log("\nNext steps:");
      console.log("1. Execute this transaction from the Safe:");
      console.log(`   - To: ${stakingRewardsAddress}`);
      console.log(`   - Data: ${encodeFunctionData({
        abi: parseAbi(["function acceptOwnership()"]),
        functionName: "acceptOwnership",
      })}`);
      return;
    }
  } catch {
    // pendingOwner() might not exist if no transfer is pending
  }
  
  // Generate transferOwnership transaction data
  const transferData = encodeFunctionData({
    abi: parseAbi(["function transferOwnership(address newOwner)"]),
    functionName: "transferOwnership",
    args: [safeAddress as `0x${string}`],
  });
  
  console.log("\n=== Step 1: Current Owner Must Execute ===");
  console.log("The current owner must execute this transaction:");
  console.log(`To: ${stakingRewardsAddress}`);
  console.log(`Data: ${transferData}`);
  console.log(`\nOr using cast:`);
  console.log(`cast send ${stakingRewardsAddress} 'transferOwnership(address)' ${safeAddress} --private-key $DEPLOYER_PK --rpc-url $ETHEREUM_SEPOLIA_RPC_URL`);
  
  console.log("\n=== Step 2: Safe Must Accept ===");
  console.log("After step 1, the Safe must execute this transaction:");
  console.log(`To: ${stakingRewardsAddress}`);
  console.log(`Data: ${encodeFunctionData({
    abi: parseAbi(["function acceptOwnership()"]),
    functionName: "acceptOwnership",
  })}`);
  
  console.log("\n=== Alternative: Complete Both Steps ===");
  console.log("Or run: npm run transfer-staking-ownership && npm run accept-staking-ownership");
}

// Generate Safe transaction to accept StakingRewards ownership
export async function generateAcceptOwnershipTransaction() {
  const stakingRewardsAddress = ADDRESSES.STAKING_REWARDS;
  const safeAddress = process.env.MULTISIG_ADDRESS || "0x8FE61F653450051cEcbae12475BA2b8fbA628c7A";
  
  const acceptOwnershipData = encodeFunctionData({
    abi: parseAbi(["function acceptOwnership()"]),
    functionName: "acceptOwnership",
  });

  const transaction: SafeTransactionBuilderTransaction = {
    to: stakingRewardsAddress,
    value: "0",
    data: acceptOwnershipData,
    contractMethod: {
      inputs: [],
      name: "acceptOwnership", 
      payable: false,
    },
    contractInputsValues: {},
  };

  const checksum = `0x${Buffer.from(JSON.stringify([transaction])).toString("hex").slice(0, 64)}`;

  const safeBatch: SafeTransactionBuilderBatch = {
    version: "1.0",
    chainId: "11155111",
    createdAt: Date.now(),
    meta: {
      name: "Accept StakingRewards Ownership",
      description: "Accept ownership of StakingRewards contract",
      txBuilderVersion: "1.17.1", 
      createdFromSafeAddress: safeAddress,
      createdFromOwnerAddress: "",
      checksum: checksum,
    },
    transactions: [transaction],
  };

  console.log("=== Accept Ownership Transaction ===\n");
  console.log(JSON.stringify(safeBatch));
  
  console.log("\n=== Instructions ===");
  console.log("1. Copy the JSON above");
  console.log("2. Go to your Safe web app");
  console.log("3. Navigate to Transaction Builder");
  console.log('4. Click "Import JSON" or drag & drop the JSON file');
  console.log("5. Review and execute the transaction to accept ownership");

  return safeBatch;
}

export async function generateBatchTransaction(ethAmount: string) {
  let amount = parseEther(ethAmount);

  // Use multisig address from env or default
  const multisigAddress = process.env.MULTISIG_ADDRESS || "0x8FE61F653450051cEcbae12475BA2b8fbA628c7A";

  // 1) Get staking state and compute minimum HLG needed to avoid RewardTooSmall
  const { activeStaked, burnBps } = await getStakingInfo();
  const minHlgNeeded = computeMinHLGToDepositToAvoidRewardTooSmall(activeStaked, burnBps);

  // 2) Get initial quote from Uniswap for the swap
  let { amountOut: expectedHlgOut, fee: poolFee } = await getQuote(amount);
  let slippageBps = BigInt(parseInt(process.env.SLIPPAGE_BPS || "5000", 10)); // default 50%
  let minHlgOut = (expectedHlgOut * (10_000n - slippageBps)) / 10_000n;

  // 3) If after slippage the min out is below the required threshold, scale ETH amount up
  if (minHlgNeeded > 0n && minHlgOut < minHlgNeeded) {
    // Exponential ramp-up until we cross the threshold or hit a sane cap
    let attempts = 0;
    while (attempts < 6 && minHlgOut < minHlgNeeded) {
      // Increase by factor ~ required/min, with safety margin 1.15x, clamp to +2x at most per step
      const ratio = Number(minHlgNeeded) / Math.max(1, Number(minHlgOut));
      const factor = Math.min(2.0, Math.max(1.15, ratio * 1.05));
      amount = BigInt(Math.ceil(Number(amount) * factor));
      const q = await getQuote(amount);
      expectedHlgOut = q.amountOut;
      poolFee = q.fee;
      minHlgOut = (expectedHlgOut * (10_000n - slippageBps)) / 10_000n;
      attempts += 1;
    }

    // Optional small binary search refinement (2 iterations)
    if (minHlgOut >= minHlgNeeded) {
      let low = 0n;
      let high = amount;
      for (let i = 0; i < 2; i += 1) {
        const mid = (low + high) / 2n;
        const q = await getQuote(mid);
        const midMinOut = (q.amountOut * (10_000n - slippageBps)) / 10_000n;
        if (midMinOut >= minHlgNeeded) {
          high = mid; // try smaller amount
          expectedHlgOut = q.amountOut;
          poolFee = q.fee;
          minHlgOut = midMinOut;
        } else {
          low = mid + 1n;
        }
      }
      amount = high;
    }
  }

  console.log(`Processing ${ethAmount} ETH`);
  console.log(`Multisig Address: ${multisigAddress}`);
  console.log(`Expected HLG: ${formatEther(expectedHlgOut)}`);
  console.log(`Min HLG (${Number(slippageBps) / 100}% slippage): ${formatEther(minHlgOut)}`);
  if (minHlgNeeded > 0n) {
    console.log(`Min HLG required to avoid RewardTooSmall: ${formatEther(minHlgNeeded)}`);
    if (minHlgOut < minHlgNeeded) {
      console.log(
        `⚠️  Warning: even after scaling, min out ${formatEther(minHlgOut)} is below required ${formatEther(minHlgNeeded)}; consider providing more ETH or using --hlg direct deposit.`,
      );
    }
  } else {
    console.log("Note: No active stakers detected; deposit will be a no-op until staking starts.");
  }

  const deadline = Math.floor(Date.now() / 1000) + 1800;

  // Safe Transaction Builder format
  const transactions: SafeTransactionBuilderTransaction[] = [
    // 1. Wrap ETH to WETH
    {
      to: ADDRESSES.WETH,
      value: amount.toString(),
      data: null,
      contractMethod: {
        inputs: [],
        name: "deposit",
        payable: true,
      },
      contractInputsValues: null,
    },

    // 2. Approve WETH for SwapRouter
    {
      to: ADDRESSES.WETH,
      value: "0",
      data: encodeFunctionData({
        abi: parseAbi(["function approve(address,uint256)"]),
        functionName: "approve",
        args: [ADDRESSES.SWAP_ROUTER as `0x${string}`, amount],
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
        spender: ADDRESSES.SWAP_ROUTER,
        amount: amount.toString(),
      },
    },

    // 3. Swap WETH to HLG (using SwapRouter02 interface WITHOUT deadline)
    {
      to: ADDRESSES.SWAP_ROUTER,
      value: "0",
      data: encodeFunctionData({
        abi: parseAbi([
          "function exactInputSingle((address tokenIn, address tokenOut, uint24 fee, address recipient, uint256 amountIn, uint256 amountOutMinimum, uint160 sqrtPriceLimitX96)) returns (uint256 amountOut)",
        ]),
        functionName: "exactInputSingle",
        args: [
          {
            tokenIn: ADDRESSES.WETH as `0x${string}`,
            tokenOut: ADDRESSES.HLG as `0x${string}`,
            fee: poolFee,
            recipient: multisigAddress as `0x${string}`,
            amountIn: amount,
            amountOutMinimum: minHlgOut,
            sqrtPriceLimitX96: 0n,
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
          tokenIn: ADDRESSES.WETH,
          tokenOut: ADDRESSES.HLG,
          fee: poolFee,
          recipient: multisigAddress,
          amountIn: amount.toString(),
          amountOutMinimum: minHlgOut.toString(),
          sqrtPriceLimitX96: "0",
        },
      },
    },

    // 4. Approve HLG for StakingRewards
    {
      to: ADDRESSES.HLG,
      value: "0",
      data: encodeFunctionData({
        abi: parseAbi(["function approve(address,uint256)"]),
        functionName: "approve",
        args: [ADDRESSES.STAKING_REWARDS as `0x${string}`, expectedHlgOut * 2n],
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
        spender: ADDRESSES.STAKING_REWARDS,
        amount: (expectedHlgOut * 2n).toString(),
      },
    },

    // 5. Deposit to StakingRewards
    {
      to: ADDRESSES.STAKING_REWARDS,
      value: "0",
      data: encodeFunctionData({
        abi: parseAbi(["function depositAndDistribute(uint256)"]),
        functionName: "depositAndDistribute",
        // Deposit at least the conservative minOut to guarantee threshold
        args: [minHlgOut],
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

  // Generate checksum (simplified - in practice you'd want a proper hash)
  const checksum = `0x${Buffer.from(JSON.stringify(transactions)).toString("hex").slice(0, 64)}`;

  const safeBatch: SafeTransactionBuilderBatch = {
    version: "1.0",
    chainId: "11155111", // Sepolia chain ID
    createdAt: Date.now(),
    meta: {
      name: "HLG Fee Distribution Batch",
      description: `Convert ${ethAmount} ETH to HLG and stake in StakingRewards contract`,
      txBuilderVersion: "1.17.1",
      createdFromSafeAddress: multisigAddress,
      createdFromOwnerAddress: "",
      checksum: checksum,
    },
    transactions: transactions,
  };

  // Simulate the transaction first
  console.log("\n=== Tenderly Simulation ===");
  try {
    // Create the exact batch transaction that Safe will execute
    // Gnosis Safe MultiSendCallOnly (widely used canonical address)
    const multisendAddress = "0x40A2aCCbd92BCA938b02010E17A5b8929b49130D";
    let multisendData = ""; // build raw hex without 0x prefix

    for (const tx of transactions) {
      const operation = "00"; // 0 = CALL
      const to = tx.to.slice(2).padStart(40, "0");
      const value = BigInt(tx.value).toString(16).padStart(64, "0");
      const dataLength = tx.data ? (tx.data.slice(2).length / 2).toString(16).padStart(64, "0") : "0".padStart(64, "0");
      const data = tx.data ? tx.data.slice(2) : "";

      multisendData += operation + to + value + dataLength + data;
    }

    // Encode the multisend call - this is what the Safe will actually execute via DELEGATECALL
    const multisendCallData = encodeFunctionData({
      abi: parseAbi(["function multiSend(bytes transactions)"]),
      functionName: "multiSend",
      args: [`0x${multisendData}` as `0x${string}`],
    });

    // Wrap with Safe execTransaction payload for an accurate simulation
    const safeExecCalldata = createSafeExecutionData(
      multisendAddress,
      "0",
      multisendCallData,
      1, // DELEGATECALL
    );

    console.log("Simulating actual Safe execTransaction (DELEGATECALL to MultiSend)...");
    let result: TenderlyResponse | undefined;
    let bundleUrl: string | undefined;
    try {
      // Try bundle simulation (approveHash + approveHash + exec)
      bundleUrl = await simulateSafeBundle(
        multisigAddress,
        multisendAddress,
        multisendCallData,
        process.env.SAFE_OWNER_ADDRESS || "0x1ef43b825f6d1c3bfa93b3951e711f5d64550bda",
        process.env.SAFE_OWNER_ADDRESS_2 || process.env.SAFE_SECOND_OWNER || "0x2ef43b825f6d1c3bfa93b3951e711f5d64550bdb",
      );
      if (bundleUrl) console.log(`🔗 Bundle simulation: ${bundleUrl}`);
    } catch {}

    result = await simulateWithTenderly(
      multisigAddress,
      multisigAddress,
      safeExecCalldata,
      "0",
      undefined,
      {
        [ADDRESSES.WETH]: amount * 2n,
        [ADDRESSES.HLG]: expectedHlgOut * 10n,
      },
    );

    if (result.transaction.status) {
      console.log("✅ Simulation SUCCESS!");
      const tenderlyAccount =
        process.env.TENDERLY_ACCOUNT || process.env.TENDERLY_USER || process.env.TENDERLY_USERNAME;
      const tenderlyProject = process.env.TENDERLY_PROJECT || process.env.TENDERLY_PROJECT_SLUG;
      if (tenderlyAccount && tenderlyProject) {
        console.log(
          `📊 View simulation: https://dashboard.tenderly.co/${tenderlyAccount}/${tenderlyProject}/simulator/${result.simulation.id}`,
        );
      }
    } else {
      console.log("❌ Simulation FAILED");
      console.log("Error:", result.transaction.error_message || "Unknown error");
      const tenderlyAccount =
        process.env.TENDERLY_ACCOUNT || process.env.TENDERLY_USER || process.env.TENDERLY_USERNAME;
      const tenderlyProject = process.env.TENDERLY_PROJECT || process.env.TENDERLY_PROJECT_SLUG;
      if (tenderlyAccount && tenderlyProject) {
        console.log(
          `🔍 Debug simulation: https://dashboard.tenderly.co/${tenderlyAccount}/${tenderlyProject}/simulator/${result.simulation.id}`,
        );
      }

      // Still output the JSON in case user wants to investigate
      console.log("\n⚠️  Transaction failed simulation but JSON is generated below for investigation:");
    }
  } catch (error) {
    console.log("❌ Simulation request failed:", error);
    console.log("\n⚠️  Proceeding without simulation...");
  }

  // Output Safe Transaction Builder JSON
  console.log("\n=== Safe Transaction Builder JSON ===\n");
  console.log(JSON.stringify(safeBatch));

  console.log("\n=== Instructions ===");
  console.log("1. Copy the JSON above");
  console.log("2. Go to your Safe web app");
  console.log("3. Navigate to Transaction Builder");
  console.log('4. Click "Import JSON" or drag & drop the JSON file');
  console.log("5. Review and execute the batch transaction");

  return safeBatch;
}

// Build a Safe Transaction Builder batch that deposits HLG directly, no swaps
export async function generateDirectHLGDeposit(hlgAmount: string) {
  const amount = parseEther(hlgAmount);
  const multisigAddress = process.env.MULTISIG_ADDRESS || "0x8FE61F653450051cEcbae12475BA2b8fbA628c7A";

  console.log(`Direct deposit: ${hlgAmount} HLG to StakingRewards (no WETH, no swap)`);
  console.log(`Multisig Address: ${multisigAddress}`);
  console.log(`Reminder: Safe must hold at least ${hlgAmount} HLG balance`);

  const transactions: SafeTransactionBuilderTransaction[] = [
    // 1) Approve StakingRewards to pull HLG from the Safe
    {
      to: ADDRESSES.HLG,
      value: "0",
      data: encodeFunctionData({
        abi: parseAbi(["function approve(address,uint256)"]),
        functionName: "approve",
        args: [ADDRESSES.STAKING_REWARDS as `0x${string}`, amount],
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
        spender: ADDRESSES.STAKING_REWARDS,
        amount: amount.toString(),
      },
    },
    // 2) Deposit and distribute
    {
      to: ADDRESSES.STAKING_REWARDS,
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

  const checksum = `0x${Buffer.from(JSON.stringify(transactions)).toString("hex").slice(0, 64)}`;

  const safeBatch: SafeTransactionBuilderBatch = {
    version: "1.0",
    chainId: "11155111",
    createdAt: Date.now(),
    meta: {
      name: "Direct HLG Deposit",
      description: `Deposit ${hlgAmount} HLG into StakingRewards (burn/reward split applied)` ,
      txBuilderVersion: "1.17.1",
      createdFromSafeAddress: multisigAddress,
      createdFromOwnerAddress: "",
      checksum,
    },
    transactions,
  };

  console.log("\n=== Safe Transaction Builder JSON (Direct HLG) ===\n");
  console.log(JSON.stringify(safeBatch));
  return safeBatch;
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  // Simple CLI args parsing
  const args = process.argv.slice(2);
  let ethAmount = "0.6";
  let simulateOnly = false;
  let transferOwnership = false;
  let acceptOwnership = false;
  let directHLG: string | undefined;

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === "--simulate-only") {
      simulateOnly = true;
      continue;
    }
    if (arg === "--transfer-ownership") {
      transferOwnership = true;
      continue;
    }
    if (arg === "--accept-ownership") {
      acceptOwnership = true;
      continue;
    }
    if (arg === "--amount" || arg === "--eth" || arg === "-a") {
      const value = args[i + 1];
      if (value && !value.startsWith("-")) {
        ethAmount = value;
        i += 1;
      }
      continue;
    }
    if (arg === "--hlg" || arg === "--direct-hlg") {
      const value = args[i + 1];
      if (value && !value.startsWith("-")) {
        directHLG = value;
        i += 1;
      }
      continue;
    }
    // If it's a positional non-flag argument, treat it as amount
    if (arg && !arg.startsWith("-")) {
      ethAmount = arg;
    }
  }

  if (transferOwnership) {
    transferStakingRewardsOwnership().catch(console.error);
  } else if (acceptOwnership) {
    generateAcceptOwnershipTransaction().catch(console.error);
  } else {
    if (simulateOnly) {
      console.log("🎯 Running in simulation-only mode");
    }
    if (directHLG) {
      generateDirectHLGDeposit(directHLG).catch(console.error);
    } else {
      generateBatchTransaction(ethAmount).catch(console.error);
    }
  }
}
