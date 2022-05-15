import Web3 from 'web3';
import { BytesLike, ContractFactory, Contract } from 'ethers';
import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const generateInitCode = function (vars: string[], vals: any[]): string {
  const web3 = new Web3();
  return web3.eth.abi.encodeParameters(vars, vals);
};

const generateDeployCode = function (salt: string, byteCode: string, initCode: string): string {
  const web3 = new Web3();
  return web3.eth.abi.encodeFunctionCall(
    {
      name: 'deploy',
      type: 'function',
      inputs: [
        {
          type: 'bytes12',
          name: 'saltHash'
        },
        {
          type: 'bytes',
          name: 'sourceCode'
        },
        {
          type: 'bytes',
          name: 'initCode'
        },
      ]
    },
    [
      salt, // bytes12 sourceCode
      byteCode, // bytes memory sourceCode
      initCode, // bytes memory initCode
    ]
  );
};

const zeroAddress = function (): string {
  return '0x' + '00'.repeat(20);
};

const isContractDeployed = function (contract: Contract | null): boolean {
  return !(contract == null || !contract.address || contract.address == null || contract.address == '' || contract.address == zeroAddress());
};

const genesisDeployHelper = async function (hre: HardhatRuntimeEnvironment, salt: string, name: string, initCode: string) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, deterministicCustom } = deployments;
  const { deployer } = await getNamedAccounts();
  const holographGenesis = await ethers.getContract('HolographGenesis');
  let contract: Contract | null = await ethers.getContractOrNull(name);
  if (!isContractDeployed(contract)) {
    const contractBytecode: BytesLike = (await ethers.getContractFactory(name) as ContractFactory).bytecode;
    const contractDeterministic = await deterministicCustom(name, {
      from: deployer,
      args: [],
      log: true,
      deployerAddress: holographGenesis.address,
      saltHash: deployer + salt.substring(2),
      deployCode: generateDeployCode(salt, contractBytecode, initCode),
    });
    console.log('future "' + name + '" address is', contractDeterministic.address);
    await contractDeterministic.deploy();
    contract = await ethers.getContract(name);
  } else {
    console.log('reusing "' + name + '" at', contract?.address);
  };
  return contract;
};


export default { generateInitCode, generateDeployCode, zeroAddress, isContractDeployed, genesisDeployHelper };
