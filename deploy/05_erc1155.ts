declare var global: any;
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy-holographed/types';
import {
  LeanHardhatRuntimeEnvironment,
  hreSplit,
  genesisDeployHelper,
  generateInitCode,
} from '../scripts/utils/helpers';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  let { hre, hre2 } = hreSplit(hre1, global.__companionNetwork);
  // this is purposefully left empty, and is a placeholder for future use
};

export default func;
func.tags = ['DeployERC1155'];
func.dependencies = ['HolographGenesis', 'DeploySources'];
