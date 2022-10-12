import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { generateInitCode, zeroAddress } from '../scripts/utils/helpers';

describe('Holograph Interfaces Contract', async function () {
    let HolographInterfaces: any;
    let holographInterfaces: any;
    let accounts: SignerWithAddress[];
    let deployer: SignerWithAddress;
    let newDeployer: SignerWithAddress;
    let anotherNewDeployer: SignerWithAddress;

    let factoryAddr: string;
    let holographAddr: string;
    let operatorAddr: string;
    let registryAddr: string;
    let utilityTokenAddr: string;

    before(async () => {
        accounts = await ethers.getSigners();
        deployer = accounts[0];
        newDeployer = accounts[1];
        anotherNewDeployer = accounts[2];

        factoryAddr = '0x1Ce073E0A6912dBEAc4A1bE1C46186828fc8e0DD'; // NOTE: sample Address
        holographAddr = '0x0Ab35331cc5130DD52e51a9014069f18b8B5EDF9'; // NOTE: sample Address
        operatorAddr = '0xb197381F633db828a10821Ab4B6827ed5d81BC95'; // NOTE: sample Address
        registryAddr = '0xeB721f3E4C45a41fBdF701c8143E52665e67c76b'; // NOTE: sample Address
        utilityTokenAddr = '0x4b02422DC46bb21D657A701D02794cD3Caeb17d0'; // NOTE: sample Address

        HolographInterfaces = await ethers.getContractFactory('HolographInterfaces');
        holographInterfaces = await HolographInterfaces.deploy();
        await holographInterfaces.deployed();
    });

    describe('constructor', async function () {
        it('should successfully deploy')
    })

    describe.only('init()', async function() {
        it('should successfully be initialized once', async function() {
            const initCode = generateInitCode(['address'], [deployer.address]);
            await expect(holographInterfaces.connect(deployer).init(initCode)).to.not.be.reverted;
        })
        it('should fail if already initialized', async function() {
            const initCode = generateInitCode(['address'], [deployer.address]);
            await expect(holographInterfaces.connect(deployer).init(initCode)).to.be.reverted;
        });
        it('Should allow external contract to call fn')
        it('should fail to allow inherited contract to call fn')
    })

    describe(`contractURI()`, async function() {
        it('should successfully get contract URI')
        it('Should allow external contract to call fn')
        it('should fail to allow inherited contract to call fn')
    })

    describe(`getUriPrepend()`, async function() {
        it('should get expected prepend value')
        it('Should allow external contract to call fn')
        it('should fail to allow inherited contract to call fn')
    })

    describe('updateUriPrepend(uriTypes,string)', async function() {
        it('should allow admin to alter _prependURI')
        it('should fail to allow owner to alter _prependURI')
        it('should fail to allow non-owner to alter _prependURI')
    })

    describe('updateUriPrepends(uriTypes, string[])', async function() {
        it('should allow admin to alter _prependURI')
        it('should fail to allow owner to alter _prependURI')
        it('should fail to allow non-owner to alter _prependURI')
    })

    describe(`getChainId()`, async function() {
        it('should get expected toChainId value')
        it('Should allow external contract to call fn')
        it('should fail to allow inherited contract to call fn')
    })

    describe('updateChainIdMap()', async function() {
        it('should allow admin to alter _chainIdMap')
        it('should fail to allow owner to alter _chainIdMap')
        it('should fail to allow non-owner to alter _chainIdMap')
    })


    describe(`supportsInterface()`, async function() {
        it('should get expected _supportedInterfaces value')
        it('Should allow external contract to call fn')
        it('should fail to allow inherited contract to call fn')
    })

    describe('updateInterface()', async function() {
        it('should allow admin to alter _supportedInterfaces')
        it('should fail to allow owner to alter _supportedInterfaces')
        it('should fail to allow non-owner to alter _supportedInterfaces')
    })

    describe('updateInterfaces()', async function() {
        it('should allow admin to alter _supportedInterfaces')
        it('should fail to allow owner to alter _supportedInterfaces')
        it('should fail to allow non-owner to alter _supportedInterfaces')
    })

    describe(`receive()`, async function() {
        it('should revert')
    })

    describe(`fallback()`, async function() {
        it('should revert')
    })

})
