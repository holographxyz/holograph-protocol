declare var global: any;
import path from 'path';

import fs from 'fs';
import { BytesLike, ContractFactory, Contract, BigNumber } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { DeployFunction } from '@holographxyz/hardhat-deploy-holographed/types';
import { LeanHardhatRuntimeEnvironment, hreSplit, zeroAddress, txParams, getDeployer } from '../scripts/utils/helpers';
import { MultisigAwareTx } from '../scripts/utils/multisig-aware-tx';
import { NetworkType, networks } from '@holographxyz/networks';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  console.log(`Starting deploy script: ${path.basename(__filename)} 👇`);

  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork);
  const deployer = await getDeployer(hre);
  const deployerAddress = await deployer.signer.getAddress();
  const salt = hre.deploymentSalt;

  const currentNetworkType: NetworkType = networks[hre.networkName].type;

  console.log(`Checking lzEndpoint for ${hre1.network.name} network`);
  console.log(`LZ Endpoint ${networks[hre.networkName].lzEndpoint}`);

  let lzEndpoint = networks[hre.networkName].lzEndpoint;

  if (lzEndpoint) {
    if (currentNetworkType === NetworkType.local && lzEndpoint === undefined) {
      lzEndpoint = (await hre.getNamedAccounts()).lzEndpoint;
      const mockLZEndpoint = await hre.deployments.deploy('MockLZEndpoint', {
        ...(await txParams({
          hre,
          from: lzEndpoint,
          to: '0x0000000000000000000000000000000000000000',
          gasLimit: await hre.ethers.provider.estimateGas(
            (await hre.ethers.getContractFactory('MockLZEndpoint')).getDeployTransaction()
          ),
          nonce: await hre.ethers.provider.getTransactionCount(lzEndpoint),
        })),
        args: [],
        log: true,
        waitConfirmations: 1,
      } as any);
      lzEndpoint = mockLZEndpoint.address.toLowerCase();
    }

    const layerZeroModuleV2ProxyV2 = await hre.ethers.getContract('LayerZeroModuleProxyV2', deployerAddress);
    const layerZeroModuleV2 = (await hre.ethers.getContractAt(
      'LayerZeroModuleV2',
      layerZeroModuleV2ProxyV2.address,
      deployerAddress
    )) as Contract;

    if ((await layerZeroModuleV2.getLZEndpoint()).toLowerCase() !== lzEndpoint) {
      const lzTx = await MultisigAwareTx(
        hre,
        'LayerZeroModuleV2',
        layerZeroModuleV2,
        await layerZeroModuleV2.populateTransaction.setLZEndpoint(lzEndpoint, {
          ...(await txParams({
            hre,
            from: deployerAddress,
            to: layerZeroModuleV2,
            data: layerZeroModuleV2.populateTransaction.setLZEndpoint(lzEndpoint),
          })),
        })
      );
      console.log('Transaction hash:', lzTx.hash);
      await lzTx.wait();
      console.log(`Registered lzEndpoint to: ${await layerZeroModuleV2.getLZEndpoint()}`);
    } else {
      console.log(`lzEndpoint is already registered to: ${await layerZeroModuleV2.getLZEndpoint()}`);
    }

    // Migrate from LayerZero Endpoint to use the new V2 MessageLib (UltraLightNode301)
    // const endpointContractABI = ['function latestVersion() view returns (uint256)'];
    // const endpointContract = new Contract(lzEndpoint, endpointContractABI, hre.ethers.provider);
    // const latestVersion = await endpointContract.latestVersion();
    // console.log(`Latest version of the Endpoint contract is: ${latestVersion}`);

    // // Set the send and receive versions to the latest version of the endpoint contract
    // // The LZ docs specify tha tthe send version is one less than the receive version
    // const receiveUln301Version = latestVersion;
    // const sendUln301Version = latestVersion - 1;

    // console.log(`Setting sendVersion to ${sendUln301Version} and receiveVersion to ${receiveUln301Version}`);
    // const sendTxParams = await txParams({
    //   hre,
    //   from: deployerAddress,
    //   to: layerZeroModuleV2,
    //   data: layerZeroModuleV2.populateTransaction.setSendVersion(sendUln301Version),
    // });

    // const receiveTxParams = await txParams({
    //   hre,
    //   from: deployerAddress,
    //   to: layerZeroModuleV2,
    //   data: layerZeroModuleV2.populateTransaction.setReceiveVersion(receiveUln301Version),
    // });

    // const sendTx = await MultisigAwareTx(
    //   hre,
    //   'LayerZeroModuleV2',
    //   layerZeroModuleV2,
    //   await layerZeroModuleV2.populateTransaction.setSendVersion(sendUln301Version, {
    //     ...sendTxParams,
    //   })
    // );
    // console.log('Send Transaction hash:', sendTx.hash);
    // await sendTx.wait();

    // const receiveTx = await MultisigAwareTx(
    //   hre,
    //   'LayerZeroModuleV2',
    //   layerZeroModuleV2,
    //   await layerZeroModuleV2.populateTransaction.setReceiveVersion(receiveUln301Version, {
    //     ...receiveTxParams,
    //   })
    // );
    // console.log('Receive Transaction hash:', receiveTx.hash);
    // await receiveTx.wait();

    // console.log(`Successfully set sendVersion to ${sendUln301Version} and receiveVersion to ${receiveUln301Version}`);
  } else {
    console.log(`Skipping for ${hre1.network.name} network because lzEndpoint is not set`);
  }

  // LZ Executor
  let lzExecutor = networks[hre.networkName].lzExecutor;

  if (lzExecutor) {
    console.log(`lzExecutor is set to: ${lzExecutor}`);
    const layerZeroModuleV2ProxyV2 = await hre.ethers.getContract('LayerZeroModuleProxyV2', deployerAddress);
    const layerZeroModuleV2 = (await hre.ethers.getContractAt(
      'LayerZeroModuleV2',
      layerZeroModuleV2ProxyV2.address,
      deployerAddress
    )) as Contract;

    if ((await layerZeroModuleV2.getLZExecutor()).toLowerCase() !== lzExecutor) {
      console.log(`Setting lzExecutor to: ${lzExecutor} via multisig aware tx`);
      const lzTx = await MultisigAwareTx(
        hre,
        'LayerZeroModuleV2',
        layerZeroModuleV2,
        await layerZeroModuleV2.populateTransaction.setLZExecutor(lzExecutor, {
          ...(await txParams({
            hre,
            from: deployerAddress,
            to: layerZeroModuleV2,
            data: layerZeroModuleV2.populateTransaction.setLZExecutor(lzExecutor),
          })),
        })
      );
      console.log('Transaction hash:', lzTx.hash);
      await lzTx.wait();
      console.log(`Registered lzExecutor to: ${await layerZeroModuleV2.getLZExecutor()}`);
    } else {
      console.log(`lzExecutor is already registered to: ${await layerZeroModuleV2.getLZExecutor()}`);
    }
  } else {
    console.log(`Skipping for ${hre1.network.name} network because lzExecutor is not set`);
  }
  console.log(`Exiting script: ${__filename} ✅\n`);
};

export default func;
func.tags = ['MockLZEndpoint', 'LayerZero'];
// func.dependencies = ['HolographGenesis', 'DeploySources', 'LayerZeroModuleV2'];
