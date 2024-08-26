import path from 'path';
import { parse } from 'csv-parse';
import { Contract, ethers, Signer } from 'ethers';
import { Log } from '@ethersproject/providers';
import { appendFileSync, createReadStream, existsSync, unlinkSync } from 'fs';
import { TransactionReceipt, TransactionResponse } from '@ethersproject/abstract-provider';

import { DeploymentConfigSettings, Hex } from './types';

export const writeCSVFile = (filePath: string, data: string, breakLine = true) => {
  try {
    appendFileSync(`${filePath}`, breakLine ? data + '\n' : data);
  } catch (err) {
    console.error(err);
  }
};

export const deleteCSVFile = (filePath: string) => {
  try {
    const path = `${filePath}`;
    if (existsSync(path)) {
      unlinkSync(path);
    }
  } catch (err) {
    console.error(err);
  }
};

export async function readCsvFile(filePath: string): Promise<string[][]> {
  const records: any[] = [];
  const extension = path.extname(filePath);

  if (extension !== '.csv') {
    throw new Error('The file is not a CSV file.');
  }

  return new Promise((resolve) => {
    createReadStream(`${filePath}`)
      .pipe(parse({ delimiter: ',' }))
      .on('data', (data: any) => {
        records.push(data);
      })
      .on('end', () => {
        resolve(records);
      });
  });
}

/**
 * Encrypts or decrypts the given URL using the provided key (Replicate the behavior of DelayedReveal.sol::encryptDecrypt function)
 * @param url The URL to encrypt or decrypt
 * @param hexKey The key to use for encryption or decryption
 * @returns The encrypted or decrypted URL
 */
export function encryptDecrypt(url: string, hexKey: string): string {
  const encoder = new TextEncoder();
  const data = encoder.encode(url);
  const key = ethers.utils.arrayify(hexKey);

  const length = data.length;
  const result = new Uint8Array(length);

  for (let i = 0; i < length; i += 32) {
    const segmentLength = Math.min(32, length - i);
    const indexBytes = ethers.utils.zeroPad(ethers.utils.arrayify(i), 32); // Padding the index to 32 bytes
    const keySegment = ethers.utils.concat([key, indexBytes]); // Concatenating key and padded index

    const hash = ethers.utils.arrayify(ethers.utils.keccak256(keySegment));

    for (let j = 0; j < segmentLength; j++) {
      result[i + j] = data[i + j] ^ hash[j % 32];
    }
  }

  return ethers.utils.hexlify(result);
}

export async function deployHolographableContract(
  deployer: Signer,
  factoryProxyAddress: Hex,
  fullDeploymentConfig: DeploymentConfigSettings
): Promise<Hex> {
  const holographFactoryABI = [
    'function deployHolographableContract(tuple(bytes32 contractType, uint32 chainType, bytes32 salt, bytes byteCode, bytes initCode) config, tuple(bytes32 r, bytes32 s,uint8 v) signature,address signer) public',
  ];
  const contract = new Contract(factoryProxyAddress, holographFactoryABI, deployer);

  console.log('Calling deployHolographableContract...');

  let tx: TransactionResponse;
  try {
    tx = await contract.deployHolographableContract(
      fullDeploymentConfig.config,
      fullDeploymentConfig.signature,
      fullDeploymentConfig.signer
    );
  } catch (error) {
    throw new Error(`Failed to deploy the contract.`, { cause: error });
  }

  console.log('Transaction:', tx.hash);
  const receipt: TransactionReceipt = await tx.wait();

  if (receipt?.status === 1) {
    console.log('The transaction was executed successfully! Getting the contract address from logs... ');

    const bridgeableContractDeployedTopic = '0xa802207d4c618b40db3b25b7b90e6f483e16b2c1f8d3610b15b345a718c6b41b';
    const bridgeableContractDeployedLog: Log | undefined = receipt.logs.find(
      (log: Log) => log.topics[0] === bridgeableContractDeployedTopic
    );

    if (bridgeableContractDeployedLog) {
      const deploymentAddress = bridgeableContractDeployedLog.topics[1];
      return ethers.utils.getAddress(`0x${deploymentAddress.slice(26)}`).toLowerCase() as Hex;
    } else {
      throw new Error('Failed to extract transfer event from transaction receipt.');
    }
  } else {
    throw new Error('Failed to confirm the transaction.');
  }
}
