'use strict';

const fs = require ('fs');
const HDWalletProvider = require ('truffle-hdwallet-provider');
const Web3 = require ('web3');
const {
    NETWORK,
    GAS,
    DEPLOYER
} = require ('../config/env');
const {removeX, hexify, throwError, web3Error, getContractArtifact, createNetworkPropsForUser, saveContractResult} = require("./helpers/utils");

const GENESIS = 'HolographGenesis';
const GENESIS_CONTRACT = getContractArtifact(GENESIS)

const HOLOGRAPH = 'Holograph';
const HOLOGRAPH_CONTRACT = getContractArtifact(HOLOGRAPH)

const HOLOGRAPH_BRIDGE = 'HolographBridge';
const HOLOGRAPH_BRIDGE_CONTRACT = getContractArtifact(HOLOGRAPH_BRIDGE)

const HOLOGRAPH_BRIDGE_PROXY = 'HolographBridgeProxy';
const HOLOGRAPH_BRIDGE_PROXY_CONTRACT = getContractArtifact(HOLOGRAPH_BRIDGE_PROXY)

const HOLOGRAPH_FACTORY = 'HolographFactory';
const HOLOGRAPH_FACTORY_CONTRACT = getContractArtifact(HOLOGRAPH_FACTORY)

const HOLOGRAPH_FACTORY_PROXY = 'HolographFactoryProxy';
const HOLOGRAPH_FACTORY_PROXY_CONTRACT = getContractArtifact(HOLOGRAPH_FACTORY_PROXY)

const HOLOGRAPH_REGISTRY = 'HolographRegistry';
const HOLOGRAPH_REGISTRY_CONTRACT = getContractArtifact(HOLOGRAPH_REGISTRY)

const HOLOGRAPH_REGISTRY_PROXY = 'HolographRegistryProxy';
const HOLOGRAPH_REGISTRY_PROXY_CONTRACT = getContractArtifact(HOLOGRAPH_REGISTRY_PROXY)

const PA1D = 'PA1D';
const PA1D_CONTRACT = getContractArtifact(PA1D)

const SECURE_STORAGE = 'SecureStorage';

const SECURE_STORAGE_CONTRACT = getContractArtifact(SECURE_STORAGE)

const SECURE_STORAGE_PROXY = 'SecureStorageProxy';
const SECURE_STORAGE_PROXY_CONTRACT = getContractArtifact(SECURE_STORAGE_PROXY)

const { network, provider, web3 } = createNetworkPropsForUser(DEPLOYER, NETWORK)


async function main () {

    const GENESIS_ADDRESS = fs.readFileSync ('./data/' + NETWORK + '.' + GENESIS + '.address', 'utf8').trim ();

    const FACTORY = new web3.eth.Contract (
        GENESIS_CONTRACT.abi,
        GENESIS_ADDRESS
    );

    const salt = '0x000000000000000000000000';

// HolographRegistry
        const holographRegistryDeploymentResult = await FACTORY.methods.deploy (
            salt, // bytes12 saltHash
            '0x' + HOLOGRAPH_REGISTRY_CONTRACT.bin, // bytes memory sourceCode
            web3.eth.abi.encodeParameters (
                ['bytes32[]'],
                [[]]
            ) // bytes memory initCode
        ).send ({
            chainId: network.chain,
            from: provider.addresses [0],
            gas: web3.utils.toHex (1000000),
            gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
        }).catch (web3Error);
        let holographRegistryAddress = '0x' + removeX (web3.utils.keccak256 (
            '0xff'
            + removeX (GENESIS_ADDRESS)
            + removeX (provider.addresses [0]) + removeX (salt)
            + removeX (web3.utils.keccak256 ('0x' + HOLOGRAPH_REGISTRY_CONTRACT.bin))
        )).substring (24);
        if (!holographRegistryDeploymentResult.status) {
            throwError (JSON.stringify (holographRegistryDeploymentResult, null, 4));
        }
        if ('0x' + HOLOGRAPH_REGISTRY_CONTRACT ['bin-runtime'] != await web3.eth.getCode (holographRegistryAddress)) {
            throwError ('Could not properly compute CREATE2 address for holographRegistryAddress');
        }

        saveContractResult(NETWORK, HOLOGRAPH_REGISTRY, holographRegistryAddress)

// HolographRegistryProxy
        const holographRegistryProxyDeploymentResult = await FACTORY.methods.deploy (
            salt, // bytes12 saltHash
            '0x' + HOLOGRAPH_REGISTRY_PROXY_CONTRACT.bin, // bytes memory sourceCode
            web3.eth.abi.encodeParameters (
                ['address', 'bytes'],
                [
                    holographRegistryAddress,
                    web3.eth.abi.encodeParameters (
                        ['bytes32[]'],
                        [
                            [
                                '0x0000000000000000000000000000000000486f6c6f6772617068455243373231', // HolographERC721
                                '0x0000000000000000000000000000000000000000000000000000000050413144'  // PA1D
                            ]
                        ]
                    )
                ]
            ) // bytes memory initCode
        ).send ({
            chainId: network.chain,
            from: provider.addresses [0],
            gas: web3.utils.toHex (1000000),
            gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
        }).catch (web3Error);
        let holographRegistryProxyAddress = '0x' + removeX (web3.utils.keccak256 (
            '0xff'
            + removeX (GENESIS_ADDRESS)
            + removeX (provider.addresses [0]) + removeX (salt)
            + removeX (web3.utils.keccak256 ('0x' + HOLOGRAPH_REGISTRY_PROXY_CONTRACT.bin))
        )).substring (24);
        if (!holographRegistryProxyDeploymentResult.status) {
            throwError (JSON.stringify (holographRegistryProxyDeploymentResult, null, 4));
        }
        if ('0x' + HOLOGRAPH_REGISTRY_PROXY_CONTRACT ['bin-runtime'] != await web3.eth.getCode (holographRegistryProxyAddress)) {
            throwError ('Could not properly compute CREATE2 address for holographRegistryProxyAddress');
        }
        saveContractResult(NETWORK, HOLOGRAPH_REGISTRY_PROXY, holographRegistryProxyAddress)

// HolographFactory
        const holographFactoryDeploymentResult = await FACTORY.methods.deploy (
            salt, // bytes12 saltHash
            '0x' + HOLOGRAPH_FACTORY_CONTRACT.bin, // bytes memory sourceCode
            web3.eth.abi.encodeParameters (
                ['address', 'address'],
                ['0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000']
            ) // bytes memory initCode
        ).send ({
            chainId: network.chain,
            from: provider.addresses [0],
            gas: web3.utils.toHex (3000000),
            gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
        }).catch (web3Error);
        let holographFactoryAddress = '0x' + removeX (web3.utils.keccak256 (
            '0xff'
            + removeX (GENESIS_ADDRESS)
            + removeX (provider.addresses [0]) + removeX (salt)
            + removeX (web3.utils.keccak256 ('0x' + HOLOGRAPH_FACTORY_CONTRACT.bin))
        )).substring (24);
        if (!holographFactoryDeploymentResult.status) {
            throwError (JSON.stringify (holographFactoryDeploymentResult, null, 4));
        }
        if ('0x' + HOLOGRAPH_FACTORY_CONTRACT ['bin-runtime'] != await web3.eth.getCode (holographFactoryAddress)) {
            throwError ('Could not properly compute CREATE2 address for holographFactoryAddress');
        }
        saveContractResult(NETWORK, HOLOGRAPH_FACTORY, holographFactoryAddress)

// SecureStorage
        const secureStorageDeploymentResult = await FACTORY.methods.deploy (
            salt, // bytes12 saltHash
            '0x' + SECURE_STORAGE_CONTRACT.bin, // bytes memory sourceCode
            web3.eth.abi.encodeParameters (
                ['address'],
                ['0x0000000000000000000000000000000000000000']
            ) // bytes memory initCode
        ).send ({
            chainId: network.chain,
            from: provider.addresses [0],
            gas: web3.utils.toHex (1000000),
            gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
        }).catch (web3Error);
        let secureStorageAddress = '0x' + removeX (web3.utils.keccak256 (
            '0xff'
            + removeX (GENESIS_ADDRESS)
            + removeX (provider.addresses [0]) + removeX (salt)
            + removeX (web3.utils.keccak256 ('0x' + SECURE_STORAGE_CONTRACT.bin))
        )).substring (24);
        if (!secureStorageDeploymentResult.status) {
            throwError (JSON.stringify (secureStorageDeploymentResult, null, 4));
        }
        if ('0x' + SECURE_STORAGE_CONTRACT ['bin-runtime'] != await web3.eth.getCode (secureStorageAddress)) {
            throwError ('Could not properly compute CREATE2 address for secureStorageAddress');
        }
        saveContractResult(NETWORK, SECURE_STORAGE, secureStorageAddress)

// SecureStorageProxy
        const secureStorageProxyDeploymentResult = await FACTORY.methods.deploy (
            salt, // bytes12 saltHash
            '0x' + SECURE_STORAGE_PROXY_CONTRACT.bin, // bytes memory sourceCode
            web3.eth.abi.encodeParameters (
                ['address', 'bytes'],
                [
                    secureStorageAddress,
                    web3.eth.abi.encodeParameters (
                        ['address'],
                        ['0x0000000000000000000000000000000000000000']
                    ) // bytes memory initCode
                ]
            ) // bytes memory initCode
        ).send ({
            chainId: network.chain,
            from: provider.addresses [0],
            gas: web3.utils.toHex (1000000),
            gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
        }).catch (web3Error);
        let secureStorageProxyAddress = '0x' + removeX (web3.utils.keccak256 (
            '0xff'
            + removeX (GENESIS_ADDRESS)
            + removeX (provider.addresses [0]) + removeX (salt)
            + removeX (web3.utils.keccak256 ('0x' + SECURE_STORAGE_PROXY_CONTRACT.bin))
        )).substring (24);
        if (!secureStorageProxyDeploymentResult.status) {
            throwError (JSON.stringify (secureStorageProxyDeploymentResult, null, 4));
        }
        if ('0x' + SECURE_STORAGE_PROXY_CONTRACT ['bin-runtime'] != await web3.eth.getCode (secureStorageProxyAddress)) {
            throwError ('Could not properly compute CREATE2 address for secureStorageProxyAddress');
        }
        saveContractResult(NETWORK, SECURE_STORAGE_PROXY, secureStorageProxyAddress)

// HolographFactoryProxy
        const holographFactoryProxyDeploymentResult = await FACTORY.methods.deploy (
            salt, // bytes12 saltHash
            '0x' + HOLOGRAPH_FACTORY_PROXY_CONTRACT.bin, // bytes memory sourceCode
            web3.eth.abi.encodeParameters (
                ['address', 'bytes'],
                [
                    holographFactoryAddress,
                    web3.eth.abi.encodeParameters (
                        ['address', 'address'],
                        [holographRegistryProxyAddress, secureStorageAddress]
                    ) // bytes memory initCode
                ]
            ) // bytes memory initCode
        ).send ({
            chainId: network.chain,
            from: provider.addresses [0],
            gas: web3.utils.toHex (1000000),
            gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
        }).catch (web3Error);
        let holographFactoryProxyAddress = '0x' + removeX (web3.utils.keccak256 (
            '0xff'
            + removeX (GENESIS_ADDRESS)
            + removeX (provider.addresses [0]) + removeX (salt)
            + removeX (web3.utils.keccak256 ('0x' + HOLOGRAPH_FACTORY_PROXY_CONTRACT.bin))
        )).substring (24);
        if (!holographFactoryProxyDeploymentResult.status) {
            throwError (JSON.stringify (holographFactoryProxyDeploymentResult, null, 4));
        }
        if ('0x' + HOLOGRAPH_FACTORY_PROXY_CONTRACT ['bin-runtime'] != await web3.eth.getCode (holographFactoryProxyAddress)) {
            throwError ('Could not properly compute CREATE2 address for holographFactoryProxyAddress');
        }
        saveContractResult(NETWORK, HOLOGRAPH_FACTORY_PROXY, holographFactoryProxyAddress)

// HolographBridge
        const holographBridgeDeploymentResult = await FACTORY.methods.deploy (
            salt, // bytes12 saltHash
            '0x' + HOLOGRAPH_BRIDGE_CONTRACT.bin, // bytes memory sourceCode
            web3.eth.abi.encodeParameters (
                ['address', 'address'],
                ['0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000']
            ) // bytes memory initCode
        ).send ({
            chainId: network.chain,
            from: provider.addresses [0],
            gas: web3.utils.toHex (2000000),
            gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
        }).catch (web3Error);
        let holographBridgeAddress = '0x' + removeX (web3.utils.keccak256 (
            '0xff'
            + removeX (GENESIS_ADDRESS)
            + removeX (provider.addresses [0]) + removeX (salt)
            + removeX (web3.utils.keccak256 ('0x' + HOLOGRAPH_BRIDGE_CONTRACT.bin))
        )).substring (24);
        if (!holographBridgeDeploymentResult.status) {
            throwError (JSON.stringify (holographBridgeDeploymentResult, null, 4));
        }
        if ('0x' + HOLOGRAPH_BRIDGE_CONTRACT ['bin-runtime'] != await web3.eth.getCode (holographBridgeAddress)) {
            throwError ('Could not properly compute CREATE2 address for holographBridgeAddress');
        }
        saveContractResult(NETWORK, HOLOGRAPH_BRIDGE, holographBridgeAddress)

// HolographBridgeProxy
        const holographBridgeProxyDeploymentResult = await FACTORY.methods.deploy (
            salt, // bytes12 saltHash
            '0x' + HOLOGRAPH_BRIDGE_PROXY_CONTRACT.bin, // bytes memory sourceCode
            web3.eth.abi.encodeParameters (
                ['address', 'bytes'],
                [
                    holographBridgeAddress,
                    web3.eth.abi.encodeParameters (
                        ['address', 'address'],
                        [holographRegistryProxyAddress, holographFactoryProxyAddress]
                    ) // bytes memory initCode
                ]
            ) // bytes memory initCode
        ).send ({
            chainId: network.chain,
            from: provider.addresses [0],
            gas: web3.utils.toHex (1000000),
            gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
        }).catch (web3Error);
        let holographBridgeProxyAddress = '0x' + removeX (web3.utils.keccak256 (
            '0xff'
            + removeX (GENESIS_ADDRESS)
            + removeX (provider.addresses [0]) + removeX (salt)
            + removeX (web3.utils.keccak256 ('0x' + HOLOGRAPH_BRIDGE_PROXY_CONTRACT.bin))
        )).substring (24);
        if (!holographBridgeProxyDeploymentResult.status) {
            throwError (JSON.stringify (holographBridgeProxyDeploymentResult, null, 4));
        }
        if ('0x' + HOLOGRAPH_BRIDGE_PROXY_CONTRACT ['bin-runtime'] != await web3.eth.getCode (holographBridgeProxyAddress)) {
            throwError ('Could not properly compute CREATE2 address for holographBridgeProxyAddress');
        }
        saveContractResult(NETWORK, HOLOGRAPH_BRIDGE_PROXY, holographBridgeProxyAddress)

// Holograph
        const holographDeploymentResult = await FACTORY.methods.deploy (
            salt, // bytes12 saltHash
            '0x' + HOLOGRAPH_CONTRACT.bin, // bytes memory sourceCode
            web3.eth.abi.encodeParameters (
                ['uint32', 'address', 'address', 'address', 'address'],
                [
                    hexify (network.holographId.toString (16).padStart (8, '0'), true),
                    holographRegistryProxyAddress,
                    holographFactoryProxyAddress,
                    holographBridgeProxyAddress,
                    secureStorageProxyAddress
                ]
            ) // bytes memory initCode
        ).send ({
            chainId: network.chain,
            from: provider.addresses [0],
            gas: web3.utils.toHex (1000000),
            gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
        }).catch (web3Error);
        let holographAddress = '0x' + removeX (web3.utils.keccak256 (
            '0xff'
            + removeX (GENESIS_ADDRESS)
            + removeX (provider.addresses [0]) + removeX (salt)
            + removeX (web3.utils.keccak256 ('0x' + HOLOGRAPH_CONTRACT.bin))
        )).substring (24);
        if (!holographDeploymentResult.status) {
            throwError (JSON.stringify (holographDeploymentResult, null, 4));
        }
        if ('0x' + HOLOGRAPH_CONTRACT ['bin-runtime'] != await web3.eth.getCode (holographAddress)) {
            throwError ('Could not properly compute CREATE2 address for holographAddress');
        }
        saveContractResult(NETWORK, HOLOGRAPH, holographAddress)

// PA1D
        const pa1dDeploymentResult = await FACTORY.methods.deploy (
            salt, // bytes12 saltHash
            '0x' + PA1D_CONTRACT.bin, // bytes memory sourceCode
            web3.eth.abi.encodeParameters (
                ['address', 'uint256'],
                [provider.addresses [0], '0x0000000000000000000000000000000000000000000000000000000000000000']
            ) // bytes memory initCode
        ).send ({
            chainId: network.chain,
            from: provider.addresses [0],
            gas: web3.utils.toHex (5000000),
            gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
        }).catch (web3Error);
        let pa1dAddress = '0x' + removeX (web3.utils.keccak256 (
            '0xff'
            + removeX (GENESIS_ADDRESS)
            + removeX (provider.addresses [0]) + removeX (salt)
            + removeX (web3.utils.keccak256 ('0x' + PA1D_CONTRACT.bin))
        )).substring (24);
        if (!pa1dDeploymentResult.status) {
            throwError (JSON.stringify (pa1dDeploymentResult, null, 4));
        }
        if ('0x' + PA1D_CONTRACT ['bin-runtime'] != await web3.eth.getCode (pa1dAddress)) {
            throwError ('Could not properly compute CREATE2 address for pa1dAddress');
        }
        saveContractResult(NETWORK, PA1D, pa1dAddress)

    process.exit ();
}

main ();
