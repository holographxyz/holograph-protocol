import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy-holographed/types';
import helpers from '../scripts/utils/helpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const salt: string = '0x' + '00'.repeat(12);

// HolographERC20
  let holographErc20 = await helpers.genesisDeployHelper(hre, salt, 'HolographERC20', helpers.generateInitCode(
    [
      'string',
      'string',
      'uint16',
      'uint256',
      'bytes'
    ],
    [
      'Holograph ERC20 Token', // contractName
      'HolographERC20', // contractSymbol
      18, // contractDecimals
      0, // eventConfig
      '0x' // initCode
    ]
  ));

};

export default func;
func.tags = ['DeployERC20'];
func.dependencies = ['HolographGenesis', 'DeploySources'];
