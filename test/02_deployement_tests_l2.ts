declare var global: any;
import { expect, assert } from 'chai';
import { PreTest } from './utils';
import setup from './utils';

describe('Validating the Holograph Protocol deployments (L2)', async () => {
  let _: PreTest;

  before(async () => {
    global.__companionNetwork = true;
    _ = await setup(true);
  });

  after(async () => {
    global.__companionNetwork = false;
  });

  beforeEach(async () => {});

  afterEach(async () => {});

  describe('Check that contract addresses are properly deployed', async () => {
    describe('Interfaces:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.interfaces.address])).to.equal(
          (await _.hre.artifacts.readArtifact('Interfaces')).deployedBytecode
        );
      });
    });

    describe('CxipERC721 Holographer:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.cxipErc721Holographer.address])).to.equal(
          (await _.hre.artifacts.readArtifact('Holographer')).deployedBytecode
        );
      });
    });

    describe('CxipERC721 Enforcer:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.cxipErc721Enforcer.address])).to.equal(
          (await _.hre.artifacts.readArtifact('HolographERC721')).deployedBytecode
        );
      });
    });

    describe('CxipERC721:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.cxipErc721.address])).to.equal(
          (await _.hre.artifacts.readArtifact('CxipERC721')).deployedBytecode
        );
      });
    });

    describe('ERC20Mock:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.erc20Mock.address])).to.equal(
          (await _.hre.artifacts.readArtifact('ERC20Mock')).deployedBytecode
        );
      });
    });

    describe('Holograph:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.holograph.address])).to.equal(
          (await _.hre.artifacts.readArtifact('Holograph')).deployedBytecode
        );
      });
    });

    describe('HolographBridge:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.holographBridge.address])).to.equal(
          (await _.hre.artifacts.readArtifact('HolographBridge')).deployedBytecode
        );
      });
    });

    describe('HolographBridgeProxy:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.holographBridgeProxy.address])).to.equal(
          (await _.hre.artifacts.readArtifact('HolographBridgeProxy')).deployedBytecode
        );
      });
    });

    describe('Holographer:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.holographer.address])).to.equal(
          (await _.hre.artifacts.readArtifact('Holographer')).deployedBytecode
        );
      });
    });

    describe('HolographERC20:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.holographErc20.address])).to.equal(
          (await _.hre.artifacts.readArtifact('HolographERC20')).deployedBytecode
        );
      });
    });

    describe('HolographERC721:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.holographErc721.address])).to.equal(
          (await _.hre.artifacts.readArtifact('HolographERC721')).deployedBytecode
        );
      });
    });

    describe('HolographFactory:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.holographFactory.address])).to.equal(
          (await _.hre.artifacts.readArtifact('HolographFactory')).deployedBytecode
        );
      });
    });

    describe('HolographFactoryProxy:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.holographFactoryProxy.address])).to.equal(
          (await _.hre.artifacts.readArtifact('HolographFactoryProxy')).deployedBytecode
        );
      });
    });

    describe('HolographGenesis:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.holographGenesis.address])).to.equal(
          (await _.hre.artifacts.readArtifact('HolographGenesis')).deployedBytecode
        );
      });
    });

    describe('HolographRegistry:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.holographRegistry.address])).to.equal(
          (await _.hre.artifacts.readArtifact('HolographRegistry')).deployedBytecode
        );
      });
    });

    describe('HolographRegistryProxy:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.holographRegistryProxy.address])).to.equal(
          (await _.hre.artifacts.readArtifact('HolographRegistryProxy')).deployedBytecode
        );
      });
    });

    describe('hToken Holographer:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.hTokenHolographer.address])).to.equal(
          (await _.hre.artifacts.readArtifact('Holographer')).deployedBytecode
        );
      });
    });

    describe('hToken Enforcer:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.hTokenEnforcer.address])).to.equal(
          (await _.hre.artifacts.readArtifact('HolographERC20')).deployedBytecode
        );
      });
    });

    describe('hToken:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.hToken.address])).to.equal(
          (await _.hre.artifacts.readArtifact('hToken')).deployedBytecode
        );
      });
    });

    describe('MockERC721Receiver:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.mockErc721Receiver.address])).to.equal(
          (await _.hre.artifacts.readArtifact('MockERC721Receiver')).deployedBytecode
        );
      });
    });

    describe('PA1D:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.pa1d.address])).to.equal(
          (await _.hre.artifacts.readArtifact('PA1D')).deployedBytecode
        );
      });
    });

    describe('SampleERC20 Holographer:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.sampleErc20Holographer.address])).to.equal(
          (await _.hre.artifacts.readArtifact('Holographer')).deployedBytecode
        );
      });
    });

    describe('SampleERC20 Enforcer:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.sampleErc20Enforcer.address])).to.equal(
          (await _.hre.artifacts.readArtifact('HolographERC20')).deployedBytecode
        );
      });
    });

    describe('SampleERC20:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.sampleErc20.address])).to.equal(
          (await _.hre.artifacts.readArtifact('SampleERC20')).deployedBytecode
        );
      });
    });

    describe('SampleERC721 Holographer:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.sampleErc721Holographer.address])).to.equal(
          (await _.hre.artifacts.readArtifact('Holographer')).deployedBytecode
        );
      });
    });

    describe('SampleERC721 Enforcer:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.sampleErc721Enforcer.address])).to.equal(
          (await _.hre.artifacts.readArtifact('HolographERC721')).deployedBytecode
        );
      });
    });

    describe('SampleERC721:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.sampleErc721.address])).to.equal(
          (await _.hre.artifacts.readArtifact('SampleERC721')).deployedBytecode
        );
      });
    });

    describe('SecureStorage:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.secureStorage.address])).to.equal(
          (await _.hre.artifacts.readArtifact('SecureStorage')).deployedBytecode
        );
      });
    });

    describe('SecureStorageProxy:', async function () {
      it('should return correct bytecode', async function () {
        expect(await _.hre.provider.send('eth_getCode', [_.secureStorageProxy.address])).to.equal(
          (await _.hre.artifacts.readArtifact('SecureStorageProxy')).deployedBytecode
        );
      });
    });
  });
});
