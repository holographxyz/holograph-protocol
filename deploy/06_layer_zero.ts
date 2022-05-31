declare var global: any;
import fs from 'fs';
import { BytesLike, ContractFactory, Contract } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy-holographed/types';
import { LeanHardhatRuntimeEnvironment, hreSplit, zeroAddress } from '../scripts/utils/helpers';
import Web3 from 'web3';
import networks from '../config/networks';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork);
  const { deployer } = await hre.getNamedAccounts();
  let lzEndpoint = networks[hre.networkName].lzEndpoint;
  if (lzEndpoint == zeroAddress()) {
    lzEndpoint = (await hre.getNamedAccounts()).lzEndpoint;
  }

  const error = function (err: string) {
    hre.deployments.log(err);
    process.exit();
  };

  const web3 = new Web3();

  const holographOperatorProxy = await hre.ethers.getContract('HolographOperatorProxy');
  const holographOperator = ((await hre.ethers.getContract('HolographOperator')) as Contract).attach(
    holographOperatorProxy.address
  );

  if ((await holographOperator.getLZEndpoint()) != lzEndpoint) {
    const lzTx = await holographOperator
      .setLZEndpoint(lzEndpoint, { nonce: await hre.ethers.provider.getTransactionCount(deployer) })
      .catch(error);
    hre.deployments.log('Transaction hash:', lzTx.hash);
    await lzTx.wait();
    hre.deployments.log(`Registered lzEndpoint to: ${await holographOperator.getLZEndpoint()}`);
  } else {
    hre.deployments.log(`lzEndpoint is already registered to: ${await holographOperator.getLZEndpoint()}`);
  }
};

export default func;
func.tags = ['LayerZero'];
func.dependencies = ['HolographGenesis', 'DeploySources'];
