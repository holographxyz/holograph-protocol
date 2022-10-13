import { PreTest } from './utils';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import setup from './utils';
import { Signature, StrictECDSA, generateInitCode, generateErc20Config } from '../scripts/utils/helpers';
import { ALREADY_DEPLOYED_ERROR_MSG, INVALID_SIGNATURE_ERROR_MSG, ONLY_ADMIN_ERROR_MSG } from './utils/error_constants';
import { ConfigureEvents } from '../scripts/utils/events';

describe.only('Holograph Factory Contract', async () => {
  let l1: PreTest;

  let Mock: any;
  let mock: any;
  let accounts: SignerWithAddress[];
  let deployer: SignerWithAddress;
  let owner: SignerWithAddress;
  let nonOwner: SignerWithAddress;
  let mockSigner: SignerWithAddress;
  let chainId: number;

  const randomAddress = () => ethers.Wallet.createRandom().address;

  let configObj: any;
  let erc20Config: any;
  let erc20ConfigHash: string;
  let erc20ConfigHashBytes: any;
  let signature: Signature;

  before(async () => {
    l1 = await setup();
    accounts = await ethers.getSigners();
    deployer = accounts[0];
    owner = accounts[1];
    nonOwner = accounts[2];

    chainId = (await ethers.provider.getNetwork()).chainId;

    Mock = await ethers.getContractFactory('Mock');
    mock = await Mock.deploy();
    await mock.deployed();

    mockSigner = await ethers.getSigner(mock.address);

    configObj = await generateErc20Config(
      l1.network,
      l1.deployer.address,
      'hToken',
      l1.network.tokenName + ' (Holographed #' + l1.network.holographId.toString() + ')',
      'h' + l1.network.tokenSymbol,
      l1.network.tokenName + ' (Holographed #' + l1.network.holographId.toString() + ')',
      '1',
      18,
      ConfigureEvents([]),
      generateInitCode(['address', 'uint16'], [l1.deployer.address, 0]),
      l1.salt
    );

    erc20Config = configObj.erc20Config;
    erc20ConfigHash = configObj.erc20ConfigHash;
    erc20ConfigHashBytes = configObj.erc20ConfigHashBytes;

    let hTokenErc20Address = await l1.registry.getHolographedHashAddress(erc20ConfigHash);
    hTokenErc20Address = await l1.registry.getHolographedHashAddress(erc20ConfigHash);

    let sig = await l1.deployer.signMessage(erc20ConfigHashBytes);
    signature = StrictECDSA({
      r: '0x' + sig.substring(2, 66),
      s: '0x' + sig.substring(66, 130),
      v: '0x' + sig.substring(130, 132),
    } as Signature);
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

  describe('deployHolographableContract()', async () => {
    it('should fail with invalid signature if config is incorrect', async () => {
      await expect(
        l1.holographFactory.connect(deployer).deployHolographableContract(erc20Config, signature, owner.address)
      ).to.be.revertedWith(INVALID_SIGNATURE_ERROR_MSG);
    });

    it('should fail contract was already deployed', async () => {
      await expect(
        l1.factory.deployHolographableContract(erc20Config, signature, l1.deployer.address)
      ).to.be.revertedWith(ALREADY_DEPLOYED_ERROR_MSG);
    });

    it('should fail contract was already deployed', async () => {
      await expect(
        l1.factory.deployHolographableContract(erc20Config, signature, l1.deployer.address)
      ).to.be.revertedWith(ALREADY_DEPLOYED_ERROR_MSG);
    });

    it('should fail with invalid signature if signature.r is incorrect', async () => {
      signature.r = `0x${'00'.repeat(32)}`;
      await expect(
        l1.holographFactory.connect(deployer).deployHolographableContract(erc20Config, signature, owner.address)
      ).to.be.revertedWith(INVALID_SIGNATURE_ERROR_MSG);
    });

    it('should fail with invalid signature if signature.s is incorrect', async () => {
      signature.s = `0x${'00'.repeat(32)}`;
      await expect(
        l1.holographFactory.connect(deployer).deployHolographableContract(erc20Config, signature, owner.address)
      ).to.be.revertedWith(INVALID_SIGNATURE_ERROR_MSG);
    });

    it('should fail with invalid signature if signature.v is incorrect', async () => {
      signature.v = `0x${'00'.repeat(32)}`;
      await expect(
        l1.holographFactory.connect(deployer).deployHolographableContract(erc20Config, signature, owner.address)
      ).to.be.revertedWith(INVALID_SIGNATURE_ERROR_MSG);
    });

    it('should fail with invalid signature if signer is incorrect', async () => {
      await expect(l1.factory.deployHolographableContract(erc20Config, signature, nonOwner.address)).to.be.revertedWith(
        INVALID_SIGNATURE_ERROR_MSG
      );
    });

    it('Should allow external contract to call fn');
    it('should fail to allow inherited contract to call fn');
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

  describe.skip('bridgeOut()', async () => {
    it('should return selector and payload');
  });

  describe('setHolograph() / getHolograph()', async () => {
    it('should allow admin to alter _holographSlot', async () => {
      await l1.holographFactory.setHolograph(l1.holograph.address);
      const _holographSlot = await l1.holographFactory.getHolograph();
      expect(_holographSlot).to.equal(l1.holograph.address);
    });

    it('should fail to allow owner to alter _holographSlot', async () => {
      await expect(l1.holographFactory.connect(nonOwner).setHolograph(l1.holograph.address)).to.be.revertedWith(
        ONLY_ADMIN_ERROR_MSG
      );
    });

    it('should fail to allow non-owner to alter _holographSlot', async () => {
      await expect(l1.holographFactory.connect(nonOwner).setHolograph(l1.holographRegistry.address)).to.be.revertedWith(
        ONLY_ADMIN_ERROR_MSG
      );
    });
  });

  describe('setRegistry() / getRegistry()', async () => {
    it('should allow admin to alter _registrySlot', async () => {
      await l1.holographFactory.setRegistry(l1.holographRegistry.address);
      const _registrySlot = await l1.holographFactory.getRegistry();
      expect(_registrySlot).to.equal(l1.holographRegistry.address);
    });

    it('should fail to allow owner to alter _registrySlot', async () => {
      await expect(l1.holographFactory.connect(nonOwner).setRegistry(l1.holographRegistry.address)).to.be.revertedWith(
        ONLY_ADMIN_ERROR_MSG
      );
    });

    it('should fail to allow non-owner to alter _registrySlot', async () => {
      await expect(l1.holographFactory.connect(nonOwner).setRegistry(l1.holographRegistry.address)).to.be.revertedWith(
        ONLY_ADMIN_ERROR_MSG
      );
    });
  });

  describe.skip('_isContract()', async () => {
    it('should not be callable', async () => {
      // await expect(l1.holographFactory._isContract()).to.be.throw;
    });
  });

  describe.skip('_verifySigner()', async () => {
    it('should not be callable');
  });

  describe(`receive()`, async () => {
    it('should revert', async () => {
      await expect(
        deployer.sendTransaction({
          to: l1.holographFactory.address,
          value: 1,
        })
      ).to.be.reverted;
    });
  });

  describe(`fallback()`, async () => {
    it('should revert', async () => {
      await expect(
        deployer.sendTransaction({
          to: l1.holographFactory.address,
        })
      ).to.be.reverted;
    });
  });
});
