import yargs from 'yargs/yargs';
import { Contract, Signer, ethers } from 'ethers';
import { hideBin } from 'yargs/helpers';
import { LedgerSigner } from '@anders-t/ethers-ledger';
import { JsonRpcProvider, Log, TransactionReceipt, TransactionResponse } from '@ethersproject/providers';

import { readCsvFile } from './utils';
import { FileColumnsType, parseFileContent, parsedEnv } from './validations';

require('dotenv').config();

/**
 * Check out the README file
 */

async function main() {
  const args = yargs(hideBin(process.argv))
    .options({
      file: {
        type: 'string',
        description: 'reveal csv file',
        alias: 'file',
      },
      contractAddress: {
        type: 'string',
        description: 'contract address',
        alias: 'address',
      },
    })
    .parseSync();

  const { file, contractAddress } = args as { file: string; contractAddress: string };

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
   * STEP 2: READ CSV FILE
   */

  const csvData = await readCsvFile(file);

  const parsedRows: FileColumnsType[] = await parseFileContent(csvData);

  /*
   * STEP 3: Batch Reveal
   */

  console.log(`Start reveal...`);
  for (let parsedRow of parsedRows) {
    if (parsedRow['Should Decrypt']) {
      const customERC721RevealABI = [
        'function reveal(uint256 _index, bytes calldata _key) public  returns (string revealedURI)',
      ];
      const customErc721Contract = new Contract(contractAddress, customERC721RevealABI, deployer);

      let tx: TransactionResponse;
      try {
        tx = await customErc721Contract.reveal(parsedRow.BatchId, parsedRow.Key);
      } catch (error) {
        throw new Error(`Failed to create reveal transaction.`, { cause: error });
      }

      console.log('Transaction:', tx.hash);
      const receipt: TransactionReceipt = await tx.wait();

      if (receipt?.status === 1) {
        console.log('The transaction was executed successfully! Getting the contract address from logs... ');

        const tokenURIRevealedTopic = '0x'; //TODO: get topic for TokenURIRevealed event
        const tokenURIRevealedLog: Log | undefined = receipt.logs.find(
          (log: Log) => log.topics[0] === tokenURIRevealedTopic
        );

        if (tokenURIRevealedLog) {
          const batchId = tokenURIRevealedLog.topics[1];
          const revealedURI = tokenURIRevealedLog.topics[2];

          console.log(`Successfully revealed Batch ID ${batchId}. URI: ${revealedURI}`);
        } else {
          throw new Error('Failed to extract transfer event from transaction receipt.');
        }
      } else {
        throw new Error('Failed to confirm the transaction.');
      }
    }
  }

  console.log(`Exiting script ✅\n`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
