import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { generateInitCode, zeroAddress } from '../scripts/utils/helpers';

describe('Holograph Factory Contract', async function () {
    let HolographFactory: any;
    let holographFactory: any;
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

        HolographFactory = await ethers.getContractFactory('HolographFactory');
        holographFactory = await HolographFactory.deploy();
        await holographFactory.deployed();
    });

    describe('init():', async function () {
        it('should successfully init once', async function() {
            const initCode = generateInitCode(['address', 'address'], [holographAddr, registryAddr]);
            await expect(holographFactory.connect(deployer).init(initCode)).to.not.be.reverted;
        })
        it('should fail if already initialized', async function() {
            const initCode = generateInitCode(['address', 'address'], [holographAddr, registryAddr]);
            await expect(holographFactory.connect(deployer).init(initCode)).to.be.reverted;
        });
    })

    describe(`bridgeIn()`, async function() {
        it('should return the expected selector from the input payload')
        it('should return bad data if payload data is invalid')
    })

    describe('bridgeOut()', async function() {
        it('should return selector and payload')
    })

    describe('deployHolographableContract()', async function() {
        it('should fail with invalid signature if config is incorrect')
        it('should fail with invalid signature if signature.r is incorrect')
        it('should fail with invalid signature if signature.s is incorrect')
        it('should fail with invalid signature if signature.v is incorrect')
        it('should fail with invalid signature if signer is incorrect')

        it('should fail contract was already deployed')

        it('Should allow external contract to call fn')
        it('should fail to allow inherited contract to call fn')
    })

    describe(`getHolograph()`, async function() {
        it('Should return valid _holographSlot')
        it('Should allow external contract to call fn')
        it('should fail to allow inherited contract to call fn')
    })

    describe('setHolograph()', async function() {
        it('should allow admin to alter _holographSlot')
        it('should fail to allow owner to alter _holographSlot')
        it('should fail to allow non-owner to alter _holographSlot')
    })

    describe(`getRegistry()`, async function() {
        it('Should return valid _registrySlot')
        it('Should allow external contract to call fn')
        it('should fail to allow inherited contract to call fn')
    })

    describe('setRegistry()', async function() {
        it('should allow admin to alter _registrySlot')
        it('should fail to allow owner to alter _registrySlot')
        it('should fail to allow non-owner to alter _registrySlot')
    })

    describe('_isContract()', async function() {
        it('should not be callable')
    })

    describe('_verifySigner()', async function() {
        it('should not be callable')
    })

    describe(`receive()`, async function() {
        it('should revert')
    })

    describe(`fallback()`, async function() {
        it('should revert')
    })
})
