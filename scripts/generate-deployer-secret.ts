import { ethers } from 'ethers';
require('dotenv').config();

/**
 * This script generates a secret hash for deployer NFTs.
 * Usage: `npx ts-node scripts/generate-deployer-secret.ts`
 */
async function main() {
  const secretString = process.env.DEPLOYER_SECRET;

  console.log(`Generating secret hash...`);
  if (!secretString) {
    throw new Error(`Secret is required`);
  }

  const hashedString = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(secretString));
  const bytes20Hash = hashedString.slice(0, 42); // 2 characters for '0x' and 40 characters for 20 bytes
  console.log(`Secret: ${secretString} = Hash: ${bytes20Hash}`);
}

main();
