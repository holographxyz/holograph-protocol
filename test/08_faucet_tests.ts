declare var global: any;
import { expect, assert, util } from 'chai';
import { BigNumberish, BytesLike, BigNumber } from 'ethers';
import { PreTest } from './utils';
import setup from './utils';
import { Faucet, HolographERC20, SampleERC20 } from '../typechain-types';
import { generateInitCode } from '../scripts/utils/helpers';

describe('Testing the Holograph Faucet', async () => {
  let l1: PreTest;

  let ERC20: HolographERC20;
  let SAMPLEERC20: SampleERC20;
  let FAUCET: Faucet;

  let DEPLOYER: string;
  let USER_A: string;
  let USER_B: string;
  let USER_C: string;

  const DEFAULT_DRIP_AMOUNT = BigNumber.from('100000000000000000000'); // 100 eth
  const DEFAULT_DRIP_COOLDOWN = 24 * 60 * 60; // 24 hours in seconds
  const INITIAL_FAUCET_FUNDS = DEFAULT_DRIP_AMOUNT.mul(20); // enough for 10 drips
  let dripCount = 0;

  // Revert messages
  const INITIALIZED = 'Faucet contract is already initialized';
  const COME_BACK_LATER = 'Come back later';
  const NOT_AN_OWNER = 'Caller is not the owner';

  before(async function () {
    l1 = await setup();
    ERC20 = await l1.holographErc20.attach(l1.sampleErc20Holographer.address);
    SAMPLEERC20 = await l1.sampleErc20.attach(l1.sampleErc20Holographer.address);
    FAUCET = l1.faucet;
    DEPLOYER = l1.deployer.address;
    USER_A = l1.wallet1.address;
    USER_B = l1.wallet2.address;
    USER_C = l1.wallet3.address;

    await SAMPLEERC20.functions.mint(FAUCET.address, INITIAL_FAUCET_FUNDS);
  });

  after(async () => {});

  beforeEach(async () => {});

  afterEach(async () => {});

  describe('Test Initializer', async function () {
    it('should fail initializing already initialized Faucet', async function () {
      await expect(
        FAUCET.init(generateInitCode(['address', 'address'], [DEPLOYER, ERC20.address]))
      ).to.be.revertedWith(INITIALIZED);
    });
  });

  describe('Default drip flow', async () => {
    it('isAllowedToWithdraw(): User is allowed to withdraw for the first time', async function () {
      expect(await FAUCET.functions.isAllowedToWithdraw(DEPLOYER)).to.be.true;
    });

    it('requestTokens(): User can withdraw for the first time', async function () {
      await FAUCET.functions.requestTokens().then((tx) => tx.wait());
      dripCount++;
      expect(await ERC20.functions.balanceOf(DEPLOYER)).to.equal(DEFAULT_DRIP_AMOUNT);
    });

    it('isAllowedToWithdraw(): User is not allowed to withdraw for the second time', async function () {
      expect(await FAUCET.functions.isAllowedToWithdraw(DEPLOYER)).to.be.false;
    });

    it('requestTokens(): User cannot withdraw for the second time', async function () {
      await expect(FAUCET.functions.requestTokens()).to.be.revertedWith(COME_BACK_LATER);
    });
  });

  describe('Owner drip flow', async () => {
    it('grantTokens(): Owner can grant tokens', async function () {
      await FAUCET.functions['grantTokens(address)'](DEPLOYER).then((tx) => tx.wait());
      dripCount++;
      expect(await ERC20.functions.balanceOf(DEPLOYER)).to.equal(DEFAULT_DRIP_AMOUNT.mul(2));
    });

    it('grantTokens(): Owner can grant tokens again with arbitrary amount', async function () {
      const factor = 2;
      await FAUCET.functions['grantTokens(address,uint256)'](DEPLOYER, DEFAULT_DRIP_AMOUNT.mul(factor)).then((tx) =>
        tx.wait()
      );
      dripCount += factor;
      expect(await ERC20.functions.balanceOf(DEPLOYER)).to.equal(DEFAULT_DRIP_AMOUNT.mul(2 + factor));
    });
  });

  describe('Owner can adjust Withdraw Cooldown', async () => {
    it('isAllowedToWithdraw(): Owner is not allowed to withdraw', async function () {
      await expect(FAUCET.functions.isAllowedToWithdraw(DEPLOYER)).to.be.revertedWith(COME_BACK_LATER);
    });

    it('setWithdrawCooldown(): Owner adjusts Withdraw Cooldown to 0 seconds', async function () {
      expect(await FAUCET.functions.setWithdrawCooldown(0)).to.not.reverted;
      expect(await FAUCET.faucetCooldown).to.equal(0);
    });

    it('isAllowedToWithdraw(): Owner is allowed to withdraw', async function () {
      expect(await FAUCET.functions.isAllowedToWithdraw(DEPLOYER)).to.be.true;
    });

    it('setWithdrawCooldown(): Owner adjusts Withdraw Cooldown back to 24 hours', async function () {
      expect(await FAUCET.functions.setWithdrawCooldown(DEFAULT_DRIP_COOLDOWN)).to.not.reverted;
      expect(await FAUCET.faucetCooldown).to.equal(DEFAULT_DRIP_COOLDOWN);
    });

    it('isAllowedToWithdraw(): Owner is not allowed to withdraw', async function () {
      await expect(FAUCET.functions.isAllowedToWithdraw(DEPLOYER)).to.be.revertedWith(COME_BACK_LATER);
    });

    it(`setWithdrawCooldown(): User can't adjust Withdraw Cooldown`, async function () {
      await expect(FAUCET.connect(USER_A).setWithdrawCooldown(0)).to.revertedWith(NOT_AN_OWNER);
    });
  });

  describe('Owner can adjust Withdraw Amount', async () => {
    const factor = 2;

    it('setWithdrawAmount(): Owner adjusts Withdraw Amount', async function () {
      expect(await FAUCET.functions.setWithdrawAmount(DEFAULT_DRIP_AMOUNT.mul(factor))).to.not.reverted;
      expect(await FAUCET.faucetDripAmount).to.equal(DEFAULT_DRIP_AMOUNT.mul(factor));
    });

    it('requestTokens(): User can withdraw increased amount', async function () {
      await FAUCET.connect(USER_A)
        .functions.requestTokens()
        .then((tx) => tx.wait());
      dripCount += factor;
      expect(await ERC20.functions.balanceOf(USER_A)).to.equal(DEFAULT_DRIP_AMOUNT.mul(factor));
    });

    it('setWithdrawAmount(): Owner adjusts Withdraw Amount back to 100 eth', async function () {
      expect(await FAUCET.functions.setWithdrawAmount(DEFAULT_DRIP_AMOUNT)).to.not.reverted;
      expect(await FAUCET.faucetDripAmount).to.equal(DEFAULT_DRIP_AMOUNT);
    });

    it(`setWithdrawAmount(): User can't adjust Withdraw Amount`, async function () {
      await expect(FAUCET.connect(USER_A).functions.setWithdrawAmount(0)).to.revertedWith(NOT_AN_OWNER);
    });
  });

  describe('Owner can Withdraw Faucet funds', async () => {
    it('withdrawTokens(address,uint256)', async function () {
      await FAUCET.functions['withdrawTokens(address,uint256)'](USER_B, DEFAULT_DRIP_AMOUNT).then((tx) => tx.wait());
      dripCount++;
      expect(await ERC20.functions.balanceOf(USER_B)).to.equal(DEFAULT_DRIP_AMOUNT);
    });

    it('withdrawTokens(address)', async function () {
      await FAUCET.functions['withdrawTokens(address)'](USER_C).then((tx) => tx.wait());
      expect(await ERC20.functions.balanceOf(USER_C)).to.equal(
        INITIAL_FAUCET_FUNDS.sub(DEFAULT_DRIP_AMOUNT.mul(dripCount))
      );
      expect(await ERC20.functions.balanceOf(FAUCET.address)).to.equal(0);
    });
  });
});
