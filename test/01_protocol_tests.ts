import fs from 'fs';
import { expect, assert } from 'chai';
import { ethers, artifacts, deployments, network } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import Web3 from 'web3';
import { BigNumberish, BytesLike, ContractFactory, Contract } from 'ethers';

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
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
  MockERC721Receiver,
  PA1D,
  SampleERC20,
  SampleERC721,
  SecureStorage,
  SecureStorageProxy,
} from '../typechain-types';
import { utf8ToBytes32, ZERO_ADDRESS, sha256 } from '../scripts/utils/helpers';

const networks = JSON.parse(fs.readFileSync('./config/networks.json', 'utf8'));
const hre: HardhatRuntimeEnvironment = require('hardhat');
const web3 = new Web3();
const chainId = '0x' + networks[hre.network.name].holographId.toString(16).padStart(8, '0');

describe('Testing the Holograph protocol', () => {
  let deployer: SignerWithAddress;

  let wallet1: SignerWithAddress;
  let wallet2: SignerWithAddress;
  let wallet3: SignerWithAddress;
  let wallet4: SignerWithAddress;
  let wallet5: SignerWithAddress;
  let wallet6: SignerWithAddress;
  let wallet7: SignerWithAddress;
  let wallet8: SignerWithAddress;
  let wallet9: SignerWithAddress;
  let wallet10: SignerWithAddress;

  let cxipERC721: CxipERC721;
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
  let mockErc721Receiver: MockERC721Receiver;
  let pa1d: PA1D;
  let sampleErc20: SampleERC20;
  let sampleErc721: SampleERC721;
  let secureStorage: SecureStorage;
  let secureStorageProxy: SecureStorageProxy;

  before(async () => {
    const accounts = await ethers.getSigners();
    deployer = accounts[0];

    wallet1 = accounts[1];
    wallet2 = accounts[2];
    wallet3 = accounts[3];
    wallet4 = accounts[4];
    wallet5 = accounts[5];
    wallet6 = accounts[6];
    wallet7 = accounts[7];
    wallet8 = accounts[8];
    wallet9 = accounts[9];
    wallet10 = accounts[10];

    await deployments.fixture([
      'HolographGenesis',
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
    ]);

    // cxipERC721 = (await ethers.getContract('CxipERC721')) as CxipERC721;
    erc20Mock = (await ethers.getContract('ERC20Mock')) as ERC20Mock;
    holograph = (await ethers.getContract('Holograph')) as Holograph;
    holographBridge = (await ethers.getContract('HolographBridge')) as HolographBridge;
    holographBridgeProxy = (await ethers.getContract('HolographBridgeProxy')) as HolographBridgeProxy;
    // holographer = (await ethers.getContract('Holographer')) as Holographer;
    holographErc20 = (await ethers.getContract('HolographERC20')) as HolographERC20;
    holographErc721 = (await ethers.getContract('HolographERC721')) as HolographERC721;
    holographFactory = (await ethers.getContract('HolographFactory')) as HolographFactory;
    holographFactoryProxy = (await ethers.getContract('HolographFactoryProxy')) as HolographFactoryProxy;
    holographGenesis = (await ethers.getContract('HolographGenesis')) as HolographGenesis;
    holographRegistry = (await ethers.getContract('HolographRegistry')) as HolographRegistry;
    holographRegistryProxy = (await ethers.getContract('HolographRegistryProxy')) as HolographRegistryProxy;
    hToken = (await ethers.getContractOrNull('hToken')) as HToken;
    mockErc721Receiver = (await ethers.getContract('MockERC721Receiver')) as MockERC721Receiver;
    pa1d = (await ethers.getContract('PA1D')) as PA1D;
    // sampleErc20 = (await ethers.getContract('SampleERC20')) as SampleERC20;
    // sampleErc721 = (await ethers.getContract('SampleERC721')) as SampleERC721;
    secureStorage = (await ethers.getContract('SecureStorage')) as SecureStorage;
    secureStorageProxy = (await ethers.getContract('SecureStorageProxy')) as SecureStorageProxy;
  });

  beforeEach(async () => {});

  afterEach(async () => {});

  describe('Check that contract addresses are properly deployed', async () => {
    /*describe('CxipERC721', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [cxipERC721.address])).to.equal(
            (await artifacts.readArtifact('CxipERC721')).deployedBytecode
          );
        });
      });
    });*/
    describe('ERC20Mock', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [erc20Mock.address])).to.equal(
            (await artifacts.readArtifact('ERC20Mock')).deployedBytecode
          );
        });
      });
    });
    describe('Holograph', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [holograph.address])).to.equal(
            (await artifacts.readArtifact('Holograph')).deployedBytecode
          );
        });
      });
    });
    describe('HolographBridge', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [holographBridge.address])).to.equal(
            (await artifacts.readArtifact('HolographBridge')).deployedBytecode
          );
        });
      });
    });
    describe('HolographBridgeProxy', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [holographBridgeProxy.address])).to.equal(
            (await artifacts.readArtifact('HolographBridgeProxy')).deployedBytecode
          );
        });
      });
    });
    /*describe('Holographer', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [holographer.address])).to.equal(
            (await artifacts.readArtifact('Holographer')).deployedBytecode
          );
        });
      });
    });*/
    describe('HolographERC20', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [holographErc20.address])).to.equal(
            (await artifacts.readArtifact('HolographERC20')).deployedBytecode
          );
        });
      });
    });
    describe('HolographERC721', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [holographErc721.address])).to.equal(
            (await artifacts.readArtifact('HolographERC721')).deployedBytecode
          );
        });
      });
    });
    describe('HolographFactory', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [holographFactory.address])).to.equal(
            (await artifacts.readArtifact('HolographFactory')).deployedBytecode
          );
        });
      });
    });
    describe('HolographFactoryProxy', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [holographFactoryProxy.address])).to.equal(
            (await artifacts.readArtifact('HolographFactoryProxy')).deployedBytecode
          );
        });
      });
    });
    describe('HolographGenesis', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [holographGenesis.address])).to.equal(
            (await artifacts.readArtifact('HolographGenesis')).deployedBytecode
          );
        });
      });
    });
    describe('HolographRegistry', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [holographRegistry.address])).to.equal(
            (await artifacts.readArtifact('HolographRegistry')).deployedBytecode
          );
        });
      });
    });
    describe('HolographRegistryProxy', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [holographRegistryProxy.address])).to.equal(
            (await artifacts.readArtifact('HolographRegistryProxy')).deployedBytecode
          );
        });
      });
    });
    describe('hToken', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          const registry = holographRegistry.attach(holographRegistryProxy.address);
          const holographerAddress = await registry.getHToken(chainId);
          const holographer = (await ethers.getContractAt('Holographer', holographerAddress)) as Holographer;
          expect(await network.provider.send('eth_getCode', [await holographer.getSourceContract()])).to.equal(
            (await artifacts.readArtifact('hToken')).deployedBytecode
          );
        });
      });
    });
    describe('MockERC721Receiver', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [mockErc721Receiver.address])).to.equal(
            (await artifacts.readArtifact('MockERC721Receiver')).deployedBytecode
          );
        });
      });
    });
    describe('PA1D', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [pa1d.address])).to.equal(
            (await artifacts.readArtifact('PA1D')).deployedBytecode
          );
        });
      });
    });
    /*describe('SampleERC20', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [sampleErc20.address])).to.equal(
            (await artifacts.readArtifact('SampleERC20')).deployedBytecode
          );
        });
      });
    });*/
    /*describe('SampleERC721', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [sampleErc721.address])).to.equal(
            (await artifacts.readArtifact('SampleERC721')).deployedBytecode
          );
        });
      });
    });*/
    describe('SecureStorage', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [secureStorage.address])).to.equal(
            (await artifacts.readArtifact('SecureStorage')).deployedBytecode
          );
        });
      });
    });
    describe('SecureStorageProxy', async function () {
      context('check deployed bytecode', async function () {
        it('returns correct bytecode', async function () {
          expect(await network.provider.send('eth_getCode', [secureStorageProxy.address])).to.equal(
            (await artifacts.readArtifact('SecureStorageProxy')).deployedBytecode
          );
        });
      });
    });
  });
});
