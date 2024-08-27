import { ethers, Contract, Signer } from 'ethers';
import { Environment } from '@holographxyz/environment';
import { JsonRpcProvider, Log } from '@ethersproject/providers';
import { TransactionReceipt, TransactionResponse } from '@ethersproject/abstract-provider';

import { DeploymentConfigSettings, Hex } from './types';
import { getHolographAddress } from '../utils/utils';

export async function getFactoryAddress(provider: JsonRpcProvider, environment: Environment): Promise<Hex> {
  const getFactoryABI = ['function getFactory() view returns (address factory)'];
  const holograph = new Contract(getHolographAddress(environment), getFactoryABI, provider);
  try {
    const factoryProxyAddress: string = await holograph.getFactory();
    return factoryProxyAddress.toLowerCase() as Hex;
  } catch (error) {
    throw new Error(`Failed to get HolographFactory address.`, { cause: error });
  }
}

export async function getRegistryAddress(provider: JsonRpcProvider, environment: Environment): Promise<Hex> {
  const getRegistryABI = ['function getRegistry() view returns (address registry)'];
  const holograph = new Contract(getHolographAddress(environment), getRegistryABI, provider);
  try {
    const registryProxyAddress: string = await holograph.getRegistry();
    return registryProxyAddress.toLowerCase() as Hex;
  } catch (error) {
    throw new Error(`Failed to get HolographRegistry address.`, { cause: error });
  }
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
