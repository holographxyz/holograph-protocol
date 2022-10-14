import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers, deployments, network } from 'hardhat';
import * as hre1 from 'hardhat';
import { Holographer, Holographer__factory, MockExternalCall, MockExternalCall__factory } from '../typechain-types';
import Web3 from 'web3';
import setup, { PreTest } from './utils';
import networks from '../config/networks';

import { ALREADY_INITIALIZED_ERROR_MSG } from './utils/error_constants';
import { generateErc721Config, generateInitCode, hreSplit, Signature, StrictECDSA } from '../scripts/utils/helpers';
import { ConfigureEvents, HolographERC721Event } from '../scripts/utils/events';
declare var global: any;

describe('Holograph Holographer Contract', function () {
  let holographer: Holographer;
  let mockExternalCall: MockExternalCall;
  let deployer: SignerWithAddress;
  let commonUser: SignerWithAddress;
  let holograph: any;

  const createRandomAddress = () => ethers.Wallet.createRandom().address;

  const web3 = new Web3();
  let deployedBlock: number;
  const originChainMock = 1;
  let holographMock = createRandomAddress();
  const sourceContractMock = createRandomAddress();
  const contractTypeMock = '0x' + web3.utils.asciiToHex('HolographERC721').substring(2).padStart(64, '0');

  // const encoded = ethers.utils.defaultAbiCoder.encode(
  //   ['uint32', 'address', 'bytes32', 'address'],
  //   [originChainMock, holographMock, contractTypeMock, sourceContractMock]
  // );
  let initPayload: string;

  let signature: Signature;
  let l1: PreTest;
  before(async () => {
    // let { hre, hre2 } = await hreSplit(hre1, true);
    [deployer, commonUser] = await ethers.getSigners();
    l1 = await setup();
    const l2 = await setup(true);

    // await deployments.fixture(['DeploySources', 'DeployERC721', 'HolographERC721', 'RegisterTemplates']);

    // holograph = await ethers.getContract('Holograph');
    // const holographFactory = await ethers.getContract('HolographFactory');

    let { erc721Config, erc721ConfigHash, erc721ConfigHashBytes } = await generateErc721Config(
      l1.network, // reference to hardhat network object
      l1.deployer.address, // address of creator of contract
      'SampleERC721', // contract bytecode to use
      'Sample ERC721 Contract (' + l1.hre.networkName + ')', // name of contract
      'SMPLR', // token symbol of contract
      1000, // royalties to use (bps 10%) <- erc721 specific
      ConfigureEvents([
        // events to connect / capture for SampleERC721
        HolographERC721Event.bridgeIn,
        HolographERC721Event.bridgeOut,
        HolographERC721Event.afterBurn,
      ]),
      generateInitCode(['address'], [deployer.address]), // init code for SampleERC721 itself
      l1.salt // random bytes32 salt that you decide to assign this config, used again on other chains to guarantee uniqueness if all above vars are same for another contract for some reason
    );

    const sig = await deployer.signMessage(erc721ConfigHashBytes);
    const signature: Signature = StrictECDSA({
      r: '0x' + sig.substring(2, 66),
      s: '0x' + sig.substring(66, 130),
      v: '0x' + sig.substring(130, 132),
    } as Signature);

    const depoyTx = await l1.holographFactory
      .connect(deployer)
      .deployHolographableContract(erc721Config, signature, deployer.address);

    // const depoyTx = await holographFactory.deployHolographableContract(erc721Config, signature, deployer.address, {
    //   nonce: await ethers.provider.getTransactionCount(deployer.address),
    // });
    const deployResult = await depoyTx.wait();

    const event = deployResult.events?.find((event: any) => event.event === 'BridgeableContractDeployed');
    const [holographerAddress, hash] = event?.args || ['', ''];
    console.log('=====> ', holographerAddress);

    // holographMock = holograph.address;

    // const HolographerFactory = await ethers.getContractFactory<Holographer__factory>('Holographer');
    // holographer = await HolographerFactory.deploy();
    // await holographer.deployed();

    const mockExternalCallFactory = await ethers.getContractFactory<MockExternalCall__factory>('MockExternalCall');
    mockExternalCall = await mockExternalCallFactory.deploy();
    await mockExternalCall.deployed();
  });

  describe('constructor', async function () {
    it('should successfully deploy', async function () {
      expect(holographer.address).to.not.equal(ethers.constants.AddressZero);
    });
  });

  describe.only('init()', () => {
    it.skip('should successfully be initialized once', async () => {
      console.log('block before: ', (await ethers.provider.getBlock('latest')).number);

      const tx = await holographer.connect(deployer).init(initPayload);
      await tx.wait();

      console.log('block after: ', (await ethers.provider.getBlock('latest')).number);
      console.log('actual Block: ', await holographer.getDeploymentBlock());

      deployedBlock = (await ethers.provider.getBlock('latest')).number;

      //TODO: _contractTypeSlot using getStorageAt
      expect(await holographer.getHolograph()).to.equal(holographMock);
      expect(await holographer.getOriginChain()).to.equal(originChainMock);
      expect(await holographer.getSourceContract()).to.equal(sourceContractMock);
      expect(await holographer.getDeploymentBlock()).to.equal(deployedBlock);
      expect(await holographer.getAdmin()).to.equal(deployer.address);
    }); // Validate hardcoded values are correct

    it.skip('should fail if already initialized', async () => {
      await expect(holographer.connect(deployer).init(initPayload)).to.be.revertedWith(ALREADY_INITIALIZED_ERROR_MSG);
    });

    it.skip('Should allow external contract to call fn', async () => {
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
    // beforeEach(async () => {
    //   deployedBlock = (await ethers.provider.getBlock('latest')).number;

    //   const tx = await holographer.connect(deployer).init(initPayload);
    //   await tx.wait();
    // });

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
