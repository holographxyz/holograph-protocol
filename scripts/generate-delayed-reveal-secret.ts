import { ethers } from 'ethers';
require('dotenv').config();

/**
 * This script generates a secret hash for delayed reveal NFTs.
 * Usage: `npx ts-node scripts/generate-delayed-reveal-secret.ts`
 */
async function main() {
  if (process.env.SECRET_PREFIX === undefined) throw new Error(`SECRET_PREFIX environment variable is required`);
  if (process.env.CHAIN_ID === undefined) throw new Error(`CHAIN_ID environment variable is required`);
  if (process.env.CONTRACT_ADDRESS === undefined) throw new Error(`CONTRACT_ADDRESS environment variable is required`);
  if (process.env.ID_FOR_DELAYED_REVEAL_NFTS === undefined)
    throw new Error(`ID_FOR_DELAYED_REVEAL_NFTS environment variable is required`);

  const prefix = process.env.SECRET_PREFIX;
  const chainId = process.env.CHAIN_ID;
  const contractAddress = process.env.CONTRACT_ADDRESS;
  const idForDelayedRevealNFTs = process.env.ID_FOR_DELAYED_REVEAL_NFTS;

  console.log(`Generating secret hash...`);

  // Concatenate all parts into a single string, assuming these values are strings
  const secretString = `${prefix},${chainId},${contractAddress},${idForDelayedRevealNFTs}`;

  // Convert the concatenated string to bytes and hash it
  const hashedString = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(secretString));

  console.log(`Secret string: ${secretString}`);
  console.log(`Secret string hash: ${hashedString}`);
}

main();
