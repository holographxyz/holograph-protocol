declare var global: any;
import fs from 'fs';
import Web3 from 'web3';
import { BigNumberish, BytesLike, ContractFactory, Contract } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from '@holographxyz/hardhat-deploy-holographed/types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
  LeanHardhatRuntimeEnvironment,
  Signature,
  hreSplit,
  zeroAddress,
  StrictECDSA,
  generateErc20Config,
  genesisDeployHelper,
  generateInitCode,
  genesisDeriveFutureAddress,
  remove0x,
  txParams,
} from '../scripts/utils/helpers';
import { MultisigAwareTx } from '../scripts/utils/multisig-aware-tx';
import { HolographERC20Event, ConfigureEvents, AllEventsEnabled } from '../scripts/utils/events';
import { NetworkType, Network, networks } from '@holographxyz/networks';
import { SuperColdStorageSigner } from 'super-cold-storage-signer';

interface HTokenData {
  primaryNetwork: Network;
  tokenSymbol: string;
  supportedNetworks: Network[];
}

const MAX_RETRIES = 3; // Number of maximum retries for the "already known" error.
const RETRY_DELAY = 2000; // Delay between retries in milliseconds.
const GAS_PRICE_INCREMENT_PERCENT = 20; // Increment the gas price by 20% for retries.

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork);
  const accounts = await hre.ethers.getSigners();
  let deployer: SignerWithAddress | SuperColdStorageSigner = accounts[0];

  const web3 = new Web3();
  const salt = hre.deploymentSalt;

  // HToken Address is the address of the hToken contract
  // while HolographedAddress is the address of the holographed token contract such as hETH
  const futureHTokenAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'hToken',
    generateInitCode(['address', 'uint16'], [deployer.address, 0])
  );
  hre.deployments.log('the future "hToken" address is', futureHTokenAddress);

  // hToken
  let hTokenDeployedCode: string = await hre.provider.send('eth_getCode', [futureHTokenAddress, 'latest']);
  if (hTokenDeployedCode == '0x' || hTokenDeployedCode == '') {
    hre.deployments.log('"hToken" bytecode not found, need to deploy"');
    let holographErc20 = await genesisDeployHelper(
      hre,
      salt,
      'hToken',
      generateInitCode(['address', 'uint16'], [deployer.address, 0]),
      futureHTokenAddress
    );
  } else {
    hre.deployments.log('"hToken" is already deployed.');
  }

  const network = networks[hre.networkName];

  const holograph = await hre.ethers.getContract('Holograph', deployer);

  const factory = (await hre.ethers.getContractAt(
    'HolographFactory',
    await holograph.getFactory(),
    deployer
  )) as Contract;

  const registry = (await hre.ethers.getContractAt(
    'HolographRegistry',
    await holograph.getRegistry(),
    deployer
  )) as Contract;

  const holographerBytecode: BytesLike = (await hre.ethers.getContractFactory('Holographer')).bytecode;

  const currentNetworkType: NetworkType = network.type;
  let hTokens: HTokenData[] = [];
  let primaryNetwork: Network;
  if (currentNetworkType == NetworkType.local) {
    primaryNetwork = networks.localhost;
    hTokens = [
      {
        primaryNetwork: networks.localhost,
        tokenSymbol: 'ETH',
        supportedNetworks: [networks.localhost, networks.localhost2],
      },
    ];
  } else if (currentNetworkType == NetworkType.testnet) {
    primaryNetwork = networks.ethereumTestnetGoerli;
    hTokens = [
      {
        primaryNetwork: networks.ethereumTestnetGoerli,
        tokenSymbol: 'ETH',
        supportedNetworks: [
          networks.arbitrumTestnetGoerli,
          networks.baseTestnetGoerli,
          networks.ethereumTestnetGoerli,
          networks.optimismTestnetGoerli,
          networks.zoraTestnetGoerli,
        ],
      },
      {
        primaryNetwork: networks.avalancheTestnet,
        tokenSymbol: 'AVAX',
        supportedNetworks: [networks.avalancheTestnet],
      },
      {
        primaryNetwork: networks.binanceSmartChainTestnet,
        tokenSymbol: 'BNB',
        supportedNetworks: [networks.binanceSmartChainTestnet],
      },
      {
        primaryNetwork: networks.mantleTestnet,
        tokenSymbol: 'MNT',
        supportedNetworks: [networks.mantleTestnet],
      },
      {
        primaryNetwork: networks.polygonTestnet,
        tokenSymbol: 'MATIC',
        supportedNetworks: [networks.polygonTestnet],
      },
    ];
  } else if (currentNetworkType == NetworkType.mainnet) {
    primaryNetwork = networks.ethereum;
    hTokens = [
      {
        primaryNetwork: networks.ethereum,
        tokenSymbol: 'ETH',
        supportedNetworks: [
          networks.arbitrumOne,
          networks.arbitrumNova,
          networks.base,
          networks.ethereum,
          networks.optimism,
          networks.zora,
        ],
      },
      {
        primaryNetwork: networks.avalanche,
        tokenSymbol: 'AVAX',
        supportedNetworks: [networks.avalanche],
      },
      {
        primaryNetwork: networks.binanceSmartChain,
        tokenSymbol: 'BNB',
        supportedNetworks: [networks.binanceSmartChain],
      },
      {
        primaryNetwork: networks.mantle,
        tokenSymbol: 'MNT',
        supportedNetworks: [networks.mantle],
      },
      {
        primaryNetwork: networks.polygon,
        tokenSymbol: 'MATIC',
        supportedNetworks: [networks.polygon],
      },
    ];
  } else {
    throw new Error('cannot identity current NetworkType');
  }

  const hTokenDeployer = async function (
    holograph: Contract,
    factory: Contract,
    registry: Contract,
    holographerBytecode: BytesLike,
    data: HTokenData
  ) {
    console.log(`Deploying hToken for ${data.tokenSymbol} on ${data.primaryNetwork.name}`);
    const hTokenHash = '0x' + web3.utils.asciiToHex('hToken').substring(2).padStart(64, '0');
    const chainId = '0x' + data.primaryNetwork.holographId.toString(16).padStart(8, '0');
    let { erc20Config, erc20ConfigHash, erc20ConfigHashBytes } = await generateErc20Config(
      data.primaryNetwork,
      `0x21Ab3Aa7053A3615E02d4aC517B7075b45BF524f`, // NOTE: This is the hot wallet deployer
      'hTokenProxy',
      'Holographed ' + data.tokenSymbol,
      'h' + data.tokenSymbol,
      'Holographed ' + data.tokenSymbol,
      '1',
      18,
      ConfigureEvents([]),
      generateInitCode(
        ['bytes32', 'address', 'bytes'],
        [
          hTokenHash,
          registry.address,
          generateInitCode(
            ['address', 'uint16'],
            [`0x21Ab3Aa7053A3615E02d4aC517B7075b45BF524f` /*  // NOTE: This is the hot wallet deployer */, 0]
          ),
        ]
      ),
      salt
    );

    const futureHolographedTokenAddress = hre.ethers.utils.getCreate2Address(
      factory.address,
      erc20ConfigHash,
      hre.ethers.utils.keccak256(holographerBytecode)
    );
    hre.deployments.log('the future "h' + data.tokenSymbol + '" address is', futureHolographedTokenAddress);

    let hTokenDeployedCode: string = await hre.provider.send('eth_getCode', [futureHolographedTokenAddress, 'latest']);
    if (hTokenDeployedCode == '0x' || hTokenDeployedCode == '') {
      hre.deployments.log('need to deploy "hToken ' + data.tokenSymbol + '"');

      const sig = await deployer.signMessage(erc20ConfigHashBytes);
      const signature: Signature = StrictECDSA({
        r: '0x' + sig.substring(2, 66),
        s: '0x' + sig.substring(66, 130),
        v: '0x' + sig.substring(130, 132),
      } as Signature);

      const deployTx = await factory.deployHolographableContract(erc20Config, signature, deployer.address, {
        ...(await txParams({
          hre,
          from: deployer,
          to: factory,
          data: factory.populateTransaction.deployHolographableContract(erc20Config, signature, deployer.address),
        })),
      });
      const deployResult = await deployTx.wait();
      let eventIndex: number = 0;
      let eventFound: boolean = false;
      for (let i = 0, l = deployResult.events.length; i < l; i++) {
        let e = deployResult.events[i];
        if (e.event == 'BridgeableContractDeployed') {
          eventFound = true;
          eventIndex = i;
          break;
        }
      }
      if (!eventFound) {
        throw new Error('BridgeableContractDeployed event not fired');
      }
      let hTokenAddress = deployResult.events[eventIndex].args[0];
      if (hTokenAddress != futureHolographedTokenAddress) {
        throw new Error(
          `Seems like hTokenAddress ${hTokenAddress} and futureHolographedTokenAddress ${futureHolographedTokenAddress} do not match!`
        );
      }
      hre.deployments.log('deployed "hToken ' + data.tokenSymbol + '" at:', hTokenAddress);
    } else {
      hre.deployments.log('reusing "hToken ' + data.tokenSymbol + '" at:', futureHolographedTokenAddress);
    }

    const hToken = ((await hre.ethers.getContract('hToken', deployer)) as Contract).attach(
      futureHolographedTokenAddress
    );

    // NOTE: Since the factory is the owner of the contract we bypass the multisig aware tx and use the signer directly.
    for (let network of data.supportedNetworks) {
      console.log(`Checking if ${network.chain.toString()} is supported`);
      let nonce = await hre.ethers.provider.getTransactionCount(deployer.address, 'latest');
      let retries = 0;
      let gasPrice = await hre.ethers.provider.getGasPrice();

      while (retries < MAX_RETRIES) {
        try {
          // Your original logic...
          if (!(await hToken.isSupportedChain(network.chain))) {
            hre.deployments.log('Need to add ' + network.chain.toString() + ' as supported chain');
            const hTokenWithSigner = hToken.connect(deployer);
            const tx = await hTokenWithSigner.updateSupportedChain(network.chain, true, {
              nonce: nonce,
              gasPrice: gasPrice,
            });
            await tx.wait();
            hre.deployments.log(`Transaction mined: ${tx.hash}`);
            hre.deployments.log('Set ' + network.chain.toString() + ' as supported chain');
            break;
          } else {
            hre.deployments.log('Chain ' + network.chain.toString() + ' is already supported');
            break;
          }
        } catch (error) {
          if (error.message.includes('replacement fee too low')) {
            hre.deployments.log('Encountered "replacement fee too low" error. Retrying with higher gas price...');
            retries++;

            // Increase the gas price by a certain percentage for the next attempt.
            gasPrice = gasPrice.add(gasPrice.mul(GAS_PRICE_INCREMENT_PERCENT).div(100));
            await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY)); // Wait before retrying.
          } else if (error.message.includes('already known')) {
            // Handle the "already known" error as previously discussed.
            hre.deployments.log('Encountered "already known" error. Retrying with incremented nonce...');
            retries++;
            nonce++;
            await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY));
          } else {
            // For any other errors, you might want to throw or handle them differently.
            throw error;
          }
        }
      }

      if (retries === MAX_RETRIES) {
        throw new Error('Max retries reached without success.');
      }

      // NOTE: This can only be done on develop, but must switch to testnet deployer key.
      // On other networks this must be a multisig tx
      // const chain = '0x' + network.holographId.toString(16).padStart(8, '0');
      // if ((await registry.getHToken(chain)) != futureHolographedTokenAddress) {
      //   hre.deployments.log(
      //     'Updated "Registry" with "hToken ' +
      //       data.tokenSymbol +
      //       '" for holographChainId #' +
      //       Number.parseInt(chain).toString()
      //   );
      //   const setHTokenTx = await MultisigAwareTx(
      //     hre,
      //     deployer,
      //     'HolographRegistry',
      //     registry,
      //     await registry.populateTransaction.setHToken(chain, futureHolographedTokenAddress, {
      //       ...(await txParams({
      //         hre,
      //         from: deployer,
      //         to: registry,
      //         data: registry.populateTransaction.setHToken(chain, futureHolographedTokenAddress),
      //       })),
      //     })
      //   );
      //   await setHTokenTx.wait();
    }
  };

  for (let hToken of hTokens) {
    await hTokenDeployer(holograph, factory, registry, holographerBytecode, hToken);
  }
};

export default func;
func.tags = ['TEMP_HTOKEN_UPGRADE'];
func.dependencies = [];
