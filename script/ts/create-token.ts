/**
 * Holograph Token Creation Script
 *
 * Creates ERC20 tokens through the Doppler Airlock using HolographFactory.
 * The factory creates HolographERC20 tokens with governance and DeFi features.
 *
 * Environment Variables Required:
 * - PRIVATE_KEY: Private key for the account creating tokens
 * - BASESCAN_API_KEY: API key for contract verification on Base Sepolia
 *
 * Optional Environment Variables:
 * - BASE_SEPOLIA_RPC_URL: Custom RPC endpoint (uses public by default)
 *
 * Prerequisites:
 * - HolographFactory must be authorized with Doppler Airlock (✅ Done)
 * - Factory deployed at: 0x47ca9bEa164E94C38Ec52aB23377dC2072356D10
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
import { formatCompactEther, formatGas } from "./lib/format.js";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

// Constants - Updated with current deployment addresses
const FEE_ROUTER = "0x2addbd495582389b96C7B06C4D877e6C1B522bD4" as const;

// Holograph deployment addresses from deployment.json
const HOLOGRAPH_ADDRESSES = {
  factoryProxy: "0x47ca9bEa164E94C38Ec52aB23377dC2072356D10", // HolographFactory Proxy
  factoryImplementation: "0x08Eb3E7A917bB125613E6Dd2D82ef4D6d6248102", // HolographFactory Implementation
  erc20Implementation: "0x4679Ba09dcfcC80CF1E6628F9850C54b198b5D6A", // HolographERC20 Implementation
} as const;

const DOPPLER_ADDRESSES = {
  airlock: "0x3411306Ce66c9469BFF1535BA955503c4Bde1C6e",
  tokenFactory: HOLOGRAPH_ADDRESSES.factoryProxy, // Our HolographFactory Proxy
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

// Time constants
const SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
const SECONDS_PER_DAY = 24 * 60 * 60;
const AUCTION_START_BUFFER = 600; // 10 minutes

// Gas and retry constants
const GAS_BUFFER_MULTIPLIER = 2n;
const RETRY_DELAY_MS = 2000;
const MAX_RETRIES = 3;

// Uniswap V4 constants
const LP_FEE = 3000;
const TICK_SPACING = 8;

// Shares constants
const PROTOCOL_MIN_SHARES = "0.05"; // 5%
const CREATOR_SHARES = "0.95"; // 95%

// Default token parameters
const DEFAULT_YEARLY_MINT_CAP = 0n;
const DEFAULT_VESTING_DURATION = 0n;

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
      { name: "migrationPool", type: "address" },
    ],
    stateMutability: "nonpayable",
  },
] as const;

// Get the project root directory
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
// When compiled, we'll be in dist/script/, so we need to go up 2 levels to get to project root
// When running directly with tsx, we'll be in script/, so we need to go up 1 level
const isCompiled = __dirname.includes('/dist/');
const PROJECT_ROOT = isCompiled ? dirname(dirname(__dirname)) : dirname(__dirname);

// Utility functions
function loadContractBytecode(contractName: string): `0x${string}` {
  try {
    let artifactPath: string;
    if (contractName === "HolographERC20") {
      artifactPath = join(PROJECT_ROOT, "out", `${contractName}.sol`, `${contractName}.json`);
    } else {
      artifactPath = join(PROJECT_ROOT, "artifacts", "doppler", `${contractName}.json`);
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

function getERC1167Bytecode(implementation: Address): `0x${string}` {
  // ERC1167 minimal proxy bytecode with implementation address embedded
  // Format: 0x3d602d80600a3d3981f3363d3d373d3d3d363d73{implementation}5af43d82803e903d91602b57fd5bf3
  const prefix = "0x3d602d80600a3d3981f3363d3d373d3d3d363d73";
  const suffix = "0x5af43d82803e903d91602b57fd5bf3";
  return `${prefix}${implementation.slice(2).toLowerCase()}${suffix}` as `0x${string}`;
}

function extractTokenAddress(receipt: any): string | null {
  for (const log of receipt.logs) {
    try {
      // Look for Airlock Create event: event Create(address asset, address indexed numeraire, address initializer, address poolOrHook)
      if (log.address.toLowerCase() === DOPPLER_ADDRESSES.airlock.toLowerCase()) {
        const decoded = decodeEventLog({
          abi: [
            {
              type: "event",
              name: "Create",
              inputs: [
                { name: "asset", type: "address", indexed: false },
                { name: "numeraire", type: "address", indexed: true },
                { name: "initializer", type: "address", indexed: false },
                { name: "poolOrHook", type: "address", indexed: false },
              ],
            },
          ],
          data: log.data,
          topics: log.topics,
        });

        if (decoded.eventName === "Create" && decoded.args.asset) {
          return decoded.args.asset as string;
        }
      }

      // Look for HolographFactory TokenDeployed event (backup method)
      if (log.address.toLowerCase() === DOPPLER_ADDRESSES.tokenFactory.toLowerCase()) {
        const decoded = decodeEventLog({
          abi: [
            {
              type: "event",
              name: "TokenDeployed",
              inputs: [
                { name: "token", type: "address", indexed: true },
                { name: "name", type: "string", indexed: false },
                { name: "symbol", type: "string", indexed: false },
                { name: "initialSupply", type: "uint256", indexed: false },
                { name: "recipient", type: "address", indexed: true },
                { name: "owner", type: "address", indexed: true },
                { name: "creator", type: "address", indexed: false },
              ],
            },
          ],
          data: log.data,
          topics: log.topics,
        });

        if (decoded.eventName === "TokenDeployed" && decoded.args.token) {
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
      cwd: PROJECT_ROOT,
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

  console.log("⚠️  Token verification skipped - tokens are deployed as ERC1167 minimal proxies");
  console.log("💡 The token is a clone of the HolographERC20 implementation:");
  console.log(`📍 Implementation: ${HOLOGRAPH_ADDRESSES.erc20Implementation}`);
  console.log(
    `🔗 View implementation: https://sepolia.basescan.org/address/${HOLOGRAPH_ADDRESSES.erc20Implementation}#code`,
  );
  console.log(`🔗 View proxy token: https://sepolia.basescan.org/address/${tokenAddress}`);

  try {
    // For minimal proxies, we verify against the Clones library pattern
    console.log("🔍 Attempting to verify as ERC1167 minimal proxy...");
    await verifyContract(
      tokenAddress,
      "@openzeppelin/contracts/proxy/Clones.sol:Clones",
      `000000000000000000000000${HOLOGRAPH_ADDRESSES.erc20Implementation.slice(2)}`,
      apiKey,
    );
    console.log("🎉 Proxy contract verification completed!");
  } catch (error: any) {
    console.log("ℹ️  Proxy verification not needed - BaseScan should auto-detect ERC1167 proxies");
  }

  // Print deployment summary
  console.log("");
  console.log("🎊 DEPLOYMENT SUMMARY:");
  console.log(`📍 Token Address: ${tokenAddress}`);
  console.log(`📛 Token Name: ${config.name}`);
  console.log(`🏷️  Token Symbol: ${config.symbol}`);
  console.log(`💰 Initial Supply: ${formatCompactEther(createParams.initialSupply)}`);
  console.log(`🌐 Explorer: https://sepolia.basescan.org/address/${tokenAddress}`);
  console.log(`📄 Contract Code: https://sepolia.basescan.org/address/${tokenAddress}#code`);
}

// Salt mining
async function mineValidSalt(
  _tokenFactoryData: `0x${string}`,
  poolInitializerData: `0x${string}`,
  _initialSupply: bigint,
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
    // tickSpacing - unused but needed for destructuring
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

  // Note: Token constructor args not needed for ERC1167 minimal proxy CREATE2 calculation
  // Tokens are deployed as clones of the implementation, not full contracts
  
  // Note: tokenFactoryData and initialSupply are extracted from poolInitializerData
  // for parameter structure matching but not directly used in salt mining

  // Calculate init code hashes
  const dopplerBytecode = loadContractBytecode("Doppler");
  const dopplerInitHash = keccak256(concat([dopplerBytecode, dopplerConstructorArgs]));

  // For HolographFactory, tokens are deployed as ERC1167 minimal proxies
  // The init code hash is just the ERC1167 bytecode with the implementation address embedded
  const tokenCloneBytecode = getERC1167Bytecode(HOLOGRAPH_ADDRESSES.erc20Implementation);
  const tokenInitHash = keccak256(tokenCloneBytecode);

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

// Custom error class for better error handling
class TokenCreationError extends Error {
  code: string;
  override cause: Error | undefined;

  constructor(message: string, code: string, cause?: Error) {
    super(message);
    this.name = "TokenCreationError";
    this.code = code;
    this.cause = cause;
  }
}

// Validation functions
function validateEnvironment(): { privateKey: `0x${string}`; rpcUrl: string } {
  const privateKey = process.env.PRIVATE_KEY as `0x${string}`;
  if (!privateKey) {
    throw new TokenCreationError("PRIVATE_KEY environment variable is required", "ENV_MISSING_PRIVATE_KEY");
  }

  const rpcUrl = process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org";

  return { privateKey, rpcUrl };
}

// Client setup functions
function setupClients(privateKey: `0x${string}`, rpcUrl: string) {
  const account = privateKeyToAccount(privateKey);

  const publicClient = createPublicClient({
    chain: baseSepolia,
    transport: http(rpcUrl),
  });

  const walletClient = createWalletClient({
    account,
    chain: baseSepolia,
    transport: http(rpcUrl),
  });

  return { account, publicClient, walletClient };
}

// Token parameter preparation functions
function prepareTokenParams(config: TokenConfig) {
  const tokenFactoryData = encodeAbiParameters(
    parseAbiParameters("string, string, uint256, uint256, address[], uint256[], string"),
    [config.name, config.symbol, DEFAULT_YEARLY_MINT_CAP, DEFAULT_VESTING_DURATION, [], [], ""],
  );

  return tokenFactoryData;
}

function prepareGovernanceParams(config: TokenConfig) {
  const governanceData = encodeAbiParameters(parseAbiParameters("string, uint256, uint256, uint256"), [
    `${config.name} DAO`,
    7200n, // voting delay
    50400n, // voting period
    0n, // proposal threshold
  ]);

  return governanceData;
}

function preparePoolInitializerParams(config: TokenConfig, auctionStart: number, auctionEnd: number) {
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
      LP_FEE, // lpFee
      TICK_SPACING, // tick spacing
    ],
  );

  return poolInitializerData;
}

function prepareLiquidityParams(account: Address) {
  const lockDuration = SECONDS_PER_YEAR;
  const protocolOwner = "0x852a09C89463D236eea2f097623574f23E225769" as const;

  const beneficiaries = [
    {
      beneficiary: protocolOwner,
      shares: parseEther(PROTOCOL_MIN_SHARES),
    },
    {
      beneficiary: account,
      shares: parseEther(CREATOR_SHARES),
    },
  ].sort((a, b) => {
    if (a.beneficiary.toLowerCase() < b.beneficiary.toLowerCase()) return -1;
    if (a.beneficiary.toLowerCase() > b.beneficiary.toLowerCase()) return 1;
    return 0;
  });

  const liquidityMigratorData = encodeAbiParameters(parseAbiParameters("uint24, int24, uint32, (address,uint96)[]"), [
    LP_FEE,
    TICK_SPACING,
    lockDuration,
    beneficiaries.map((b) => [b.beneficiary, b.shares] as const),
  ]);

  return liquidityMigratorData;
}

async function executeTokenCreation(
  createParams: CreateTokenParams,
  account: Address,
  publicClient: any,
  walletClient: any,
): Promise<{ hash: `0x${string}`; tokenAddress: string | undefined }> {
  console.log("⛽ Estimating gas...");
  const gasEstimate = await publicClient.estimateContractGas({
    address: DOPPLER_ADDRESSES.airlock,
    abi: AIRLOCK_ABI,
    functionName: "create",
    args: [createParams as any],
    account: account,
  });

  console.log(`📊 Gas estimated: ${formatGas(gasEstimate)}`);

  console.log("📤 Submitting transaction to Doppler Airlock...");
  const hash = await walletClient.writeContract({
    address: DOPPLER_ADDRESSES.airlock,
    abi: AIRLOCK_ABI,
    functionName: "create",
    args: [createParams as any],
    gas: gasEstimate * GAS_BUFFER_MULTIPLIER,
  });

  console.log("🧾 Transaction hash:", hash);
  console.log("🔗 Explorer:", `https://sepolia.basescan.org/tx/${hash}`);

  console.log("⏳ Waiting for transaction confirmation...");
  const receipt = await publicClient.waitForTransactionReceipt({ hash });

  if (receipt.status !== "success") {
    throw new TokenCreationError("Transaction reverted", "TX_REVERTED");
  }

  console.log("✅ Token creation successful!");
  console.log(`💰 Gas used: ${formatGas(receipt.gasUsed)}`);

  const tokenAddress = extractTokenAddress(receipt);
  return { hash, tokenAddress: tokenAddress || undefined };
}

async function verifyTokenDeployment(tokenAddress: string, publicClient: any): Promise<boolean> {
  for (let i = 0; i < MAX_RETRIES; i++) {
    try {
      if (i > 0) {
        console.log(`🔄 Retrying token verification (attempt ${i + 1}/${MAX_RETRIES})...`);
        await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS));
      }

      const code = await publicClient.getCode({ address: tokenAddress as Address });
      if (code && code !== "0x") {
        console.log("✅ Token contract deployment verified!");
        console.log(`📏 Contract bytecode size: ${(code.length - 2) / 2} bytes`);
        return true;
      }
    } catch (error) {
      if (i === MAX_RETRIES - 1) {
        console.log("⚠️  Could not verify token contract deployment:", error);
      }
    }
  }

  return false;
}

// Main function
async function createToken() {
  // Validate environment
  const { privateKey, rpcUrl } = validateEnvironment();

  // Setup clients
  const { account, publicClient, walletClient } = setupClients(privateKey, rpcUrl);

  // Token configuration
  const config: TokenConfig = {
    name: "Test Token",
    symbol: "TEST",
    initialSupply: parseEther("100000"),
    minProceeds: parseEther("100"),
    maxProceeds: parseEther("10000"),
    auctionDurationDays: 3,
  };

  console.log("🚀 Creating token:", config.name);

  // Prepare all parameters
  const tokenFactoryData = prepareTokenParams(config);
  const governanceData = prepareGovernanceParams(config);

  // Set auction timing
  const fixedStartTime = Math.floor(Date.now() / 1000) + AUCTION_START_BUFFER;
  const auctionStart = fixedStartTime;
  const auctionEnd = auctionStart + config.auctionDurationDays * SECONDS_PER_DAY;

  console.log("⏰ Auction timing:", {
    auctionStart: new Date(auctionStart * 1000).toISOString(),
    auctionEnd: new Date(auctionEnd * 1000).toISOString(),
    duration: config.auctionDurationDays + " days",
  });

  const poolInitializerData = preparePoolInitializerParams(config, auctionStart, auctionEnd);

  // Mine valid salt
  const salt = await mineValidSalt(
    tokenFactoryData,
    poolInitializerData,
    config.initialSupply,
    config.initialSupply,
    "0x0000000000000000000000000000000000000000" as Address,
    publicClient,
  );

  const liquidityMigratorData = prepareLiquidityParams(account.address);

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
    // Execute token creation
    const { hash, tokenAddress } = await executeTokenCreation(
      createParams,
      account.address,
      publicClient,
      walletClient,
    );

    if (tokenAddress) {
      console.log("🎉 Token address:", tokenAddress);
      console.log("🔗 Basescan:", `https://sepolia.basescan.org/address/${tokenAddress}`);

      // Verify deployment
      const deploymentVerified = await verifyTokenDeployment(tokenAddress, publicClient);

      if (!deploymentVerified) {
        console.log("⚠️  Token address found but bytecode verification failed");
        console.log("💡 The token may still be valid - check the transaction link above");
      }

      await verifyTokenContract(tokenAddress, createParams, config);
    } else {
      console.log("⚠️  Could not extract token address from transaction logs");
      console.log("💡 You can find the token address by checking the transaction on BaseScan:");
      console.log(`🔗 Transaction: https://sepolia.basescan.org/tx/${hash}`);
    }

    return hash;
  } catch (error) {
    if (error instanceof TokenCreationError) {
      console.error(`❌ Token creation failed [${error.code}]:`, error.message);
    } else {
      console.error("❌ Token creation failed:", error);
    }
    throw error;
  }
}

// Execute the script
createToken().catch(console.error);
