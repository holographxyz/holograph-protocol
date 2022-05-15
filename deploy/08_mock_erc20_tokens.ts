import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const mockErc20Tokens = await deploy('ERC20Mock', {
    from: deployer,
    args: [
      'Wrapped ETH (MOCK)',
      'WETHmock',
      18,
      'DomainSeperator',
      '1'
    ],
    log: true,
  });
};

export default func;
func.tags = ['MockERC720Tokens'];
func.dependencies = ['HolographGenesis'];
