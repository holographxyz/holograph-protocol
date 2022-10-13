import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers, deployments } from 'hardhat';
import { Holographer, Holographer__factory, MockExternalCall, MockExternalCall__factory } from '../typechain-types';
import Web3 from 'web3';

import { ALREADY_INITIALIZED_ERROR_MSG } from './utils/error_constants';

describe('Holograph Holographer Contract', async function () {
  let holographer: Holographer;
  let mockExternalCall: MockExternalCall;
  let deployer: SignerWithAddress;
  let commonUser: SignerWithAddress;
  let holograph: any;

  function createRandomAddress() {
    return ethers.Wallet.createRandom().address;
  }

  /** Testing */
  const web3 = new Web3();
  let erc721Hash: string = '0x' + web3.utils.asciiToHex('HolographERC721').substring(2).padStart(64, '0');
  /** Testing */

  let deployedBlock: number;
  const originChainMock = 1;
  let holographMock = createRandomAddress();
  const sourceContractMock = createRandomAddress();
  const contractTypeMock = erc721Hash;
  // '0x4552433732310000000000000000000000000000000000000000000000000000';

  const initPayload = ethers.utils.defaultAbiCoder.encode(
    ['uint32', 'address', 'bytes32', 'address'],
    [originChainMock, holographMock, contractTypeMock, sourceContractMock]
  );

  beforeEach(async () => {
    [deployer, commonUser] = await ethers.getSigners();

    await deployments.fixture(['Holograph']);
    holograph = await ethers.getContract('Holograph');

    holographMock = holograph.address;

    const HolographerFactory = await ethers.getContractFactory<Holographer__factory>('Holographer');
    holographer = await HolographerFactory.deploy();
    await holographer.deployed();

    const mockExternalCallFactory = await ethers.getContractFactory<MockExternalCall__factory>('MockExternalCall');
    mockExternalCall = await mockExternalCallFactory.deploy();
    await mockExternalCall.deployed();
  });

  describe('init()', async function () {
    it.only('should successfully be initialized once', async () => {
      console.log('block before: ', (await ethers.provider.getBlock('latest')).number);

      const tx = await holographer.connect(deployer).init(initPayload);
      await tx.wait();

      console.log('block after: ', (await ethers.provider.getBlock('latest')).number);
      console.log('actual Block: ', await holographer.getDeploymentBlock());

      deployedBlock = (await ethers.provider.getBlock('latest')).number;

      //TODO: _contractTypeSlot using getStorageAt
      // expect(await holographer.getHolograph()).to.equal(holographMock);
      // expect(await holographer.getOriginChain()).to.equal(originChainMock);
      // expect(await holographer.getSourceContract()).to.equal(sourceContractMock);
      // expect(await holographer.getDeploymentBlock()).to.equal(deployedBlock);
      // expect(await holographer.getAdmin()).to.equal(deployer.address);
    }); // Validate hardcoded values are correct

    it('should fail if already initialized', async () => {
      const tx = await holographer.connect(deployer).init(initPayload);
      await tx.wait();

      await expect(holographer.connect(deployer).init(initPayload)).to.be.revertedWith(ALREADY_INITIALIZED_ERROR_MSG);
    });

    it('Should allow external contract to call fn', async () => {
      let ABI = ['function init(bytes memory initPayload) external'];
      let iface = new ethers.utils.Interface(ABI);
      let encodedFunctionData = iface.encodeFunctionData('init', [initPayload]);

      await expect(mockExternalCall.connect(deployer).callExternalFn(holographer.address, encodedFunctionData)).to.not
        .be.reverted;

      //TODO: _contractTypeSlot using getStorageAt
      expect(await holographer.getHolograph()).to.equal(holographMock);
      expect(await holographer.getOriginChain()).to.equal(originChainMock);
      expect(await holographer.getSourceContract()).to.equal(sourceContractMock);
    });

    it('should fail to allow inherited contract to call fn', async () => {});
  });

  describe('After initialized', () => {
    beforeEach(async () => {
      deployedBlock = (await ethers.provider.getBlock('latest')).number;

      const tx = await holographer.connect(deployer).init(initPayload);
      await tx.wait();
    });

    describe(`getDeploymentBlock()`, async function () {
      it('Should return valid _blockHeightSlot', async () => {
        expect(await holographer.getDeploymentBlock()).to.equal(deployedBlock);
      });

      it('Should allow external contract to call fn', async () => {
        let ABI = ['function getDeploymentBlock() external view returns (address holograph) '];
        let iface = new ethers.utils.Interface(ABI);
        let encodedFunctionData = iface.encodeFunctionData('getDeploymentBlock', []);

        await expect(mockExternalCall.connect(deployer).callExternalFn(holographer.address, encodedFunctionData)).to.not
          .be.reverted;
      });

      it('should fail to allow inherited contract to call fn');
    });

    describe(`getHolograph()`, async function () {
      it('Should return valid _holographSlot', async () => {
        expect(await holographer.getHolograph()).to.equal(holographMock);
      });

      it('Should allow external contract to call fn', async () => {
        let ABI = ['function getHolograph() external view returns (address holograph)'];
        let iface = new ethers.utils.Interface(ABI);
        let encodedFunctionData = iface.encodeFunctionData('getHolograph', []);

        await expect(mockExternalCall.connect(deployer).callExternalFn(holographer.address, encodedFunctionData)).to.not
          .be.reverted;
      });

      it('should fail to allow inherited contract to call fn');
    });

    describe(`getOriginChain()`, async function () {
      it('Should return valid _originChainSlot', async () => {
        expect(await holographer.getOriginChain()).to.equal(originChainMock);
      });

      it('Should allow external contract to call fn', async () => {
        let ABI = ['function getOriginChain() external view returns (uint32 originChain)'];
        let iface = new ethers.utils.Interface(ABI);
        let encodedFunctionData = iface.encodeFunctionData('getOriginChain', []);

        await expect(mockExternalCall.connect(deployer).callExternalFn(holographer.address, encodedFunctionData)).to.not
          .be.reverted;
      });

      it('should fail to allow inherited contract to call fn');
    });

    describe(`getSourceContract()`, async function () {
      it('Should return valid _sourceContractSlot', async () => {
        expect(await holographer.getSourceContract()).to.equal(sourceContractMock);
      });

      it('Should allow external contract to call fn', async () => {
        let ABI = ['function getSourceContract() external view returns (address sourceContract)'];
        let iface = new ethers.utils.Interface(ABI);
        let encodedFunctionData = iface.encodeFunctionData('getSourceContract', []);

        await expect(mockExternalCall.connect(deployer).callExternalFn(holographer.address, encodedFunctionData)).to.not
          .be.reverted;
      });

      it('should fail to allow inherited contract to call fn');
    });

    describe(`getHolographEnforcer()`, async function () {
      it.skip('Should return Holograph smart contract that controls and enforces the ERC standards', async () => {
        //TODO:
        // expect(await holographer.getHolographEnforcer()).to.equal();
      });

      it('Should allow external contract to call fn', async () => {
        let ABI = ['function getHolographEnforcer() public view returns (address)'];
        let iface = new ethers.utils.Interface(ABI);
        let encodedFunctionData = iface.encodeFunctionData('getHolographEnforcer', []);

        await expect(mockExternalCall.connect(deployer).callExternalFn(holographer.address, encodedFunctionData)).to.not
          .be.reverted;
      });

      it('should fail to allow inherited contract to call fn');
    });
  });

  describe('fallback()', () => {
    it('TODO ');
  });
});
