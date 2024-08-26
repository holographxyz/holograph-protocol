import {
  Contract,
  Signer,
  ethers,
  JsonRpcProvider,
  TransactionReceipt,
  TransactionResponse,
  Interface,
  getAddress,
} from 'ethers-v6';
import yargs from 'yargs/yargs';
import { hideBin } from 'yargs/helpers';
import { SafeTransactionOptionalProps } from '@safe-global/protocol-kit';
import { MetaTransactionData } from '@safe-global/safe-core-sdk-types';
import Safe, { EthersAdapter } from '@safe-global/protocol-kit';
import SafeApiKit from '@safe-global/api-kit';

import { parsedEnv } from './env.validation';
import { MetadataParams } from './types';
import { flattenObject } from '../utils/utils';

require('dotenv').config();

/**
 * Check out the README file
 */

async function main() {
  const args = yargs(hideBin(process.argv))
    .options({
      safe: {
        type: 'boolean',
        description: 'Using Safe wallet',
        alias: 'safe',
        default: false,
      },
    })
    .parseSync();

  const { safe } = args as { safe: boolean };

  /*
   * STEP 1: LOAD SENSITIVE INFORMATION SAFELY
   */

  const privateKey = parsedEnv.PRIVATE_KEY;
  const providerURL = parsedEnv.CUSTOM_ERC721_PROVIDER_URL;

  const provider: JsonRpcProvider = new JsonRpcProvider(providerURL);

  let deployer: Signer = new ethers.Wallet(privateKey, provider);

  const deployerAddress = await deployer.getAddress();

  const chainId = (await provider.getNetwork()).chainId;

  /*
   * STEP 2: SET HARDCODED VALUES
   */

  let safeAddress = ''; // [OPTIONAL]: Only if the Safe wallet is going to be used
  const contractAddress = getAddress('');

  const params: MetadataParams = {
    name: 'NewCountdownERC721',
    description: 'Description of the token',
    imageURI: 'ar://o8eyC27OuSZF0z-zIen5NTjJOKTzOQzKJzIe3F7Lmg0/1.png',
    animationURI: 'ar://animationUriHere',
    externalUrl: 'https://your-nft-project.com',
    encryptedMediaUrl: 'ar://encryptedMediaUriHere',
    decryptionKey: 'decryptionKeyHere',
    hash: 'uniqueNftHashHere',
    decryptedMediaUrl: 'ar://decryptedMediaUriHere',
    tokenOfEdition: 0,
    editionSize: 0,
  };

  /*
   * STEP 3: CREATE THE TX
   */

  const countdownERC721ABI = [
    'function setMetadataParams(tuple(string,string,string,string,string,string,string,string,string,uint256,uint256) params) external',
  ];

  if (safe) {
    await executeMultisigSetMetadataParams();
  } else {
    await executeSetMetadataParams();
  }

  console.log(`The transaction was executed successfully! Exiting script ✅\n`);

  /*
   *
   *
   * Functions implementations:
   *
   *
   */

  async function executeSetMetadataParams() {
    if (!safeAddress) {
      throw new Error('To use the safe wallet, the "safeAddress" must be filled!');
    }

    safeAddress = getAddress(safeAddress);

    const countdownErc721Contract = new Contract(contractAddress, countdownERC721ABI, deployer);

    let tx: TransactionResponse;
    try {
      tx = await countdownErc721Contract.setMetadataParams(flattenObject(params));
    } catch (error) {
      throw new Error(`Failed to create transaction.`, { cause: error });
    }

    console.log('Transaction:', tx.hash);
    const receipt: TransactionReceipt | null = await tx.wait();

    if (receipt?.status !== 1) {
      throw new Error('Failed to confirm the transaction.');
    }
  }

  async function executeMultisigSetMetadataParams() {
    const ethAdapter = new EthersAdapter({
      ethers,
      signerOrProvider: deployer,
    });

    const safeService = new SafeApiKit({ chainId });

    const safeSdk = await Safe.create({ ethAdapter, safeAddress });

    let iface = new Interface(countdownERC721ABI);

    const data = iface.encodeFunctionData('setMetadataParams', [flattenObject(params)]);

    const transactions: MetaTransactionData[] = [
      {
        to: contractAddress,
        value: '0',
        data,
      },
    ];

    const options: SafeTransactionOptionalProps = {
      safeTxGas: undefined, // Optional
      baseGas: undefined, // Optional
      gasPrice: undefined, // Optional
      gasToken: undefined, // Optional
      refundReceiver: undefined, // Optional
      nonce: undefined, // Optional
    };

    const safeTransaction = await safeSdk.createTransaction({ transactions, options });

    console.log('Transaction Request:', safeTransaction);

    const nonce = await safeService.getNextNonce(safeAddress); // This method takes all queued/pending transactions into account when calculating the next nonce, creating a unique one for all different transactions.

    const safeTxHash = await safeSdk.getTransactionHash(safeTransaction);
    const senderSignature = await safeSdk.signHash(safeTxHash);

    console.log('Sending transaction to approving queue...');
    try {
      await safeService.proposeTransaction({
        safeAddress,
        safeTransactionData: safeTransaction.data,
        safeTxHash,
        senderAddress: deployerAddress,
        senderSignature: senderSignature.data,
        origin: 'setMetadataParams script',
      });
    } catch (error) {
      throw new Error(`Failed to send transaction to the approving queue.`, { cause: error });
    }

    console.log('Transaction successfully sent to the approving queue! Please review it.');
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
