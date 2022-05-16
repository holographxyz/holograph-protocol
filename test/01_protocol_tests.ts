import { expect, assert } from 'chai';
import { ethers, deployments } from 'hardhat';
import Web3 from 'web3';
import { BigNumberish, BytesLike, ContractFactory } from 'ethers';

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

const web3 = new Web3();

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
        ]);

        //    cxipERC721 = (await ethers.getContract('CxipERC721')) as CxipERC721;
        erc20Mock = (await ethers.getContract('ERC20Mock')) as ERC20Mock;
        holograph = (await ethers.getContract('Holograph')) as Holograph;
        holographBridge = (await ethers.getContract('HolographBridge')) as HolographBridge;
        holographBridgeProxy = (await ethers.getContract('HolographBridgeProxy')) as HolographBridgeProxy;
        //    holographer = (await ethers.getContract('Holographer')) as Holographer;
        holographErc20 = (await ethers.getContract('HolographERC20')) as HolographERC20;
        holographErc721 = (await ethers.getContract('HolographERC721')) as HolographERC721;
        holographFactory = (await ethers.getContract('HolographFactory')) as HolographFactory;
        holographFactoryProxy = (await ethers.getContract('HolographFactoryProxy')) as HolographFactoryProxy;
        holographGenesis = (await ethers.getContract('HolographGenesis')) as HolographGenesis;
        holographRegistry = (await ethers.getContract('HolographRegistry')) as HolographRegistry;
        holographRegistryProxy = (await ethers.getContract('HolographRegistryProxy')) as HolographRegistryProxy;
        //    hToken = (await ethers.getContract('hToken')) as HToken;
        mockErc721Receiver = (await ethers.getContract('MockERC721Receiver')) as MockERC721Receiver;
        pa1d = (await ethers.getContract('PA1D')) as PA1D;
        //    sampleErc20 = (await ethers.getContract('SampleERC20')) as SampleERC20;
        //    sampleErc721 = (await ethers.getContract('SampleERC721')) as SampleERC721;
        secureStorage = (await ethers.getContract('SecureStorage')) as SecureStorage;
        secureStorageProxy = (await ethers.getContract('SecureStorageProxy')) as SecureStorageProxy;
    });

    beforeEach(async () => {});

    afterEach(async () => {});

    describe('Check contract addresses', async () => {
        it('should not be empty', async () => {
            expect(erc20Mock.address != '', 'erc20Mock.address = ' + erc20Mock.address).to.be.true;
            expect(holograph.address != '', 'holograph.address = ' + holograph.address).to.be.true;
            expect(holographBridge.address != '', 'holographBridge.address = ' + holographBridge.address).to.be.true;
            expect(holographBridgeProxy.address != '', 'holographBridgeProxy.address = ' + holographBridgeProxy.address)
                .to.be.true;
            expect(holographErc20.address != '', 'holographErc20.address = ' + holographErc20.address).to.be.true;
            expect(holographErc721.address != '', 'holographErc721.address = ' + holographErc721.address).to.be.true;
            expect(holographFactory.address != '', 'holographFactory.address = ' + holographFactory.address).to.be.true;
            expect(
                holographFactoryProxy.address != '',
                'holographFactoryProxy.address = ' + holographFactoryProxy.address
            ).to.be.true;
            expect(holographGenesis.address != '', 'holographGenesis.address = ' + holographGenesis.address).to.be.true;
            expect(holographRegistry.address != '', 'holographRegistry.address = ' + holographRegistry.address).to.be
                .true;
            expect(
                holographRegistryProxy.address != '',
                'holographRegistryProxy.address = ' + holographRegistryProxy.address
            ).to.be.true;
            expect(mockErc721Receiver.address != '', 'mockErc721Receiver.address = ' + mockErc721Receiver.address).to.be
                .true;
            expect(pa1d.address != '', 'pa1d.address = ' + pa1d.address).to.be.true;
            expect(secureStorage.address != '', 'secureStorage.address = ' + secureStorage.address).to.be.true;
            expect(secureStorageProxy.address != '', 'secureStorageProxy.address = ' + secureStorageProxy.address).to.be
                .true;
        });
    });
});
