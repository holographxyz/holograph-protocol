/**
 * Holograph Token Creation Script
 *
 * Environment Variables Required:
 * - PRIVATE_KEY: Private key for the account creating tokens
 * - BASESCAN_API_KEY: API key for contract verification on Base Sepolia
 *
 * Optional Environment Variables:
 * - BASE_SEPOLIA_RPC_URL: Custom RPC endpoint (uses public by default)
 */

import dotenv from "dotenv";
dotenv.config();

import {
  createWalletClient,
  createPublicClient,
  http,
  parseEther,
  encodeAbiParameters,
  parseAbiParameters,
  decodeAbiParameters,
  Address,
  keccak256,
  concat,
  pad,
  toHex,
  decodeEventLog,
} from "viem";
import { baseSepolia } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { readFileSync } from "fs";
import { spawn } from "child_process";

// Constants
const FEE_ROUTER = "0x10F2c0fdc9799A293b4C726a1314BD73A4AB9f20" as const;

const DOPPLER_ADDRESSES = {
  airlock: "0x3411306Ce66c9469BFF1535BA955503c4Bde1C6e",
  tokenFactory: "0xbA59B9510806034C3B8a7f46756Feeb5387340e3", // Our HolographFactory
  governanceFactory: "0x9dBFaaDC8c0cB2c34bA698DD9426555336992e20",
  v4Initializer: "0x8e891d249f1ecbffa6143c03eb1b12843aef09d3",
  migrator: "0x846a84918aA87c14b86B2298776e8ea5a4e34C9E", // UniswapV4Migrator (latest)
  poolManager: "0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408",
  dopplerDeployer: "0x60a039e4add40ca95e0475c11e8a4182d06c9aa0",
} as const;

// Hook flags for salt mining
const HOOK_FLAGS = {
  BEFORE_INITIALIZE_FLAG: 1n << 13n,
  AFTER_INITIALIZE_FLAG: 1n << 12n,
  BEFORE_ADD_LIQUIDITY_FLAG: 1n << 11n,
  BEFORE_SWAP_FLAG: 1n << 7n,
  AFTER_SWAP_FLAG: 1n << 6n,
  BEFORE_DONATE_FLAG: 1n << 5n,
} as const;

const REQUIRED_FLAGS =
  HOOK_FLAGS.BEFORE_INITIALIZE_FLAG |
  HOOK_FLAGS.AFTER_INITIALIZE_FLAG |
  HOOK_FLAGS.BEFORE_ADD_LIQUIDITY_FLAG |
  HOOK_FLAGS.BEFORE_SWAP_FLAG |
  HOOK_FLAGS.AFTER_SWAP_FLAG |
  HOOK_FLAGS.BEFORE_DONATE_FLAG;

const FLAG_MASK = 0x3fffn;
const CHAIN_ID = 84532; // Base Sepolia
const MAX_SALT_ITERATIONS = 200_000;

// Types
interface TokenConfig {
  name: string;
  symbol: string;
  initialSupply: bigint;
  minProceeds: bigint;
  maxProceeds: bigint;
  auctionDurationDays: number;
}

interface CreateTokenParams {
  initialSupply: bigint;
  numTokensToSell: bigint;
  numeraire: Address;
  tokenFactory: Address;
  tokenFactoryData: `0x${string}`;
  governanceFactory: Address;
  governanceFactoryData: `0x${string}`;
  poolInitializer: Address;
  poolInitializerData: `0x${string}`;
  liquidityMigrator: Address;
  liquidityMigratorData: `0x${string}`;
  integrator: Address;
  salt: `0x${string}`;
}

// ABI definitions
const AIRLOCK_ABI = [
  {
    type: "function",
    name: "create",
    inputs: [
      {
        name: "params",
        type: "tuple",
        components: [
          { name: "initialSupply", type: "uint256" },
          { name: "numTokensToSell", type: "uint256" },
          { name: "numeraire", type: "address" },
          { name: "tokenFactory", type: "address" },
          { name: "tokenFactoryData", type: "bytes" },
          { name: "governanceFactory", type: "address" },
          { name: "governanceFactoryData", type: "bytes" },
          { name: "poolInitializer", type: "address" },
          { name: "poolInitializerData", type: "bytes" },
          { name: "liquidityMigrator", type: "address" },
          { name: "liquidityMigratorData", type: "bytes" },
          { name: "integrator", type: "address" },
          { name: "salt", type: "bytes32" },
        ],
      },
    ],
    outputs: [
      { name: "asset", type: "address" },
      { name: "pool", type: "address" },
      { name: "governance", type: "address" },
      { name: "timelock", type: "address" },
      { name: "migrationPool", type: "address" }
    ],
    stateMutability: "nonpayable",
  },
] as const;

// Utility functions
function loadContractBytecode(contractName: string): `0x${string}` {
  try {
    let artifactPath: string;
    if (contractName === "HolographERC20") {
      artifactPath = `out/${contractName}.sol/${contractName}.json`;
    } else {
      artifactPath = `artifacts/doppler/${contractName}.json`;
    }
    
    const artifactContent = readFileSync(artifactPath, "utf8");
    const artifact = JSON.parse(artifactContent);

    if (!artifact.bytecode?.object) {
      throw new Error(`Bytecode not found in ${contractName} artifact`);
    }

    return artifact.bytecode.object as `0x${string}`;
  } catch (error) {
    throw new Error(`Could not load ${contractName} bytecode: ${error}`);
  }
}

function computeCreate2Address(salt: `0x${string}`, initCodeHash: `0x${string}`, deployer: Address): Address {
  const packed = concat(["0xff", deployer, salt, initCodeHash]);
  const hash = keccak256(packed);
  return `0x${hash.slice(-40)}` as Address;
}

function extractTokenAddress(receipt: any): string | null {
  for (const log of receipt.logs) {
    try {
      // Look for TokenDeployed event from HolographFactory
      if (log.address.toLowerCase() === DOPPLER_ADDRESSES.tokenFactory.toLowerCase()) {
        const decoded = decodeEventLog({
          abi: [{
            type: "event",
            name: "TokenDeployed",
            inputs: [
              { name: "token", type: "address", indexed: true },
              { name: "name", type: "string", indexed: false },
              { name: "symbol", type: "string", indexed: false },
              { name: "initialSupply", type: "uint256", indexed: false },
              { name: "recipient", type: "address", indexed: true },
              { name: "owner", type: "address", indexed: true }
            ]
          }],
          data: log.data,
          topics: log.topics,
        });

        if (decoded.eventName === "TokenDeployed") {
          return decoded.args.token as string;
        }
      }
    } catch (error) {
      continue;
    }
  }
  return null;
}

// Contract verification
async function verifyContract(
  contractAddress: string,
  contractPath: string,
  constructorArgs: string,
  apiKey: string,
): Promise<void> {
  console.log(`🔍 Verifying contract at ${contractAddress}...`);

  return new Promise<void>((resolve, reject) => {
    const args = [
      "verify-contract",
      "--verifier",
      "etherscan",
      "--chain-id",
      CHAIN_ID.toString(),
      "--constructor-args",
      constructorArgs,
      "--etherscan-api-key",
      apiKey,
      "--flatten",
      "--force",
      contractAddress,
      contractPath,
    ];

    const env = {
      ...process.env,
      ETHERSCAN_API_KEY: apiKey,
      BASESCAN_API_KEY: apiKey,
    };

    const childProcess = spawn("forge", args, {
      stdio: ["pipe", "pipe", "pipe"],
      cwd: process.cwd(),
      env,
    });

    let stdout = "";
    let stderr = "";

    childProcess.stdout?.on("data", (data: any) => {
      stdout += data.toString();
    });

    childProcess.stderr?.on("data", (data: any) => {
      stderr += data.toString();
    });

    childProcess.on("close", (code: number | null) => {
      const output = (stdout + stderr).toLowerCase();

      // Check for success indicators
      if (
        output.includes("successfully verified") ||
        output.includes("contract verification successful") ||
        output.includes("verification completed")
      ) {
        console.log("✅ Contract verification successful!");
        resolve();
        return;
      }

      // Check for already verified
      if (
        output.includes("already verified") ||
        output.includes("contract source code already verified") ||
        output.includes("is already verified")
      ) {
        console.log("ℹ️  Contract was already verified.");
        resolve();
        return;
      }

      // If we get here, it's likely a real error
      reject(new Error(`Verification failed with code ${code}\nstdout: ${stdout}\nstderr: ${stderr}`));
    });
  });
}

async function verifyTokenContract(
  tokenAddress: string,
  createParams: CreateTokenParams,
  config: TokenConfig,
): Promise<void> {
  console.log("🔍 Preparing HolographERC20 contract verification...");

  const apiKey = process.env.BASESCAN_API_KEY || process.env.ETHERSCAN_API_KEY;
  if (!apiKey) {
    console.log("⚠️  BASESCAN_API_KEY not found - skipping contract verification");
    console.log("💡 Add BASESCAN_API_KEY to your .env file to enable contract verification");
    return;
  }

  const [name, symbol, yearlyMintCap, vestingDuration, recipients, amounts, tokenURI] = decodeAbiParameters(
    parseAbiParameters("string, string, uint256, uint256, address[], uint256[], string"),
    createParams.tokenFactoryData,
  );

  const constructorArgs = encodeAbiParameters(
    parseAbiParameters("string, string, uint256, address, address, address, uint256, uint256, address[], uint256[], string"),
    [
      name,
      symbol,
      createParams.initialSupply,
      DOPPLER_ADDRESSES.airlock as Address, // recipient
      DOPPLER_ADDRESSES.airlock as Address, // owner  
      "0x1a44076050125825900e736c501f859c50fE728c" as Address, // LayerZero endpoint Base Sepolia
      yearlyMintCap,
      vestingDuration,
      recipients,
      amounts,
      tokenURI,
    ],
  );

  try {
    await verifyContract(tokenAddress, "src/HolographERC20.sol:HolographERC20", constructorArgs, apiKey);
    console.log("🎉 Token contract verification completed!");
    console.log(`🔗 View verified contract: https://sepolia.basescan.org/address/${tokenAddress}#code`);
  } catch (error: any) {
    console.log("⚠️  Automatic contract verification failed, but the token was created successfully!");
    console.log("📋 Manual verification instructions:");
    console.log(`1. Go to: https://sepolia.basescan.org/verifyContract`);
    console.log(`2. Enter contract address: ${tokenAddress}`);
    console.log(`3. Select compiler: Solidity (Single file)`);
    console.log(`4. Select compiler version: v0.8.26+commit.8a97fa7a`);
    console.log(`5. Select optimization: Yes, with 200 runs`);
    console.log(`6. Paste the flattened source code (generate with: forge flatten src/HolographERC20.sol)`);
    console.log(`7. Constructor arguments: ${constructorArgs}`);
    console.log("");
    console.log("Or try this command manually:");
    console.log(
      `forge verify-contract --verifier etherscan --chain-id ${CHAIN_ID} --etherscan-api-key YOUR_API_KEY --constructor-args ${constructorArgs} --flatten ${tokenAddress} src/HolographERC20.sol:HolographERC20`,
    );
  }

  // Print deployment summary
  console.log("");
  console.log("🎊 DEPLOYMENT SUMMARY:");
  console.log(`📍 Token Address: ${tokenAddress}`);
  console.log(`📛 Token Name: ${name}`);
  console.log(`🏷️  Token Symbol: ${symbol}`);
  console.log(`💰 Initial Supply: ${createParams.initialSupply.toString()}`);
  console.log(`🌐 Explorer: https://sepolia.basescan.org/address/${tokenAddress}`);
  console.log(`📄 Contract Code: https://sepolia.basescan.org/address/${tokenAddress}#code`);
}

// Salt mining
async function mineValidSalt(
  tokenFactoryData: `0x${string}`,
  poolInitializerData: `0x${string}`,
  initialSupply: bigint,
  numTokensToSell: bigint,
  numeraire: Address,
  publicClient: any,
): Promise<`0x${string}`> {
  console.log("⛏️  Mining valid salt...");

  const [
    minimumProceeds,
    maximumProceeds,
    startingTime,
    endingTime,
    startingTick,
    endingTick,
    epochLength,
    gamma,
    isToken0,
    numPDSlugs,
    lpFee,
    tickSpacing,
  ] = decodeAbiParameters(
    parseAbiParameters(
      "uint256, uint256, uint256, uint256, int24, int24, uint256, int24, bool, uint256, uint24, int24",
    ),
    poolInitializerData,
  );

  // Prepare Doppler constructor arguments
  const dopplerConstructorArgs = encodeAbiParameters(
    parseAbiParameters(
      "address, uint256, uint256, uint256, uint256, uint256, int24, int24, uint256, int24, bool, uint256, address, uint24",
    ),
    [
      DOPPLER_ADDRESSES.poolManager as Address,
      numTokensToSell,
      minimumProceeds,
      maximumProceeds,
      startingTime,
      endingTime,
      startingTick,
      endingTick,
      epochLength,
      gamma,
      isToken0,
      numPDSlugs,
      DOPPLER_ADDRESSES.v4Initializer as Address,
      lpFee,
    ],
  );

  // Prepare token constructor arguments for HolographERC20
  const [name, symbol, yearlyMintCap, vestingDuration, recipients, amounts, tokenURI] = decodeAbiParameters(
    parseAbiParameters("string, string, uint256, uint256, address[], uint256[], string"),
    tokenFactoryData,
  );

  const tokenConstructorArgs = encodeAbiParameters(
    parseAbiParameters("string, string, uint256, address, address, address, uint256, uint256, address[], uint256[], string"),
    [
      name,
      symbol,
      initialSupply,
      DOPPLER_ADDRESSES.airlock as Address, // recipient
      DOPPLER_ADDRESSES.airlock as Address, // owner
      "0x1a44076050125825900e736c501f859c50fE728c" as Address, // LayerZero endpoint Base Sepolia
      yearlyMintCap,
      vestingDuration,
      recipients,
      amounts,
      tokenURI,
    ],
  );

  // Calculate init code hashes
  const dopplerBytecode = loadContractBytecode("Doppler");
  const dopplerInitHash = keccak256(concat([dopplerBytecode, dopplerConstructorArgs]));

  const holographERC20Bytecode = loadContractBytecode("HolographERC20");
  const tokenInitHash = keccak256(concat([holographERC20Bytecode, tokenConstructorArgs]));

  // Mine salt
  for (let saltNum = 0; saltNum < MAX_SALT_ITERATIONS; saltNum++) {
    if (saltNum % 10000 === 0) {
      console.log(`⛏️  Mining progress: ${saltNum}/${MAX_SALT_ITERATIONS}`);
    }

    const salt = pad(toHex(saltNum), { size: 32 }) as `0x${string}`;
    const hookAddress = computeCreate2Address(salt, dopplerInitHash, DOPPLER_ADDRESSES.dopplerDeployer as Address);
    const assetAddress = computeCreate2Address(salt, tokenInitHash, DOPPLER_ADDRESSES.tokenFactory as Address);

    // Check hook flags
    const hookFlags = BigInt(hookAddress) & FLAG_MASK;
    if (hookFlags !== REQUIRED_FLAGS) {
      continue;
    }

    // Check if hook address is available
    try {
      const code = await publicClient.getBytecode({ address: hookAddress });
      if (code && code !== "0x") {
        continue;
      }
    } catch {
      continue;
    }

    // Check token ordering
    const assetBigInt = BigInt(assetAddress);
    const numeraireBigInt = BigInt(numeraire);
    const correctOrdering = isToken0 ? assetBigInt < numeraireBigInt : assetBigInt > numeraireBigInt;

    if (!correctOrdering) {
      continue;
    }

    console.log(`✅ Found valid salt: ${saltNum}`);
    console.log(`📍 Hook address: ${hookAddress}`);
    console.log(`📍 Asset address: ${assetAddress}`);
    console.log(`🔍 Hook flags: ${hookFlags} (required: ${REQUIRED_FLAGS})`);
    console.log(`🔍 Token ordering: isToken0=${isToken0}, asset < numeraire: ${assetBigInt < numeraireBigInt}`);
    return salt;
  }

  throw new Error(`Could not find valid salt after ${MAX_SALT_ITERATIONS} iterations`);
}

// Main function
async function createToken() {
  const privateKey = process.env.PRIVATE_KEY as `0x${string}`;
  if (!privateKey) {
    throw new Error("PRIVATE_KEY environment variable is required");
  }

  const account = privateKeyToAccount(privateKey);
  const rpcUrl = process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org";

  const publicClient = createPublicClient({
    chain: baseSepolia,
    transport: http(rpcUrl),
  });

  const walletClient = createWalletClient({
    account,
    chain: baseSepolia,
    transport: http(rpcUrl),
  });

  const config: TokenConfig = {
    name: "Test Token",
    symbol: "TEST",
    initialSupply: parseEther("100000"),
    minProceeds: parseEther("100"),
    maxProceeds: parseEther("10000"),
    auctionDurationDays: 3,
  };

  console.log("🚀 Creating token:", config.name);

  // Prepare factory data
  const tokenFactoryData = encodeAbiParameters(
    parseAbiParameters("string, string, uint256, uint256, address[], uint256[], string"),
    [config.name, config.symbol, 0n, 0n, [], [], ""],
  );

  const governanceData = encodeAbiParameters(parseAbiParameters("string, uint256, uint256, uint256"), [
    `${config.name} DAO`,
    7200n, // voting delay
    50400n, // voting period
    0n, // proposal threshold
  ]);

  // Set auction timing with buffer
  const fixedStartTime = Math.floor(Date.now() / 1000) + 600; // 10 minutes from now
  const auctionStart = fixedStartTime;
  const auctionEnd = auctionStart + config.auctionDurationDays * 24 * 60 * 60;

  console.log("⏰ Auction timing:", {
    auctionStart: new Date(auctionStart * 1000).toISOString(),
    auctionEnd: new Date(auctionEnd * 1000).toISOString(),
    duration: config.auctionDurationDays + " days",
  });

  const poolInitializerData = encodeAbiParameters(
    parseAbiParameters(
      "uint256, uint256, uint256, uint256, int24, int24, uint256, int24, bool, uint256, uint24, int24",
    ),
    [
      config.minProceeds,
      config.maxProceeds,
      BigInt(auctionStart),
      BigInt(auctionEnd),
      6000, // starting tick
      60000, // ending tick
      400n, // epoch length
      800, // gamma
      false, // isToken0
      8n, // numPDSlugs
      3000, // lpFee
      8, // tick spacing
    ],
  );

  // Mine valid salt
  const salt = await mineValidSalt(
    tokenFactoryData,
    poolInitializerData,
    config.initialSupply,
    config.initialSupply,
    "0x0000000000000000000000000000000000000000" as Address,
    publicClient,
  );

  // Prepare liquidity migrator data for UniswapV4Migrator
  const lockDuration = 365 * 24 * 60 * 60; // 1 year in seconds
  const protocolOwner = "0xaCE07c3c1D3b556D42633211f0Da71dc6F6d1c42" as const; // Protocol owner from Airlock
  
  // Create beneficiaries array with proper BeneficiaryData structure
  // Must be sorted by address and include protocol owner with minimum 5% (0.05e18)
  const beneficiaries = [
    {
      beneficiary: protocolOwner,
      shares: parseEther("0.05") // 5% minimum for protocol owner
    },
    {
      beneficiary: account.address, // Token creator gets the remaining 95%
      shares: parseEther("0.95")
    }
  ].sort((a, b) => {
    // Sort by address (ascending)
    if (a.beneficiary.toLowerCase() < b.beneficiary.toLowerCase()) return -1;
    if (a.beneficiary.toLowerCase() > b.beneficiary.toLowerCase()) return 1;
    return 0;
  });
  
  // Encode as proper BeneficiaryData array
  const liquidityMigratorData = encodeAbiParameters(
    parseAbiParameters("uint24, int24, uint32, (address,uint96)[]"),
    [
      3000, // fee (matches LP_FEE)
      8, // tickSpacing (matches TICK_SPACING)
      lockDuration,
      beneficiaries.map(b => [b.beneficiary, b.shares] as const)
    ]
  );

  const createParams: CreateTokenParams = {
    initialSupply: config.initialSupply,
    numTokensToSell: config.initialSupply,
    numeraire: "0x0000000000000000000000000000000000000000" as Address,
    tokenFactory: DOPPLER_ADDRESSES.tokenFactory as Address,
    tokenFactoryData,
    governanceFactory: DOPPLER_ADDRESSES.governanceFactory as Address,
    governanceFactoryData: governanceData,
    poolInitializer: DOPPLER_ADDRESSES.v4Initializer as Address,
    poolInitializerData,
    liquidityMigrator: DOPPLER_ADDRESSES.migrator as Address,
    liquidityMigratorData,
    integrator: FEE_ROUTER,
    salt,
  };

  try {
    console.log("⛽ Estimating gas...");
    const gasEstimate = await publicClient.estimateContractGas({
      address: DOPPLER_ADDRESSES.airlock,
      abi: AIRLOCK_ABI,
      functionName: "create",
      args: [createParams as any],
      account: account.address,
    });

    console.log(`📊 Gas estimated: ${gasEstimate.toString()}`);

    console.log("📤 Submitting transaction to Doppler Airlock...");
    const hash = await walletClient.writeContract({
      address: DOPPLER_ADDRESSES.airlock,
      abi: AIRLOCK_ABI,
      functionName: "create",
      args: [createParams as any],
      gas: gasEstimate * 2n, // 2x buffer for safety
    });

    console.log("🧾 Transaction hash:", hash);
    console.log("🔗 Explorer:", `https://sepolia.basescan.org/tx/${hash}`);

    console.log("⏳ Waiting for transaction confirmation...");
    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    if (receipt.status === "success") {
      console.log("✅ Token creation successful!");
      console.log(`💰 Gas used: ${receipt.gasUsed.toString()}`);

      const tokenAddress = extractTokenAddress(receipt);
      if (tokenAddress) {
        console.log("🎉 Token address:", tokenAddress);
        console.log("🔗 Basescan:", `https://sepolia.basescan.org/address/${tokenAddress}`);
        await verifyTokenContract(tokenAddress, createParams, config);
      } else {
        console.log("⚠️  Could not extract token address from transaction logs");
      }

      return hash;
    } else {
      throw new Error("Transaction reverted");
    }
  } catch (error) {
    console.error("❌ Token creation failed:", error);
    throw error;
  }
}

// Execute the script
createToken().catch(console.error);
