import { expect, assert } from 'chai';
import { ethers } from 'hardhat';
import Web3 from 'web3';
import { deployments } from 'hardhat';
import { BigNumberish, BytesLike, ContractFactory } from 'ethers';

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
  CxipRegistry,
  CxipERC721Proxy,
  CxipERC1155Proxy,
  CxipProvenanceProxy,
  PA1DProxy,
  CxipProvenance,
  CxipERC721,
  PA1D,
  MockERC721Receiver,
  CxipFactory,
} from '../typechain-types';
import { utf8ToBytes32, ZERO_ADDRESS, sha256 } from './utils';

const web3 = new Web3(Web3.givenProvider || 'ws://localhost:8545');

describe('CXIP', () => {
  let deployer: SignerWithAddress;
  let user: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let user4: SignerWithAddress;
  let user5: SignerWithAddress;
  let testWallet: SignerWithAddress;
  let testWallet2: SignerWithAddress;
  let testWallet3: SignerWithAddress;

  let niftygateway: string;

  let registry: CxipRegistry;

  let erc721Proxy: CxipERC721Proxy;
  let erc1155Proxy: CxipERC1155Proxy;
  let provenanceProxy: CxipProvenanceProxy;
  let royaltiesProxy: PA1DProxy;

  let erc721: CxipERC721;
  let provenance: CxipProvenance;
  let royalties: PA1D;

  let mockErc721Receiver: MockERC721Receiver;

  let factory: CxipFactory;

  before(async () => {
    const accounts = await ethers.getSigners();
    deployer = accounts[0];
    user = accounts[1];
    user2 = accounts[2];
    user3 = accounts[3];
    user4 = accounts[4];
    user5 = accounts[5];
    testWallet = accounts[6];
    testWallet2 = accounts[7];
    testWallet3 = accounts[8];
    niftygateway = testWallet.address;

    await deployments.fixture([
      'CxipRegistry',
      'CxipERC721Proxy',
      'CxipERC1155Proxy',
      'CxipProvenanceProxy',
      'PA1DProxy',

      'CxipProvenance',
      'CxipERC721',
      'CxipERC1155',
      'PA1D',

      'MockERC721Receiver',

      'Register',
    ]);
    registry = (await ethers.getContract('CxipRegistry')) as CxipRegistry;

    provenanceProxy = (await ethers.getContract(
      'CxipProvenanceProxy'
    )) as CxipProvenanceProxy;
    provenance = (await ethers.getContract('CxipProvenance')) as CxipProvenance;

    erc721Proxy = (await ethers.getContract(
      'CxipERC721Proxy'
    )) as CxipERC721Proxy;
    erc721 = (await ethers.getContract('CxipERC721')) as CxipERC721;

    royaltiesProxy = (await ethers.getContract('PA1DProxy')) as PA1DProxy;
    royalties = (await ethers.getContract('PA1D')) as PA1D as PA1D;

    mockErc721Receiver = (await ethers.getContract(
      'MockERC721Receiver'
    )) as MockERC721Receiver;
  });

  beforeEach(async () => {});

  afterEach(async () => {});

  describe('Registry', async () => {
    it('should set and get ERC721', async () => {
      const erc721Tx = await registry.setERC721CollectionSource(erc721.address);
      await erc721Tx.wait();
      const erc721Address = await registry.getERC721CollectionSource();
      expect(erc721Address).to.equal(erc721.address);
    });

    it('should set and get provenance', async () => {
      const provenanceTx = await registry.setProvenanceSource(
        provenance.address
      );
      await provenanceTx.wait();
      const provenanceAddress = await registry.getProvenanceSource();
      expect(provenanceAddress).to.equal(provenance.address);
    });

    it('should set and get provenance proxy', async () => {
      const provenanceProxyTx = await registry.setProvenance(
        provenanceProxy.address
      );
      await provenanceProxyTx.wait();
      const provenanceProxyAddress = await registry.getProvenance();
      expect(provenanceProxyAddress).to.equal(provenanceProxy.address);
    });

    it('should set and get royalties', async () => {
      const royaltiesTx = await registry.setPA1DSource(royalties.address);
      await royaltiesTx.wait();
      const royaltiesAddress = await registry.getPA1DSource();
      expect(royaltiesAddress).to.equal(royalties.address);
    });

    it('should set and get royalties proxy', async () => {
      const royaltiesProxyTx = await registry.setPA1D(royaltiesProxy.address);
      await royaltiesProxyTx.wait();
      const royaltiesProxyAddress = await registry.getPA1D();
      expect(royaltiesProxyAddress).to.equal(royaltiesProxy.address);
    });
  });

  describe('Collection', async () => {
    it('should create a collection', async () => {
      const salt = user3.address + '0x000000000000000000000000'.substring(2);

      // Attach the provenance implementation ABI to provenance proxy
      const p = await provenance.attach(provenanceProxy.address);

      const result = await p.connect(user3).createERC721Collection(
        salt,
        user3.address,
        [
          `0x0000000000000000000000000000000000000000000000000000000000000000`,
          `0x0000000000000000000000000000000000000000000000000000000000000000`,
          '0x0',
        ] as any,
        [
          `${utf8ToBytes32('Collection name')}`, // Collection name
          '0x0000000000000000000000000000000000000000000000000000000000000000', // Collection name 2
          `${utf8ToBytes32('Collection symbol')}`, // Collection symbol
          user3.address, // royalties (address)
          '0x0000000000000000000003e8', // 1000 bps (uint96)
        ] as unknown as {
          name: BytesLike;
          name2: BytesLike;
          symbol: BytesLike;
          royalties: string;
          bps: BigNumberish;
        }
      );

      result.wait();

      const collectionAddress = await p.getCollectionById(0);
      const collectionType = await p.getCollectionType(collectionAddress);
      const c = erc721.attach(collectionAddress);

      expect(collectionAddress).not.to.equal(ZERO_ADDRESS);
      expect(collectionType).not.to.equal(ZERO_ADDRESS);
      expect(await c.connect(user3)['isOwner()']()).to.equal(true); // TODO: isOwner() is overloaded
      expect(await c.connect(user3).owner()).to.equal(user3.address);
      expect(await c.connect(user3).name()).to.equal('Collection name');
      expect(await c.connect(user3).symbol()).to.equal('Collection symbol');
      expect(await c.connect(user3).baseURI()).to.equal(
        `https://cxip.dev/nft/${collectionAddress.toLowerCase()}`
      );
      expect(await c.connect(user3).contractURI()).to.equal(
        `https://nft.cxip.dev/${collectionAddress.toLowerCase()}/`
      );
    });
  });

  describe('ERC721', async () => {
    it('should create a ERC721 NFT in a collection', async () => {
      // First create a new identity
      const salt = user4.address + '0x000000000000000000000000'.substring(2);
      const tokenId =
        '0x0000000000000000000000000000000000000000000000000000000000000001';

      // Attach the provenance implementation ABI to provenance proxy
      const p = provenance.attach(provenanceProxy.address);

      // Then create the collection
      const result = await p.connect(user4).createERC721Collection(
        salt,
        user4.address,
        [
          `0x0000000000000000000000000000000000000000000000000000000000000000`,
          `0x0000000000000000000000000000000000000000000000000000000000000000`,
          '0x0',
        ] as unknown as { r: BytesLike; s: BytesLike; v: BigNumberish },
        [
          `${utf8ToBytes32('Collection name')}`, // Collection name
          '0x0000000000000000000000000000000000000000000000000000000000000000', // Collection name 2
          `${utf8ToBytes32('Collection symbol')}`, // Collection symbol
          user4.address, // royalties (address)
          '0x0000000000000000000003e8', // 1000 bps (uint96)
        ] as unknown as {
          name: BytesLike;
          name2: BytesLike;
          symbol: BytesLike;
          royalties: string;
          bps: BigNumberish;
        }
      );

      result.wait();

      const collectionAddress = await p.getCollectionById(1);
      const collectionType = await p.getCollectionType(collectionAddress);
      expect(collectionAddress).not.to.equal(ZERO_ADDRESS);
      expect(collectionType).not.to.equal(ZERO_ADDRESS);

      const c = erc721.attach(collectionAddress);

      // Finally create a new ERC721 NFT in the collection
      const payload =
        '0x398d6a45a2c3d1145dfc3a229313e4c3b65165eb0b8b04c0fe787d0e32924775';
      const wallet = user4.address;

      // This signature composition is required to send in the payload to create ERC721
      const sig = await user4.signMessage(payload);
      const signature = {
        r: '0x' + sig.substring(2, 66),
        s: '0x' + sig.substring(66, 130),
        v: '0x' + (parseInt('0x' + sig.substring(130, 132)) + 27).toString(16),
      };

      // The arweave and ipfs hashes are split into two variables to pack into slots
      const arHash = 'd3dStWPKvAsticf1YqNT3FQCzT2nYlAw' + 'RVNFVlKmonc';
      const ipfsHash = 'QmX3UFC6GeqnmBbthWQhxRW6WgTmWWVd' + 'ist3TL59UbTZYx';
      const nftTx = await c
        .connect(user4)
        .cxipMint(tokenId, [
          payload,
          [signature.r, signature.s, signature.v],
          wallet,
          web3.utils.asciiToHex(arHash.substring(0, 32)),
          web3.utils.asciiToHex(arHash.substring(32, 43)),
          web3.utils.asciiToHex(ipfsHash.substring(0, 32)),
          web3.utils.asciiToHex(ipfsHash.substring(32, 46)),
        ] as unknown as {
          payloadHash: BytesLike;
          payloadSignature: { r: BytesLike; s: BytesLike; v: BigNumberish };
          creator: string;
          arweave: BytesLike;
          arweave2: BytesLike;
          ipfs: BytesLike;
          ipfs2: BytesLike;
        });

      await nftTx.wait();

      expect(await c.connect(user4).payloadHash(tokenId)).to.equal(payload);
      expect(await c.connect(user4).payloadSigner(tokenId)).to.equal(
        user4.address
      );
      expect(await c.connect(user4).arweaveURI(tokenId)).to.equal(
        `https://arweave.cxip.dev/${arHash}`
      );
      expect(await c.connect(user4).tokenURI(tokenId)).to.equal(
        `https://arweave.cxip.dev/${arHash}`
      );
      expect(await c.connect(user4).ipfsURI(tokenId)).to.equal(
        `https://ipfs.cxip.dev/${ipfsHash}`
      );
      expect(await c.connect(user4).httpURI(tokenId)).to.equal(
        `https://cxip.dev/nft/${collectionAddress.toLowerCase()}/0x${tokenId.slice(
          -2
        )}`
      );

      const r = royalties.attach(collectionAddress);

      // Check unset royalties (only one benificiary is set in the royalties array)
      let royaltiesData = await r.connect(user4).getRoyalties(tokenId);

      expect(royaltiesData[0][0]).to.equal(ZERO_ADDRESS);
      expect(ethers.utils.formatUnits(royaltiesData[0][0], 18)).to.equal('0.0');

      // Set royalties to 10000 bps (100%)
      const royaltyBPS = 10000;
      await r.connect(user4).setRoyalties(tokenId, user4.address, royaltyBPS);

      // Check again after setting
      royaltiesData = await r.connect(user4).getRoyalties(tokenId);
      expect(royaltiesData[0][0]).to.equal(user4.address);
      expect(royaltiesData[1][0].toNumber()).to.equal(royaltyBPS);

      // Configure the royalty payout amounts and beneficiaries
      // 3000 bps (30%) to the deployer and 7000 (70%) to the user4
      await r
        .connect(user4)
        .configurePayouts([deployer.address, user4.address], [3000, 7000]);

      // Check that the payout info matches what was set in configuration
      let payoutInfo = await r.connect(user4).getPayoutInfo();
      const payoutAccounts = payoutInfo[0];
      const payoutAmounts = payoutInfo[1];
      expect(payoutAmounts[0].toNumber()).to.equal(3000);
      expect(payoutAmounts[1].toNumber()).to.equal(7000);
      expect(payoutAccounts[0]).to.equal(deployer.address);
      expect(payoutAccounts[1]).to.equal(user4.address);
    });
  });

  describe('Daniel Arsham: Eroding and Reforming Cars', async () => {
    it('should create 8 ERC721 NFTs in a collection', async () => {
      const tokenId = 1;
      const nonExistentTokenId = 999;
      const totalSupply = 8;
      const salt = user5.address + '0x000000000000000000000000'.substring(2);

      // Attach the provenance implementation ABI to provenance proxy
      const p = provenance.attach(provenanceProxy.address);

      // Then create the collection
      const result = await p.connect(user5).createERC721Collection(
        salt,
        user5.address,
        [
          `0x0000000000000000000000000000000000000000000000000000000000000000`,
          `0x0000000000000000000000000000000000000000000000000000000000000000`,
          '0x00',
        ] as unknown as { r: BytesLike; s: BytesLike; v: BigNumberish },
        [
          `${utf8ToBytes32('Daniel Arsham: Eroding and Refor')}`, // Collection name
          `${utf8ToBytes32('ming Cars')}`, // Collection name 2
          `${utf8ToBytes32('ERCs')}`, // Collection symbol
          user5.address, // royalties (address)
          '0x0000000000000000000003e8', // 1000 bps (uint96)
        ] as unknown as {
          name: BytesLike;
          name2: BytesLike;
          symbol: BytesLike;
          royalties: string;
          bps: BigNumberish;
        }
      );

      result.wait();

      const collectionAddress = await p.getCollectionById(2);
      const collectionType = await p.getCollectionType(collectionAddress);
      expect(collectionAddress).not.to.equal(ZERO_ADDRESS);
      expect(collectionType).not.to.equal(ZERO_ADDRESS);

      const c = erc721.attach(collectionAddress);
      const collectionName = await c.name();
      const collectionSymbol = await c.symbol();

      assert.isNotOk(
        collectionName != 'Daniel Arsham: Eroding and Reforming Cars',
        'Collection name missmatch, we want "Daniel Arsham: Eroding and Reforming Cars", but got "' +
          collectionName +
          '" instead.'
      );
      assert.isNotOk(
        collectionSymbol != 'ERCs',
        'Collection symbol missmatch, we want "ERCs", but got "' +
          collectionSymbol +
          '" instead.'
      );

      const wallet = user5.address;
      let payload: BytesLike;
      const arweave: string = 'https://arweave.cxip.dev/';
      const arHashes: Array<string> = [
        'k6Dej-c5ga1TkKlJ5vjxtCyY6W6Ipc2ds7gzHAZKir0',
        '3hBx7NynGoLPctHG8oS5uYKYdJNDj7A_IwTos9K-bUA',
        'tbkb5xO694ktcSTGn7WVIwm8Y_7cucgoN6bduo9kZDA',
        'KLBvdyxNunXuNhCyrDkPyEuJUA9frtKNa-bjFAEusB4',
        'veEDJpGhtGpA4bac62nyhY3HTbWDAV_bTtAkj6vi4dc',
        '_XAoDq-i3N7bwMNeNoUwCDVLvasCh46Fnhl9wKoaF88',
        'WYDKFYbl6sbJP5LENzwAIlbtH0enQx_HDde0_kD5QAE',
        'ucbj933WwVHVTQZP2yupmfEatLqoFYnWCQr1xXKbKdg'
      ];
      let arHash: BytesLike;
      const ipfsHashes: Array<string> = [
        'QmVLY9uE6quyCumNg4CqhAPh8Q8Kn4Hw5FTE6wKPMxKK9w',
        'QmYpYw7pk3pJqeLF7GNCP6QD7WjST3JK8zzG4cmDMM4RiU',
        'QmeZEHUkaXhRBUQhCVSJ3wrqjpAiGjySoeWq8aHufFX87e',
        'QmXXtXd943CP6fx2ZMgX4iPvZpzzW9a4FbpFCs1GMeeMof',
        'QmfX685GuEWkeLtPyyXm4DSRpHXXUsgAYDCEShrHY7GHej',
        'QmQpH5cm3CDCBGUEJ9Lo1aZc6afRdpy4jUbb9R7yfZLHxX',
        'QmYQWLJgq9zVMfkqUwDpGrP31jaobVqRMvgzzch9K1J25Y',
        'QmNs7Fvu81wDuWE2oG7D3SdSpDRmS5aDzFQHDGXdXzz8AU'
      ];
      let ipfsHash: BytesLike;
      let sig: any;
      let signature: { r: BytesLike; s: BytesLike; v: BigNumberish };


      // Mustang (State 1)
      arHash = arHashes[0];
      ipfsHash = ipfsHashes[0];
      payload = '0x' + '00'.repeat(32);
      sig = await user5.signMessage(payload);
      signature = {
        r: '0x' + sig.substring(2, 66),
        s: '0x' + sig.substring(66, 130),
        v: '0x' + (parseInt('0x' + sig.substring(130, 132)) + 27).toString(16),
      };
      const mustang1 = [
        payload,
        [signature.r, signature.s, signature.v],
        wallet,
        web3.utils.asciiToHex(arHash.substring(0, 32)),
        web3.utils.asciiToHex(arHash.substring(32, 43)),
        web3.utils.asciiToHex(ipfsHash.substring(0, 32)),
        web3.utils.asciiToHex(ipfsHash.substring(32, 46)),
      ] as unknown as {
        payloadHash: BytesLike;
        payloadSignature: { r: BytesLike; s: BytesLike; v: BigNumberish };
        creator: string;
        arweave: BytesLike;
        arweave2: BytesLike;
        ipfs: BytesLike;
        ipfs2: BytesLike;
      };
      const mustang1tx = await c.connect(user5).cxipMint(1, mustang1);
      await mustang1tx.wait();


      // Mustang (State 2)
      arHash = arHashes[1];
      ipfsHash = ipfsHashes[1];
      payload = '0x' + '00'.repeat(32);
      sig = await user5.signMessage(payload);
      signature = {
        r: '0x' + sig.substring(2, 66),
        s: '0x' + sig.substring(66, 130),
        v: '0x' + (parseInt('0x' + sig.substring(130, 132)) + 27).toString(16),
      };
      const mustang2 = [
        payload,
        [signature.r, signature.s, signature.v],
        wallet,
        web3.utils.asciiToHex(arHash.substring(0, 32)),
        web3.utils.asciiToHex(arHash.substring(32, 43)),
        web3.utils.asciiToHex(ipfsHash.substring(0, 32)),
        web3.utils.asciiToHex(ipfsHash.substring(32, 46)),
      ] as unknown as {
        payloadHash: BytesLike;
        payloadSignature: { r: BytesLike; s: BytesLike; v: BigNumberish };
        creator: string;
        arweave: BytesLike;
        arweave2: BytesLike;
        ipfs: BytesLike;
        ipfs2: BytesLike;
      };
      const mustang2tx = await c.connect(user5).cxipMint(2, mustang2);
      await mustang2tx.wait();


      // DeLorean (State 1)
      arHash = arHashes[2];
      ipfsHash = ipfsHashes[2];
      payload = '0x' + '00'.repeat(32);
      sig = await user5.signMessage(payload);
      signature = {
        r: '0x' + sig.substring(2, 66),
        s: '0x' + sig.substring(66, 130),
        v: '0x' + (parseInt('0x' + sig.substring(130, 132)) + 27).toString(16),
      };
      const delorean1 = [
        payload,
        [signature.r, signature.s, signature.v],
        wallet,
        web3.utils.asciiToHex(arHash.substring(0, 32)),
        web3.utils.asciiToHex(arHash.substring(32, 43)),
        web3.utils.asciiToHex(ipfsHash.substring(0, 32)),
        web3.utils.asciiToHex(ipfsHash.substring(32, 46)),
      ] as unknown as {
        payloadHash: BytesLike;
        payloadSignature: { r: BytesLike; s: BytesLike; v: BigNumberish };
        creator: string;
        arweave: BytesLike;
        arweave2: BytesLike;
        ipfs: BytesLike;
        ipfs2: BytesLike;
      };
      const delorean1tx = await c.connect(user5).cxipMint(3, delorean1);
      await delorean1tx.wait();


      // DeLorean (State 2)
      arHash = arHashes[3];
      ipfsHash = ipfsHashes[3];
      payload = '0x' + '00'.repeat(32);
      sig = await user5.signMessage(payload);
      signature = {
        r: '0x' + sig.substring(2, 66),
        s: '0x' + sig.substring(66, 130),
        v: '0x' + (parseInt('0x' + sig.substring(130, 132)) + 27).toString(16),
      };
      const delorean2 = [
        payload,
        [signature.r, signature.s, signature.v],
        wallet,
        web3.utils.asciiToHex(arHash.substring(0, 32)),
        web3.utils.asciiToHex(arHash.substring(32, 43)),
        web3.utils.asciiToHex(ipfsHash.substring(0, 32)),
        web3.utils.asciiToHex(ipfsHash.substring(32, 46)),
      ] as unknown as {
        payloadHash: BytesLike;
        payloadSignature: { r: BytesLike; s: BytesLike; v: BigNumberish };
        creator: string;
        arweave: BytesLike;
        arweave2: BytesLike;
        ipfs: BytesLike;
        ipfs2: BytesLike;
      };
      const delorean2tx = await c.connect(user5).cxipMint(4, delorean2);
      await delorean2tx.wait();


      // California (State 1)
      arHash = arHashes[4];
      ipfsHash = ipfsHashes[4];
      payload = '0x' + '00'.repeat(32);
      sig = await user5.signMessage(payload);
      signature = {
        r: '0x' + sig.substring(2, 66),
        s: '0x' + sig.substring(66, 130),
        v: '0x' + (parseInt('0x' + sig.substring(130, 132)) + 27).toString(16),
      };
      const california1 = [
        payload,
        [signature.r, signature.s, signature.v],
        wallet,
        web3.utils.asciiToHex(arHash.substring(0, 32)),
        web3.utils.asciiToHex(arHash.substring(32, 43)),
        web3.utils.asciiToHex(ipfsHash.substring(0, 32)),
        web3.utils.asciiToHex(ipfsHash.substring(32, 46)),
      ] as unknown as {
        payloadHash: BytesLike;
        payloadSignature: { r: BytesLike; s: BytesLike; v: BigNumberish };
        creator: string;
        arweave: BytesLike;
        arweave2: BytesLike;
        ipfs: BytesLike;
        ipfs2: BytesLike;
      };
      const california1tx = await c.connect(user5).cxipMint(5, california1);
      await california1tx.wait();


      // California (State 2)
      arHash = arHashes[5];
      ipfsHash = ipfsHashes[5];
      payload = '0x' + '00'.repeat(32);
      sig = await user5.signMessage(payload);
      signature = {
        r: '0x' + sig.substring(2, 66),
        s: '0x' + sig.substring(66, 130),
        v: '0x' + (parseInt('0x' + sig.substring(130, 132)) + 27).toString(16),
      };
      const california2 = [
        payload,
        [signature.r, signature.s, signature.v],
        wallet,
        web3.utils.asciiToHex(arHash.substring(0, 32)),
        web3.utils.asciiToHex(arHash.substring(32, 43)),
        web3.utils.asciiToHex(ipfsHash.substring(0, 32)),
        web3.utils.asciiToHex(ipfsHash.substring(32, 46)),
      ] as unknown as {
        payloadHash: BytesLike;
        payloadSignature: { r: BytesLike; s: BytesLike; v: BigNumberish };
        creator: string;
        arweave: BytesLike;
        arweave2: BytesLike;
        ipfs: BytesLike;
        ipfs2: BytesLike;
      };
      const california2tx = await c.connect(user5).cxipMint(6, california2);
      await california2tx.wait();


      // E30 (State 1)
      arHash = arHashes[6];
      ipfsHash = ipfsHashes[6];
      payload = '0x' + '00'.repeat(32);
      sig = await user5.signMessage(payload);
      signature = {
        r: '0x' + sig.substring(2, 66),
        s: '0x' + sig.substring(66, 130),
        v: '0x' + (parseInt('0x' + sig.substring(130, 132)) + 27).toString(16),
      };
      const e301 = [
        payload,
        [signature.r, signature.s, signature.v],
        wallet,
        web3.utils.asciiToHex(arHash.substring(0, 32)),
        web3.utils.asciiToHex(arHash.substring(32, 43)),
        web3.utils.asciiToHex(ipfsHash.substring(0, 32)),
        web3.utils.asciiToHex(ipfsHash.substring(32, 46)),
      ] as unknown as {
        payloadHash: BytesLike;
        payloadSignature: { r: BytesLike; s: BytesLike; v: BigNumberish };
        creator: string;
        arweave: BytesLike;
        arweave2: BytesLike;
        ipfs: BytesLike;
        ipfs2: BytesLike;
      };
      const e301tx = await c.connect(user5).cxipMint(7, e301);
      await e301tx.wait();


      // E30 (State 2)
      arHash = arHashes[7];
      ipfsHash = ipfsHashes[7];
      payload = '0x' + '00'.repeat(32);
      sig = await user5.signMessage(payload);
      signature = {
        r: '0x' + sig.substring(2, 66),
        s: '0x' + sig.substring(66, 130),
        v: '0x' + (parseInt('0x' + sig.substring(130, 132)) + 27).toString(16),
      };
      const e302 = [
        payload,
        [signature.r, signature.s, signature.v],
        wallet,
        web3.utils.asciiToHex(arHash.substring(0, 32)),
        web3.utils.asciiToHex(arHash.substring(32, 43)),
        web3.utils.asciiToHex(ipfsHash.substring(0, 32)),
        web3.utils.asciiToHex(ipfsHash.substring(32, 46)),
      ] as unknown as {
        payloadHash: BytesLike;
        payloadSignature: { r: BytesLike; s: BytesLike; v: BigNumberish };
        creator: string;
        arweave: BytesLike;
        arweave2: BytesLike;
        ipfs: BytesLike;
        ipfs2: BytesLike;
      };
      const e302tx = await c.connect(user5).cxipMint(8, e302);
      await e302tx.wait();


      describe('tokenURI', function () {
        context('when getting State 1 tokenURIs', async function () {
          assert.isNotOk(
            (await c.tokenURI(1)) != (arweave + arHashes[0]),
            "ar hash missmatch, we get" + await c.tokenURI(1)
          );
          it('returns correct Arweave URI for 10001-10050', async function () {
            const firstToken = 1;
            const lastToken = 2;
            expect(await c.tokenURI(firstToken)).to.be.equal(arweave + arHashes[0]);
            expect(await c.tokenURI(lastToken)).to.be.equal(arweave + arHashes[1]);
          });

          it('returns correct Arweave URI for 20001-20100', async function () {
            const firstToken = 3;
            const lastToken = 4;
            expect(await c.tokenURI(firstToken)).to.be.equal(arweave + arHashes[2]);
            expect(await c.tokenURI(lastToken)).to.be.equal(arweave + arHashes[3]);
          });

          it('returns correct Arweave URI for 30001-30100', async function () {
            const firstToken = 5;
            const lastToken = 6;
            expect(await c.tokenURI(firstToken)).to.be.equal(arweave + arHashes[4]);
            expect(await c.tokenURI(lastToken)).to.be.equal(arweave + arHashes[5]);
          });

          it('returns correct Arweave URI for 40001-40150', async function () {
            const firstToken = 7;
            const lastToken = 8;
            expect(await c.tokenURI(firstToken)).to.be.equal(arweave + arHashes[6]);
            expect(await c.tokenURI(lastToken)).to.be.equal(arweave + arHashes[7]);
          });
        });
      });

      /// ERC721 Token standard tests
      describe('balanceOf', function () {
        context('when the given address owns some tokens', function () {
          it('returns the amount of tokens owned by the given address', async function () {
            expect(await c.balanceOf(user5.address)).to.be.equal(totalSupply);
          });
        });

        context('when the given address does not own any tokens', function () {
          it('returns 0', async function () {
            expect(await c.balanceOf(user.address)).to.be.equal('0');
          });
        });

        context('when querying the zero address', function () {
          it('throws', async function () {
            await expect(c.balanceOf(ZERO_ADDRESS)).to.be.revertedWith(
              'CXIP: zero address'
            );
          });
        });
      });

      describe('ownerOf', function () {
        context(
          'when the given token ID was tracked by this token',
          function () {
            it('returns the owner of the given token ID', async function () {
              expect(await c.ownerOf(tokenId)).to.be.equal(user5.address);
            });
          }
        );

        context(
          'when the given token ID was not tracked by this token',
          function () {
            const tokenId = nonExistentTokenId;

            it('reverts', async function () {
              await expect(c.ownerOf(tokenId)).to.be.revertedWith(
                'ERC721: token does not exist'
              );
            });
          }
        );
      });

      describe('balanceOf', function () {
        context('get total owned tokens for wallet', function () {
          it('returns ' + totalSupply.toString() + ' for wallet', async function () {
            expect(await c.balanceOf(user5.address)).to.be.equal(totalSupply);
          });

          it('returns 0 for test wallet', async function () {
            expect(await c.balanceOf(testWallet2.address)).to.be.equal(0);
          });
        });
      });

      describe('tokenByIndex', function () {
        context('get token by index, within totalSupply limit', function () {
          it('returns tokenId for valid index', async function () {
            expect(await c.tokenByIndex(0)).to.be.above(0);
          });

          it('fails for index out of range', async function () {
            await expect(c.tokenByIndex(await c.totalSupply())).to.be.revertedWith('CXIP: index out of bounds');
          });
        });
      });

      describe('tokenOfOwnerByIndex', function () {
        context('get token of owner by index', function () {
          it('returns tokenId for valid index', async function () {
            expect(await c.tokenOfOwnerByIndex(user5.address, 0)).to.be.above(0);
          });

          it('fails for index out of range', async function () {
            await expect(c.tokenOfOwnerByIndex(user5.address, await c.balanceOf(user5.address))).to.be.revertedWith('CXIP: index out of bounds');
          });

          it('fails for wallet with no tokens', async function () {
            await expect(c.tokenOfOwnerByIndex(testWallet2.address, 0)).to.be.revertedWith('CXIP: index out of bounds');
          });
        });
      });

      describe('approve', function () {
        context('approving address for tokenId', function () {
          const tokenId = 1;
          it('returns correct wallet as approved', async function () {
            await c.connect(user5).approve(testWallet2.address, tokenId);
            expect(await c.getApproved(tokenId)).to.be.equal(
              testWallet2.address
            );
          });

          it('reverts for not approved wallet', async function () {
            await expect(
              c
                .connect(testWallet3)
                ['transferFrom(address,address,uint256)'](
                  user5.address,
                  testWallet3.address,
                  tokenId
                )
            ).to.be.revertedWith('CXIP: not approved sender');
          });

          it('reverts for not approved tokenId transfer', async function () {
            const wrongTokendId = 2;
            await expect(
              c
                .connect(testWallet2)
                ['transferFrom(address,address,uint256)'](
                  user5.address,
                  testWallet3.address,
                  wrongTokendId
                )
            ).to.be.revertedWith('CXIP: not approved sender');
          });

          it('allows approved to transfer token', async function () {
            await c
              .connect(testWallet2)
              ['transferFrom(address,address,uint256)'](
                user5.address,
                testWallet3.address,
                tokenId
              );
            expect(await c.ownerOf(tokenId)).to.be.equal(testWallet3.address);
          });
        });
      });

      describe('approveForAll', function () {
        context('approving operator for all owned tokens', function () {
          const tokenId = 1;
          it('returns operator as approvedForAll', async function () {
            await c
              .connect(testWallet3)
              .setApprovalForAll(testWallet2.address, true);
            expect(
              await c.isApprovedForAll(testWallet3.address, testWallet2.address)
            ).to.be.equal(true);
          });

          it('reverts for not approvedForAll wallet', async function () {
            await expect(
              c
                .connect(user5)
                ['transferFrom(address,address,uint256)'](
                  testWallet3.address,
                  user5.address,
                  tokenId
                )
            ).to.be.revertedWith('CXIP: not approved sender');
          });

          it('allows operator to transfer any owned token', async function () {
            await c
              .connect(testWallet2)
              ['transferFrom(address,address,uint256)'](
                testWallet3.address,
                user5.address,
                tokenId
              );
            expect(await c.ownerOf(tokenId)).to.be.equal(user5.address);
          });
        });
      });

      describe('safeTransferFrom', function () {
        context(
          'using MockErc721Receiver to test safeTransferFrom functionality',
          function () {
            const r = mockErc721Receiver.attach(mockErc721Receiver.address);
            const tokenId = 1;

            it('reverts for safeTransferFrom on unsupported ERC721 Receiver smart contract', async function () {
              // we disable support first
              await r.toggleWorks(false);
              // we try a transfer
              await expect(
                c
                  .connect(user5)
                  ['safeTransferFrom(address,address,uint256)'](
                    user5.address,
                    r.address,
                    tokenId
                  )
              ).to.be.revertedWith('CXIP: onERC721Received fail');
            });

            it('succeeds for safeTransferFrom on supported ERC721 Receiver smart contract', async function () {
              // we enable support first
              await r.toggleWorks(true);
              // we try a safeTransferFrom
              await c
                .connect(user5)
                ['safeTransferFrom(address,address,uint256)'](
                  user5.address,
                  r.address,
                  tokenId
                );
              expect(await c.ownerOf(tokenId)).to.be.equal(r.address);
            });

            it('transfers token out of ERC721 Receiver smart contract', async function () {
                await r.transferNFT(c.address, tokenId, user5.address);
                expect(await c.ownerOf(tokenId)).to.be.equal(user5.address);
            });
          }
        );
      });

      describe('burn', function () {
        context('burn owned token', function () {
          it('fails to burn not owned/approved token', async function () {
            await expect(c.connect(testWallet2).burn(tokenId)).to.be.revertedWith('CXIP: not approved sender');
          });

          it('burns owned token', async function () {
            await c.connect(user5).burn(tokenId);
            await expect(c.ownerOf(tokenId)).to.be.revertedWith('ERC721: token does not exist');
          });
        });
      });

    });
  });
});
