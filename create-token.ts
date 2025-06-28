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
  Hash,
  keccak256,
  concat,
  pad,
  toHex,
} from "viem";
import { baseSepolia } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { readFileSync } from "fs";

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

  // Use block timestamp like the Forge test does
  const latestBlock = await publicClient.getBlock();
  const now = Number(latestBlock.timestamp);
  const auctionEnd = now + config.auctionDurationDays * 24 * 60 * 60;

  console.log("Auction timing:", {
    blockTimestamp: now,
    currentTime: Math.floor(Date.now() / 1000),
    auctionStart: now,
    auctionEnd: auctionEnd,
    duration: config.auctionDurationDays + " days",
  });

  const poolInitializerData = encodeAbiParameters(
    parseAbiParameters(
      "uint256, uint256, uint256, uint256, int24, int24, uint256, int24, bool, uint256, uint24, int24",
    ),
    [
      config.minProceeds,
      config.maxProceeds,
      BigInt(now),
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
    console.log("Estimating gas...");
    const gasEstimate = await publicClient.estimateContractGas({
      address: HOLOGRAPH_FACTORY,
      abi: HOLOGRAPH_FACTORY_ABI,
      functionName: "createToken",
      args: [createParams],
      account: account.address,
    });

    console.log("Submitting transaction...");
    const hash = await walletClient.writeContract({
      address: HOLOGRAPH_FACTORY,
      abi: HOLOGRAPH_FACTORY_ABI,
      functionName: "createToken",
      args: [createParams],
      gas: (gasEstimate * 120n) / 100n,
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

    if (receipt.status === "success") {
      console.log("✅ TOKEN CREATION SUCCESSFUL!");
      console.log("🎉 Transaction confirmed on block:", receipt.blockNumber);
      console.log("💰 Gas used:", receipt.gasUsed.toString());
      console.log("📝 Events emitted:", receipt.logs.length);
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
