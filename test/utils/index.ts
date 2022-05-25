declare var global: any;
import fs from 'fs';
import { expect, assert } from 'chai';
import { EthereumProvider, Artifacts, HardhatRuntimeEnvironment } from 'hardhat/types';
import { Address, Deployment, DeploymentsExtension } from 'hardhat-deploy-holographed/types';
import Web3 from 'web3';
import { BigNumberish, BytesLike, ContractFactory, Contract } from 'ethers';
import type { ethers } from 'ethers';
import type EthersT from 'ethers';
import { HardhatEthersHelpers } from '@nomiclabs/hardhat-ethers/types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
  Admin,
  CxipERC721,
  ERC20Mock,
  Holograph,
  HolographBridge,
  HolographBridgeProxy,
  Holographer,
  HolographERC20,
  HolographERC721,
  HolographFactory,
  HolographFactoryProxy,
  HolographGenesis,
  HolographRegistry,
  HolographRegistryProxy,
  HToken,
  Interfaces,
  MockERC721Receiver,
  Owner,
  PA1D,
  SampleERC20,
  SampleERC721,
  SecureStorage,
  SecureStorageProxy,
} from '../../typechain-types';
import {
  LeanHardhatRuntimeEnvironment,
  Network,
  Networks,
  l2Ethers,
  hreSplit,
  utf8ToBytes32,
  ZERO_ADDRESS,
  sha256,
  getHolographedContractHash,
  generateInitCode,
} from '../../scripts/utils/helpers';

let hre1: HardhatRuntimeEnvironment = require('hardhat');
const networks: Networks = JSON.parse(fs.readFileSync('./config/networks.json', 'utf8')) as Networks;

export interface PreTest {
  hre: LeanHardhatRuntimeEnvironment;
  hre2: LeanHardhatRuntimeEnvironment;
  networks: Networks;
  network: Network;
  network2: Network;
  web3: Web3;
  chainId: BytesLike;
  chainId2: BytesLike;
  deployer: SignerWithAddress;
  wallet1: SignerWithAddress;
  wallet2: SignerWithAddress;
  wallet3: SignerWithAddress;
  wallet4: SignerWithAddress;
  wallet5: SignerWithAddress;
  wallet6: SignerWithAddress;
  wallet7: SignerWithAddress;
  wallet8: SignerWithAddress;
  wallet9: SignerWithAddress;
  wallet10: SignerWithAddress;
  admin: Admin;
  cxipErc721: CxipERC721;
  erc20Mock: ERC20Mock;
  holograph: Holograph;
  holographBridge: HolographBridge;
  holographBridgeProxy: HolographBridgeProxy;
  holographer: Holographer;
  holographErc20: HolographERC20;
  holographErc721: HolographERC721;
  holographFactory: HolographFactory;
  holographFactoryProxy: HolographFactoryProxy;
  holographGenesis: HolographGenesis;
  holographRegistry: HolographRegistry;
  holographRegistryProxy: HolographRegistryProxy;
  hToken: HToken;
  interfaces: Interfaces;
  mockErc721Receiver: MockERC721Receiver;
  owner: Owner;
  pa1d: PA1D;
  sampleErc20: SampleERC20;
  sampleErc721: SampleERC721;
  secureStorage: SecureStorage;
  secureStorageProxy: SecureStorageProxy;
  registry: HolographRegistry;
  factory: HolographFactory;
  bridge: HolographBridge;
  hTokenHolographer: Holographer;
  hTokenEnforcer: HolographERC20;
  sampleErc20Holographer: Holographer;
  sampleErc20Enforcer: HolographERC20;
  sampleErc721Holographer: Holographer;
  sampleErc721Enforcer: HolographERC721;
  cxipErc721Holographer: Holographer;
  cxipErc721Enforcer: HolographERC721;
}

const animatedLoader = function (text: string) {
  process.stdout.write('\n');
  const symbols: string[] = ['▄▄▄', '▄▄■', '▄■▀', '■▀▀', '▀▀▀', '▀▀■', '▀■▄', '■▄▄'];
  let counter: number = 0;
  return setInterval(() => {
    let symbol: string = symbols[counter];
    counter++;
    if (counter == symbols.length) {
      counter = 0;
    }
    process.stdout.write('    ' + '\x1b[33m' + symbol + '\x1b[0m' + text + '\x1b[0m' + '\r');
  }, 100);
};

export default async function (l2?: boolean): Promise<PreTest> {
  const web3 = new Web3();
  let { hre, hre2 } = hreSplit(hre1, l2);
  const network: Network = networks[hre.networkName];
  const network2: Network = networks[hre2.networkName];
  const chainId: BytesLike = '0x' + network.holographId.toString(16).padStart(8, '0');
  const chainId2: BytesLike = '0x' + network2.holographId.toString(16).padStart(8, '0');
  const fixtures: string[] = [
    'HolographGenesis',
    'Interfaces',
    'HolographRegistry',
    'HolographRegistryProxy',
    'SecureStorage',
    'SecureStorageProxy',
    'HolographFactory',
    'HolographFactoryProxy',
    'HolographBridge',
    'HolographBridgeProxy',
    'Holograph',
    'PA1D',
    'HolographERC20',
    'HolographERC721',
    'ERC20Mock',
    'MockERC721Receiver',
    'RegisterTemplates',
    'hToken',
    'SampleERC20',
    'SampleERC721',
    'CxipERC721',
  ];

  let loop = animatedLoader('\x1b[2m' + ' loading/deploying relevant contracts');
  global.__throttled = false;
  await hre.deployments.fixture(fixtures);
  global.__throttled = false;
  clearInterval(loop);
  process.stdout.write(
    '    ' + '\x1b[32m' + '███' + '\x1b[0m' + '\x1b[2m' + ' relevant contracts loaded           ' + '\x1b[0m' + '\n\n'
  );

  const accounts = await hre.ethers.getSigners();
  const deployer: SignerWithAddress = accounts[0];
  const wallet1: SignerWithAddress = accounts[1];
  const wallet2: SignerWithAddress = accounts[2];
  const wallet3: SignerWithAddress = accounts[3];
  const wallet4: SignerWithAddress = accounts[4];
  const wallet5: SignerWithAddress = accounts[5];
  const wallet6: SignerWithAddress = accounts[6];
  const wallet7: SignerWithAddress = accounts[7];
  const wallet8: SignerWithAddress = accounts[8];
  const wallet9: SignerWithAddress = accounts[9];
  const wallet10: SignerWithAddress = accounts[10];

  let admin: Admin;
  let cxipErc721: CxipERC721;
  let erc20Mock: ERC20Mock;
  let holograph: Holograph;
  let holographBridge: HolographBridge;
  let holographBridgeProxy: HolographBridgeProxy;
  let holographer: Holographer;
  let holographErc20: HolographERC20;
  let holographErc721: HolographERC721;
  let holographFactory: HolographFactory;
  let holographFactoryProxy: HolographFactoryProxy;
  let holographGenesis: HolographGenesis;
  let holographRegistry: HolographRegistry;
  let holographRegistryProxy: HolographRegistryProxy;
  let hToken: HToken;
  let interfaces: Interfaces;
  let mockErc721Receiver: MockERC721Receiver;
  let owner: Owner;
  let pa1d: PA1D;
  let sampleErc20: SampleERC20;
  let sampleErc721: SampleERC721;
  let secureStorage: SecureStorage;
  let secureStorageProxy: SecureStorageProxy;

  let registry: HolographRegistry;
  let factory: HolographFactory;
  let bridge: HolographBridge;

  let hTokenHolographer: Holographer;
  let hTokenEnforcer: HolographERC20;
  let sampleErc20Holographer: Holographer;
  let sampleErc20Enforcer: HolographERC20;
  let sampleErc721Holographer: Holographer;
  let sampleErc721Enforcer: HolographERC721;
  let cxipErc721Holographer: Holographer;
  let cxipErc721Enforcer: HolographERC721;

  let hTokenHash: BytesLike;
  let sampleErc20Hash: BytesLike;
  let sampleErc721Hash: BytesLike;
  let cxipErc721Hash: BytesLike;

  admin = (await hre.ethers.getContractOrNull('Admin')) as Admin;
  cxipErc721 = (await hre.ethers.getContractOrNull('CxipERC721')) as CxipERC721;
  erc20Mock = (await hre.ethers.getContract('ERC20Mock')) as ERC20Mock;
  holograph = (await hre.ethers.getContract('Holograph')) as Holograph;
  holographBridge = (await hre.ethers.getContract('HolographBridge')) as HolographBridge;
  holographBridgeProxy = (await hre.ethers.getContract('HolographBridgeProxy')) as HolographBridgeProxy;
  // holographer = (await hre.ethers.getContractOrNull('Holographer')) as Holographer;
  holographErc20 = (await hre.ethers.getContract('HolographERC20')) as HolographERC20;
  holographErc721 = (await hre.ethers.getContract('HolographERC721')) as HolographERC721;
  holographFactory = (await hre.ethers.getContract('HolographFactory')) as HolographFactory;
  holographFactoryProxy = (await hre.ethers.getContract('HolographFactoryProxy')) as HolographFactoryProxy;
  holographGenesis = (await hre.ethers.getContract('HolographGenesis')) as HolographGenesis;
  holographRegistry = (await hre.ethers.getContract('HolographRegistry')) as HolographRegistry;
  holographRegistryProxy = (await hre.ethers.getContract('HolographRegistryProxy')) as HolographRegistryProxy;
  // hToken = (await hre.ethers.getContractOrNull('hToken')) as HToken;
  interfaces = (await hre.ethers.getContractOrNull('Interfaces')) as Interfaces;
  mockErc721Receiver = (await hre.ethers.getContract('MockERC721Receiver')) as MockERC721Receiver;
  owner = (await hre.ethers.getContractOrNull('Owner')) as Owner;
  pa1d = (await hre.ethers.getContract('PA1D')) as PA1D;
  // sampleErc20 = (await hre.ethers.getContractOrNull('SampleERC20')) as SampleERC20;
  // sampleErc721 = (await hre.ethers.getContractOrNull('SampleERC721')) as SampleERC721;
  secureStorage = (await hre.ethers.getContract('SecureStorage')) as SecureStorage;
  secureStorageProxy = (await hre.ethers.getContract('SecureStorageProxy')) as SecureStorageProxy;

  bridge = holographBridge.attach(await holograph.getBridge()) as HolographBridge;
  factory = holographFactory.attach(await holograph.getFactory()) as HolographFactory;
  registry = holographRegistry.attach(await holograph.getRegistry()) as HolographRegistry;

  holographer = (await hre.ethers.getContractAt('Holographer', await registry.getHToken(chainId))) as Holographer;

  hTokenHash = await getHolographedContractHash(
    deployer.address,
    'hToken', // contractName
    'HolographERC20', // contractType
    chainId, // chainId
    '0x' + '00'.repeat(32), // salt
    generateInitCode(
      ['string', 'string', 'uint8', 'uint256', 'string', 'string', 'bool', 'bytes'],
      [
        network.tokenName + ' (Holographed)', // string memory contractName
        'h' + network.tokenSymbol, // string memory contractSymbol
        18, // uint8 contractDecimals
        '0x' + '00'.repeat(32), // uint256 eventConfig
        network.tokenName + ' (Holographed)', // string domainSeperator
        '1', // string domainVersion
        false, // bool skipInit
        generateInitCode(
          ['address', 'uint16'],
          [
            deployer.address, // owner
            0, // fee (bps)
          ]
        ),
      ]
    )
  );
  hTokenHolographer = (await hre.ethers.getContractAt(
    'Holographer',
    await registry.getHolographedHashAddress(hTokenHash)
  )) as Holographer;
  hTokenEnforcer = (await hre.ethers.getContractAt(
    'HolographERC20',
    await hTokenHolographer.getHolographEnforcer()
  )) as HolographERC20;
  hToken = (await hre.ethers.getContractAt('hToken', await hTokenHolographer.getSourceContract())) as HToken;

  sampleErc20Hash = await getHolographedContractHash(
    deployer.address,
    'SampleERC20', // contractName
    'HolographERC20', // contractType
    chainId, // chainId
    '0x' + '00'.repeat(32), // salt
    generateInitCode(
      ['string', 'string', 'uint8', 'uint256', 'string', 'string', 'bool', 'bytes'],
      [
        'Sample ERC20 Token (' + hre.networkName + ')', // string memory contractName
        'SMPL', // string memory contractSymbol
        18, // uint8 contractDecimals
        '0x' + '00'.repeat(32), // uint256 eventConfig
        'Sample ERC20 Token', // string domainSeperator
        '1', // string domainVersion
        false, // bool skipInit
        generateInitCode(
          ['address', 'uint16'],
          [
            deployer.address, // owner
            0, // fee (bps)
          ]
        ),
      ]
    )
  );
  sampleErc20Holographer = (await hre.ethers.getContractAt(
    'Holographer',
    await registry.getHolographedHashAddress(sampleErc20Hash)
  )) as Holographer;
  sampleErc20Enforcer = (await hre.ethers.getContractAt(
    'HolographERC20',
    await sampleErc20Holographer.getHolographEnforcer()
  )) as HolographERC20;
  sampleErc20 = (await hre.ethers.getContractAt(
    'SampleERC20',
    await sampleErc20Holographer.getSourceContract()
  )) as SampleERC20;

  sampleErc721Hash = await getHolographedContractHash(
    deployer.address,
    'SampleERC721', // contractName
    'HolographERC721', // contractType
    chainId, // chainId
    '0x' + '00'.repeat(32), // salt
    generateInitCode(
      ['string', 'string', 'uint16', 'uint256', 'bool', 'bytes'],
      [
        'Sample ERC721 Contract (' + hre.networkName + ')', // string memory contractName
        'SMPLR', // string memory contractSymbol
        1000, // uint16 contractBps
        '0x' + '00'.repeat(32), // uint256 eventConfig
        false, // bool skipInit
        generateInitCode(
          ['address'],
          [
            deployer.address, // owner
          ]
        ),
      ]
    )
  );
  sampleErc721Holographer = (await hre.ethers.getContractAt(
    'Holographer',
    await registry.getHolographedHashAddress(sampleErc721Hash)
  )) as Holographer;
  sampleErc721Enforcer = (await hre.ethers.getContractAt(
    'HolographERC721',
    await sampleErc721Holographer.getHolographEnforcer()
  )) as HolographERC721;
  sampleErc721 = (await hre.ethers.getContractAt(
    'SampleERC721',
    await sampleErc721Holographer.getSourceContract()
  )) as SampleERC721;

  cxipErc721Hash = await getHolographedContractHash(
    deployer.address,
    'CxipERC721', // contractName
    'HolographERC721', // contractType
    chainId, // chainId
    '0x' + '00'.repeat(32), // salt
    generateInitCode(
      ['string', 'string', 'uint16', 'uint256', 'bool', 'bytes'],
      [
        'CXIP ERC721 Collection (' + hre.networkName + ')', // string memory contractName
        'CXIP', // string memory contractSymbol
        1000, // uint16 contractBps
        '0x' + '00'.repeat(32), // uint256 eventConfig
        false, // bool skipInit
        generateInitCode(
          ['address'],
          [
            deployer.address, // owner
          ]
        ),
      ]
    )
  );
  cxipErc721Holographer = (await hre.ethers.getContractAt(
    'Holographer',
    await registry.getHolographedHashAddress(cxipErc721Hash)
  )) as Holographer;
  cxipErc721Enforcer = (await hre.ethers.getContractAt(
    'HolographERC721',
    await cxipErc721Holographer.getHolographEnforcer()
  )) as HolographERC721;
  cxipErc721 = (await hre.ethers.getContractAt(
    'CxipERC721',
    await cxipErc721Holographer.getSourceContract()
  )) as CxipERC721;

  return {
    hre,
    hre2,
    networks,
    network,
    network2,
    web3,
    chainId,
    chainId2,
    deployer,
    wallet1,
    wallet2,
    wallet3,
    wallet4,
    wallet5,
    wallet6,
    wallet7,
    wallet8,
    wallet9,
    wallet10,
    admin,
    cxipErc721,
    erc20Mock,
    holograph,
    holographBridge,
    holographBridgeProxy,
    holographer,
    holographErc20,
    holographErc721,
    holographFactory,
    holographFactoryProxy,
    holographGenesis,
    holographRegistry,
    holographRegistryProxy,
    hToken,
    interfaces,
    mockErc721Receiver,
    owner,
    pa1d,
    sampleErc20,
    sampleErc721,
    secureStorage,
    secureStorageProxy,
    registry,
    factory,
    bridge,
    hTokenHolographer,
    hTokenEnforcer,
    sampleErc20Holographer,
    sampleErc20Enforcer,
    sampleErc721Holographer,
    sampleErc721Enforcer,
    cxipErc721Holographer,
    cxipErc721Enforcer,
  } as PreTest;
}
