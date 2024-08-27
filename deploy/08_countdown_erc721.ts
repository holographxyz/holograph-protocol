declare var global: any;
import path from 'path';

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { DeployFunction, DeployOptions } from '@holographxyz/hardhat-deploy-holographed/types';
import {
  hreSplit,
  txParams,
  genesisDeployHelper,
  generateInitCode,
  genesisDeriveFutureAddress,
  zeroAddress,
  getDeployer,
} from '../scripts/utils/helpers';
import { MultisigAwareTx } from '../scripts/utils/multisig-aware-tx';
import { Contract } from 'ethers';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  console.log(`Starting deploy script: ${path.basename(__filename)} 👇`);

  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork);
  const deployer = await getDeployer(hre);
  const deployerAddress = await deployer.signer.getAddress();

  // Salt is used for deterministic address generation
  const salt = hre.deploymentSalt;

  // Deploy the CountdownERC721 custom contract source
  const CountdownERC721InitCode = generateInitCode(
    [
      'tuple(string,string,string,string,string,uint40,uint32,uint24,address,address,address,string,tuple(uint104,uint24))',
    ],
    [
      [
        '', // Description
        '', // imageURI
        '', // animationURI
        '', // externalLink
        '', // encryptedMediaURI
        1718822400, // Epoch time for June 3, 2024
        4173120, // Total number of ten-minute intervals until Oct 8, 2103
        600, // Duration of each interval
        deployerAddress, // initialOwner
        deployerAddress, // initialMinter
        deployerAddress, // fundsRecipient
        '', // contractURI
        [0, 0], // salesConfig
      ],
    ]
  );

  const futureCountdownERC721Address = await genesisDeriveFutureAddress(
    hre,
    salt,
    'CountdownERC721',
    CountdownERC721InitCode
  );
  console.log('the future "CountdownERC721" address is', futureCountdownERC721Address);

  let CountdownERC721DeployedCode: string = await hre.provider.send('eth_getCode', [
    futureCountdownERC721Address,
    'latest',
  ]);

  if (CountdownERC721DeployedCode === '0x' || CountdownERC721DeployedCode === '') {
    console.log('"CountdownERC721" bytecode not found, need to deploy"');
    let CountdownERC721 = await genesisDeployHelper(
      hre,
      salt,
      'CountdownERC721',
      CountdownERC721InitCode,
      futureCountdownERC721Address
    );
  } else {
    console.log('"CountdownERC721" is already deployed.');
  }

  console.log(`Exiting script: ${__filename} ✅\n`);
};

export default func;
func.tags = ['CountdownERC721'];
func.dependencies = ['HolographGenesis', 'DeploySources'];
