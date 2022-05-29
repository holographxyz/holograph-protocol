declare var global: any;
import fs from 'fs';
import { BytesLike, ContractFactory, Contract } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy-holographed/types';
import { LeanHardhatRuntimeEnvironment, hreSplit } from '../scripts/utils/helpers';
import Web3 from 'web3';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork);
  const { deployer, lzEndpoint } = await hre.getNamedAccounts();

  const error = function (err: string) {
    hre.deployments.log(err);
    process.exit();
  };

  const web3 = new Web3();

  const holographBridgeProxy = await hre.ethers.getContract('HolographBridgeProxy');
  const holographBridge = ((await hre.ethers.getContract('HolographBridge')) as Contract).attach(
    holographBridgeProxy.address
  );

  if ((await holographBridge.getLZEndpoint()) != lzEndpoint) {
    const lzTx = await holographBridge
      .setLZEndpoint(lzEndpoint, { nonce: await hre.ethers.provider.getTransactionCount(deployer) })
      .catch(error);
    hre.deployments.log('Transaction hash:', lzTx.hash);
    await lzTx.wait();
    hre.deployments.log(`Registered lzEndpoint to: ${await holographBridge.getLZEndpoint()}`);
  } else {
    hre.deployments.log(`lzEndpoint is already registered to: ${await holographBridge.getLZEndpoint()}`);
  }
};

export default func;
func.tags = ['LayerZero'];
func.dependencies = ['HolographGenesis', 'DeploySources'];
