declare var global: any;
import { expect, assert } from 'chai';
import { PreTest } from './utils';
import setup from './utils';
import { BigNumberish, BytesLike } from 'ethers';
import { zeroAddress, functionHash, XOR, buildDomainSeperator } from '../scripts/utils/helpers';

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

  describe('Check interfaces', async function () {
    describe('ERC165', async function () {
      it('ERC165 interface supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('supportsInterface(bytes4)'))).to.be.true;
      });
    });

    describe('ERC20', async function () {
      it('allowance supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('allowance(address,address)'))).to.be.true;
      });

      it('approve supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('approve(address,uint256)'))).to.be.true;
      });

      it('balanceOf supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('balanceOf(address)'))).to.be.true;
      });

      it('totalSupply supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('totalSupply()'))).to.be.true;
      });

      it('transfer supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('transfer(address,uint256)'))).to.be.true;
      });

      it('transferFrom supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('transferFrom(address,address,uint256)'))).to.be.true;
      });

      it('ERC20 interface supported', async function () {
        expect(
          await ERC20.supportsInterface(
            XOR([
              functionHash('allowance(address,address)'),
              functionHash('approve(address,uint256)'),
              functionHash('balanceOf(address)'),
              functionHash('totalSupply()'),
              functionHash('transfer(address,uint256)'),
              functionHash('transferFrom(address,address,uint256)'),
            ])
          )
        ).to.be.true;
      });
    });

    describe('ERC20Metadata', async function () {
      it('name supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('name()'))).to.be.true;
      });

      it('symbol supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('symbol()'))).to.be.true;
      });

      it('decimals supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('decimals()'))).to.be.true;
      });

      it('ERC20Metadata interface supported', async function () {
        expect(
          await ERC20.supportsInterface(
            XOR([functionHash('name()'), functionHash('symbol()'), functionHash('decimals()')])
          )
        ).to.be.true;
      });
    });

    describe('ERC20Burnable', async function () {
      it('burn supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('burn(uint256)'))).to.be.true;
      });

      it('burnFrom supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('burnFrom(address,uint256)'))).to.be.true;
      });

      it('ERC20Burnable interface supported', async function () {
        expect(
          await ERC20.supportsInterface(XOR([functionHash('burn(uint256)'), functionHash('burnFrom(address,uint256)')]))
        ).to.be.true;
      });
    });

    describe('ERC20Safer', async function () {
      it('safeTransfer supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('safeTransfer(address,uint256)'))).to.be.true;
      });

      it('safeTransfer (with bytes) supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('safeTransfer(address,uint256,bytes)'))).to.be.true;
      });

      it('safeTransferFrom supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('safeTransferFrom(address,address,uint256)'))).to.be.true;
      });

      it('safeTransferFrom (with bytes) supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('safeTransferFrom(address,address,uint256,bytes)'))).to.be
          .true;
      });

      it('ERC20Safer interface supported', async function () {
        expect(
          await ERC20.supportsInterface(
            XOR([
              functionHash('safeTransfer(address,uint256)'),
              functionHash('safeTransfer(address,uint256,bytes)'),
              functionHash('safeTransferFrom(address,address,uint256)'),
              functionHash('safeTransferFrom(address,address,uint256,bytes)'),
            ])
          )
        ).to.be.true;
      });
    });

    describe('ERC20Permit', async function () {
      it('permit supported', async function () {
        expect(
          await ERC20.supportsInterface(functionHash('permit(address,address,uint256,uint256,uint8,bytes32,bytes32)'))
        ).to.be.true;
      });

      it('nonces supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('nonces(address)'))).to.be.true;
      });

      it('DOMAIN_SEPARATOR supported', async function () {
        expect(await ERC20.supportsInterface(functionHash('DOMAIN_SEPARATOR()'))).to.be.true;
      });

      it('ERC20Permit interface supported', async function () {
        expect(
          await ERC20.supportsInterface(
            XOR([
              functionHash('permit(address,address,uint256,uint256,uint8,bytes32,bytes32)'),
              functionHash('nonces(address)'),
              functionHash('DOMAIN_SEPARATOR()'),
            ])
          )
        ).to.be.true;
      });
    });
  });

  describe('Test ERC20Metadata', async function () {
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

  describe('Test ERC20', async function () {
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

  describe('Test ERC20Burnable', async function () {
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

  describe('Test ERC20Permit', async function () {
    describe('Check domain seperator', async function () {
      it('should return correct domain seperator', async function () {
        expect(await ERC20.DOMAIN_SEPARATOR()).to.equal(
          buildDomainSeperator(_.network.chain, 'Sample ERC20 Token', '1', ERC20.address)
        );
      });
    });
  });
});
