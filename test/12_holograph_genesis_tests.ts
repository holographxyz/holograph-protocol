import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { generateInitCode, zeroAddress } from '../scripts/utils/helpers';

describe.only('Holograph Genesis Contract', async function () {
  let HolographGenesis: any;
  let holographGenesis: any;
  let HolographGenesisChild: any;
  let holographGenesisChild: any;
  let Mock: any;
  let mock: any;
  let accounts: SignerWithAddress[];
  let deployer: SignerWithAddress;
  let newDeployer: SignerWithAddress;
  let anotherNewDeployer: SignerWithAddress;
  let mockSigner: SignerWithAddress;

  before(async function () {
    accounts = await ethers.getSigners();
    deployer = accounts[0];
    newDeployer = accounts[1];
    anotherNewDeployer = accounts[2];

    HolographGenesis = await ethers.getContractFactory('HolographGenesis');
    holographGenesis = await HolographGenesis.deploy();
    await holographGenesis.deployed();

    HolographGenesisChild = await ethers.getContractFactory('MockHolographGenesisChild');
    holographGenesisChild = await HolographGenesisChild.deploy();
    await holographGenesisChild.deployed();

    Mock = await ethers.getContractFactory('Mock');
    mock = await Mock.deploy();
    await mock.deployed();

    mockSigner = await ethers.getSigner(mock.address);
  });

  describe('constructor', async function () {
    it('should successfully deploy', async () => {
      const holographGenesisAddress = holographGenesis.address;
      const events = await holographGenesis.queryFilter('Message');

      if (events[0].args) {
        expect(events[0].args[0]).to.equal('The future of NFTs is Holograph.');
      } else {
        throw new Error('No events found after deployment of HolographGenesis');
      }

      expect(holographGenesisAddress).to.not.equal(zeroAddress);
      expect(events.length).to.equal(1);
    });
  });

  describe('deploy()', async function () {
    it('should fail if chainId is not this blockchains chainId', async () => {
      const chainId = (await ethers.provider.getNetwork()).chainId;

      await holographGenesis.deploy(
        chainId,
        `0x${'ff'.repeat(12)}`,
        `0x${'ff'.repeat(32)}`,
        generateInitCode(['address', 'uint16'], [deployer.address, 0])
      );
    });

    it('should fail if contract was already deployed');
    it('should fail if the deployment failed');
    it('should fail if contract init code does not match the init selector');
  });

  describe(`approveDeployer()`, async function () {
    it('Should allow deployer wallet to add to approved deployers', async () => {
      const tx = await holographGenesis.approveDeployer(newDeployer.address, true);
      await tx.wait();
      const isApprovedDeployer = await holographGenesis.isApprovedDeployer(newDeployer.address);
      expect(isApprovedDeployer).to.equal(true);
    });

    it('should fail non-deployer wallet to add approved deployers', async () => {
      await expect(holographGenesis.connect(mockSigner).approveDeployer(newDeployer.address, true)).to.be.revertedWith(
        'HOLOGRAPH: deployer not approved'
      );
    });

    it.skip('Should allow external contract to call fn', async () => {
      let tx = await holographGenesis.approveDeployer(mockSigner.address, true);
      await tx.wait();
      expect(await holographGenesis.isApprovedDeployer(mockSigner.address)).to.equal(true);
      expect(await holographGenesis.connect(mockSigner).approveDeployer(anotherNewDeployer.address, true)).to.equal(
        true
      );
    });

    it('should allow inherited contract to call fn', async () => {
      let tx = await holographGenesisChild.approveDeployer(mockSigner.address, true);
      await tx.wait();
      const isApprovedDeployer = await holographGenesis.isApprovedDeployer(newDeployer.address);
      expect(isApprovedDeployer).to.equal(true);
    });
  });

  describe(`isApprovedDeployer()`, async () => {
    it('Should return true to approved deployer wallet', async () => {
      const isApprovedDeployer = await holographGenesis.isApprovedDeployer(deployer.address);
      expect(isApprovedDeployer).to.equal(true);
    });

    it('Should return false to non-approved deployer wallet', async () => {
      const isApprovedDeployer = await holographGenesis.isApprovedDeployer(accounts[10].address);
      expect(isApprovedDeployer).to.equal(false);
    });

    // I believe this is a duplicate of the above test
    it.skip('Should return false non-deployer wallet');

    it('Should allow external contract to call fn', async () => {
      const isApprovedDeployer = await holographGenesis.connect(mockSigner).isApprovedDeployer(deployer.address);
      expect(isApprovedDeployer).to.equal(true);
    });

    it('should allow inherited contract to call fn', async () => {
      const isApprovedDeployer = await holographGenesisChild.IsApprovedDeployerMock(deployer.address);
      expect(isApprovedDeployer).to.equal(true);
    });
  });

  describe.skip('_isContract()', async function () {
    it('should not be callable from an external contract', async () => {
      await expect(holographGenesis.connect(mock.address)['_isContract'](deployer.address)).to.be.revertedWith('TODO');
    });
  });
});
