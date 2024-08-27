declare var global: any;
import path from 'path';

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { DeployFunction } from '@holographxyz/hardhat-deploy-holographed/types';
import {
  LeanHardhatRuntimeEnvironment,
  hreSplit,
  genesisDeployHelper,
  generateInitCode,
  genesisDeriveFutureAddress,
  zeroAddress,
  getGasPrice,
  getGasLimit,
  getDeployer,
} from '../scripts/utils/helpers';
import { HolographERC721Event, ConfigureEvents } from '../scripts/utils/events';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  console.log(`Starting deploy script: ${path.basename(__filename)} 👇`);

  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork);
  const deployer = await getDeployer(hre);
  const deployerAddress = await deployer.signer.getAddress();
  const salt = hre.deploymentSalt;

  const futureErc721Address = await genesisDeriveFutureAddress(
    hre,
    salt,
    'HolographERC721',
    generateInitCode(
      ['string', 'string', 'uint16', 'uint256', 'bool', 'bytes'],
      [
        'Holograph ERC721 Collection', // contractName
        'hNFT', // contractSymbol
        1000, // contractBps === 0%
        ConfigureEvents([]), // eventConfig
        true, // skipInit
        generateInitCode(['address'], [deployerAddress]), // initCode
      ]
    )
  );
  console.log('the future "HolographERC721" address is', futureErc721Address);

  // HolographERC721
  let erc721DeployedCode: string = await hre.provider.send('eth_getCode', [futureErc721Address, 'latest']);
  if (erc721DeployedCode === '0x' || erc721DeployedCode === '') {
    console.log('"HolographERC721" bytecode not found, need to deploy"');
    let holographErc721 = await genesisDeployHelper(
      hre,
      salt,
      'HolographERC721',
      generateInitCode(
        ['string', 'string', 'uint16', 'uint256', 'bool', 'bytes'],
        [
          'Holograph ERC721 Collection', // contractName
          'hNFT', // contractSymbol
          1000, // contractBps === 0%
          ConfigureEvents([]), // eventConfig
          true, // skipInit
          generateInitCode(['address'], [deployerAddress]), // initCode
        ]
      ),
      futureErc721Address
    );
  } else {
    console.log('"HolographERC721" is already deployed.');
  }

  // CxipERC721
  const futureCxipErc721Address = await genesisDeriveFutureAddress(
    hre,
    salt,
    'CxipERC721',
    generateInitCode(['address'], [deployerAddress])
  );
  console.log('the future "CxipERC721" address is', futureCxipErc721Address);

  let cxipErc721DeployedCode: string = await hre.provider.send('eth_getCode', [futureCxipErc721Address, 'latest']);
  if (cxipErc721DeployedCode === '0x' || cxipErc721DeployedCode === '') {
    console.log('"CxipERC721" bytecode not found, need to deploy"');
    let cxipErc721 = await genesisDeployHelper(
      hre,
      salt,
      'CxipERC721',
      generateInitCode(['address'], [deployerAddress]),
      futureCxipErc721Address
    );
  } else {
    console.log('"CxipERC721" is already deployed.');
  }

  // HolographLegacyERC721
  const futureHolographLegacyErc721Address = await genesisDeriveFutureAddress(
    hre,
    salt,
    'HolographLegacyERC721',
    generateInitCode(['address'], [deployerAddress])
  );
  console.log('the future "HolographLegacyERC721" address is', futureHolographLegacyErc721Address);

  let holographLegacyErc721DeployedCode: string = await hre.provider.send('eth_getCode', [
    futureHolographLegacyErc721Address,
    'latest',
  ]);
  if (holographLegacyErc721DeployedCode === '0x' || holographLegacyErc721DeployedCode === '') {
    console.log('"HolographLegacyERC721" bytecode not found, need to deploy"');
    let HolographLegacyErc721 = await genesisDeployHelper(
      hre,
      salt,
      'HolographLegacyERC721',
      generateInitCode(['address'], [deployerAddress]),
      futureHolographLegacyErc721Address
    );
  } else {
    console.log('"HolographLegacyERC721" is already deployed.');
  }

  console.log(`Exiting script: ${__filename} ✅\n`);
};

export default func;
func.tags = ['HolographERC721', 'CxipERC721', 'HolographLegacyERC721', 'DeployERC721'];
func.dependencies = ['HolographGenesis', 'DeploySources'];
