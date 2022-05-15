import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy-holographed/types';
import Web3 from 'web3';
import helpers from '../scripts/utils/helpers';

const networks = JSON.parse(fs.readFileSync('./config/networks.json', 'utf8'));

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, deterministicCustom } = deployments;
  const { deployer } = await getNamedAccounts();

  const web3 = new Web3();

  const error = function (err: string) {
    console.log(err);
    process.exit(1);
  };

  const salt: string = '0x' + '00'.repeat(12);

// HolographRegistry
  let holographRegistry = await helpers.genesisDeployHelper(hre, salt, 'HolographRegistry', helpers.generateInitCode(
    [
      'bytes32[]'
    ],
    [
      []
    ]
  ));

// HolographRegistryProxy
  let holographRegistryProxy = await helpers.genesisDeployHelper(hre, salt, 'HolographRegistryProxy', helpers.generateInitCode(
    [
      'address',
      'bytes'
    ],
    [
      holographRegistry?.address,
      helpers.generateInitCode(
        [
          'bytes32[]'
        ],
        [
          [
            '0x' + web3.utils.asciiToHex('HolographERC721').substring(2).padStart(64, '0'),
            '0x' + web3.utils.asciiToHex('HolographERC20').substring(2).padStart(64, '0'),
            '0x' + web3.utils.asciiToHex('PA1D').substring(2).padStart(64, '0')
          ]
        ]
      )
    ]
  ));

// SecureStorage
  let secureStorage = await helpers.genesisDeployHelper(hre, salt, 'SecureStorage', helpers.generateInitCode(
    [
      'address'
    ],
    [
      helpers.zeroAddress()
    ]
  ));

// SecureStorageProxy
  let secureStorageProxy = await helpers.genesisDeployHelper(hre, salt, 'SecureStorageProxy', helpers.generateInitCode(
    [
      'address',
      'bytes'
    ],
    [
      secureStorage?.address,
      helpers.generateInitCode(
        [
          'address'
        ],
        [
          helpers.zeroAddress()
        ]
      )
    ]
  ));

// HolographFactory
  let holographFactory = await helpers.genesisDeployHelper(hre, salt, 'HolographFactory', helpers.generateInitCode(
    [
      'address',
      'address'
    ],
    [
      helpers.zeroAddress(),
      helpers.zeroAddress()
    ]
  ));

// HolographFactoryProxy
  let holographFactoryProxy = await helpers.genesisDeployHelper(hre, salt, 'HolographFactoryProxy', helpers.generateInitCode(
    [
      'address',
      'bytes'
    ],
    [
      holographFactory?.address,
      helpers.generateInitCode(
        [
          'address',
          'address'
        ],
        [
          holographRegistryProxy?.address, // HolographRegistry
          secureStorage?.address // SecureStorage
        ]
      )
    ]
  ));

// HolographBridge
  let holographBridge = await helpers.genesisDeployHelper(hre, salt, 'HolographBridge', helpers.generateInitCode(
    [
      'address',
      'address'
    ],
    [
      helpers.zeroAddress(),
      helpers.zeroAddress()
    ]
  ));

// HolographBridgeProxy
  let holographBridgeProxy = await helpers.genesisDeployHelper(hre, salt, 'HolographBridgeProxy', helpers.generateInitCode(
    [
      'address',
      'bytes'
    ],
    [
      holographBridge?.address,
      helpers.generateInitCode(
        [
          'address',
          'address'
        ],
        [
          holographRegistryProxy?.address,
          holographFactoryProxy?.address
        ]
      )
    ]
  ));

// Holograph
  let holograph = await helpers.genesisDeployHelper(hre, salt, 'Holograph', helpers.generateInitCode(
    [
      'uint32',
      'address',
      'address',
      'address',
      'address'
    ],
    [
      '0x' + networks[hre.network.name].holographId.toString(16).padStart(8, '0'),
      holographRegistryProxy?.address,
      holographFactoryProxy?.address,
      holographBridgeProxy?.address,
      secureStorageProxy?.address
    ]
  ));

// PA1D
  let royalties = await helpers.genesisDeployHelper(hre, salt, 'PA1D', helpers.generateInitCode(
    [
      'address',
      'uint256'
    ],
    [
      deployer,
      '0x' + '00'.repeat(32)
    ]
  ));
};

export default func;
func.tags = ['DeploySources'];
func.dependencies = ['HolographGenesis'];
