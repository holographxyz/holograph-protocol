declare var global: any;
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy-holographed/types';
import { LeanHardhatRuntimeEnvironment, hreSplit } from '../scripts/utils/helpers';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  let { hre, hre2 } = hreSplit(hre1, global.__companionNetwork);
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const mockErc721Receiver = await deploy('MockERC721Receiver', {
    from: deployer,
    args: [],
    log: true,
  });
};
export default func;
func.tags = ['MockERC721Receiver'];
func.dependencies = ['HolographGenesis'];