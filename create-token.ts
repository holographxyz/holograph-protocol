/**
 * Holograph Token Creation Script with Automated Contract Verification
 *
 * Environment Variables Required:
 * - PRIVATE_KEY: Private key for the account creating tokens
 * - BASESCAN_API_KEY: API key for contract verification on Base Sepolia
 *   Get one at: https://basescan.org/apis
 *
 * Optional Environment Variables:
 * - ETHERSCAN_API_KEY: Alternative to BASESCAN_API_KEY
 * - BASE_SEPOLIA_RPC_URL: Custom RPC endpoint (uses public by default)
 *
 * Features:
 * ✅ Mines valid salt for Doppler deployment
 * ✅ Creates tokens through HolographFactory
 * ✅ Automatically verifies deployed DERC20 contracts
 * ✅ Provides Basescan links for easy access
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
  encodeFunctionData,
  Address,
  Hash,
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

// Contract addresses - Base Sepolia testnet
const HOLOGRAPH_FACTORY = "0x5290Bee84DC83AC667cF9573eC1edC6FE38eFe50" as const;

const DOPPLER_ADDRESSES = {
  airlock: "0x7E6cF695a8BeA4b2bF94FbB5434a7da3f39A2f8D",
  tokenFactory: "0xAd62fc9eEbbDC2880c0d4499B0660928d13405cE",
  governanceFactory: "0xff02a43A90c25941f8c5f4917eaD79EB33C3011C",
  v4Initializer: "0x511b44b4cC8Cb80223F203E400309b010fEbFAec",
  migrator: "0x8f4814999D2758ffA69689A37B0ce225C1eEcBFf",
  poolManager: "0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408",
  dopplerDeployer: "0x7980Be665C8011A413c598F82fa6f95feACa2e1e",
} as const;

// ABI for HolographFactory.createToken function
const HOLOGRAPH_FACTORY_ABI = [
  {
    type: "function",
    name: "createToken",
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
    outputs: [{ name: "asset", type: "address" }],
    stateMutability: "nonpayable",
  },
  {
    type: "event",
    name: "TokenLaunched",
    inputs: [
      { name: "asset", type: "address", indexed: true },
      { name: "salt", type: "bytes32", indexed: false },
    ],
  },
] as const;

// Hook flags - exact values from AirlockMiner.sol
const HOOK_FLAGS = {
  BEFORE_INITIALIZE_FLAG: 1n << 13n,
  AFTER_INITIALIZE_FLAG: 1n << 12n,
  BEFORE_ADD_LIQUIDITY_FLAG: 1n << 11n,
  BEFORE_SWAP_FLAG: 1n << 7n,
  AFTER_SWAP_FLAG: 1n << 6n,
  BEFORE_DONATE_FLAG: 1n << 5n,
} as const;

// Required flags - exact pattern from AirlockMiner.sol
const REQUIRED_FLAGS =
  HOOK_FLAGS.BEFORE_INITIALIZE_FLAG |
  HOOK_FLAGS.AFTER_INITIALIZE_FLAG |
  HOOK_FLAGS.BEFORE_ADD_LIQUIDITY_FLAG |
  HOOK_FLAGS.BEFORE_SWAP_FLAG |
  HOOK_FLAGS.AFTER_SWAP_FLAG |
  HOOK_FLAGS.BEFORE_DONATE_FLAG;

// Flag mask to check bottom 14 bits - from AirlockMiner.sol
const FLAG_MASK = 0x3fffn;

/**
 * Execute shell command and return promise
 */
function execCommand(command: string, args: string[], options: any = {}): Promise<string> {
  return new Promise((resolve, reject) => {
    const process = spawn(command, args, {
      stdio: ["pipe", "pipe", "pipe"],
      ...options,
    });

    let stdout = "";
    let stderr = "";

    process.stdout?.on("data", (data) => {
      stdout += data.toString();
    });

    process.stderr?.on("data", (data) => {
      stderr += data.toString();
    });

    process.on("close", (code) => {
      if (code === 0) {
        resolve(stdout);
      } else {
        reject(new Error(`Command failed with code ${code}\nstdout: ${stdout}\nstderr: ${stderr}`));
      }
    });
  });
}

/**
 * Verify contract using forge verify-contract
 */
async function verifyContract(
  contractAddress: string,
  contractPath: string,
  constructorArgs: string,
  chainId: number,
  apiKey: string,
): Promise<void> {
  console.log(`🔍 Verifying contract at ${contractAddress}...`);
  console.log(`📋 Constructor args: ${constructorArgs}`);

  try {
    const args = [
      "verify-contract",
      "--chain-id",
      chainId.toString(),
      "--constructor-args",
      constructorArgs,
      "--etherscan-api-key",
      apiKey,
      contractAddress,
      contractPath,
    ];

    console.log("🚀 Running forge verify-contract command...");
    console.log(`forge ${args.join(" ")}`);

    const result = await execCommand("forge", args, {
      cwd: process.cwd(),
    });

    console.log("✅ Contract verification successful!");
    console.log(result);
  } catch (error: any) {
    console.error("❌ Contract verification failed:");
    console.error(error.message);

    // Check if already verified
    if (error.message.includes("already verified") || error.message.includes("Contract source code already verified")) {
      console.log("ℹ️  Contract was already verified.");
      return;
    }

    throw error;
  }
}

/**
 * Extract token address from TokenLaunched event logs
 */
function extractTokenAddress(logs: any[]): string | null {
  for (const log of logs) {
    try {
      if (log.address.toLowerCase() === HOLOGRAPH_FACTORY.toLowerCase()) {
        const decoded = decodeEventLog({
          abi: HOLOGRAPH_FACTORY_ABI,
          data: log.data,
          topics: log.topics,
        });

        if (decoded.eventName === "TokenLaunched") {
          return decoded.args.asset as string;
        }
      }
    } catch (error) {
      // Skip logs that don't match our ABI
      continue;
    }
  }
  return null;
}

/**
 * Verify the DERC20 token contract with proper constructor arguments
 */
async function verifyTokenContract(tokenAddress: string, createParams: any, config: any): Promise<void> {
  console.log("🔍 Preparing DERC20 contract verification...");

  try {
    // Check if BASESCAN_API_KEY is available
    const apiKey = process.env.BASESCAN_API_KEY || process.env.ETHERSCAN_API_KEY;
    if (!apiKey) {
      console.log("⚠️  BASESCAN_API_KEY or ETHERSCAN_API_KEY not found in environment variables");
      console.log("💡 Add BASESCAN_API_KEY to your .env file to enable contract verification");
      return;
    }

    // Decode the tokenFactoryData to get the constructor arguments
    const [name, symbol, yearlyMintCap, vestingDuration, recipients, amounts, tokenURI] = decodeAbiParameters(
      parseAbiParameters("string, string, uint256, uint256, address[], uint256[], string"),
      createParams.tokenFactoryData,
    );

    // Construct the exact constructor arguments that were used to deploy DERC20
    // DERC20 constructor signature:
    // constructor(name_, symbol_, initialSupply, recipient, owner_, yearlyMintRate_, vestingDuration_, recipients_, amounts_, tokenURI_)
    const constructorArgs = encodeAbiParameters(
      parseAbiParameters("string, string, uint256, address, address, uint256, uint256, address[], uint256[], string"),
      [
        name, // name_
        symbol, // symbol_
        createParams.initialSupply, // initialSupply
        DOPPLER_ADDRESSES.airlock as Address, // recipient (airlock)
        DOPPLER_ADDRESSES.airlock as Address, // owner_ (airlock)
        yearlyMintCap, // yearlyMintRate_
        vestingDuration, // vestingDuration_
        recipients, // recipients_
        amounts, // amounts_
        tokenURI, // tokenURI_
      ],
    );

    console.log("📋 DERC20 Constructor Arguments:");
    console.log(`  - name: ${name}`);
    console.log(`  - symbol: ${symbol}`);
    console.log(`  - initialSupply: ${createParams.initialSupply.toString()}`);
    console.log(`  - recipient: ${DOPPLER_ADDRESSES.airlock}`);
    console.log(`  - owner: ${DOPPLER_ADDRESSES.airlock}`);
    console.log(`  - yearlyMintCap: ${yearlyMintCap.toString()}`);
    console.log(`  - vestingDuration: ${vestingDuration.toString()}`);
    console.log(`  - recipients: [${recipients.join(", ")}]`);
    console.log(`  - amounts: [${amounts.join(", ")}]`);
    console.log(`  - tokenURI: ${tokenURI}`);

    // Verify the DERC20 contract
    await verifyContract(
      tokenAddress,
      "lib/doppler/src/DERC20.sol:DERC20",
      constructorArgs,
      84532, // Base Sepolia chain ID
      apiKey,
    );

    console.log("🎉 Token contract verification completed!");
    console.log(`🔗 View verified contract: https://sepolia.basescan.org/address/${tokenAddress}#code`);
    console.log("");
    console.log("🎊 DEPLOYMENT SUMMARY:");
    console.log(`📍 Token Address: ${tokenAddress}`);
    console.log(`📛 Token Name: ${name}`);
    console.log(`🏷️  Token Symbol: ${symbol}`);
    console.log(`💰 Initial Supply: ${createParams.initialSupply.toString()}`);
    console.log(`✅ Contract Status: Verified on Basescan`);
    console.log(`🌐 Explorer: https://sepolia.basescan.org/address/${tokenAddress}`);
    console.log(`📄 Contract Code: https://sepolia.basescan.org/address/${tokenAddress}#code`);
  } catch (error: any) {
    console.error("❌ Token contract verification failed:");
    console.error(error.message);
    console.log("💡 You can manually verify the contract later using the displayed constructor arguments");
  }
}

/**
 * Compute CREATE2 address - exact implementation from AirlockMiner.sol
 */
function computeCreate2Address(salt: `0x${string}`, initCodeHash: `0x${string}`, deployer: Address): Address {
  const packed = concat(["0xff", deployer, salt, initCodeHash]);
  const hash = keccak256(packed);
  return `0x${hash.slice(-40)}` as Address;
}

/**
 * Load real compiled bytecode - exact method from working Forge test
 */
function getDopplerCreationCode(): `0x${string}` {
  try {
    const bytecode = readFileSync("lib/doppler/out/Doppler.sol/Doppler.bin", "utf8").trim();
    return `0x${bytecode}` as `0x${string}`;
  } catch (error) {
    throw new Error(`Could not load Doppler bytecode: ${error}`);
  }
}

function getDERC20CreationCode(): `0x${string}` {
  try {
    const bytecode = readFileSync("lib/doppler/out/DERC20.sol/DERC20.bin", "utf8").trim();
    return `0x${bytecode}` as `0x${string}`;
  } catch (error) {
    throw new Error(`Could not load DERC20 bytecode: ${error}`);
  }
}

/**
 * Mine valid salt - complete implementation from AirlockMiner.sol
 */
async function mineValidSalt(
  tokenFactoryData: `0x${string}`,
  poolInitializerData: `0x${string}`,
  initialSupply: bigint,
  numTokensToSell: bigint,
  numeraire: Address,
  publicClient: any,
): Promise<`0x${string}`> {
  console.log("Starting mining with AirlockMiner.sol algorithm...");

  // Decode poolInitializerData - exact pattern from AirlockMiner.sol
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

  // Compute Doppler initCodeHash - exact pattern from AirlockMiner.sol
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

  const dopplerBytecode = getDopplerCreationCode();
  const dopplerInitHash = keccak256(concat([dopplerBytecode, dopplerConstructorArgs]));

  // Decode tokenFactoryData - exact pattern from AirlockMiner.sol
  const [name, symbol, yearlyMintCap, vestingDuration, recipients, amounts, tokenURI] = decodeAbiParameters(
    parseAbiParameters("string, string, uint256, uint256, address[], uint256[], string"),
    tokenFactoryData,
  );

  const tokenConstructorArgs = encodeAbiParameters(
    parseAbiParameters("string, string, uint256, address, address, uint256, uint256, address[], uint256[], string"),
    [
      name,
      symbol,
      initialSupply,
      DOPPLER_ADDRESSES.airlock as Address,
      DOPPLER_ADDRESSES.airlock as Address,
      yearlyMintCap,
      vestingDuration,
      recipients,
      amounts,
      tokenURI,
    ],
  );

  const derc20Bytecode = getDERC20CreationCode();
  const tokenInitHash = keccak256(concat([derc20Bytecode, tokenConstructorArgs]));

  // Mine for valid salt - exact logic from AirlockMiner.sol
  for (let saltNum = 0; saltNum < 200_000; saltNum++) {
    if (saltNum % 10000 === 0) {
      console.log(`Mining progress: ${saltNum}/200,000`);
    }

    const salt = pad(toHex(saltNum), { size: 32 }) as `0x${string}`;

    // Compute CREATE2 addresses - exact addresses from AirlockMiner.sol
    const hookAddress = computeCreate2Address(salt, dopplerInitHash, DOPPLER_ADDRESSES.dopplerDeployer as Address);
    const assetAddress = computeCreate2Address(salt, tokenInitHash, DOPPLER_ADDRESSES.tokenFactory as Address);

    // Check hook flags - exact condition from AirlockMiner.sol
    const hookFlags = BigInt(hookAddress) & FLAG_MASK;
    if (hookFlags !== REQUIRED_FLAGS) {
      continue;
    }

    // Check if hook address has no code - exact condition from AirlockMiner.sol
    try {
      const code = await publicClient.getBytecode({ address: hookAddress });
      if (code && code !== "0x") {
        continue;
      }
    } catch {
      // Continue if we can't check bytecode
    }

    // Check token ordering - exact isToken0 logic from AirlockMiner.sol
    const assetBigInt = BigInt(assetAddress);
    const numeraireBigInt = BigInt(numeraire);
    const correctOrdering = isToken0 ? assetBigInt < numeraireBigInt : assetBigInt > numeraireBigInt;

    if (!correctOrdering) {
      continue;
    }

    console.log(`✅ Found valid salt: ${saltNum} (${salt})`);
    console.log(`Hook address: ${hookAddress}`);
    console.log(`Asset address: ${assetAddress}`);
    console.log(`Hook flags: 0x${hookFlags.toString(16)}`);

    return salt;
  }

  throw new Error("AirlockMiner: could not find salt");
}

async function createToken() {
  const privateKey = process.env.PRIVATE_KEY as `0x${string}`;
  if (!privateKey) {
    throw new Error("PRIVATE_KEY environment variable is required");
  }

  const account = privateKeyToAccount(privateKey);

  const publicClient = createPublicClient({
    chain: baseSepolia,
    transport: http(),
  });

  const walletClient = createWalletClient({
    account,
    chain: baseSepolia,
    transport: http(),
  });

  // Token configuration
  const config = {
    name: "Test Token",
    symbol: "TEST",
    initialSupply: parseEther("100000"),
    minProceeds: parseEther("100"),
    maxProceeds: parseEther("10000"),
    auctionDurationDays: 3,
  };

  console.log("Creating token:", config.name);

  // Encode factory data
  const tokenFactoryData = encodeAbiParameters(
    parseAbiParameters("string, string, uint256, uint256, address[], uint256[], string"),
    [config.name, config.symbol, 0n, 0n, [], [], ""],
  );

  const governanceData = encodeAbiParameters(parseAbiParameters("string, uint256, uint256, uint256"), [
    `${config.name} DAO`,
    7200n,
    50400n,
    0n,
  ]);

  // Set auction start time to be safely in the future to avoid InvalidStartTime()
  const latestBlock = await publicClient.getBlock();
  const blockTime = Number(latestBlock.timestamp);
  const auctionStart = blockTime + 300; // Start 5 minutes in the future
  const auctionEnd = auctionStart + config.auctionDurationDays * 24 * 60 * 60;

  console.log("Auction timing:", {
    blockTimestamp: blockTime,
    currentTime: Math.floor(Date.now() / 1000),
    auctionStart: auctionStart,
    auctionEnd: auctionEnd,
    duration: config.auctionDurationDays + " days",
    bufferSeconds: 300,
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
      6000, // startTick (int24)
      60000, // endTick (int24)
      400n, // epochLength (uint256)
      800, // gamma (int24)
      false, // isToken0 (bool)
      8n, // numSlices (uint256)
      3000, // fee (uint24)
      8, // tickSpacing (int24)
    ],
  );

  // Mine salt using complete AirlockMiner.sol algorithm
  const salt = await mineValidSalt(
    tokenFactoryData,
    poolInitializerData,
    config.initialSupply,
    config.initialSupply,
    "0x0000000000000000000000000000000000000000" as Address,
    publicClient,
  );
  console.log("Using mined salt:", salt);

  const createParams = {
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
    liquidityMigratorData: "0x" as `0x${string}`,
    integrator: "0x0000000000000000000000000000000000000000" as Address, // Set to zero like the test
    salt,
  };

  try {
    // Step 1: Simulate the contract call to catch revert reasons
    console.log("🔍 DEBUGGING: Simulating contract call to catch revert reasons...");
    try {
      const simulationResult = await publicClient.simulateContract({
        address: HOLOGRAPH_FACTORY,
        abi: HOLOGRAPH_FACTORY_ABI,
        functionName: "createToken",
        args: [createParams],
        account: account.address,
      });
      console.log("✅ Simulation successful, predicted result:", simulationResult.result);
    } catch (simulationError: any) {
      console.log("❌ SIMULATION FAILED - This reveals the revert reason:");
      console.log("Error name:", simulationError.name);
      console.log("Error message:", simulationError.message);
      console.log("Error shortMessage:", simulationError.shortMessage);

      if (simulationError.cause) {
        console.log("Error cause:", simulationError.cause);
      }

      if (simulationError.data) {
        console.log("Raw error data:", simulationError.data);
        const errorSignature = simulationError.data.slice(0, 10);
        console.log("Error signature:", errorSignature);

        // Common Holograph/Doppler error signatures
        const knownErrors = {
          "0xe65af6a0": "WrongModuleState(address)",
          "0x08c379a0": "Error(string)", // Standard revert reason
          "0x4e487b71": "Panic(uint256)", // Panic errors
          "0x875bfcd5": "HOLOGRAPH: module not found",
          "0x47da3b73": "HOLOGRAPH: operator not found",
          "0x8a4c79d2": "Airlock: wrong module state",
        };

        if (knownErrors[errorSignature as keyof typeof knownErrors]) {
          console.log("Known error type:", knownErrors[errorSignature as keyof typeof knownErrors]);
        }
      }

      // Show detailed error information
      console.log("Full simulation error object:", JSON.stringify(simulationError, null, 2));

      // This will help us understand the exact revert reason before proceeding
      throw new Error(`🚨 CONTRACT SIMULATION FAILED: ${simulationError.shortMessage || simulationError.message}`);
    }

    // Step 2: Debug parameter validation
    console.log("📋 DEBUGGING: Validating transaction parameters:");
    console.log("- Contract:", HOLOGRAPH_FACTORY);
    console.log("- Account:", account.address);
    console.log("- Salt:", createParams.salt);
    console.log("- TokenFactory:", createParams.tokenFactory);
    console.log("- GovernanceFactory:", createParams.governanceFactory);
    console.log("- PoolInitializer:", createParams.poolInitializer);
    console.log("- LiquidityMigrator:", createParams.liquidityMigrator);
    console.log("- Integrator:", createParams.integrator);
    console.log("- InitialSupply:", createParams.initialSupply.toString());
    console.log("- NumTokensToSell:", createParams.numTokensToSell.toString());
    console.log("- Numeraire:", createParams.numeraire);

    // Step 3: Verify contract states
    console.log("🔍 DEBUGGING: Checking contract states...");
    try {
      // Check if contracts exist
      const factoryCode = await publicClient.getBytecode({ address: HOLOGRAPH_FACTORY });
      const airlockCode = await publicClient.getBytecode({ address: DOPPLER_ADDRESSES.airlock as Address });
      const tokenFactoryCode = await publicClient.getBytecode({ address: DOPPLER_ADDRESSES.tokenFactory as Address });

      console.log("Contract bytecode lengths:");
      console.log("- HolographFactory:", factoryCode?.length || 0);
      console.log("- Doppler Airlock:", airlockCode?.length || 0);
      console.log("- Token Factory:", tokenFactoryCode?.length || 0);
    } catch (codeError) {
      console.log("Could not check contract bytecode:", codeError);
    }

    console.log("Estimating gas...");
    const gasEstimate = await publicClient.estimateContractGas({
      address: HOLOGRAPH_FACTORY,
      abi: HOLOGRAPH_FACTORY_ABI,
      functionName: "createToken",
      args: [createParams],
      account: account.address,
    });

    console.log("📊 Gas estimated:", gasEstimate.toString());

    // Step 4: Advanced debugging - check simulation vs execution timing
    console.log("🔍 DEBUGGING: Checking execution context differences...");
    const preExecutionBlock = await publicClient.getBlock();
    console.log("Pre-execution block:", {
      number: preExecutionBlock.number,
      timestamp: preExecutionBlock.timestamp,
      hash: preExecutionBlock.hash,
    });

    // Try static call with exact current block
    try {
      const staticCallResult = await publicClient.call({
        to: HOLOGRAPH_FACTORY,
        data: encodeFunctionData({
          abi: HOLOGRAPH_FACTORY_ABI,
          functionName: "createToken",
          args: [createParams],
        }),
        account: account.address,
        blockNumber: preExecutionBlock.number,
      });
      console.log("✅ Static call at current block succeeded:", staticCallResult);
    } catch (staticError: any) {
      console.log("❌ Static call failed:", staticError.message);
      console.log("This suggests the issue happens at execution time!");
    }

    console.log("Submitting transaction with extra gas buffer...");
    const hash = await walletClient.writeContract({
      address: HOLOGRAPH_FACTORY,
      abi: HOLOGRAPH_FACTORY_ABI,
      functionName: "createToken",
      args: [createParams],
      gas: gasEstimate * 2n, // Double the gas to rule out gas issues
    });

    console.log("Transaction hash:", hash);
    console.log("Explorer:", `https://sepolia.basescan.org/tx/${hash}`);

    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    console.log("Transaction receipt:", {
      status: receipt.status,
      blockNumber: receipt.blockNumber,
      gasUsed: receipt.gasUsed.toString(),
      logs: receipt.logs.length,
    });

    // Step 5: Debug why it reverted - check if computed addresses already exist
    if (receipt.status === "reverted") {
      console.log("🔍 DEBUGGING: Checking if computed addresses already exist...");

      // Get the mined addresses for debugging
      const saltUsed = createParams.salt;
      console.log("Salt used:", saltUsed);

      // Get the mined hook and token addresses
      const tokenFactoryData = createParams.tokenFactoryData;
      const poolInitializerData = createParams.poolInitializerData;

      try {
        // Simulate again at the actual transaction block to see the difference
        const actualBlock = await publicClient.getBlock({ blockNumber: receipt.blockNumber });
        console.log("Actual transaction block:", {
          number: actualBlock.number,
          timestamp: actualBlock.timestamp,
          hash: actualBlock.hash,
        });

        // Try simulation at the actual block
        try {
          const simulationAtTxBlock = await publicClient.simulateContract({
            address: HOLOGRAPH_FACTORY,
            abi: HOLOGRAPH_FACTORY_ABI,
            functionName: "createToken",
            args: [createParams],
            account: account.address,
            blockNumber: receipt.blockNumber,
          });
          console.log("✅ Simulation at tx block succeeded:", simulationAtTxBlock.result);
        } catch (txBlockError: any) {
          console.log("❌ Simulation at tx block failed:", txBlockError.shortMessage);
          console.log("This confirms the state changed between simulation and execution!");

          if (txBlockError.data) {
            const errorSignature = txBlockError.data.slice(0, 10);
            console.log("Error signature at tx block:", errorSignature);

            // Check for common deployment conflicts
            if (errorSignature === "0xe65af6a0") {
              console.log("🚨 LIKELY CAUSE: Another transaction used the same salt!");
              console.log("The computed hook/token addresses already exist.");
            }
          }
        }
      } catch (debugError) {
        console.log("Debug error:", debugError);
      }
    }

    if (receipt.status === "success") {
      console.log("✅ TOKEN CREATION SUCCESSFUL!");
      console.log("🎉 Transaction confirmed on block:", receipt.blockNumber);
      console.log("💰 Gas used:", receipt.gasUsed.toString());
      console.log("📝 Events emitted:", receipt.logs.length);

      // Extract token address from TokenLaunched event logs
      const tokenAddress = extractTokenAddress(receipt.logs);
      if (tokenAddress) {
        console.log("🎉 Token address:", tokenAddress);
        console.log("🔗 Basescan:", `https://sepolia.basescan.org/address/${tokenAddress}`);

        // Verify the DERC20 token contract
        await verifyTokenContract(tokenAddress, createParams, config);
      } else {
        console.log("⚠️  Could not extract token address from transaction logs");
      }

      return hash;
    } else {
      console.log("❌ Transaction reverted on chain");

      // Get transaction details to understand the revert
      try {
        const tx = await publicClient.getTransaction({ hash });
        console.log("Transaction details:", {
          from: tx.from,
          to: tx.to,
          value: tx.value.toString(),
          gas: tx.gas.toString(),
          gasPrice: tx.gasPrice?.toString(),
          blockNumber: tx.blockNumber,
        });
      } catch (e) {
        console.log("Could not fetch transaction details:", e);
      }

      throw new Error(`Transaction failed with status: ${receipt.status}`);
    }
  } catch (error) {
    console.error("❌ Token creation failed:", error);
    throw error;
  }
}

// Run the script
createToken().catch(console.error);
