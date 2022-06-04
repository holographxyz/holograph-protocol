declare var global: any;
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy-holographed/types';
import {
  LeanHardhatRuntimeEnvironment,
  hreSplit,
  genesisDeployHelper,
  generateInitCode,
  zeroAddress,
} from '../scripts/utils/helpers';
import { HolographERC721Event, ConfigureEvents } from '../scripts/utils/events';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork);
  const { getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();

  const salt = hre.deploymentSalt;

  // HolographERC20
  let holographErc721 = await genesisDeployHelper(
    hre,
    salt,
    'HolographERC721',
    generateInitCode(
      ['string', 'string', 'uint16', 'uint256', 'bool', 'bytes'],
      [
        'Holograph ERC721 Collection', // contractName
        'hNFT', // contractSymbol
        1000, // contractBps == 0%
        ConfigureEvents([]), // eventConfig
        true, // skipInit
        generateInitCode(['address'], [deployer]), // initCode
      ]
    )
  );

  // CxipERC721
  let cxipErc721 = await genesisDeployHelper(hre, salt, 'CxipERC721', generateInitCode(['address'], [zeroAddress()]));
};

export default func;
func.tags = ['HolographERC721', 'CxipERC721', 'DeployERC721'];
func.dependencies = ['HolographGenesis', 'DeploySources'];
