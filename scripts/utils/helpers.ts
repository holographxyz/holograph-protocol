import Web3 from 'web3';
import crypto from 'crypto';
import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction, Deployment } from 'hardhat-deploy-holographed/types';
import { BytesLike, ContractFactory, Contract } from 'ethers';

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
          name: 'saltHash',
        },
        {
          type: 'bytes',
          name: 'sourceCode',
        },
        {
          type: 'bytes',
          name: 'initCode',
        },
      ],
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
  return !(
    contract == null ||
    !contract?.address ||
    contract?.address == null ||
    contract?.address == '' ||
    contract?.address == zeroAddress()
  );
};

const genesisDeriveFutureAddress = async function (
  hre: HardhatRuntimeEnvironment,
  salt: string,
  name: string,
  initCode: string
): Promise<string> {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, deterministicCustom } = deployments;
  const { deployer } = await getNamedAccounts();
  let holographGenesis: any = await ethers.getContractOrNull('HolographGenesis');
  if (holographGenesis == null) {
    try {
      holographGenesis = await deployments.get('HolographGenesis');
    } catch (ex: any) {
      throw new Error('We need to have HolographGenesis deployed.');
    }
  }
  const contractBytecode: BytesLike = ((await ethers.getContractFactory(name)) as ContractFactory).bytecode;
  const contractDeterministic = await deterministicCustom(name, {
    from: deployer,
    args: [],
    log: true,
    deployerAddress: holographGenesis?.address,
    saltHash: deployer + salt.substring(2),
    deployCode: generateDeployCode(salt, contractBytecode, initCode),
  });
  return contractDeterministic.address;
};

const genesisDeployHelper = async function (
  hre: HardhatRuntimeEnvironment,
  salt: string,
  name: string,
  initCode: string
): Promise<Contract> {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, deterministicCustom } = deployments;
  const { deployer } = await getNamedAccounts();
  let holographGenesis: any = await ethers.getContractOrNull('HolographGenesis');
  if (holographGenesis == null) {
    try {
      holographGenesis = await deployments.get('HolographGenesis');
    } catch (ex: any) {
      // we do nothing
    }
  }
  let contract: any = await ethers.getContractOrNull(name);
  if (contract == null) {
    try {
      contract = await deployments.get(name);
    } catch (ex: any) {
      // we do nothing
    }
  }
  if (!isContractDeployed(contract)) {
    const contractBytecode: BytesLike = ((await ethers.getContractFactory(name)) as ContractFactory).bytecode;
    const contractDeterministic = await deterministicCustom(name, {
      from: deployer,
      args: [],
      log: true,
      deployerAddress: holographGenesis?.address,
      saltHash: deployer + salt.substring(2),
      deployCode: generateDeployCode(salt, contractBytecode, initCode),
    });
    console.log('future "' + name + '" address is', contractDeterministic.address);
    await contractDeterministic.deploy();
    contract = await ethers.getContract(name);
  } else {
    console.log('reusing "' + name + '" at', contract?.address);
  }
  if (contract == null) {
    return {} as Contract;
  } else {
    return contract as Contract;
  }
};

const utf8ToBytes32 = function (str: string): string {
  return (
    '0x' +
    Array.from(str)
      .map((c) =>
        c.charCodeAt(0) < 128 ? c.charCodeAt(0).toString(16) : encodeURIComponent(c).replace(/\%/g, '').toLowerCase()
      )
      .join('')
      .padStart(64, '0')
  );
};

const ZERO_ADDRESS: string = '0x0000000000000000000000000000000000000000';

const remove0x = function (input: string): string {
  if (input.startsWith('0x')) {
    return input.substring(2);
  } else {
    return input;
  }
};

const sha256 = function (x: string): string {
  return '0x' + crypto.createHash('sha256').update(x, 'utf8').digest('hex');
};

export {
  generateInitCode,
  generateDeployCode,
  zeroAddress,
  isContractDeployed,
  genesisDeriveFutureAddress,
  genesisDeployHelper,
  utf8ToBytes32,
  ZERO_ADDRESS,
  remove0x,
  sha256,
};
