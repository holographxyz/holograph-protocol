declare var global: any;
import path from 'path';

import { BigNumber, Contract } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { DeployFunction } from '@holographxyz/hardhat-deploy-holographed/types';
import { NetworkType, Network, networks } from '@holographxyz/networks';
import {
  genesisDeriveFutureAddress,
  txParams,
  genesisDeployHelper,
  generateInitCode,
  zeroAddress,
  LeanHardhatRuntimeEnvironment,
  hreSplit,
  gweiToWei,
  getDeployer,
} from '../scripts/utils/helpers';
import { MultisigAwareTx } from '../scripts/utils/multisig-aware-tx';
import { parseUnits } from '@ethersproject/units';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  console.log(`Starting deploy script: ${path.basename(__filename)} 👇`);

  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork);
  const deployer = await getDeployer(hre);
  const deployerAddress = await deployer.signer.getAddress();

  const subOneWei = function (input: BigNumber): BigNumber {
    return input.sub(BigNumber.from('1'));
  };

  const salt = hre.deploymentSalt;

  const MSG_BASE_GAS: BigNumber = BigNumber.from('110000');
  const MSG_GAS_PER_BYTE: BigNumber = BigNumber.from('25');
  const JOB_BASE_GAS: BigNumber = BigNumber.from('160000');
  const JOB_GAS_PER_BYTE: BigNumber = BigNumber.from('35');
  const MIN_GAS_PRICE: BigNumber = BigNumber.from('1'); // 1 WEI
  const GAS_LIMIT: BigNumber = BigNumber.from('10000001');

  const defaultParams: BigNumber[] = [
    MSG_BASE_GAS,
    MSG_GAS_PER_BYTE,
    JOB_BASE_GAS,
    JOB_GAS_PER_BYTE,
    MIN_GAS_PRICE,
    GAS_LIMIT,
  ];

  const networkSpecificParams: { [key: string]: BigNumber[] } = {
    ethereum: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('40', 'gwei'), // MIN_GAS_PRICE,
      GAS_LIMIT,
    ],
    ethereumTestnetSepolia: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('1', 'gwei'), // MIN_GAS_PRICE
      GAS_LIMIT,
    ],

    binanceSmartChain: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      BigNumber.from('180000'),
      BigNumber.from('40'),
      parseUnits('0.1', 'gwei'), // MIN_GAS_PRICE
      GAS_LIMIT,
    ],
    binanceSmartChainTestnet: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      BigNumber.from('180000'),
      BigNumber.from('40'),
      parseUnits('0.1', 'gwei'), // MIN_GAS_PRICE
      GAS_LIMIT,
    ],

    avalanche: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('30', 'gwei'), // MIN_GAS_PRICE, // 30 GWEI
      GAS_LIMIT,
    ],
    avalancheTestnet: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('1', 'gwei'), // MIN_GAS_PRICE, // 30 GWEI
      GAS_LIMIT,
    ],

    polygon: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('200', 'gwei'), // MIN_GAS_PRICE, // 200 GWEI
      GAS_LIMIT,
    ],
    polygonTestnet: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('5', 'gwei'), // MIN_GAS_PRICE, // 5 GWEI
      GAS_LIMIT,
    ],

    optimism: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('0.001', 'gwei'), // MIN_GAS_PRICE
      GAS_LIMIT,
    ],
    optimismTestnetSepolia: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('0.001', 'gwei'), // MIN_GAS_PRICE
      GAS_LIMIT,
    ],

    arbitrumOne: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('0.1', 'gwei'), // MIN_GAS_PRICE
      GAS_LIMIT,
    ],
    arbitrumTestnetSepolia: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('0.1', 'gwei'), // MIN_GAS_PRICE
      GAS_LIMIT,
    ],

    mantle: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('0.001', 'gwei'), // MIN_GAS_PRICE
      GAS_LIMIT,
    ],
    mantleTestnet: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('0.001', 'gwei'), // MIN_GAS_PRICE
      GAS_LIMIT,
    ],

    base: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('0.001', 'gwei'), // MIN_GAS_PRICE
      GAS_LIMIT,
    ],
    baseTestnet: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('0.001', 'gwei'), // MIN_GAS_PRICE
      GAS_LIMIT,
    ],

    zora: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('0.001', 'gwei'), // MIN_GAS_PRICE
      GAS_LIMIT,
    ],
    zoraTestnet: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      parseUnits('0.001', 'gwei'), // MIN_GAS_PRICE
      GAS_LIMIT,
    ],
  };

  // Retrieve the network configuration for the current Hardhat runtime environment (hre) network
  const network: Network = networks[hre.networkName];

  // Extract the type of the current network (e.g., testnet, mainnet)
  const networkType: NetworkType = network.type;

  // Get an array of all network keys (names) defined in the networks object
  const networkKeys: string[] = Object.keys(networks);

  // Initialize an empty array to hold the names of supported networks
  let supportedNetworkNames: string[] = [];

  // Initialize an empty array to hold the supported network objects
  let supportedNetworks: Network[] = [];

  // Initialize an empty array to keep track of chain IDs for supported networks
  let chainIds: number[] = [];

  // Initialize an empty array to hold gas parameter configurations for each supported network
  let gasParameters: BigNumber[][] = [];

  // Loop over all network keys to filter and process supported networks
  for (let i = 0, l = networkKeys.length; i < l; i++) {
    // Current network key in the iteration
    const key: string = networkKeys[i];

    // Corresponding network object for the current key
    const value: Network = networks[key];

    // Check if the current network is active and of the same type as the current network type
    if (value.active && value.type === networkType) {
      // If conditions are met, add the network name to the supportedNetworkNames array
      supportedNetworkNames.push(key);

      // Also, add the network object to the supportedNetworks array
      supportedNetworks.push(value);

      // Check if the network has a valid holographId (greater than 0)
      if (value.holographId > 0) {
        // Special handling if the current network's holographId matches the target network's holographId
        if (value.holographId === network.holographId) {
          // Add a 0 to the chainIds array to represent the current network specifically
          chainIds.push(0);

          // Check if there are network-specific gas parameters for the current network and add them to the gasParameters array
          // If not, add the default gas parameters
          if (key in networkSpecificParams) {
            gasParameters.push(networkSpecificParams[key]!);
          } else {
            gasParameters.push(defaultParams);
          }
        }

        // Add the current network's holographId to the chainIds array
        chainIds.push(value.holographId);

        // Again, check for network-specific gas parameters or default to the defaultParams
        if (key in networkSpecificParams) {
          gasParameters.push(networkSpecificParams[key]!);
        } else {
          gasParameters.push(defaultParams);
        }
      }
    }
  }

  const holograph = await hre.ethers.getContract('Holograph', deployerAddress);

  const futureOptimismGasPriceOracleAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'OVM_GasPriceOracle',
    generateInitCode(['uint256', 'uint256', 'uint256', 'uint256', 'uint256'], [0, 0, 0, 0, 0])
  );
  console.log('the future "OVM_GasPriceOracle" address is', futureOptimismGasPriceOracleAddress);

  // OVM_GasPriceOracle
  let optimismGasPriceOracleDeployedCode: string = await hre.provider.send('eth_getCode', [
    futureOptimismGasPriceOracleAddress,
    'latest',
  ]);
  if (optimismGasPriceOracleDeployedCode === '0x' || optimismGasPriceOracleDeployedCode === '') {
    console.log('"OVM_GasPriceOracle" bytecode not found, need to deploy"');
    let optimismGasPriceOracle = await genesisDeployHelper(
      hre,
      salt,
      'OVM_GasPriceOracle',
      generateInitCode(
        ['uint256', 'uint256', 'uint256', 'uint256', 'uint256'],
        [
          1000000, // gasPrice === 1 (since scalar is with 6 decimal places)
          100000000000, // l1BaseFee === 100 GWEI
          2100, // overhead
          1000000, // scalar (since division does not work well in non-decimal numbers, we multiply and then divide by scalar after)
          6, // decimals
        ]
      ),
      futureOptimismGasPriceOracleAddress
    );
  } else {
    console.log('"OVM_GasPriceOracle" is already deployed..');
  }

  // LayerZeroModuleV2
  const futureLayerZeroModuleV2Address = await genesisDeriveFutureAddress(
    hre,
    salt,
    'LayerZeroModuleV2',
    generateInitCode(
      [
        'address',
        'address',
        'address',
        'address',
        'uint32[]',
        'struct(uint256,uint256,uint256,uint256,uint256,uint256)[]',
      ],
      [zeroAddress, zeroAddress, zeroAddress, zeroAddress, [], []]
    )
  );
  console.log('the future "LayerZeroModuleV2" address is', futureLayerZeroModuleV2Address);

  let layerZeroModuleDeployedCode: string = await hre.provider.send('eth_getCode', [
    futureLayerZeroModuleV2Address,
    'latest',
  ]);
  if (layerZeroModuleDeployedCode === '0x' || layerZeroModuleDeployedCode === '') {
    console.log('"LayerZeroModuleV2" bytecode not found, need to deploy"');
    let layerZeroModule = await genesisDeployHelper(
      hre,
      salt,
      'LayerZeroModuleV2',
      generateInitCode(
        [
          'address',
          'address',
          'address',
          'address',
          'uint32[]',
          'struct(uint256,uint256,uint256,uint256,uint256,uint256)[]',
        ],
        [zeroAddress, zeroAddress, zeroAddress, zeroAddress, [], []]
      ),
      futureLayerZeroModuleV2Address
    );
  } else {
    console.log('"LayerZeroModuleV2" is already deployed..');
  }

  // LayerZeroModuleProxyV2
  const futureLayerZeroModuleProxyV2Address = await genesisDeriveFutureAddress(
    hre,
    salt,
    'LayerZeroModuleProxyV2',
    generateInitCode(
      ['address', 'bytes'],
      [
        zeroAddress,
        generateInitCode(
          [
            'address',
            'address',
            'address',
            'address',
            'uint32[]',
            'struct(uint256,uint256,uint256,uint256,uint256,uint256)[]',
          ],
          [zeroAddress, zeroAddress, zeroAddress, zeroAddress, [], []]
        ),
      ]
    )
  );
  console.log('the future "LayerZeroModuleProxyV2" address is', futureLayerZeroModuleProxyV2Address);

  let layerZeroModuleProxyDeployedCode: string = await hre.provider.send('eth_getCode', [
    futureLayerZeroModuleProxyV2Address,
    'latest',
  ]);
  if (layerZeroModuleProxyDeployedCode === '0x' || layerZeroModuleProxyDeployedCode === '') {
    console.log('"LayerZeroModuleProxyV2" bytecode not found, need to deploy"');
    let layerZeroModuleProxy = await genesisDeployHelper(
      hre,
      salt,
      'LayerZeroModuleProxyV2',
      generateInitCode(
        ['address', 'bytes'],
        [
          futureLayerZeroModuleV2Address,
          generateInitCode(
            [
              'address',
              'address',
              'address',
              'address',
              'uint32[]',
              'struct(uint256,uint256,uint256,uint256,uint256,uint256)[]',
            ],
            [
              await holograph.getBridge(),
              await holograph.getInterfaces(),
              await holograph.getOperator(),
              futureOptimismGasPriceOracleAddress,
              chainIds,
              gasParameters,
            ]
          ),
        ]
      ),
      futureLayerZeroModuleProxyV2Address
    );
  } else {
    console.log('"LayerZeroModuleProxyV2" is already deployed..');
  }

  const holographOperator = ((await hre.ethers.getContract('HolographOperator', deployerAddress)) as Contract).attach(
    await holograph.getOperator()
  );

  if (
    (await holographOperator.getMessagingModule()).toLowerCase() !== futureLayerZeroModuleProxyV2Address.toLowerCase()
  ) {
    const lzTx = await MultisigAwareTx(
      hre,
      'HolographOperator',
      holographOperator,
      await holographOperator.populateTransaction.setMessagingModule(futureLayerZeroModuleProxyV2Address, {
        ...(await txParams({
          hre,
          from: deployerAddress,
          to: holographOperator,
          data: holographOperator.populateTransaction.setMessagingModule(futureLayerZeroModuleProxyV2Address),
        })),
      })
    );
    console.log('Transaction hash:', lzTx.hash);
    await lzTx.wait();
    console.log(`Registered MessagingModule to: ${await holographOperator.getMessagingModule()}`);
  } else {
    console.log(`MessagingModule is already registered to: ${await holographOperator.getMessagingModule()}`);
  }

  const lzModule = ((await hre.ethers.getContract('LayerZeroModuleV2', deployerAddress)) as Contract).attach(
    futureLayerZeroModuleProxyV2Address
  );

  // we check that LayerZeroModuleV2 has correct OptimismGasPriceOracle set
  if (
    (await lzModule.getOptimismGasPriceOracle()).toLowerCase() !== futureOptimismGasPriceOracleAddress.toLowerCase()
  ) {
    const lzOpTx = await MultisigAwareTx(
      hre,
      'LayerZeroModuleV2',
      lzModule,
      await lzModule.populateTransaction.setOptimismGasPriceOracle(futureOptimismGasPriceOracleAddress, {
        ...(await txParams({
          hre,
          from: deployerAddress,
          to: lzModule,
          data: lzModule.populateTransaction.setOptimismGasPriceOracle(futureOptimismGasPriceOracleAddress),
        })),
      })
    );
    console.log('Transaction hash:', lzOpTx.hash);
    await lzOpTx.wait();
    console.log(`Registered OptimismGasPriceOracle to: ${await lzModule.getOptimismGasPriceOracle()}`);
  } else {
    console.log(`OptimismGasPriceOracle is already registered to: ${await lzModule.getOptimismGasPriceOracle()}`);
  }

  chainIds = [];
  gasParameters = [];

  // Begin checking for gas parameter inconsistencies
  console.log(`Checking existing gas parameters`);

  // Iterate over all supported networks
  for (let i = 0, l = supportedNetworks.length; i < l; i++) {
    // Retrieve the current network in the loop
    let currentNetwork: Network = supportedNetworks[i];

    // Fetch the current gas parameters for the current network using its holograph ID
    let currentGasParameters: BigNumber[] = await lzModule.getGasParameters(currentNetwork.holographId);

    // Iterate 6 times for each gas parameter (MSG_BASE_GAS, MSG_GAS_PER_BYTE, JOB_BASE_GAS, JOB_GAS_PER_BYTE, MIN_GAS_PRICE, GAS_LIMIT)
    for (let i = 0; i < 6; i++) {
      // Check if the current network's key exists in the networkSpecificParams object
      if (currentNetwork.key in networkSpecificParams) {
        // If so, check if the specific gas parameter does not equal the corresponding current gas parameter
        if (!networkSpecificParams[currentNetwork.key]![i].eq(currentGasParameters[i])) {
          // If there's a mismatch, add the network's holograph ID to the chainIds array
          chainIds.push(currentNetwork.holographId);
          // Also, add the network-specific parameters to the gasParameters array
          gasParameters.push(networkSpecificParams[currentNetwork.key]!);

          // Special case for if the current network is the one being deployed to
          if (currentNetwork.holographId === network.holographId) {
            // Mark the deployment network specifically by adding 0 to chainIds
            chainIds.push(0);
            // Add its parameters again to gasParameters
            gasParameters.push(networkSpecificParams[currentNetwork.key]!);
          }
          // Exit the inner loop early since a mismatch was found
          break;
        }
      } else if (!defaultParams[i].eq(currentGasParameters[i])) {
        // If the network key does not exist, use default parameters
        // Add the current network's holograph ID to chainIds for default parameter mismatch
        chainIds.push(currentNetwork.holographId);
        // Add the default parameters to gasParameters
        gasParameters.push(defaultParams);

        // Special case for the deployment network, similar to above
        if (currentNetwork.holographId === network.holographId) {
          chainIds.push(0); // Mark the deployment network
          gasParameters.push(defaultParams); // Add default parameters for it
        }
        // Exit the inner loop early since a mismatch was found
        break;
      }
    }
  }

  // After iterating through all networks, check if any chainIds were added
  if (chainIds.length > 0) {
    // Log that inconsistencies were found if there are any chainIds
    console.log('Found some gas parameter inconsistencies');

    // Prepare and send a transaction to update the gas parameters
    // This involves calling a specific function on the LayerZero module with the updated parameters
    const lzTx = await MultisigAwareTx(
      hre,
      'LayerZeroModuleV2',
      lzModule,
      await lzModule.populateTransaction[
        'setGasParameters(uint32[],(uint256,uint256,uint256,uint256,uint256,uint256)[])'
      ](chainIds, gasParameters, {
        ...(await txParams({
          hre,
          from: deployerAddress,
          to: lzModule,
          data: lzModule.populateTransaction[
            'setGasParameters(uint32[],(uint256,uint256,uint256,uint256,uint256,uint256)[])'
          ](chainIds, gasParameters),
        })),
      })
    );

    // Log the transaction hash for tracking
    console.log('Transaction hash:', lzTx.hash);

    // Wait for the transaction to be confirmed
    await lzTx.wait();

    // Log a message indicating the gas parameters have been updated
    console.log('Updated LayerZero GasParameters');
  }

  console.log(`Exiting script: ${__filename} ✅\n`);
};

export default func;
func.tags = ['LayerZeroModuleV2'];
func.dependencies = ['HolographGenesis', 'DeploySources'];
