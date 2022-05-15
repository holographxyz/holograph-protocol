import { run, ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy-holographed/types';
import { BigNumberish, BytesLike, ContractFactory, Contract } from 'ethers';
import Web3 from 'web3';
import helpers from '../scripts/utils/helpers';

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
      deployCode: helpers.generateDeployCode(salt, registryBytecode, helpers.generateInitCode(['bytes32[]'], [[]])),
    });
    console.log('future "HolographRegistry" address is', registryDeterministic.address);
    await registryDeterministic.deploy();
  } else {
    console.log ('reusing "HolographRegistry" at', registry.address);
  }

};

export default func;
func.tags = ['DeploySources'];
func.dependencies = ['HolographGenesis'];
