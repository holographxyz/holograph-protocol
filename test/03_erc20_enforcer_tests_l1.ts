declare var global: any;
import { expect, assert } from 'chai';
import { PreTest } from './utils';
import setup from './utils';
import { BigNumberish, BytesLike, BigNumber } from 'ethers';
import { zeroAddress, functionHash, XOR, buildDomainSeperator, randomHex } from '../scripts/utils/helpers';

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

      // "onERC20Received(address,address,uint256,bytes)"
      // "safeTransfer(address,uint256)"
      // "safeTransferFrom(address,address,uint256)"
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

      // "onERC20Received(address,address,uint256,bytes)"
      // "safeTransfer(address,uint256)"
      // "safeTransferFrom(address,address,uint256)"
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

    describe('Check EIP712 permit functionality', async function () {
      const maxValue: BytesLike = '0x' + 'ff'.repeat(32);
      const badDeadline = Math.round(Date.now() / 1000) - 60 * 24;
      const goodDeadline = Math.round(Date.now() / 1000) + 60 * 24;

      it('should return 0 nonce', async function () {
        expect(await ERC20.nonces(_.deployer.address)).to.equal(0);
      });

      it('should fail for expired deadline', async function () {
        await expect(
          ERC20.permit(
            _.deployer.address,
            _.wallet1.address,
            maxValue,
            badDeadline,
            '0x00',
            '0x' + '00'.repeat(32),
            '0x' + '00'.repeat(32)
          )
        ).to.be.revertedWith('ERC20: expired deadline');
      });

      it('should fail for empty signature', async function () {
        await expect(
          ERC20.permit(
            _.deployer.address,
            _.wallet1.address,
            maxValue,
            goodDeadline,
            '0x1b',
            '0x' + '00'.repeat(32),
            '0x' + '00'.repeat(32)
          )
        ).to.be.revertedWith('ECDSA: invalid signature');
      });

      it('should fail for zero address signature', async function () {
        await expect(
          ERC20.permit(
            _.deployer.address,
            _.wallet1.address,
            maxValue,
            goodDeadline,
            '0x1b',
            '0x' + '11'.repeat(32),
            '0x' + '11'.repeat(32)
          )
        ).to.be.revertedWith('ECDSA: invalid signature');
      });

      it('should fail for invalid signature v value', async function () {
        await expect(
          ERC20.permit(
            _.deployer.address,
            _.wallet1.address,
            maxValue,
            goodDeadline,
            '0x00',
            '0x' + '00'.repeat(32),
            '0x' + '00'.repeat(32)
          )
        ).to.be.revertedWith("ECDSA: invalid signature 'v' value");
      });

      it('should fail for invalid signature', async function () {
        await expect(
          ERC20.permit(
            _.deployer.address,
            _.wallet1.address,
            maxValue,
            goodDeadline,
            '0x1b',
            '0x' + '35'.repeat(32),
            '0x' + '68'.repeat(32)
          )
        ).to.be.revertedWith('ERC20: invalid signature');
      });

      it('should succeed for valid signature', async function () {
        let domain = {
          name: 'Sample ERC20 Token',
          version: '1',
          chainId: _.network.chain,
          verifyingContract: ERC20.address,
        };
        let types = {
          Permit: [
            { name: 'owner', type: 'address' },
            { name: 'spender', type: 'address' },
            { name: 'value', type: 'uint256' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
          ],
        };
        let nonce = await ERC20.nonces(_.deployer.address);
        let value = {
          owner: _.deployer.address,
          spender: _.wallet1.address,
          value: maxValue,
          nonce: nonce,
          deadline: goodDeadline,
        };
        let sig = await _.deployer._signTypedData(domain, types, value);
        let signature: { r: string; s: string; v: string } = {
          r: '0x' + sig.substring(2, 66),
          s: '0x' + sig.substring(66, 130),
          v: '0x' + sig.substring(130, 132),
        };
        const validator: BigNumber = BigNumber.from(
          '0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0'
        );
        if (BigNumber.from(signature.s).gt(validator)) {
          // we have an issue
          signature.s = BigNumber.from('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141')
            .sub(BigNumber.from(signature.s))
            .toHexString();
          let v = parseInt(signature.v);
          if (v < 27) {
            v = 27;
          }
          if (v == 27) {
            v = 28;
          } else {
            v = 27;
          }
          signature.v = '0x' + v.toString(16).padStart(2, '0');
        }

        await expect(
          ERC20.permit(
            _.deployer.address,
            _.wallet1.address,
            maxValue,
            goodDeadline,
            signature.v,
            signature.r,
            signature.s
          )
        )
          .to.emit(ERC20, 'Approval')
          .withArgs(_.deployer.address, _.wallet1.address, maxValue);
      });
    });
  });

  describe('Ownership tests', async function () {
    describe('Owner', async function () {
      it('should return deployer address', async function () {
        expect(await ERC20.owner()).to.equal(_.deployer.address);
      });

      it('deployer should return true for isOwner', async function () {
        expect(await SAMPLEERC20.attach(_.sampleErc20.address)['isOwner()']()).to.be.true;
      });

      it('deployer should return true for isOwner (msgSender)', async function () {
        expect(await SAMPLEERC20.attach(ERC20.address)['isOwner(address)'](zeroAddress())).to.be.true;
      });

      it('wallet1 should return false for isOwner', async function () {
        expect(await SAMPLEERC20.attach(_.sampleErc20.address).connect(_.wallet1)['isOwner()']()).to.be.false;
      });

      it('should return "HolographFactoryProxy" address', async function () {
        expect(await ERC20.getOwner()).to.equal(_.holographFactoryProxy.address);
      });

      it('deployer should fail transferring ownership', async function () {
        await expect(ERC20.setOwner(_.wallet1.address)).to.be.revertedWith('HOLOGRAPH: owner only function');
      });

      it.skip('deployer should set owner to wallet1', async function () {
        await expect(ERC20.setOwner(_.wallet1.address))
          .to.emit(ERC20, 'OwnershipTransferred')
          .withArgs(_.deployer.address, _.wallet1.address);
      });

      it.skip('wallet1 should transfer ownership to deployer', async function () {
        await expect(ERC20.connect(_.wallet1).transferOwnership(_.deployer.address))
          .to.emit(ERC20, 'OwnershipTransferred')
          .withArgs(_.wallet1.address, _.deployer.address);
      });
    });

    describe('Admin', async function () {
      it('should return deployer address', async function () {
        expect(await ERC20.admin()).to.equal(_.deployer.address);
      });

      it('should return deployer address', async function () {
        expect(await ERC20.getAdmin()).to.equal(_.deployer.address);
      });

      it('wallet1 should fail setting admin', async function () {
        await expect(ERC20.connect(_.wallet1).setAdmin(_.wallet2.address)).to.be.revertedWith(
          'HOLOGRAPH: admin only function'
        );
      });

      it('deployer should succeed setting admin', async function () {
        await ERC20.setAdmin(_.wallet1.address);

        expect(await ERC20.admin()).to.equal(_.wallet1.address);

        await ERC20.connect(_.wallet1).setAdmin(_.deployer.address);

        expect(await ERC20.admin()).to.equal(_.deployer.address);
      });
    });
  });

  describe('Source tests', async function () {
    describe('Minting', async function () {
      // "sourceMint(address,uint256)"
      // "sourceMintBatch(address[],uint256[])"
    });

    describe('Transferring', async function () {
      // "sourceTransfer(address,address,uint256)"
    });

    describe('Burning', async function () {
      // "sourceBurn(address,uint256)"
    });
  });

  describe('Basic bridge tests', async function () {
    describe('Bridge OUT', async function () {
      // "holographBridgeOut(uint32,address,address,address,uint256)"
    });

    describe('Bridge IN', async function () {
      // "holographBridgeIn(uint32,address,address,uint256,bytes)"
    });
  });

  // SHOULD ALSO TEST RE-ENTRANCY WITH A MOCK RECEIVER THAT ATTEMPTS A RE-ENTRANT CALL MIDWAY
});
