import { Contract, Signer, ethers } from 'ethers';
import { LedgerSigner } from '@anders-t/ethers-ledger';
import { JsonRpcProvider, TransactionReceipt, TransactionResponse } from '@ethersproject/providers';
import { parsedEnv } from './env.validation';

require('dotenv').config();

/**
 * WARNING:
 * This feature is still a work in progress and is not yet ready for testing.
 */

/**
 * Check out the README file
 */
async function main() {
  /*
   * STEP 1: LOAD SENSITIVE INFORMATION SAFELY
   */

  const privateKey = parsedEnv.PRIVATE_KEY;
  const providerURL = parsedEnv.CUSTOM_ERC721_PROVIDER_URL;
  const isHardwareWalletEnabled = parsedEnv.HARDWARE_WALLET_ENABLED;

  const provider: JsonRpcProvider = new JsonRpcProvider(providerURL);

  let deployer: Signer;
  if (isHardwareWalletEnabled) {
    deployer = new LedgerSigner(provider, "44'/60'/0'/0/0");
  } else {
    deployer = new ethers.Wallet(privateKey, provider);
  }

  /*
   * STEP 2: SET HARDCODED VALUES
   */

  const contractAddress = '';
  const newOwner = '';

  /*
   * STEP 3: UPDATE OWNER
   */

  const countdownERC721ABI = [
    'function setOwner(address ownerAddress) public',
    'function owner() view returns (address)',
  ];
  const countdownErc721Contract = new Contract(contractAddress, countdownERC721ABI, deployer);

  console.log('---> Before:');
  let owner = await countdownErc721Contract.owner();
  console.log(`- owner(): ${owner}`);

  console.log(`\n---> Setting the owner to ${newOwner}`);
  let tx: TransactionResponse;
  try {
    tx = await countdownErc721Contract.setOwner(newOwner);
  } catch (error) {
    throw new Error(`Failed to create transaction.`, { cause: error });
  }

  console.log('\nTransaction:', tx.hash);
  const receipt: TransactionReceipt = await tx.wait();

  if (receipt?.status !== 1) {
    throw new Error('Failed to confirm the transaction.');
  }

  console.log('\n---> After:');
  owner = await countdownErc721Contract.owner();
  console.log(`- owner(): ${owner}`);

  console.log(`The transaction was executed successfully! Exiting script ✅\n`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
