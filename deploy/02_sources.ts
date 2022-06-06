declare var global: any;
import fs from 'fs';
import Web3 from 'web3';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy-holographed/types';
import {
  genesisDeriveFutureAddress,
  genesisDeployHelper,
  generateInitCode,
  zeroAddress,
  LeanHardhatRuntimeEnvironment,
  hreSplit,
} from '../scripts/utils/helpers';
import networks from '../config/networks';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork);
  const { deployments, getNamedAccounts } = hre;
  const { deploy, deterministicCustom } = deployments;
  const { deployer } = await getNamedAccounts();

  const web3 = new Web3();

  const salt = hre.deploymentSalt;

  const futureHolographAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'Holograph',
    generateInitCode(
      ['uint32', 'address', 'address', 'address', 'address', 'address', 'address', 'address'],
      [
        '0x' + networks[hre.networkName].holographId.toString(16).padStart(8, '0'),
        zeroAddress(),
        zeroAddress(),
        zeroAddress(),
        zeroAddress(),
        zeroAddress(),
        zeroAddress(),
        zeroAddress(),
      ]
    )
  );
  hre.deployments.log('the future "Holograph" address is', futureHolographAddress);

  const futureBridgeProxyAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'HolographBridgeProxy',
    generateInitCode(
      ['address', 'bytes'],
      [
        zeroAddress(),
        generateInitCode(
          ['address', 'address', 'address', 'address', 'address'],
          [zeroAddress(), zeroAddress(), zeroAddress(), zeroAddress(), zeroAddress()]
        ),
      ]
    )
  );
  hre.deployments.log('the future "HolographBridgeProxy" address is', futureBridgeProxyAddress);

  const futureFactoryProxyAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'HolographFactoryProxy',
    generateInitCode(
      ['address', 'bytes'],
      [
        zeroAddress(),
        generateInitCode(['address', 'address', 'address'], [zeroAddress(), zeroAddress(), zeroAddress()]),
      ]
    )
  );
  hre.deployments.log('the future "HolographFactoryProxy" address is', futureFactoryProxyAddress);

  const futureOperatorProxyAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'HolographOperatorProxy',
    generateInitCode(
      ['address', 'bytes'],
      [
        zeroAddress(),
        generateInitCode(['address', 'address', 'address'], [zeroAddress(), zeroAddress(), zeroAddress()]),
      ]
    )
  );
  hre.deployments.log('the future "HolographOperatorProxy" address is', futureOperatorProxyAddress);

  const futureRegistryProxyAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'HolographRegistryProxy',
    generateInitCode(
      ['address', 'bytes'],
      [zeroAddress(), generateInitCode(['address', 'bytes32[]'], [zeroAddress(), []])]
    )
  );
  hre.deployments.log('the future "HolographRegistryProxy" address is', futureRegistryProxyAddress);

  const futureTreasuryProxyAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'HolographTreasuryProxy',
    generateInitCode(
      ['address', 'bytes'],
      [
        zeroAddress(),
        generateInitCode(
          ['address', 'address', 'address', 'address'],
          [zeroAddress(), zeroAddress(), zeroAddress(), zeroAddress()]
        ),
      ]
    )
  );
  hre.deployments.log('the future "HolographTreasuryProxy" address is', futureTreasuryProxyAddress);

  const futureInterfacesAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'Interfaces',
    generateInitCode(['address'], [zeroAddress()])
  );
  hre.deployments.log('the future "Interfaces" address is', futureInterfacesAddress);

  // Holograph
  let holograph = await genesisDeployHelper(
    hre,
    salt,
    'Holograph',
    generateInitCode(
      ['uint32', 'address', 'address', 'address', 'address', 'address', 'address'],
      [
        '0x' + networks[hre.networkName].holographId.toString(16).padStart(8, '0'),
        futureBridgeProxyAddress,
        futureFactoryProxyAddress,
        futureInterfacesAddress,
        futureOperatorProxyAddress,
        futureRegistryProxyAddress,
        futureTreasuryProxyAddress,
      ]
    )
  );

  // HolographBridge
  let holographBridge = await genesisDeployHelper(
    hre,
    salt,
    'HolographBridge',
    generateInitCode(
      ['address', 'address', 'address', 'address', 'address'],
      [zeroAddress(), zeroAddress(), zeroAddress(), zeroAddress(), zeroAddress()]
    )
  );

  // HolographBridgeProxy
  let holographBridgeProxy = await genesisDeployHelper(
    hre,
    salt,
    'HolographBridgeProxy',
    generateInitCode(
      ['address', 'bytes'],
      [
        holographBridge.address,
        generateInitCode(
          ['address', 'address', 'address', 'address', 'address'],
          [
            futureFactoryProxyAddress,
            futureHolographAddress,
            futureInterfacesAddress,
            futureOperatorProxyAddress,
            futureRegistryProxyAddress,
          ]
        ),
      ]
    )
  );

  // HolographFactory
  let holographFactory = await genesisDeployHelper(
    hre,
    salt,
    'HolographFactory',
    generateInitCode(['address', 'address', 'address'], [zeroAddress(), zeroAddress(), zeroAddress()])
  );

  // HolographFactoryProxy
  let holographFactoryProxy = await genesisDeployHelper(
    hre,
    salt,
    'HolographFactoryProxy',
    generateInitCode(
      ['address', 'bytes'],
      [
        holographFactory.address,
        generateInitCode(
          ['address', 'address'],
          [
            futureHolographAddress, // Holograph
            futureRegistryProxyAddress, // HolographRegistry
          ]
        ),
      ]
    )
  );

  // HolographOperator
  let holographOperator = await genesisDeployHelper(
    hre,
    salt,
    'HolographOperator',
    generateInitCode(
      ['address', 'address', 'address', 'address'],
      [zeroAddress(), zeroAddress(), zeroAddress(), zeroAddress()]
    )
  );

  // HolographOperatorProxy
  let holographOperatorProxy = await genesisDeployHelper(
    hre,
    salt,
    'HolographOperatorProxy',
    generateInitCode(
      ['address', 'bytes'],
      [
        holographOperator.address,
        generateInitCode(
          ['address', 'address', 'address', 'address'],
          [futureBridgeProxyAddress, futureHolographAddress, futureInterfacesAddress, futureRegistryProxyAddress]
        ),
      ]
    )
  );

  // HolographRegistry
  let holographRegistry = await genesisDeployHelper(
    hre,
    salt,
    'HolographRegistry',
    generateInitCode(['address', 'bytes32[]'], [zeroAddress(), []])
  );

  // HolographRegistryProxy
  let holographRegistryProxy = await genesisDeployHelper(
    hre,
    salt,
    'HolographRegistryProxy',
    generateInitCode(
      ['address', 'bytes'],
      [
        holographRegistry.address,
        generateInitCode(
          ['address', 'bytes32[]'],
          [
            futureHolographAddress,
            [
              '0x' + web3.utils.asciiToHex('HolographERC20').substring(2).padStart(64, '0'),
              '0x' + web3.utils.asciiToHex('HolographERC721').substring(2).padStart(64, '0'),
              '0x' + web3.utils.asciiToHex('HolographERC1155').substring(2).padStart(64, '0'),
              '0x' + web3.utils.asciiToHex('CxipERC721').substring(2).padStart(64, '0'),
              '0x' + web3.utils.asciiToHex('CxipERC1155').substring(2).padStart(64, '0'),
              '0x' + web3.utils.asciiToHex('PA1D').substring(2).padStart(64, '0'),
            ],
          ]
        ),
      ]
    )
  );

  // HolographTreasury
  let holographTreasury = await genesisDeployHelper(
    hre,
    salt,
    'HolographTreasury',
    generateInitCode(
      ['address', 'address', 'address', 'address'],
      [zeroAddress(), zeroAddress(), zeroAddress(), zeroAddress()]
    )
  );

  // HolographTreasuryProxy
  let holographTreasuryProxy = await genesisDeployHelper(
    hre,
    salt,
    'HolographTreasuryProxy',
    generateInitCode(
      ['address', 'bytes'],
      [
        holographTreasury.address,
        generateInitCode(
          ['address', 'address', 'address', 'address'],
          [futureBridgeProxyAddress, futureHolographAddress, futureOperatorProxyAddress, futureRegistryProxyAddress]
        ),
      ]
    )
  );

  // Interfaces
  let interfaces = await genesisDeployHelper(hre, salt, 'Interfaces', generateInitCode(['address'], [deployer]));

  // PA1D
  let royalties = await genesisDeployHelper(
    hre,
    salt,
    'PA1D',
    generateInitCode(['address', 'uint256'], [deployer, '0x' + '00'.repeat(32)])
  );
};

export default func;
func.tags = [
  'DeploySources',

  'Holograph',
  'HolographBridge',
  'HolographBridgeProxy',
  'HolographFactory',
  'HolographFactoryProxy',
  'HolographOperator',
  'HolographOperatorProxy',
  'HolographRegistry',
  'HolographRegistryProxy',
  'HolographTreasury',
  'HolographTreasuryProxy',
  'Interfaces',
  'PA1D',
];
func.dependencies = ['HolographGenesis'];
