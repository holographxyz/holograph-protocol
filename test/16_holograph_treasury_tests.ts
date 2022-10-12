import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { generateInitCode, zeroAddress } from '../scripts/utils/helpers';
import { HolographTreasury, MockExternalCall } from '../typechain-types';

describe('Holograph Treasury Contract', async function () {
  let holographTreasury: HolographTreasury;
  let mockExternalCall: MockExternalCall;
  let deployer: SignerWithAddress;
  let commonUser: SignerWithAddress;

  const ONLY_ADMIN_ERROR_MSG = 'HOLOGRAPH: admin only function';

  function createRandomAddress() {
    return ethers.Wallet.createRandom().address;
  }

  const bridgeMock = createRandomAddress();
  const holographMock = createRandomAddress();
  const operatorMock = createRandomAddress();
  const registryMock = createRandomAddress();

  const initPayload = ethers.utils.defaultAbiCoder.encode(
    ['address', 'address', 'address', 'address'],
    [bridgeMock, holographMock, operatorMock, registryMock]
  );

  beforeEach(async () => {
    [deployer, commonUser] = await ethers.getSigners();

    const holographTreasuryFactory = await ethers.getContractFactory('HolographTreasury');
    holographTreasury = (await holographTreasuryFactory.deploy()) as HolographTreasury;
    await holographTreasury.deployed();

    const mockExternalCallFactory = await ethers.getContractFactory('MockExternalCall');
    mockExternalCall = (await mockExternalCallFactory.deploy()) as MockExternalCall;
    await mockExternalCall.deployed();
  });

  describe('constructor', async function () {});

  describe('init()', async function () {
    it('should successfully be initialized once', async () => {
      const tx = await holographTreasury.connect(deployer).init(initPayload);
      await tx.wait();

      expect(await holographTreasury.getHolograph()).to.equal(holographMock);
      expect(await holographTreasury.getOperator()).to.equal(operatorMock);
      expect(await holographTreasury.getRegistry()).to.equal(registryMock);
      expect(await holographTreasury.getBridge()).to.equal(bridgeMock);
    }); // Validate hardcoded values are correct

    it('should fail if already initialized', async () => {
      const tx = await holographTreasury.connect(deployer).init(initPayload);
      await tx.wait();
      await expect(holographTreasury.connect(deployer).init(initPayload)).to.be.revertedWith(
        'HOLOGRAPH: already initialized'
      );
    });

    it('Should allow external contract to call fn', async () => {
      let ABI = ['function init(bytes memory initPayload)'];
      let iface = new ethers.utils.Interface(ABI);
      let encodedFunctionData = iface.encodeFunctionData('init', [initPayload]);

      await expect(mockExternalCall.connect(deployer).callExternalFn(holographTreasury.address, encodedFunctionData)).to
        .not.be.reverted;

      expect(await holographTreasury.getHolograph()).to.equal(holographMock);
      expect(await holographTreasury.getOperator()).to.equal(operatorMock);
      expect(await holographTreasury.getRegistry()).to.equal(registryMock);
      expect(await holographTreasury.getBridge()).to.equal(bridgeMock);
    });

    it('should fail to allow inherited contract to call fn', async () => {});
  });

  describe('After initialized', () => {
    beforeEach(async () => {
      const tx = await holographTreasury.connect(deployer).init(initPayload);
      await tx.wait();
    });

    function testIfIsPrivate(fnAbi: string, fnName: string, args: any[] = []) {
      it('is private function', async () => {
        let iface = new ethers.utils.Interface([fnAbi]);
        let encodedFunctionData = iface.encodeFunctionData(fnName, args);

        await expect(
          ethers.provider.call({
            to: holographTreasury.address,
            data: encodedFunctionData,
          })
        ).to.be.reverted;
      });
    }

    describe(`_bridge()`, async function () {
      it('should successfully get _bridgeSlot', async () => {
        // should I use ethers.provider.getStorageAt ?
      });

      // it('should successfully be initialized once')
      testIfIsPrivate('function _bridge() view returns (address bridge)', '_bridge');
    });

    describe(`_holograph()`, async function () {
      it('should successfully get _holographSlot', async () => {});

      // it('should successfully be initialized once')
      testIfIsPrivate('function _holograph() view returns (address holograph)', '_holograph');
    });

    describe(`_operator()`, async function () {
      it('should successfully get _operatorSlot', async () => {});

      // it('should successfully be initialized once')
      testIfIsPrivate('function _operator() view returns (address operator)', '_operator');
    });

    describe(`_registry()`, async function () {
      it('should successfully get _registrySlot', async () => {});

      // it('should successfully be initialized once')
      testIfIsPrivate('function _registry() view returns (address registry)', '_registry');
    });

    describe(`getBridge()`, async function () {
      it('Should return valid _bridgeSlot', async () => {
        expect(await holographTreasury.getBridge()).to.equal(bridgeMock);
      });
      it('Should allow external contract to call fn');
      it('should fail to allow inherited contract to call fn');
    });

    describe('setBridge()', async function () {
      const newBridgeAdd = createRandomAddress();

      it('should allow admin to alter _bridgeSlot', async () => {
        const tx = await holographTreasury.connect(deployer).setBridge(newBridgeAdd);
        await tx.wait();

        expect(await holographTreasury.getBridge()).to.equal(newBridgeAdd);
      });

      // ?
      it('should fail to allow owner to alter _bridgeSlot');

      // Should I change this to "non-Admin"?
      it('should fail to allow non-owner to alter _bridgeSlot', async () => {
        await expect(holographTreasury.connect(commonUser).setBridge(newBridgeAdd)).to.be.revertedWith(
          ONLY_ADMIN_ERROR_MSG
        );
      });
    });

    describe(`getHolograph()`, async function () {
      it('Should return valid _holographSlot', async () => {
        expect(await holographTreasury.getHolograph()).to.equal(holographMock);
      });
      it('Should allow external contract to call fn');
      it('should fail to allow inherited contract to call fn');
    });

    describe('setHolograph()', async function () {
      const newHolographAdd = createRandomAddress();

      it('should allow admin to alter _holographSlot', async () => {
        const tx = await holographTreasury.connect(deployer).setHolograph(newHolographAdd);
        await tx.wait();

        expect(await holographTreasury.getHolograph()).to.equal(newHolographAdd);
      });

      it('should fail to allow owner to alter _holographSlot');

      it('should fail to allow non-owner to alter _holographSlot', async () => {
        await expect(holographTreasury.connect(commonUser).setHolograph(newHolographAdd)).to.be.revertedWith(
          ONLY_ADMIN_ERROR_MSG
        );
      });
    });

    describe(`getOperator()`, async function () {
      it('Should return valid _operatorSlot', async () => {
        expect(await holographTreasury.getOperator()).to.equal(operatorMock);
      });
      it('Should allow external contract to call fn');
      it('should fail to allow inherited contract to call fn');
    });

    describe('setOperator()', async function () {
      const newOperatorAdd = createRandomAddress();

      it('should allow admin to alter _operatorSlot', async () => {
        const tx = await holographTreasury.connect(deployer).setOperator(newOperatorAdd);
        await tx.wait();

        expect(await holographTreasury.getOperator()).to.equal(newOperatorAdd);
      });

      it('should fail to allow owner to alter _operatorSlot');

      it('should fail to allow non-owner to alter _operatorSlot', async () => {
        await expect(holographTreasury.connect(commonUser).setOperator(newOperatorAdd)).to.be.revertedWith(
          ONLY_ADMIN_ERROR_MSG
        );
      });
    });

    describe(`getRegistry()`, async function () {
      it('Should return valid _registrySlot', async () => {
        expect(await holographTreasury.getRegistry()).to.equal(registryMock);
      });
      it('Should allow external contract to call fn');
      it('should fail to allow inherited contract to call fn');
    });

    describe('setRegistry()', async function () {
      const newRegistryAdd = createRandomAddress();

      it('should allow admin to alter _registrySlot', async () => {
        const tx = await holographTreasury.connect(deployer).setRegistry(newRegistryAdd);
        await tx.wait();

        expect(await holographTreasury.getRegistry()).to.equal(newRegistryAdd);
      });

      it('should fail to allow owner to alter _registrySlot');

      it('should fail to allow non-owner to alter _registrySlot', async () => {
        await expect(holographTreasury.connect(commonUser).setOperator(newRegistryAdd)).to.be.revertedWith(
          ONLY_ADMIN_ERROR_MSG
        );
      });
    });
  });
});
