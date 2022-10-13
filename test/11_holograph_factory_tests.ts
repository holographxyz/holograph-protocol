import { PreTest } from './utils';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import setup from './utils';
import { generateInitCode, zeroAddress } from '../scripts/utils/helpers';

describe.only('Holograph Factory Contract', async () => {
  let l1: PreTest;
  let HolographRegistry: any;
  let holographRegistry: any;

  let Mock: any;
  let mock: any;
  let accounts: SignerWithAddress[];
  let deployer: SignerWithAddress;
  let newDeployer: SignerWithAddress;
  let anotherNewDeployer: SignerWithAddress;
  let mockSigner: SignerWithAddress;
  let chainId: number;

  before(async () => {
    l1 = await setup();
    accounts = await ethers.getSigners();
    deployer = accounts[0];
    newDeployer = accounts[1];
    anotherNewDeployer = accounts[2];
    chainId = (await ethers.provider.getNetwork()).chainId;

    Mock = await ethers.getContractFactory('Mock');
    mock = await Mock.deploy();
    await mock.deployed();

    mockSigner = await ethers.getSigner(mock.address);
  });

  describe('init():', async () => {
    // TODO: Check initialized
    // it.only('should check that contract was successfully initialized once', async () => {
    //   await expect(l1.holographFactory.connect(deployer)._isInitialized().to.equal(true);
    // });

    it('should fail if already initialized', async () => {
      const initCode = generateInitCode(
        ['address', 'address'],
        [l1.holographFactory.address, l1.holographRegistry.address]
      );
      await expect(l1.holographFactory.connect(deployer).init(initCode)).to.be.reverted;
    });
  });

  describe.skip(`bridgeIn()`, async () => {
    it('should return the expected selector from the input payload', async () => {
      const payload = '0x0000000000000000000000000000000000000000000000000000000000000000';
      const expectedSelector = '0x00000000';
      const selector = await l1.holographFactory.bridgeIn(chainId, payload);
      expect(selector).to.equal(expectedSelector);
    });

    it('should return bad data if payload data is invalid', async () => {
      const payload = '0x0000000000000000000000000000000000000000000000000000000000000000';
    });
  });

  describe('bridgeOut()', async () => {
    it('should return selector and payload');
  });

  describe('deployHolographableContract()', async () => {
    it('should fail with invalid signature if config is incorrect');
    it('should fail with invalid signature if signature.r is incorrect');
    it('should fail with invalid signature if signature.s is incorrect');
    it('should fail with invalid signature if signature.v is incorrect');
    it('should fail with invalid signature if signer is incorrect');

    it('should fail contract was already deployed');

    it('Should allow external contract to call fn');
    it('should fail to allow inherited contract to call fn');
  });

  describe('setHolograph() / getHolograph()', async () => {
    it('should allow admin to alter _holographSlot', async () => {
      await l1.holographFactory.setHolograph(l1.holograph.address);
      const _holographSlot = await l1.holographFactory.getHolograph();
      expect(_holographSlot).to.equal(l1.holograph.address);
    });

    it('should fail to allow owner to alter _holographSlot');
    it('should fail to allow non-owner to alter _holographSlot');
  });

  describe('setRegistry() / getRegistry()', async () => {
    it('should allow admin to alter _registrySlot', async () => {
      await l1.holographFactory.setRegistry(l1.holographRegistry.address);
      const _registrySlot = await l1.holographFactory.getRegistry();
      expect(_registrySlot).to.equal(l1.holographRegistry.address);
    });

    it('should fail to allow owner to alter _registrySlot', async () => {
      await expect(l1.holographFactory.connect(deployer).setRegistry(l1.holographRegistry.address)).to.be.reverted;
    });

    it('should fail to allow non-owner to alter _registrySlot');
  });

  describe('_isContract()', async () => {
    it('should not be callable');
  });

  describe('_verifySigner()', async () => {
    it('should not be callable');
  });

  describe(`receive()`, async () => {
    it('should revert');
  });

  describe(`fallback()`, async () => {
    it('should revert');
  });
});
