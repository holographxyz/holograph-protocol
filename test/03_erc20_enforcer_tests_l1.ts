declare var global: any;
import { expect, assert } from 'chai';
import { PreTest } from './utils';
import setup from './utils';
import { BigNumberish, BytesLike } from 'ethers';
import { zeroAddress } from '../scripts/utils/helpers';

import {
  CxipERC721,
  ERC20Mock,
  Holograph,
  HolographBridge,
  HolographBridgeProxy,
  Holographer,
  HolographERC20,
  HolographERC721,
  HolographFactory,
  HolographFactoryProxy,
  HolographGenesis,
  HolographRegistry,
  HolographRegistryProxy,
  HToken,
  MockERC721Receiver,
  PA1D,
  SampleERC20,
  SampleERC721,
  SecureStorage,
  SecureStorageProxy,
} from '../typechain-types';

describe('Testing the Holograph ERC20 Enforcer (L1)', async function () {
  let _: PreTest;
  let ERC20: HolographERC20;
  let SAMPLEERC20: SampleERC20;

  const tokenName: string = 'Sample ERC20 Token';
  const tokenSymbol: string = 'SMPL';
  const tokenDecimals: number = 18;
  const totalTokens: string = '12.34';
  let tokensWei: string;

  before(async function () {
    global.__companionNetwork = false;
    _ = await setup();
    tokensWei = _.web3.utils.toWei(totalTokens, 'ether');
    ERC20 = await _.holographErc20.attach(_.sampleErc20Holographer.address);
    SAMPLEERC20 = await _.sampleErc20.attach(_.sampleErc20Holographer.address);
  });

  after(async function () {
    global.__companionNetwork = false;
  });

  beforeEach(async function () {});

  afterEach(async function () {});

  describe('Check that deployed ERC20 token contract data is correct', async function () {
    describe('token name:', async function () {
      it('should return "' + tokenName + '" for token name', async function () {
        expect(await ERC20.name()).to.equal(tokenName);
      });
    });

    describe('token symbol:', async function () {
      it('should return "' + tokenSymbol + '" for token symbol', async function () {
        expect(await ERC20.symbol()).to.equal(tokenSymbol);
      });
    });

    describe('token decimals:', async function () {
      it('should return "' + tokenDecimals + '" for token decimals', async function () {
        expect(await ERC20.decimals()).to.equal(tokenDecimals);
      });
    });
  });

  describe('Mint ERC20 tokens', async function () {
    describe('try to mint ' + totalTokens + ' ' + tokenSymbol + ' tokens', async function () {
      it('should have a total supply of 0 ' + tokenSymbol + ' tokens', async function () {
        expect(await ERC20.totalSupply()).to.equal(0);
      });

      it('should emit Transfer event for ' + totalTokens + ' ' + tokenSymbol + ' tokens', async function () {
        await expect(SAMPLEERC20.mint(zeroAddress(), _.deployer.address, tokensWei))
          .to.emit(ERC20, 'Transfer')
          .withArgs(zeroAddress(), _.deployer.address, tokensWei);
      });

      it('should have a total supply of ' + totalTokens + ' ' + tokenSymbol + ' tokens', async function () {
        expect(await ERC20.totalSupply()).to.equal(tokensWei);
      });

      it('deployer wallet should show a balance of ' + totalTokens + ' ' + tokenSymbol + ' tokens', async function () {
        expect(await ERC20.balanceOf(_.deployer.address)).to.equal(tokensWei);
      });
    });
  });

  describe('Test token transfers', async function () {
    describe('token approvals', async function () {
      const maxValue: BytesLike = '0x' + 'ff'.repeat(32);
      const halfValue: BytesLike = '0x' + '00'.repeat(16) + 'ff'.repeat(16);
      const halfInverseValue: BytesLike = '0x' + 'ff'.repeat(16) + '00'.repeat(16);
      it('should fail when approving a zero address', async function () {
        await expect(ERC20.approve(zeroAddress(), maxValue)).to.be.revertedWith('ERC20: spender is zero address');
      });

      it('should succeed when approving valid address', async function () {
        await expect(ERC20.approve(_.wallet2.address, maxValue))
          .to.emit(ERC20, 'Approval')
          .withArgs(_.deployer.address, _.wallet2.address, maxValue);
      });

      it('should succeed decreasing allowance above zero', async function () {
        await expect(ERC20.decreaseAllowance(_.wallet2.address, halfValue))
          .to.emit(ERC20, 'Approval')
          .withArgs(_.deployer.address, _.wallet2.address, halfInverseValue);
      });

      it('should fail decreasing allowance below zero', async function () {
        await expect(ERC20.decreaseAllowance(_.wallet2.address, maxValue)).to.be.revertedWith(
          'ERC20: decreased below zero'
        );
      });

      it('should succeed increasing allowance below max value', async function () {
        await expect(ERC20.increaseAllowance(_.wallet2.address, halfValue))
          .to.emit(ERC20, 'Approval')
          .withArgs(_.deployer.address, _.wallet2.address, maxValue);
      });

      it('should fail increasing allowance above max value', async function () {
        await expect(ERC20.increaseAllowance(_.wallet2.address, maxValue)).to.be.revertedWith(
          'ERC20: increased above max value'
        );
      });

      it('should succeed decreasing allowance to zero', async function () {
        await expect(ERC20.decreaseAllowance(_.wallet2.address, maxValue))
          .to.emit(ERC20, 'Approval')
          .withArgs(_.deployer.address, _.wallet2.address, 0);
      });

      it('should succeed increasing allowance to max value', async function () {
        await expect(ERC20.increaseAllowance(_.wallet2.address, maxValue))
          .to.emit(ERC20, 'Approval')
          .withArgs(_.deployer.address, _.wallet2.address, maxValue);
      });
    });

    describe('failed transfer', async function () {
      it("should fail if sender doesn't have enough tokens", async function () {
        await expect(
          ERC20.transfer(_.wallet1.address, _.web3.utils.toWei((parseInt(totalTokens) + 1.0).toString(), 'ether'))
        ).to.be.revertedWith('ERC20: amount exceeds balance');
      });

      it('should fail if sending to zero address', async function () {
        await expect(ERC20.transfer(zeroAddress(), tokensWei)).to.be.revertedWith('ERC20: recipient is zero address');
      });

      it('should fail if sending from zero address', async function () {
        await expect(ERC20.transferFrom(zeroAddress(), _.wallet1.address, tokensWei)).to.be.revertedWith(
          'ERC20: amount exceeds allowance'
        );
      });

      it('should fail if sending from not approved address', async function () {
        await expect(ERC20.transferFrom(_.wallet1.address, _.deployer.address, tokensWei)).to.be.revertedWith(
          'ERC20: amount exceeds allowance'
        );
      });

      it('should fail if sending from not approved address', async function () {
        await expect(ERC20.transferFrom(_.wallet1.address, _.deployer.address, tokensWei)).to.be.revertedWith(
          'ERC20: amount exceeds allowance'
        );
      });

      it('should fail if allowance is smaller than transfer amount', async function () {
        const smallerAmount: string = tokensWei.slice(0, -2);
        await expect(ERC20.approve(_.wallet2.address, smallerAmount))
          .to.emit(ERC20, 'Approval')
          .withArgs(_.deployer.address, _.wallet2.address, smallerAmount);
        await expect(
          ERC20.connect(_.wallet2).transferFrom(_.deployer.address, _.wallet1.address, tokensWei)
        ).to.be.revertedWith('ERC20: amount exceeds allowance');
        await expect(ERC20.approve(_.wallet2.address, 0))
          .to.emit(ERC20, 'Approval')
          .withArgs(_.deployer.address, _.wallet2.address, 0);
      });
    });

    describe('successful transfer', async function () {
      it('should succeed when transferring available tokens', async function () {
        await expect(ERC20.transfer(_.wallet1.address, tokensWei))
          .to.emit(ERC20, 'Transfer')
          .withArgs(_.deployer.address, _.wallet1.address, tokensWei);
      });

      it('deployer should have a balance of 0 ' + tokenSymbol + ' tokens', async function () {
        expect(await ERC20.balanceOf(_.deployer.address)).to.equal(0);
      });

      it('wallet1 should have a balance of ' + totalTokens + ' ' + tokenSymbol + ' tokens', async function () {
        expect(await ERC20.balanceOf(_.wallet1.address)).to.equal(tokensWei);
      });

      it('should succeed when safely transferring available tokens', async function () {
        await expect(ERC20.connect(_.wallet1)['safeTransfer(address,uint256)'](_.deployer.address, tokensWei))
          .to.emit(ERC20, 'Transfer')
          .withArgs(_.wallet1.address, _.deployer.address, tokensWei);
      });

      it('wallet1 should have a balance of 0 ' + tokenSymbol + ' tokens', async function () {
        expect(await ERC20.balanceOf(_.wallet1.address)).to.equal(0);
      });

      it('deployer should have a balance of ' + totalTokens + ' ' + tokenSymbol + ' tokens', async function () {
        expect(await ERC20.balanceOf(_.deployer.address)).to.equal(tokensWei);
      });

      it('should succeed when transferring using an approved spender', async function () {
        await expect(ERC20.approve(_.wallet1.address, tokensWei))
          .to.emit(ERC20, 'Approval')
          .withArgs(_.deployer.address, _.wallet1.address, tokensWei);
        expect(await ERC20.allowance(_.deployer.address, _.wallet1.address)).to.equal(tokensWei);
        await expect(ERC20.connect(_.wallet1).transferFrom(_.deployer.address, _.wallet1.address, tokensWei))
          .to.emit(ERC20, 'Transfer')
          .withArgs(_.deployer.address, _.wallet1.address, tokensWei);
        expect(await ERC20.allowance(_.deployer.address, _.wallet1.address)).to.equal(0);
        await expect(ERC20.connect(_.wallet1).transfer(_.deployer.address, tokensWei))
          .to.emit(ERC20, 'Transfer')
          .withArgs(_.wallet1.address, _.deployer.address, tokensWei);
      });
    });
  });

  describe('Test token burning', async function () {
    it('should fail burning more tokens than current balance', async function () {
      await expect(ERC20.connect(_.wallet1).burn(tokensWei)).to.be.revertedWith('ERC20: amount exceeds balance');
    });

    it('should succeed burning current balance', async function () {
      await expect(ERC20.burn(tokensWei))
        .to.emit(ERC20, 'Transfer')
        .withArgs(_.deployer.address, zeroAddress(), tokensWei);
      expect(await ERC20.totalSupply()).to.equal(0);
    });

    it('should fail burning via not approved spender', async function () {
      await expect(SAMPLEERC20.mint(zeroAddress(), _.deployer.address, tokensWei))
        .to.emit(ERC20, 'Transfer')
        .withArgs(zeroAddress(), _.deployer.address, tokensWei);
      expect(await ERC20.totalSupply()).to.equal(tokensWei);
      await expect(ERC20.connect(_.wallet1).burnFrom(_.deployer.address, tokensWei)).to.be.revertedWith(
        'ERC20: amount exceeds allowance'
      );
    });

    it('should succeed burning via approved spender', async function () {
      await expect(ERC20.approve(_.wallet1.address, tokensWei))
        .to.emit(ERC20, 'Approval')
        .withArgs(_.deployer.address, _.wallet1.address, tokensWei);
      await expect(ERC20.connect(_.wallet1).burnFrom(_.deployer.address, tokensWei))
        .to.emit(ERC20, 'Transfer')
        .withArgs(_.deployer.address, zeroAddress(), tokensWei);
      expect(await ERC20.totalSupply()).to.equal(0);
    });
  });
});
