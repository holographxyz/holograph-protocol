declare var global: any;
import { expect, assert } from 'chai';
import { PreTest } from './utils';
import setup from './utils';
import { BigNumberish, BytesLike, BigNumber, ContractFactory } from 'ethers';
import {
  Signature,
  StrictECDSA,
  zeroAddress,
  functionHash,
  XOR,
  toHex,
  buildDomainSeperator,
  randomHex,
  generateInitCode,
} from '../scripts/utils/helpers';

import {
  Admin,
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
  Interfaces,
  MockERC721Receiver,
  Owner,
  PA1D,
  SampleERC20,
  SampleERC721,
  SecureStorage,
  SecureStorageProxy,
} from '../typechain-types';
import { DeploymentConfigStruct } from '../typechain-types/HolographFactory';

describe('Testing cross-chain configurations (L1 & L2)', async function () {
  let l1: PreTest;
  let l2: PreTest;

  before(async function () {
    global.__companionNetwork = false;
    l1 = await setup();
    global.__companionNetwork = true;
    l2 = await setup(true);
    global.__companionNetwork = false;
  });

  after(async function () {
    global.__companionNetwork = false;
  });

  beforeEach(async function () {});

  afterEach(async function () {});

  describe('Validate cross-chain data', async function () {
    describe('CxipERC721', async function () {
      it('contract addresses should not match', async function () {
        expect(l1.cxipErc721.address).to.not.equal(l2.cxipErc721.address);
      });
    });

    describe('ERC20Mock', async function () {
      it('contract addresses should match', async function () {
        expect(l1.erc20Mock.address).to.equal(l2.erc20Mock.address);
      });
    });

    describe('Holograph', async function () {
      it('contract addresses should match', async function () {
        expect(l1.holograph.address).to.equal(l2.holograph.address);
      });
    });

    describe('HolographBridge', async function () {
      it('contract addresses should match', async function () {
        expect(l1.holographBridge.address).to.equal(l2.holographBridge.address);
      });
    });

    describe('HolographBridgeProxy', async function () {
      it('contract addresses should match', async function () {
        expect(l1.holographBridgeProxy.address).to.equal(l2.holographBridgeProxy.address);
      });
    });

    describe('Holographer', async function () {
      it('contract addresses should not match', async function () {
        expect(l1.holographer.address).to.not.equal(l2.holographer.address);
      });
    });

    describe('HolographERC20', async function () {
      it('contract addresses should match', async function () {
        expect(l1.holographErc20.address).to.equal(l2.holographErc20.address);
      });
    });

    describe('HolographERC721', async function () {
      it('contract addresses should match', async function () {
        expect(l1.holographErc721.address).to.equal(l2.holographErc721.address);
      });
    });

    describe('HolographFactory', async function () {
      it('contract addresses should match', async function () {
        expect(l1.holographFactory.address).to.equal(l2.holographFactory.address);
      });
    });

    describe('HolographFactoryProxy', async function () {
      it('contract addresses should match', async function () {
        expect(l1.holographFactoryProxy.address).to.equal(l2.holographFactoryProxy.address);
      });
    });

    describe('HolographGenesis', async function () {
      it('contract addresses should match', async function () {
        expect(l1.holographGenesis.address).to.equal(l2.holographGenesis.address);
      });
    });

    describe('HolographRegistry', async function () {
      it('contract addresses should match', async function () {
        expect(l1.holographRegistry.address).to.equal(l2.holographRegistry.address);
      });
    });

    describe('HolographRegistryProxy', async function () {
      it('contract addresses should match', async function () {
        expect(l1.holographRegistryProxy.address).to.equal(l2.holographRegistryProxy.address);
      });
    });

    describe('hToken', async function () {
      it('contract addresses should not match', async function () {
        expect(l1.hToken.address).to.not.equal(l2.hToken.address);
      });
    });

    describe('Interfaces', async function () {
      it('contract addresses should match', async function () {
        expect(l1.interfaces.address).to.equal(l2.interfaces.address);
      });
    });

    describe('MockERC721Receiver', async function () {
      it('contract addresses should match', async function () {
        expect(l1.mockErc721Receiver.address).to.equal(l2.mockErc721Receiver.address);
      });
    });

    describe('PA1D', async function () {
      it('contract addresses should match', async function () {
        expect(l1.pa1d.address).to.equal(l2.pa1d.address);
      });
    });

    describe('SampleERC20', async function () {
      it('contract addresses should not match', async function () {
        expect(l1.sampleErc20.address).to.not.equal(l2.sampleErc20.address);
      });
    });

    describe('SampleERC721', async function () {
      it('contract addresses should not match', async function () {
        expect(l1.sampleErc721.address).to.not.equal(l2.sampleErc721.address);
      });
    });

    describe('SecureStorage', async function () {
      it('contract addresses should match', async function () {
        expect(l1.secureStorage.address).to.equal(l2.secureStorage.address);
      });
    });

    describe('SecureStorageProxy', async function () {
      it('contract addresses should match', async function () {
        expect(l1.secureStorageProxy.address).to.equal(l2.secureStorageProxy.address);
      });
    });

    describe('HolographRegistry', async function () {
      it('contract addresses should match', async function () {
        expect(l1.registry.address).to.equal(l2.registry.address);
      });
    });

    describe('HolographFactory', async function () {
      it('contract addresses should match', async function () {
        expect(l1.factory.address).to.equal(l2.factory.address);
      });
    });

    describe('HolographBridge', async function () {
      it('contract addresses should match', async function () {
        expect(l1.bridge.address).to.equal(l2.bridge.address);
      });
    });

    describe('hToken Holographer', async function () {
      it('contract addresses should not match', async function () {
        expect(l1.hTokenHolographer.address).to.not.equal(l2.hTokenHolographer.address);
      });
    });

    describe('hToken HolographERC20 Enforcer', async function () {
      it('contract addresses should match', async function () {
        expect(l1.hTokenEnforcer.address).to.equal(l2.hTokenEnforcer.address);
      });
    });

    describe('SampleERC20 Holographer', async function () {
      it('contract addresses should not match', async function () {
        expect(l1.sampleErc20Holographer.address).to.not.equal(l2.sampleErc20Holographer.address);
      });
    });

    describe('SampleERC20 HolographERC20 Enforcer', async function () {
      it('contract addresses should match', async function () {
        expect(l1.sampleErc20Enforcer.address).to.equal(l2.sampleErc20Enforcer.address);
      });
    });

    describe('SampleERC721 Holographer', async function () {
      it('contract addresses should not match', async function () {
        expect(l1.sampleErc721Holographer.address).to.not.equal(l2.sampleErc721Holographer.address);
      });
    });

    describe('SampleERC721 HolographERC721 Enforcer', async function () {
      it('contract addresses should match', async function () {
        expect(l1.sampleErc721Enforcer.address).to.equal(l2.sampleErc721Enforcer.address);
      });
    });

    describe('CxipERC721 Holographer', async function () {
      it('contract addresses should not match', async function () {
        expect(l1.cxipErc721Holographer.address).to.not.equal(l2.cxipErc721Holographer.address);
      });
    });

    describe('CxipERC721 HolographERC721 Enforcer', async function () {
      it('contract addresses should match', async function () {
        expect(l1.cxipErc721Enforcer.address).to.equal(l2.cxipErc721Enforcer.address);
      });
    });
  });

  describe('Deploy cross-chain contracts', async function () {
    describe('hToken', async function () {
      it('deploy l1 equivalent on l2', async function () {
        let chainId: string = '0x' + l1.network.holographId.toString(16).padStart(8, '0');
        let erc20Hash: string = '0x' + l1.web3.utils.asciiToHex('HolographERC20').substring(2).padStart(64, '0');
        let hTokenErc20Artifact: ContractFactory = await l1.hre.ethers.getContractFactory('hToken');
        let erc20Config: DeploymentConfigStruct = {
          contractType: erc20Hash,
          chainType: chainId,
          salt: '0x' + '00'.repeat(32),
          byteCode: hTokenErc20Artifact.bytecode,
          initCode: generateInitCode(
            ['string', 'string', 'uint8', 'uint256', 'string', 'string', 'bool', 'bytes'],
            [
              l1.network.tokenName + ' (Holographed)', // string memory contractName
              'h' + l1.network.tokenSymbol, // string memory contractSymbol
              18, // uint8 contractDecimals
              '0x' + '00'.repeat(32), // uint256 eventConfig
              l1.network.tokenName + ' (Holographed)', // string domainSeperator
              '1', // string domainVersion
              false, // bool skipInit
              generateInitCode(
                ['address', 'uint16'],
                [
                  l1.deployer.address, // owner
                  0, // fee (bps)
                ]
              ),
            ]
          ),
        };
        let erc20ConfigHash: number[] = l1.web3.utils.hexToBytes(
          l1.web3.utils.keccak256(
            '0x' +
              (erc20Config.contractType as string).substring(2) +
              (erc20Config.chainType as string).substring(2) +
              (erc20Config.salt as string).substring(2) +
              l1.web3.utils.keccak256(erc20Config.byteCode as string).substring(2) +
              l1.web3.utils.keccak256(erc20Config.initCode as string).substring(2) +
              l1.deployer.address.substring(2)
          )
        );

        let hTokenErc20Address = await l2.registry.getHolographedHashAddress(erc20ConfigHash);

        expect(hTokenErc20Address).to.equal(zeroAddress());

        hTokenErc20Address = await l1.registry.getHolographedHashAddress(erc20ConfigHash);

        let sig = await l1.deployer.signMessage(erc20ConfigHash);
        let signature: Signature = StrictECDSA({
          r: '0x' + sig.substring(2, 66),
          s: '0x' + sig.substring(66, 130),
          v: '0x' + sig.substring(130, 132),
        } as Signature);

        await expect(l2.factory.deployHolographableContract(erc20Config, signature, l1.deployer.address))
          .to.emit(l2.factory, 'BridgeableContractDeployed')
          .withArgs(hTokenErc20Address, toHex(erc20ConfigHash));
      });

      it('deploy l2 equivalent on l1', async function () {
        let chainId: string = '0x' + l2.network.holographId.toString(16).padStart(8, '0');
        let erc20Hash: string = '0x' + l2.web3.utils.asciiToHex('HolographERC20').substring(2).padStart(64, '0');
        let hTokenErc20Artifact: ContractFactory = await l2.hre.ethers.getContractFactory('hToken');
        let erc20Config: DeploymentConfigStruct = {
          contractType: erc20Hash,
          chainType: chainId,
          salt: '0x' + '00'.repeat(32),
          byteCode: hTokenErc20Artifact.bytecode,
          initCode: generateInitCode(
            ['string', 'string', 'uint8', 'uint256', 'string', 'string', 'bool', 'bytes'],
            [
              l2.network.tokenName + ' (Holographed)', // string memory contractName
              'h' + l2.network.tokenSymbol, // string memory contractSymbol
              18, // uint8 contractDecimals
              '0x' + '00'.repeat(32), // uint256 eventConfig
              l2.network.tokenName + ' (Holographed)', // string domainSeperator
              '1', // string domainVersion
              false, // bool skipInit
              generateInitCode(
                ['address', 'uint16'],
                [
                  l2.deployer.address, // owner
                  0, // fee (bps)
                ]
              ),
            ]
          ),
        };
        let erc20ConfigHash: number[] = l2.web3.utils.hexToBytes(
          l2.web3.utils.keccak256(
            '0x' +
              (erc20Config.contractType as string).substring(2) +
              (erc20Config.chainType as string).substring(2) +
              (erc20Config.salt as string).substring(2) +
              l2.web3.utils.keccak256(erc20Config.byteCode as string).substring(2) +
              l2.web3.utils.keccak256(erc20Config.initCode as string).substring(2) +
              l2.deployer.address.substring(2)
          )
        );

        let hTokenErc20Address = await l1.registry.getHolographedHashAddress(erc20ConfigHash);

        expect(hTokenErc20Address).to.equal(zeroAddress());

        hTokenErc20Address = await l2.registry.getHolographedHashAddress(erc20ConfigHash);

        let sig = await l2.deployer.signMessage(erc20ConfigHash);
        let signature: Signature = StrictECDSA({
          r: '0x' + sig.substring(2, 66),
          s: '0x' + sig.substring(66, 130),
          v: '0x' + sig.substring(130, 132),
        } as Signature);

        await expect(l1.factory.deployHolographableContract(erc20Config, signature, l2.deployer.address))
          .to.emit(l1.factory, 'BridgeableContractDeployed')
          .withArgs(hTokenErc20Address, toHex(erc20ConfigHash));
      });
    });

    describe('SampleERC20', async function () {
      it('deploy l1 equivalent on l2', async function () {
        let chainId: string = '0x' + l1.network.holographId.toString(16).padStart(8, '0');
        let erc20Hash: string = '0x' + l1.web3.utils.asciiToHex('HolographERC20').substring(2).padStart(64, '0');
        let sampleErc20Artifact: ContractFactory = await l1.hre.ethers.getContractFactory('SampleERC20');
        let erc20Config: DeploymentConfigStruct = {
          contractType: erc20Hash,
          chainType: chainId,
          salt: '0x' + '00'.repeat(32),
          byteCode: sampleErc20Artifact.bytecode,
          initCode: generateInitCode(
            ['string', 'string', 'uint8', 'uint256', 'string', 'string', 'bool', 'bytes'],
            [
              'Sample ERC20 Token (' + l1.hre.networkName + ')', // string memory contractName
              'SMPL', // string memory contractSymbol
              18, // uint8 decimals
              '0x' + '00'.repeat(32), // uint256 eventConfig
              'Sample ERC20 Token', // string domainSeperator
              '1', // string domainVersion
              false, // bool skipInit
              generateInitCode(
                ['address', 'uint16'],
                [
                  l1.deployer.address, // owner
                  0, // fee (bps)
                ]
              ),
            ]
          ),
        };
        let erc20ConfigHash: number[] = l1.web3.utils.hexToBytes(
          l1.web3.utils.keccak256(
            '0x' +
              (erc20Config.contractType as string).substring(2) +
              (erc20Config.chainType as string).substring(2) +
              (erc20Config.salt as string).substring(2) +
              l1.web3.utils.keccak256(erc20Config.byteCode as string).substring(2) +
              l1.web3.utils.keccak256(erc20Config.initCode as string).substring(2) +
              l1.deployer.address.substring(2)
          )
        );

        let sampleErc20Address = await l2.registry.getHolographedHashAddress(erc20ConfigHash);

        expect(sampleErc20Address).to.equal(zeroAddress());

        sampleErc20Address = await l1.registry.getHolographedHashAddress(erc20ConfigHash);

        let sig = await l1.deployer.signMessage(erc20ConfigHash);
        let signature: Signature = StrictECDSA({
          r: '0x' + sig.substring(2, 66),
          s: '0x' + sig.substring(66, 130),
          v: '0x' + sig.substring(130, 132),
        } as Signature);

        await expect(l2.factory.deployHolographableContract(erc20Config, signature, l1.deployer.address))
          .to.emit(l2.factory, 'BridgeableContractDeployed')
          .withArgs(sampleErc20Address, toHex(erc20ConfigHash));
      });

      it('deploy l2 equivalent on l1', async function () {
        let chainId: string = '0x' + l2.network.holographId.toString(16).padStart(8, '0');
        let erc20Hash: string = '0x' + l2.web3.utils.asciiToHex('HolographERC20').substring(2).padStart(64, '0');
        let sampleErc20Artifact: ContractFactory = await l2.hre.ethers.getContractFactory('SampleERC20');
        let erc20Config: DeploymentConfigStruct = {
          contractType: erc20Hash,
          chainType: chainId,
          salt: '0x' + '00'.repeat(32),
          byteCode: sampleErc20Artifact.bytecode,
          initCode: generateInitCode(
            ['string', 'string', 'uint8', 'uint256', 'string', 'string', 'bool', 'bytes'],
            [
              'Sample ERC20 Token (' + l2.hre.networkName + ')', // string memory contractName
              'SMPL', // string memory contractSymbol
              18, // uint8 decimals
              '0x' + '00'.repeat(32), // uint256 eventConfig
              'Sample ERC20 Token', // string domainSeperator
              '1', // string domainVersion
              false, // bool skipInit
              generateInitCode(
                ['address', 'uint16'],
                [
                  l2.deployer.address, // owner
                  0, // fee (bps)
                ]
              ),
            ]
          ),
        };
        let erc20ConfigHash: number[] = l2.web3.utils.hexToBytes(
          l2.web3.utils.keccak256(
            '0x' +
              (erc20Config.contractType as string).substring(2) +
              (erc20Config.chainType as string).substring(2) +
              (erc20Config.salt as string).substring(2) +
              l2.web3.utils.keccak256(erc20Config.byteCode as string).substring(2) +
              l2.web3.utils.keccak256(erc20Config.initCode as string).substring(2) +
              l2.deployer.address.substring(2)
          )
        );

        let sampleErc20Address = await l1.registry.getHolographedHashAddress(erc20ConfigHash);

        expect(sampleErc20Address).to.equal(zeroAddress());

        sampleErc20Address = await l2.registry.getHolographedHashAddress(erc20ConfigHash);

        let sig = await l2.deployer.signMessage(erc20ConfigHash);
        let signature: Signature = StrictECDSA({
          r: '0x' + sig.substring(2, 66),
          s: '0x' + sig.substring(66, 130),
          v: '0x' + sig.substring(130, 132),
        } as Signature);

        await expect(l1.factory.deployHolographableContract(erc20Config, signature, l2.deployer.address))
          .to.emit(l1.factory, 'BridgeableContractDeployed')
          .withArgs(sampleErc20Address, toHex(erc20ConfigHash));
      });
    });

    describe('SampleERC721', async function () {
      it('deploy l1 equivalent on l2', async function () {
        let chainId: string = '0x' + l1.network.holographId.toString(16).padStart(8, '0');
        let erc721Hash: string = '0x' + l1.web3.utils.asciiToHex('HolographERC721').substring(2).padStart(64, '0');
        let sampleErc721Artifact: ContractFactory = await l1.hre.ethers.getContractFactory('SampleERC721');
        let erc721Config: DeploymentConfigStruct = {
          contractType: erc721Hash,
          chainType: chainId,
          salt: '0x' + '00'.repeat(32),
          byteCode: sampleErc721Artifact.bytecode,
          initCode: generateInitCode(
            ['string', 'string', 'uint16', 'uint256', 'bool', 'bytes'],
            [
              'Sample ERC721 Contract (' + l1.hre.networkName + ')', // string memory contractName
              'SMPLR', // string memory contractSymbol
              1000, // uint16 contractBps
              '0x' + '00'.repeat(32), // uint256 eventConfig
              false, // bool skipInit
              generateInitCode(
                ['address'],
                [
                  l1.deployer.address, // owner
                ]
              ),
            ]
          ),
        };
        let erc721ConfigHash: number[] = l1.web3.utils.hexToBytes(
          l1.web3.utils.keccak256(
            '0x' +
              (erc721Config.contractType as string).substring(2) +
              (erc721Config.chainType as string).substring(2) +
              (erc721Config.salt as string).substring(2) +
              l1.web3.utils.keccak256(erc721Config.byteCode as string).substring(2) +
              l1.web3.utils.keccak256(erc721Config.initCode as string).substring(2) +
              l1.deployer.address.substring(2)
          )
        );

        let sampleErc721Address = await l2.registry.getHolographedHashAddress(erc721ConfigHash);

        expect(sampleErc721Address).to.equal(zeroAddress());

        sampleErc721Address = await l1.registry.getHolographedHashAddress(erc721ConfigHash);

        let sig = await l1.deployer.signMessage(erc721ConfigHash);
        let signature: Signature = StrictECDSA({
          r: '0x' + sig.substring(2, 66),
          s: '0x' + sig.substring(66, 130),
          v: '0x' + sig.substring(130, 132),
        } as Signature);

        await expect(l2.factory.deployHolographableContract(erc721Config, signature, l1.deployer.address))
          .to.emit(l2.factory, 'BridgeableContractDeployed')
          .withArgs(sampleErc721Address, toHex(erc721ConfigHash));
      });

      it('deploy l2 equivalent on l1', async function () {
        let chainId: string = '0x' + l2.network.holographId.toString(16).padStart(8, '0');
        let erc721Hash: string = '0x' + l2.web3.utils.asciiToHex('HolographERC721').substring(2).padStart(64, '0');
        let sampleErc721Artifact: ContractFactory = await l2.hre.ethers.getContractFactory('SampleERC721');
        let erc721Config: DeploymentConfigStruct = {
          contractType: erc721Hash,
          chainType: chainId,
          salt: '0x' + '00'.repeat(32),
          byteCode: sampleErc721Artifact.bytecode,
          initCode: generateInitCode(
            ['string', 'string', 'uint16', 'uint256', 'bool', 'bytes'],
            [
              'Sample ERC721 Contract (' + l2.hre.networkName + ')', // string memory contractName
              'SMPLR', // string memory contractSymbol
              1000, // uint16 contractBps
              '0x' + '00'.repeat(32), // uint256 eventConfig
              false, // bool skipInit
              generateInitCode(
                ['address'],
                [
                  l2.deployer.address, // owner
                ]
              ),
            ]
          ),
        };
        let erc721ConfigHash: number[] = l2.web3.utils.hexToBytes(
          l2.web3.utils.keccak256(
            '0x' +
              (erc721Config.contractType as string).substring(2) +
              (erc721Config.chainType as string).substring(2) +
              (erc721Config.salt as string).substring(2) +
              l2.web3.utils.keccak256(erc721Config.byteCode as string).substring(2) +
              l2.web3.utils.keccak256(erc721Config.initCode as string).substring(2) +
              l2.deployer.address.substring(2)
          )
        );

        let sampleErc721Address = await l1.registry.getHolographedHashAddress(erc721ConfigHash);

        expect(sampleErc721Address).to.equal(zeroAddress());

        sampleErc721Address = await l2.registry.getHolographedHashAddress(erc721ConfigHash);

        let sig = await l2.deployer.signMessage(erc721ConfigHash);
        let signature: Signature = StrictECDSA({
          r: '0x' + sig.substring(2, 66),
          s: '0x' + sig.substring(66, 130),
          v: '0x' + sig.substring(130, 132),
        } as Signature);

        await expect(l1.factory.deployHolographableContract(erc721Config, signature, l2.deployer.address))
          .to.emit(l1.factory, 'BridgeableContractDeployed')
          .withArgs(sampleErc721Address, toHex(erc721ConfigHash));
      });
    });

    describe('CxipERC721', async function () {
      it('deploy l1 equivalent on l2', async function () {
        let chainId: string = '0x' + l1.network.holographId.toString(16).padStart(8, '0');
        let erc721Hash: string = '0x' + l1.web3.utils.asciiToHex('HolographERC721').substring(2).padStart(64, '0');
        let cxipErc721Artifact: ContractFactory = await l1.hre.ethers.getContractFactory('CxipERC721');
        let erc721Config: DeploymentConfigStruct = {
          contractType: erc721Hash,
          chainType: chainId,
          salt: '0x' + '00'.repeat(32),
          byteCode: cxipErc721Artifact.bytecode,
          initCode: generateInitCode(
            ['string', 'string', 'uint16', 'uint256', 'bool', 'bytes'],
            [
              'CXIP ERC721 Collection (' + l1.hre.networkName + ')', // string memory contractName
              'CXIP', // string memory contractSymbol
              1000, // uint16 contractBps
              '0x' + '00'.repeat(32), // uint256 eventConfig
              false, // bool skipInit
              generateInitCode(
                ['address'],
                [
                  l1.deployer.address, // owner
                ]
              ),
            ]
          ),
        };
        let erc721ConfigHash: number[] = l1.web3.utils.hexToBytes(
          l1.web3.utils.keccak256(
            '0x' +
              (erc721Config.contractType as string).substring(2) +
              (erc721Config.chainType as string).substring(2) +
              (erc721Config.salt as string).substring(2) +
              l1.web3.utils.keccak256(erc721Config.byteCode as string).substring(2) +
              l1.web3.utils.keccak256(erc721Config.initCode as string).substring(2) +
              l1.deployer.address.substring(2)
          )
        );

        let cxipErc721Address = await l2.registry.getHolographedHashAddress(erc721ConfigHash);

        expect(cxipErc721Address).to.equal(zeroAddress());

        cxipErc721Address = await l1.registry.getHolographedHashAddress(erc721ConfigHash);

        let sig = await l1.deployer.signMessage(erc721ConfigHash);
        let signature: Signature = StrictECDSA({
          r: '0x' + sig.substring(2, 66),
          s: '0x' + sig.substring(66, 130),
          v: '0x' + sig.substring(130, 132),
        } as Signature);

        await expect(l2.factory.deployHolographableContract(erc721Config, signature, l1.deployer.address))
          .to.emit(l2.factory, 'BridgeableContractDeployed')
          .withArgs(cxipErc721Address, toHex(erc721ConfigHash));
      });

      it('deploy l2 equivalent on l1', async function () {
        let chainId: string = '0x' + l2.network.holographId.toString(16).padStart(8, '0');
        let erc721Hash: string = '0x' + l2.web3.utils.asciiToHex('HolographERC721').substring(2).padStart(64, '0');
        let cxipErc721Artifact: ContractFactory = await l2.hre.ethers.getContractFactory('CxipERC721');
        let erc721Config: DeploymentConfigStruct = {
          contractType: erc721Hash,
          chainType: chainId,
          salt: '0x' + '00'.repeat(32),
          byteCode: cxipErc721Artifact.bytecode,
          initCode: generateInitCode(
            ['string', 'string', 'uint16', 'uint256', 'bool', 'bytes'],
            [
              'CXIP ERC721 Collection (' + l2.hre.networkName + ')', // string memory contractName
              'CXIP', // string memory contractSymbol
              1000, // uint16 contractBps
              '0x' + '00'.repeat(32), // uint256 eventConfig
              false, // bool skipInit
              generateInitCode(
                ['address'],
                [
                  l2.deployer.address, // owner
                ]
              ),
            ]
          ),
        };
        let erc721ConfigHash: number[] = l2.web3.utils.hexToBytes(
          l2.web3.utils.keccak256(
            '0x' +
              (erc721Config.contractType as string).substring(2) +
              (erc721Config.chainType as string).substring(2) +
              (erc721Config.salt as string).substring(2) +
              l2.web3.utils.keccak256(erc721Config.byteCode as string).substring(2) +
              l2.web3.utils.keccak256(erc721Config.initCode as string).substring(2) +
              l2.deployer.address.substring(2)
          )
        );

        let cxipErc721Address = await l1.registry.getHolographedHashAddress(erc721ConfigHash);

        expect(cxipErc721Address).to.equal(zeroAddress());

        cxipErc721Address = await l2.registry.getHolographedHashAddress(erc721ConfigHash);

        let sig = await l2.deployer.signMessage(erc721ConfigHash);
        let signature: Signature = StrictECDSA({
          r: '0x' + sig.substring(2, 66),
          s: '0x' + sig.substring(66, 130),
          v: '0x' + sig.substring(130, 132),
        } as Signature);

        await expect(l1.factory.deployHolographableContract(erc721Config, signature, l2.deployer.address))
          .to.emit(l1.factory, 'BridgeableContractDeployed')
          .withArgs(cxipErc721Address, toHex(erc721ConfigHash));
      });
    });
  });
});
