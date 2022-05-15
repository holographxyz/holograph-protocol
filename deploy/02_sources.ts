import { run, ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy-holographed/types';
import { BigNumberish, BytesLike, ContractFactory, Contract } from 'ethers';
import Web3 from 'web3';

const generateInitCode = function (vars: string[], vals: any[]): string {
  const web3 = new Web3();
  return web3.eth.abi.encodeParameters(vars, vals);
}

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
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, deterministicCustom } = deployments;
  const { deployer } = await getNamedAccounts();

  const web3 = new Web3();

  const error = function (err: string) {
    console.log(err);
    process.exit(1);
  };

  // Get the genesis contract to use as a deployer
  const genesis = await ethers.getContract('HolographGenesis');

  const registryFactory: ContractFactory = await ethers.getContractFactory('HolographRegistry');
  const registryBytecode: BytesLike = registryFactory.bytecode;

  const salt: string = '0x000000000000000000000000';

  const registry: Contract | null  = await ethers.getContractOrNull('HolographRegistry');
  if (registry == null || !registry.address || registry.address == null || registry.address == '0x' + '00'.repeat(20)) {
    const registryDeterministic = await deterministicCustom('HolographRegistry', {
      from: deployer,
      args: [],
      log: true,
      deployerAddress: genesis.address,
      saltHash: deployer + salt.substring(2),
      deployCode: generateDeployCode(salt, registryBytecode, generateInitCode(['bytes32[]'], [[]])),
    });
    console.log('deploying "HolographRegistry" to', registryDeterministic.address);
    await registryDeterministic.deploy();
  } else {
    console.log ('reusing "HolographRegistry" at', registry.address);
  }

};

export default func;
func.tags = ['DeploySources'];
func.dependencies = ['HolographGenesis'];
