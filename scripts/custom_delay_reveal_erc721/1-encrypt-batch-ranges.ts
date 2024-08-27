import yargs from 'yargs/yargs';
import { ethers } from 'ethers';
import { hideBin } from 'yargs/helpers';
import { JsonRpcProvider } from '@ethersproject/providers';

import { deleteCSVFile, encryptDecrypt, readCsvFile, writeCSVFile } from './utils';
import { FileColumnsSchema, FileColumnsType, parseFileContent, parsedEnv } from './validations';

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
    })
    .parseSync();

  const { file } = args as { file: string };

  /*
   * STEP 1: LOAD SENSITIVE INFORMATION SAFELY
   */

  const providerURL = parsedEnv.CUSTOM_ERC721_PROVIDER_URL;

  const provider: JsonRpcProvider = new JsonRpcProvider(providerURL);
  const chainId: number = await provider.getNetwork().then((network: any) => network.chainId);

  /*
   * STEP 2: CSV FILE VALIDATION
   */

  const csvData = await readCsvFile(file);

  const parsedRows: FileColumnsType[] = await parseFileContent(csvData);

  deleteCSVFile(file);
  writeCSVFile(file, Object.keys(FileColumnsSchema.shape).join(','));

  console.log(`Generating provenance hash and encrypting URIs...`);
  for (let parsedRow of parsedRows) {
    if (!parsedRow.EncryptedURI || !parsedRow.ProvenanceHash) {
      parsedRow.ProvenanceHash = ethers.utils.keccak256(
        ethers.utils.solidityPack(['string', 'bytes', 'uint256'], [parsedRow['RevealURI Path'], parsedRow.Key, chainId])
      );
      parsedRow.EncryptedURI = encryptDecrypt(parsedRow['RevealURI Path'], parsedRow.Key);
      const data = Object.values(parsedRow).join(',');
      writeCSVFile(file, data);
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
