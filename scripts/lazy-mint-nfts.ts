import { ethers } from 'ethers';
import * as dotenv from 'dotenv';
import * as fs from 'fs';
import * as path from 'path';

import { LedgerSigner } from '@anders-t/ethers-ledger';
import { encryptDecrypt } from './custom_delay_reveal_erc721/utils';
dotenv.config();

async function main() {
  // Check for required environment variables
  if (process.env.PRIVATE_KEY === undefined) throw new Error(`PRIVATE_KEY environment variable is required`);
  if (process.env.AMOUNT_TO_LAZY_MINT === undefined)
    throw new Error(`AMOUNT_TO_LAZY_MINT environment variable is required`);
  if (process.env.PLACEHOLDER_URI_FOR_TOKENS === undefined)
    throw new Error(`PLACEHOLDER_URI_FOR_TOKENS environment variable is required`);
  if (process.env.REVEALED_URI === undefined) throw new Error(`REVEALED_URI environment variable is required`);
  if (process.env.SECRET_KEY === undefined) throw new Error(`SECRET_KEY environment variable is required`);

  // Setup the path to the contract artifact
  const artifactPath = path.join(__dirname, '../artifacts/src/token/CustomERC721.sol/CustomERC721.json');

  // Read the contract artifact
  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));

  // Extract the ABI from the artifact
  const contractABI = artifact.abi;

  // Load sensitive information safely
  const privateKey = process.env.PRIVATE_KEY as string;
  const contractAddress = '';
  const providerURL = '';

  // Setup ethers provider
  const provider = new ethers.providers.JsonRpcProvider(providerURL);

  let signer;
  if (process.env.HARDWARE_WALLET_ENABLED === 'true') {
    signer = new LedgerSigner(provider, "44'/60'/0'/0/0");
  } else {
    signer = new ethers.Wallet(privateKey, provider);
  }

  const contract = new ethers.Contract(contractAddress, contractABI, signer);

  // LazyMint parameters
  const amount = process.env.AMOUNT_TO_LAZY_MINT as string;
  const placeholderURIForTokens = process.env.PLACEHOLDER_URI_FOR_TOKENS as string;
  const revealedUri = process.env.REVEALED_URI as string;

  const encryptedURI = encryptDecrypt(process.env.REVEALED_URI, process.env.SECRET_KEY);

  // abi.encodePacked(revealedURI, _key, block.chainid)
  const provenanceHash = ethers.utils.keccak256(
    ethers.utils.solidityPack(
      ['string', 'bytes', 'uint256'],
      [revealedUri, process.env.SECRET_KEY, await provider.getNetwork().then((network) => network.chainId)]
    )
  );

  console.log(`=========== Input data ============`);
  console.log(`\x1b[34mAmount to mint\x1b[0m: \x1b[36m${amount}\x1b[0m`);
  console.log(`\x1b[34mPlaceholder URI\x1b[0m: \x1b[36m${placeholderURIForTokens}\x1b[0m`);
  console.log(`\x1b[34mRevealed URI\x1b[0m: \x1b[36m${revealedUri}\x1b[0m`);
  console.log(`========== Computed data ==========`);
  console.log(`\x1b[32mEncrypted URI\x1b[0m: \x1b[33m${encryptedURI}\x1b[0m`);
  console.log(`\x1b[32mProvenance hash\x1b[0m: \x1b[33m${provenanceHash}\x1b[0m`);
  console.log(`===================================`);

  // Encode _data parameter
  const data = ethers.utils.defaultAbiCoder.encode(
    ['bytes', 'bytes32'],
    [ethers.utils.toUtf8Bytes(encryptedURI), provenanceHash]
  );

  // Call lazyMint
  const tx = await contract.lazyMint(amount, placeholderURIForTokens, data);
  console.log(`Transaction hash: ${tx.hash}`);

  // Wait for the transaction to be mined
  const receipt = await tx.wait();
  console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
