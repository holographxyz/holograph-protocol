import { expect } from 'chai';
import { ethers } from 'hardhat';

import { PA1D, MockExternalCall, MockExternalCall__factory } from '../typechain-types';
import { functionHash, generateInitCode } from '../scripts/utils/helpers';
import setup, { PreTest } from './utils';
import { HOLOGRAPHER_ALREADY_INITIALIZED_ERROR_MSG, PAD1_ALREADY_INITIALIZED_ERROR_MSG } from './utils/error_constants';

describe('PA1D Contract', async function () {
  let pad1d: PA1D;
  let l1: PreTest;
  let mockExternalCall: MockExternalCall;

  const createRandomAddress = () => ethers.Wallet.createRandom().address;

  before(async function () {
    l1 = await setup();
    pad1d = await ethers.getContractAt('PA1D', l1.pa1d.address);

    const mockExternalCallFactory = await ethers.getContractFactory<MockExternalCall__factory>('MockExternalCall');
    mockExternalCall = await mockExternalCallFactory.deploy();
    await mockExternalCall.deployed();
  });

  async function testExternalCallToFunction(fnAbi: string, fnName: string, args: any[] = []) {
    const ABI = [fnAbi];
    const iface = new ethers.utils.Interface(ABI);
    const encodedFunctionData = iface.encodeFunctionData(fnName, args);
    await expect(mockExternalCall.connect(l1.deployer).callExternalFn(pad1d.address, encodedFunctionData)).to.not.be
      .reverted;
  }

  function testIfIsPrivate(fnAbi: string, fnName: string, args: any[] = []) {
    it('is private function', async () => {
      let iface = new ethers.utils.Interface([fnAbi]);
      let encodedFunctionData = iface.encodeFunctionData(fnName, args);

      await expect(
        ethers.provider.call({
          to: pad1d.address,
          data: encodedFunctionData,
        })
      ).to.be.reverted;
    });
  }

  describe('init()', async function () {
    it('should fail be initialized twice', async function () {
      const initCode = generateInitCode(['address'], [l1.deployer.address]);
      await expect(pad1d.connect(l1.deployer).init(initCode)).to.be.revertedWith(PAD1_ALREADY_INITIALIZED_ERROR_MSG);
    });
  });

  describe('initPA1D()', () => {
    it('should fail be initialized twice', async function () {
      const initCode = generateInitCode(['address'], [l1.deployer.address]);
      await expect(pad1d.connect(l1.deployer).initPA1D(initCode)).to.be.revertedWith(
        PAD1_ALREADY_INITIALIZED_ERROR_MSG
      );
    });
  });

  describe('owner()', async function () {
    it('should return the correct owner address', async function () {
      const ownerAddress = await pad1d.connect(l1.deployer).owner();
      expect(ownerAddress).to.equal(l1.owner.address);
    });
    it('should fail when comparing to wrong address', async function () {
      const ownerAddress = await pad1d.connect(l1.wallet10).owner();
      expect(ownerAddress).to.not.equal(l1.wallet10.address);
    });
    it('should allow external contract to call fn', async function () {
      await testExternalCallToFunction('function owner() external view returns (address)', 'owner');
    });
  });

  describe('isOwner()', async function () {
    testIfIsPrivate('function isOwner() view returns (bool) ', 'isOwner');
  });

  describe('_getDefaultReceiver()', () => {
    testIfIsPrivate('function _getDefaultReceiver()  view returns (address payable receiver)', '_getDefaultReceiver');
  });

  describe('_setDefaultReceiver()', () => {
    testIfIsPrivate('function _setDefaultReceiver(address receiver)', '_setDefaultReceiver', [createRandomAddress()]);
  });

  describe('_getDefaultBp()', () => {
    testIfIsPrivate('function _getDefaultBp() private view returns (uint256 bp)', '_getDefaultBp');
  });

  describe('_setDefaultBp()', () => {
    testIfIsPrivate('function _setDefaultBp(uint256 bp)', '_setDefaultBp', [createRandomAddress()]);
  });

  describe('_getReceiver()', () => {
    testIfIsPrivate('function _getReceiver(uint256 tokenId) view returns (address payable receiver)', '_getReceiver', [
      1,
    ]);
  });

  describe('_setReceiver()', () => {
    testIfIsPrivate('function _setReceiver(uint256 tokenId, address receiver)', '_setReceiver', [
      1,
      createRandomAddress(),
    ]);
  });

  describe('_getBp()', () => {
    testIfIsPrivate('function _getBp(uint256 tokenId) view returns (uint256 bp)', '_getBp', [1]);
  });

  describe('_setBp()', () => {
    testIfIsPrivate('function _setBp(uint256 tokenId, uint256 bp)', '_setBp', [1, createRandomAddress()]);
  });

  describe.only('_getPayoutAddresses()', () => {
    testIfIsPrivate(
      'function _getPayoutAddresses() view returns (address payable[] memory addresses)',
      '_getPayoutAddresses'
    );
  });

  describe('_setPayoutAddresses()', () => {
    testIfIsPrivate('function _setPayoutAddresses(address payable[] memory addresses)', '_setPayoutAddresses', [
      [createRandomAddress(), createRandomAddress()],
    ]);
  });

  describe('_getPayoutBps()', () => {
    testIfIsPrivate('function _getPayoutBps() view returns (uint256[] memory bps)', '_getPayoutBps');
  });

  describe('_setPayoutBps()', () => {
    testIfIsPrivate('function _setPayoutBps(uint256[] memory bps)', '_setPayoutBps', [[900, 100]]);
  });

  describe('_getTokenAddress()', () => {
    testIfIsPrivate(
      'function _getTokenAddress(string memory tokenName) private view returns (address tokenAddress)',
      '_getTokenAddress',
      ['Sample ERC721 Token']
    );
  });

  describe('_setTokenAddress()', () => {
    testIfIsPrivate('function _setTokenAddress(string memory tokenName, address tokenAddress)', '_setTokenAddress', [
      'Sample ERC721 Token',
      createRandomAddress(),
    ]);
  });

  describe('_payoutEth()', () => {
    testIfIsPrivate('function _payoutEth()', '_payoutEth');
  });

  describe('_payoutToken()', () => {
    testIfIsPrivate('function _payoutToken(address tokenAddress)', '_payoutToken', [createRandomAddress()]);
  });

  describe('_payoutTokens()', () => {
    testIfIsPrivate('function _payoutTokens(address[] memory tokenAddresses)', '_payoutTokens', [
      [createRandomAddress(), createRandomAddress()],
    ]);
  });

  describe('_validatePayoutRequestor()', () => {
    testIfIsPrivate('function _validatePayoutRequestor() view', '_validatePayoutRequestor');
  });

  describe('configurePayouts', () => {
    it('should be callable by the owner', async () => {});

    it('should fail if it is not the owner calling it', async () => {});
  });

  describe('getPayoutInfo()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('getEthPayout()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('getTokenPayout()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('getTokensPayout()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('setRoyalties', () => {
    it('should be callable by the owner', async () => {});

    it('should fail if it is not the owner calling it', async () => {});
  });

  describe('royaltyInfo()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('getFeeBps()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('getFeeRecipients()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('getRoyalties()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('getFees()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('tokenCreator()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('calculateRoyaltyFee()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('marketContract()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('tokenCreators()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('bidSharesForToken()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });

  describe('getTokenAddress()', () => {
    it('anyone should be able to call the fn');

    it('should allow external contract to call fn');

    it('should allow inherited contract to call fn');
  });
});
