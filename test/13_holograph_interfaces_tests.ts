import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { AbiCoder, base64 } from 'ethers/lib/utils'
import { ethers } from 'hardhat'
import { generateInitCode } from '../scripts/utils/helpers'
import { HolographInterfaces, HolographInterfaces__factory, MockExternalCall, MockExternalCall__factory } from '../typechain-types'

describe.only('Holograph Interfaces Contract', async function () {
  let interfaces: HolographInterfaces
  let interfaces: HolographInterfaces // TODO
  let mockExternalCall: MockExternalCall

  let deployer: SignerWithAddress
  let admin: SignerWithAddress
  let user: SignerWithAddress

  const randomAddress = () => ethers.Wallet.createRandom().address

  const contractAdmin = randomAddress()

  const initCode = generateInitCode(
    ['address'],
    [contractAdmin]
  )

  enum TokenUriType {
    UNDEFINED = 0,
    IPFS,
    HTTPS,
    ARWEAVE
  }

  enum ChainIdType {
    UNDEFINED = 0,
    EVM,
    HOLOGRAPH,
    LAYERZERO,
    HYPERLANE
  }

  enum InterfaceType {
    UNDEFINED = 0,
    ERC20,
    ERC721,
    ERC1155,
    PA1D
  }

  function encodeFunctionSignature(fnSignature: string, fnName: string, fnParams: any[] = []) {
    return new ethers.utils.Interface([fnSignature]).encodeFunctionData(fnName, fnParams)
  }

  before(async () => {
    [deployer, admin, user] = await ethers.getSigners()

    const InterfacesFactory = await ethers.getContractFactory<HolographInterfaces__factory>('HolographInterfaces')
    interfaces = await InterfacesFactory.deploy()
    await interfaces.deployed()

    const mockExternalCallFactory = await ethers.getContractFactory<MockExternalCall__factory>('MockExternalCall')
    mockExternalCall = await mockExternalCallFactory.deploy()
    await mockExternalCall.deployed()
  });

  describe('constructor', async function () {
    it('should successfully deploy', async () => {
      await expect(await interfaces.deployed().then(() => true)).to.be.true
    });
  });

  describe('init()', async function () {
    it('should successfully be initialized once', async () => {
      await expect(interfaces.init(initCode)).to.not.be.reverted
      // await expect(interfaces.functions.setAdmin(admin.address)).to.not.be.reverted
    }) // Validate hardcoded values are correct

    it('should fail if already initialized', async () => {
      await expect(interfaces.init(initCode)).to.be.reverted
    });

    it('Should allow external contract to call fn');

    it('should fail to allow inherited contract to call fn');
  });

  describe(`contractURI()`, async function () {
    it('should successfully get contract URI', async () => {
      // abi.encodePacked(
      //   "data:application/json;base64,",
      //   base64.encode(
      //     AbiCoder.encodePacked(
      //       '{"name":"', name,
      //       '","description":"', name,
      //       '","image":"', imageURL,
      //       '","external_link":"', externalLink,
      //       '","seller_fee_basis_points":', Strings.uint2str(bps),
      //       ',"fee_recipient":"0x', Strings.toAsciiString(contractAddress),
      //       '"}'
      //     )
      //   )
      // )
      console.debug('\n========== contractURI\n', await interfaces.functions.contractURI('a', 'b', 'c', 1, 'd'))
      await expect((await interfaces.functions.contractURI('a', 'b', 'c', 1, 'd'))[0]).to.not.reverted
    });

    it('Should allow external contract to call fn');

    it('should fail to allow inherited contract to call fn');
  });

  describe(`getUriPrepend()`, async function () {
    it('should get expected prepend value', async () => {
      await expect(interfaces.functions.getUriPrepend(TokenUriType.IPFS)).to.equal('')
    });

    it('Should allow external contract to call fn');

    it('should fail to allow inherited contract to call fn');
  });

  describe('updateUriPrepend(uriTypes,string)', async function () {
    it('should allow admin to alter _prependURI', async () => {
      await expect(interfaces.connect(admin).functions.updateUriPrepend(TokenUriType.IPFS, 'abc')).to.not.reverted
    })

    it('should fail to allow owner to alter _prependURI', async () => {
      await expect(interfaces.functions.updateUriPrepend(TokenUriType.IPFS, 'abc')).to.reverted
    })

    it('should fail to allow non-owner to alter _prependURI', async () => {
      await expect(interfaces.connect(user).functions.updateUriPrepend(TokenUriType.IPFS, 'abc')).to.reverted
    });
  });

  describe('updateUriPrepends(uriTypes, string[])', async function () {
    it('should allow admin to alter _prependURI', async () => {
      await expect(interfaces.connect(admin).functions.updateUriPrepends([TokenUriType.IPFS, TokenUriType.HTTPS], ['abc', 'def'])).to.not.reverted
    })

    it('should fail to allow owner to alter _prependURI', async () => {
      await expect(interfaces.functions.updateUriPrepends([TokenUriType.IPFS, TokenUriType.HTTPS], ['abc', 'def'])).to.reverted
    })

    it('should fail to allow non-owner to alter _prependURI', async () => {
      await expect(interfaces.connect(user).functions.updateUriPrepends([TokenUriType.IPFS, TokenUriType.HTTPS], ['abc', 'def'])).to.reverted
    });
  });

  describe(`getChainId()`, async function () {
    it('should get expected toChainId value', async () => {
      let result = interfaces.functions.getChainId(ChainIdType.HOLOGRAPH, 2, ChainIdType.LAYERZERO)
      console.debug('\n========== getChainId\n', await result)
      await expect(interfaces.functions.getChainId(ChainIdType.HOLOGRAPH, 2, ChainIdType.LAYERZERO)).to.not.reverted
    });

    it('Should allow external contract to call fn');

    it('should fail to allow inherited contract to call fn');
  });

  describe('updateChainIdMap()', async function () {
    it('should allow admin to alter _chainIdMap', async () => {
      await expect(interfaces.connect(admin).functions.updateChainIdMap(ChainIdType.HOLOGRAPH, 1, ChainIdType.LAYERZERO, 2)).to.not.reverted
    })

    it('should fail to allow owner to alter _chainIdMap', async () => {
      await expect(interfaces.functions.updateChainIdMap(ChainIdType.HOLOGRAPH, 1, ChainIdType.LAYERZERO, 2)).to.reverted
    })

    it('should fail to allow non-owner to alter _chainIdMap', async () => {
      await expect(interfaces.connect(user).functions.updateChainIdMap(ChainIdType.HOLOGRAPH, 1, ChainIdType.LAYERZERO, 2)).to.reverted
    });
  });

  describe(`supportsInterface()`, async function () {
    it('should get expected _supportedInterfaces value', async function () {
      let result = interfaces.functions.supportsInterface(InterfaceType.ERC20, 'a')
      console.debug('\n========== supportsInterface\n', await result)
      await expect(interfaces.functions.supportsInterface(InterfaceType.ERC20, 'a')).to.not.reverted
    });

    it('Should allow external contract to call fn');

    it('should fail to allow inherited contract to call fn');
  });

  describe('updateInterface()', async function () {
    it('should allow admin to alter _supportedInterfaces', async () => {
      await expect(interfaces.connect(admin).functions.updateInterface(InterfaceType.ERC20, 'a', true)).to.not.reverted
    })

    it('should fail to allow owner to alter _supportedInterfaces', async () => {
      await expect(interfaces.functions.updateInterface(InterfaceType.ERC20, 'a', true)).to.reverted
    })

    it('should fail to allow non-owner to alter _supportedInterfaces', async () => {
      await expect(interfaces.connect(user).functions.updateInterface(InterfaceType.ERC20, 'a', true)).to.reverted
    });
  });

  describe('updateInterfaces()', async function () {
    it('should allow admin to alter _supportedInterfaces', async () => {
      await expect(interfaces.connect(admin).functions.updateInterfaces(InterfaceType.ERC20, ['a', 'b'], true)).to.not.reverted
    })

    it('should fail to allow owner to alter _supportedInterfaces', async () => {
      await expect(interfaces.functions.updateInterfaces(InterfaceType.ERC20, ['a', 'b'], true)).to.reverted
    })

    it('should fail to allow non-owner to alter _supportedInterfaces', async () => {
      await expect(interfaces.connect(user).functions.updateInterfaces(InterfaceType.ERC20, ['a', 'b'], true)).to.reverted
    });
  });

  describe(`receive()`, async function () {
    it('should revert');
  });

  describe(`fallback()`, async function () {
    it('should revert');
  });
});
