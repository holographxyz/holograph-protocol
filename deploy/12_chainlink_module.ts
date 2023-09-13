declare var global: any;
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
} from '../scripts/utils/helpers';
import { MultisigAwareTx } from '../scripts/utils/multisig-aware-tx';
import { SuperColdStorageSigner } from 'super-cold-storage-signer';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork);
  const accounts = await hre.ethers.getSigners();
  let deployer: SignerWithAddress | SuperColdStorageSigner = accounts[0];

  if (global.__superColdStorage) {
    // address, domain, authorization, ca
    const coldStorage = global.__superColdStorage;
    deployer = new SuperColdStorageSigner(
      coldStorage.address,
      'https://' + coldStorage.domain,
      coldStorage.authorization,
      deployer.provider,
      coldStorage.ca
    );
  }

  const error = function (err: string) {
    hre.deployments.log(err);
    process.exit();
  };

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
      subOneWei(gweiToWei(BigNumber.from('40'))), // MIN_GAS_PRICE, // 40 GWEI
      GAS_LIMIT,
    ],
    ethereumTestnetGoerli: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      subOneWei(gweiToWei(BigNumber.from('5'))), // MIN_GAS_PRICE, // 5 GWEI
      GAS_LIMIT,
    ],

    binanceSmartChain: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      BigNumber.from('180000'),
      BigNumber.from('40'),
      subOneWei(gweiToWei(BigNumber.from('3'))), // MIN_GAS_PRICE, // 3 GWEI
      GAS_LIMIT,
    ],
    binanceSmartChainTestnet: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      BigNumber.from('180000'),
      BigNumber.from('40'),
      subOneWei(gweiToWei(BigNumber.from('1'))), // MIN_GAS_PRICE, // 1 GWEI
      GAS_LIMIT,
    ],

    avalanche: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      subOneWei(gweiToWei(BigNumber.from('30'))), // MIN_GAS_PRICE, // 30 GWEI
      GAS_LIMIT,
    ],
    avalancheTestnet: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      subOneWei(gweiToWei(BigNumber.from('30'))), // MIN_GAS_PRICE, // 30 GWEI
      GAS_LIMIT,
    ],

    polygon: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      subOneWei(gweiToWei(BigNumber.from('200'))), // MIN_GAS_PRICE, // 200 GWEI
      GAS_LIMIT,
    ],
    polygonTestnet: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      subOneWei(gweiToWei(BigNumber.from('5'))), // MIN_GAS_PRICE, // 5 GWEI
      GAS_LIMIT,
    ],

    optimism: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      subOneWei(BigNumber.from('10000000')), // MIN_GAS_PRICE, // 0.01 GWEI
      GAS_LIMIT,
    ],
    optimismTestnetGoerli: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      subOneWei(gweiToWei(BigNumber.from('5'))), // MIN_GAS_PRICE, // 5 GWEI
      GAS_LIMIT,
    ],

    arbitrumOne: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      subOneWei(BigNumber.from('100000000')), // MIN_GAS_PRICE, // 0.1 GWEI
      GAS_LIMIT,
    ],
    arbitrumTestnetGoerli: [
      MSG_BASE_GAS,
      MSG_GAS_PER_BYTE,
      JOB_BASE_GAS,
      JOB_GAS_PER_BYTE,
      subOneWei(gweiToWei(BigNumber.from('5'))), // MIN_GAS_PRICE, // 5 GWEI
      GAS_LIMIT,
    ],
  };

  const network: Network = networks[hre.networkName];
  const networkType: NetworkType = network.type;
  const networkKeys: string[] = Object.keys(networks);
  let supportedNetworkNames: string[] = [];
  let supportedNetworks: Network[] = [];
  let chainIds: number[] = [];
  let gasParameters: BigNumber[][] = [];
  let ccipRouterAddress: string = '';

  for (let i = 0, l = networkKeys.length; i < l; i++) {
    const key: string = networkKeys[i];
    const value: Network = networks[key];
    if (value.active && value.type == networkType) {
      supportedNetworkNames.push(key);
      supportedNetworks.push(value);
      if (value.holographId > 0) {
        if (value.holographId == network.holographId) {
          chainIds.push(0);
          if (key in networkSpecificParams) {
            gasParameters.push(networkSpecificParams[key]!);
          } else {
            gasParameters.push(defaultParams);
          }
        }
        chainIds.push(value.holographId);
        if (key in networkSpecificParams) {
          gasParameters.push(networkSpecificParams[key]!);
        } else {
          gasParameters.push(defaultParams);
        }
      }
    }

    // Set the CCIP router address
    ccipRouterAddress = value.ccipEndpoint;
  }

  const holograph = await hre.ethers.getContract('Holograph', deployer);

  const futureOptimismGasPriceOracleAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'OVM_GasPriceOracle',
    generateInitCode(['uint256', 'uint256', 'uint256', 'uint256', 'uint256'], [0, 0, 0, 0, 0])
  );
  hre.deployments.log('the future "OVM_GasPriceOracle" address is', futureOptimismGasPriceOracleAddress);

  // OVM_GasPriceOracle
  let optimismGasPriceOracleDeployedCode: string = await hre.provider.send('eth_getCode', [
    futureOptimismGasPriceOracleAddress,
    'latest',
  ]);
  if (optimismGasPriceOracleDeployedCode == '0x' || optimismGasPriceOracleDeployedCode == '') {
    hre.deployments.log('"OVM_GasPriceOracle" bytecode not found, need to deploy"');
    let optimismGasPriceOracle = await genesisDeployHelper(
      hre,
      salt,
      'OVM_GasPriceOracle',
      generateInitCode(
        ['uint256', 'uint256', 'uint256', 'uint256', 'uint256'],
        [
          1000000, // gasPrice == 1 (since scalar is with 6 decimal places)
          100000000000, // l1BaseFee == 100 GWEI
          2100, // overhead
          1000000, // scalar (since division does not work well in non-decimal numbers, we multiply and then divide by scalar after)
          6, // decimals
        ]
      ),
      futureOptimismGasPriceOracleAddress
    );
  } else {
    hre.deployments.log('"OVM_GasPriceOracle" is already deployed..');
  }

  // ChainlinkModule
  const futureChainlinkModuleAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'ChainlinkModule',
    generateInitCode(
      [
        'address',
        'address',
        'address',
        'address',
        'address',
        'uint32[]',
        'struct(uint256,uint256,uint256,uint256,uint256,uint256)[]',
      ],
      [zeroAddress, zeroAddress, zeroAddress, zeroAddress, zeroAddress, [], []]
    )
  );
  hre.deployments.log('the future "ChainlinkModule" address is', futureChainlinkModuleAddress);

  let chainlinkModuleDeployedCode: string = await hre.provider.send('eth_getCode', [
    futureChainlinkModuleAddress,
    'latest',
  ]);
  if (chainlinkModuleDeployedCode == '0x' || chainlinkModuleDeployedCode == '') {
    hre.deployments.log('"ChainlinkModule" bytecode not found, need to deploy"');
    let chainlinkModule = await genesisDeployHelper(
      hre,
      salt,
      'ChainlinkModule',
      generateInitCode(
        [
          'address',
          'address',
          'address',
          'address',
          'address',
          'uint32[]',
          'struct(uint256,uint256,uint256,uint256,uint256,uint256)[]',
        ],
        [zeroAddress, zeroAddress, zeroAddress, zeroAddress, zeroAddress, [], []]
      ),
      futureChainlinkModuleAddress
    );
  } else {
    hre.deployments.log('"ChainlinkModule" is already deployed..');
  }

  // ChainlinkModuleProxy
  const futureChainlinkModuleProxyAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'ChainlinkModuleProxy',
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
            'address',
            'uint32[]',
            'struct(uint256,uint256,uint256,uint256,uint256,uint256)[]',
          ],
          [zeroAddress, zeroAddress, zeroAddress, zeroAddress, zeroAddress, [], []]
        ),
      ]
    )
  );
  hre.deployments.log('the future "ChainlinkModuleProxy" address is', futureChainlinkModuleProxyAddress);

  let chainlinkModuleProxyDeployedCode: string = await hre.provider.send('eth_getCode', [
    futureChainlinkModuleProxyAddress,
    'latest',
  ]);
  if (chainlinkModuleProxyDeployedCode == '0x' || chainlinkModuleProxyDeployedCode == '') {
    hre.deployments.log('"ChainlinkModuleProxy" bytecode not found, need to deploy"');
    let chainlinkModuleProxy = await genesisDeployHelper(
      hre,
      salt,
      'ChainlinkModuleProxy',
      generateInitCode(
        ['address', 'bytes'],
        [
          futureChainlinkModuleAddress,
          generateInitCode(
            [
              'address',
              'address',
              'address',
              'address',
              'address',
              'uint32[]',
              'struct(uint256,uint256,uint256,uint256,uint256,uint256)[]',
            ],
            [
              ccipRouterAddress, // TODO: Check that this is the right address
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
      futureChainlinkModuleProxyAddress
    );
  } else {
    hre.deployments.log('"ChainlinkModuleProxy" is already deployed..');
  }

  const holographOperator = ((await hre.ethers.getContract('HolographOperator', deployer)) as Contract).attach(
    await holograph.getOperator()
  );

  if ((await holographOperator.getMessagingModule()).toLowerCase() != futureChainlinkModuleProxyAddress.toLowerCase()) {
    const chainlinkTx = await MultisigAwareTx(
      hre,
      deployer,
      'HolographOperator',
      holographOperator,
      await holographOperator.populateTransaction.setMessagingModule(futureChainlinkModuleProxyAddress, {
        ...(await txParams({
          hre,
          from: deployer,
          to: holographOperator,
          data: holographOperator.populateTransaction.setMessagingModule(futureChainlinkModuleProxyAddress),
        })),
      })
    );
    hre.deployments.log('Transaction hash:', chainlinkTx.hash);
    await chainlinkTx.wait();
    hre.deployments.log(`Registered MessagingModule to: ${await holographOperator.getMessagingModule()}`);
  } else {
    hre.deployments.log(`MessagingModule is already registered to: ${await holographOperator.getMessagingModule()}`);
  }

  const chainlinkModule = ((await hre.ethers.getContract('ChainlinkModule', deployer)) as Contract).attach(
    futureChainlinkModuleProxyAddress
  );

  // we check that ChainlinkModule has correct OptimismGasPriceOracle set
  if (
    (await chainlinkModule.getOptimismGasPriceOracle()).toLowerCase() !=
    futureOptimismGasPriceOracleAddress.toLowerCase()
  ) {
    const chainlinkOpTx = await MultisigAwareTx(
      hre,
      deployer,
      'ChainlinkModule',
      chainlinkModule,
      await chainlinkModule.populateTransaction.setOptimismGasPriceOracle(futureOptimismGasPriceOracleAddress, {
        ...(await txParams({
          hre,
          from: deployer,
          to: chainlinkModule,
          data: chainlinkModule.populateTransaction.setOptimismGasPriceOracle(futureOptimismGasPriceOracleAddress),
        })),
      })
    );
    hre.deployments.log('Transaction hash:', chainlinkOpTx.hash);
    await chainlinkOpTx.wait();
    hre.deployments.log(`Registered OptimismGasPriceOracle to: ${await chainlinkModule.getOptimismGasPriceOracle()}`);
  } else {
    hre.deployments.log(
      `OptimismGasPriceOracle is already registered to: ${await chainlinkModule.getOptimismGasPriceOracle()}`
    );
  }

  chainIds = [];
  gasParameters = [];

  hre.deployments.log(`Checking existing gas parameters`);
  for (let i = 0, l = supportedNetworks.length; i < l; i++) {
    let currentNetwork: Network = supportedNetworks[i];
    let currentGasParameters: BigNumber[] = await chainlinkModule.getGasParameters(currentNetwork.holographId);
    for (let i = 0; i < 6; i++) {
      if (currentNetwork.key in networkSpecificParams) {
        if (!networkSpecificParams[currentNetwork.key]![i].eq(currentGasParameters[i])) {
          chainIds.push(currentNetwork.holographId);
          gasParameters.push(networkSpecificParams[currentNetwork.key]!);
          if (currentNetwork.holographId == network.holographId) {
            chainIds.push(0);
            gasParameters.push(networkSpecificParams[currentNetwork.key]!);
          }
          break;
        }
      } else if (!defaultParams[i].eq(currentGasParameters[i])) {
        chainIds.push(currentNetwork.holographId);
        gasParameters.push(defaultParams);
        if (currentNetwork.holographId == network.holographId) {
          chainIds.push(0);
          gasParameters.push(defaultParams);
        }
        break;
      }
    }
  }
  if (chainIds.length > 0) {
    hre.deployments.log('Found some gas parameter inconsistencies');
    const chainlinkTx = await MultisigAwareTx(
      hre,
      deployer,
      'ChainlinkModule',
      chainlinkModule,
      await chainlinkModule.populateTransaction[
        'setGasParameters(uint32[],(uint256,uint256,uint256,uint256,uint256,uint256)[])'
      ](chainIds, gasParameters, {
        ...(await txParams({
          hre,
          from: deployer,
          to: chainlinkModule,
          data: chainlinkModule.populateTransaction[
            'setGasParameters(uint32[],(uint256,uint256,uint256,uint256,uint256,uint256)[])'
          ](chainIds, gasParameters),
        })),
      })
    );
    hre.deployments.log('Transaction hash:', chainlinkTx.hash);
    await chainlinkTx.wait();
    hre.deployments.log('Updated Chainlink GasParameters');
  }
};

export default func;
func.tags = ['ChainlinkModule'];
func.dependencies = ['HolographGenesis', 'DeploySources'];
