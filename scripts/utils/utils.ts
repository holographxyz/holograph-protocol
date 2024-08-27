import { Hex } from '../custom_delay_reveal_erc721/types';
import { hexlify, zeroPad } from '@ethersproject/bytes';
import { Contract, ethers } from 'ethers';
import { Environment } from '@holographxyz/environment';
import { JsonRpcProvider } from '@ethersproject/providers';

export function flattenObject(obj: Record<string, any>): any[] {
  return Object.values(obj).map((value: any) => {
    if (typeof value === 'object') {
      if (Array.isArray(value)) {
        value.map((item) => flattenObject(item));
      }
      return flattenObject(value); // Recursively flatten nested objects
    }
    return value;
  });
}

export function parseBytes(str: string, size = 32): Hex {
  return hexlify(zeroPad(ethers.utils.toUtf8Bytes(str), size)) as Hex;
}

export function generateRandomSalt() {
  return '0x' + Date.now().toString(16).padStart(64, '0');
}

export function destructSignature(signedMessage: Hex) {
  return {
    r: ('0x' + signedMessage.substring(2, 66)) as Hex,
    s: ('0x' + signedMessage.substring(66, 130)) as Hex,
    v: ('0x' + signedMessage.substring(130, 132)) as Hex,
  };
}

export function getHolographAddress(environment: Environment) {
  const HOLOGRAPH_ADDRESSES: { [key in Environment]: string } = {
    [Environment.localhost]: '0x17253175f447ca4B560a87a3F39591DFC7A021e3'.toLowerCase(),
    [Environment.experimental]: '0x199728d88a68856868f50FC259F01Bb4D2672Da9'.toLowerCase(),
    [Environment.develop]: '0x11bc5912f9ed5E16820f018692f8E7FDA91a8529'.toLowerCase(),
    [Environment.testnet]: '0x1Ed99DFE7462763eaF6925271D7Cb2232a61854C'.toLowerCase(),
    [Environment.mainnet]: '0x1Ed99DFE7462763eaF6925271D7Cb2232a61854C'.toLowerCase(),
  };

  return HOLOGRAPH_ADDRESSES[environment];
}

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
