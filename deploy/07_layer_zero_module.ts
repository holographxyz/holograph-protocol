declare var global: any;
import { BigNumber, Contract } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from '@holographxyz/hardhat-deploy-holographed/types';
import { NetworkType, Network, networks } from '@holographxyz/networks';
import {
  genesisDeriveFutureAddress,
  genesisDeployHelper,
  generateInitCode,
  zeroAddress,
  LeanHardhatRuntimeEnvironment,
  hreSplit,
} from '../scripts/utils/helpers';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork);
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const error = function (err: string) {
    hre.deployments.log(err);
    process.exit();
  };

  const salt = hre.deploymentSalt;

  const MSGBASEGAS: BigNumber = BigNumber.from('110000');
  const MSGGASPERBYTE: BigNumber = BigNumber.from('25');
  const JOBBASEGAS: BigNumber = BigNumber.from('160000');
  const JOBGASPERBYTE: BigNumber = BigNumber.from('35');
  const MINGASPRICE: BigNumber = BigNumber.from('999999999');
  const GASLIMIT: BigNumber = BigNumber.from('10000001');

  const defaultParams: BigNumber[] = [MSGBASEGAS, MSGGASPERBYTE, JOBBASEGAS, JOBGASPERBYTE, MINGASPRICE, GASLIMIT];

  const network: Network = networks[hre.networkName];
  const networkType: NetworkType = network.type;
  const networkKeys: string[] = Object.keys(networks);
  const networkValues: Network[] = Object.values(networks);
  let supportedNetworkNames: string[] = [];
  let supportedNetworks: Network[] = [];
  let chainIds: number[] = [];
  let gasParameters: BigNumber[][] = [];
  for (let i = 0, l = networkKeys.length; i < l; i++) {
    const key: string = networkKeys[i];
    const value: Network = networkValues[i];
    if (value.type == networkType) {
      supportedNetworkNames.push(key);
      supportedNetworks.push(value);
      if (value.holographId > 0) {
        if (value.holographId == network.holographId) {
          chainIds.push(0);
          gasParameters.push(defaultParams);
        }
        chainIds.push(value.holographId);
        gasParameters.push(defaultParams);
      }
    }
  }

  const holograph = await hre.ethers.getContract('Holograph');

  const futureLayerZeroModuleAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'LayerZeroModule',
    generateInitCode(
      ['address', 'address', 'address', 'uint32[]', 'struct(uint256,uint256,uint256,uint256,uint256,uint256)[]'],
      [zeroAddress, zeroAddress, zeroAddress, [], []]
    )
  );
  hre.deployments.log('the future "LayerZeroModule" address is', futureLayerZeroModuleAddress);

  // LayerZeroModule
  let layerZeroModuleDeployedCode: string = await hre.provider.send('eth_getCode', [
    futureLayerZeroModuleAddress,
    'latest',
  ]);
  if (layerZeroModuleDeployedCode == '0x' || layerZeroModuleDeployedCode == '') {
    hre.deployments.log('"LayerZeroModule" bytecode not found, need to deploy"');
    let layerZeroModule = await genesisDeployHelper(
      hre,
      salt,
      'LayerZeroModule',
      generateInitCode(
        ['address', 'address', 'address', 'uint32[]', 'struct(uint256,uint256,uint256,uint256,uint256,uint256)[]'],
        [
          await holograph.getBridge(),
          await holograph.getInterfaces(),
          await holograph.getOperator(),
          chainIds,
          gasParameters,
        ]
      ),
      futureLayerZeroModuleAddress
    );
  } else {
    hre.deployments.log('"LayerZeroModule" is already deployed..');
  }

  const holographOperator = ((await hre.ethers.getContract('HolographOperator')) as Contract).attach(
    await holograph.getOperator()
  );

  if ((await holographOperator.getMessagingModule()).toLowerCase() != futureLayerZeroModuleAddress.toLowerCase()) {
    const lzTx = await holographOperator
      .setMessagingModule(futureLayerZeroModuleAddress, {
        nonce: await hre.ethers.provider.getTransactionCount(deployer),
      })
      .catch(error);
    hre.deployments.log('Transaction hash:', lzTx.hash);
    await lzTx.wait();
    hre.deployments.log(`Registered MessagingModule to: ${await holographOperator.getMessagingModule()}`);
  } else {
    hre.deployments.log(`MessagingModule is already registered to: ${await holographOperator.getMessagingModule()}`);
  }

  const lzModule = (await hre.ethers.getContract('LayerZeroModule')) as Contract;

  chainIds = [];
  gasParameters = [];

  for (let i = 0, l = supportedNetworks.length; i < l; i++) {
    let currentNetwork: Network = supportedNetworks[i];
    let currentGasParameters: BigNumber[] = await lzModule.getGasParameters(currentNetwork.holographId);
    for (let i = 0; i < 6; i++) {
      if (!defaultParams[i].eq(currentGasParameters[i])) {
        chainIds.push(currentNetwork.holographId);
        gasParameters.push(defaultParams);
        break;
      }
    }
  }
  if (chainIds.length > 0) {
    hre.deployments.log('Found some gas parameter inconsistencies');
    const lzTx = await lzModule['setGasParameters(uint32[],(uint256,uint256,uint256,uint256,uint256,uint256)[])'](
      chainIds,
      gasParameters,
      {
        nonce: await hre.ethers.provider.getTransactionCount(deployer),
      }
    ).catch(error);
    hre.deployments.log('Transaction hash:', lzTx.hash);
    await lzTx.wait();
    hre.deployments.log('Updated LayerZero GasParameters');
  }
};

export default func;
func.tags = ['LayerZeroModule'];
func.dependencies = ['HolographGenesis', 'DeploySources'];
