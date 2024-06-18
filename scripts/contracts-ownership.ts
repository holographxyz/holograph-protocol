import { Network, networks } from '@holographxyz/networks';
import { ethers } from 'ethers';
import * as fs from 'fs';
import * as path from 'path';

import { hTokenAddresses } from './utils/addresses';

const CONTRACTS = [
  'Holograph',
  'HolographBridge',
  'HolographFactory',
  'HolographInterfaces',
  'HolographOperator',
  'HolographRegistry',
  'HolographTreasury',
  'LayerZeroModule',
  'hToken',
];

const TOKENS = ['hETH', 'hBNB', 'hAVAX', 'hMATIC', 'hMNT'];

const BASE_DIR = '../deployments/mainnet';

async function getContractAdmin(contract: string, network: Network) {
  try {
    const file = path.join(__dirname, BASE_DIR, network.key, `${contract}.json`);
    const contractData = JSON.parse(fs.readFileSync(file, 'utf8'));
    const provider = new ethers.providers.JsonRpcProvider(network.rpc);
    const contractInstance = new ethers.Contract(contractData.address, contractData.abi, provider);
    const admin = (await contractInstance?.getAdmin?.()) || (await contractInstance?.owner?.());

    return {
      admin,
      contract,
      network: network.name,
    };
  } catch {
    return {
      contract,
      network: network.name,
      error: true,
    };
  }
}

async function main() {
  const baseDir = path.join(__dirname, BASE_DIR);
  const deployedNetworks = fs.readdirSync(baseDir)?.map((network) => networks[network]);
  console.log('------------------ Admin Data ------------------');

  const results = await Promise.all(
    CONTRACTS.map(
      async (contract) => await Promise.all(deployedNetworks.map((network) => getContractAdmin(contract, network)))
    )
  );

  const sortedResults = results?.flat()?.sort((a, b) => (a?.network! > b?.network! ? 1 : -1));
  sortedResults?.forEach((result) => {
    if (!result?.error) console.log(`(${result?.network}) ${result?.contract}: ${result?.admin}`);
    else console.log(`(${result?.network}) Error fetching ${result?.contract} admin`);
  });

  for (const token of TOKENS) {
    const address = hTokenAddresses?.mainnet[token as 'hETH' | 'hBNB' | 'hAVAX' | 'hMATIC' | 'hMNT'];

    const contractInstance = new ethers.Contract(
      address!,
      ['function getAdmin() public view returns (address)'],
      new ethers.providers.JsonRpcProvider(networks.ethereum.rpc)
    );
    const admin = (await contractInstance?.getAdmin?.()) || (await contractInstance?.owner?.());
    console.log(`${token}: ${admin}`);
  }

  console.log('------------------------------------------------');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
