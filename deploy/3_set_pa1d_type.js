'use strict';

const fs = require ('fs');
const HDWalletProvider = require ('truffle-hdwallet-provider');
const Web3 = require ('web3');
const {
    NETWORK,
    GAS,
    DEPLOYER
} = require ('../config/env');
const {throwError, web3Error, getContractArtifact, getNetworkInfo, createProviderAndWeb3, createNetworkPropsForUser} = require("./helpers/utils");

const HOLOGRAPH_REGISTRY = 'HolographRegistry';
const HOLOGRAPH_REGISTRY_CONTRACT = getContractArtifact(HOLOGRAPH_REGISTRY)

const HOLOGRAPH_REGISTRY_PROXY = 'HolographRegistryProxy';
const HOLOGRAPH_REGISTRY_PROXY_CONTRACT = getContractArtifact(HOLOGRAPH_REGISTRY_PROXY)

const { network, provider, web3 } = createNetworkPropsForUser(DEPLOYER, NETWORK)

async function main () {

    const HOLOGRAPH_REGISTRY_PROXY_ADDRESS = fs.readFileSync ('./data/' + NETWORK + '.' + HOLOGRAPH_REGISTRY_PROXY + '.address', 'utf8').trim ();

    const PA1D = 'PA1D';
    const PA1D_ADDRESS = fs.readFileSync ('./data/' + NETWORK + '.' + PA1D + '.address', 'utf8').trim ();

    const FACTORY = new web3.eth.Contract (
        HOLOGRAPH_REGISTRY_CONTRACT.abi,
        HOLOGRAPH_REGISTRY_PROXY_ADDRESS
    );

    const setContractTypeAddressResult2 = await FACTORY.methods.setContractTypeAddress('0x0000000000000000000000000000000000000000000000000000000050413144', PA1D_ADDRESS).send ({
        chainId: network.chain,
        from: provider.addresses [0],
        gas: web3.utils.toHex (1000000),
        gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
    }).catch (web3Error);
    if (!setContractTypeAddressResult2.status) {
        throwError (JSON.stringify (setContractTypeAddressResult2, null, 4));
    } else {
        console.log ('Set PA1D address to address type 0x0000000000000000000000000000000000000000000000000000000050413144');
    }

    process.exit ();

}

main ();
