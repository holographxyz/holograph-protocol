'use strict';

const fs = require ('fs');
const HDWalletProvider = require ('truffle-hdwallet-provider');
const Web3 = require ('web3');
const {
    NETWORK,
    GAS,
    DEPLOYER
} = require ('../config/env');
const {throwError, web3Error, getContractArtifact, createNetworkPropsForUser} = require("./helpers/utils");

const HOLOGRAPH_REGISTRY = 'HolographRegistry';
const HOLOGRAPH_REGISTRY_CONTRACT = getContractArtifact(HOLOGRAPH_REGISTRY)

const HOLOGRAPH_REGISTRY_PROXY = 'HolographRegistryProxy';
const HOLOGRAPH_REGISTRY_PROXY_CONTRACT = getContractArtifact(HOLOGRAPH_REGISTRY_PROXY)

const { network, provider, web3 } = createNetworkPropsForUser(DEPLOYER, NETWORK)

async function main () {

    const HOLOGRAPH_REGISTRY_PROXY_ADDRESS = fs.readFileSync ('./data/' + NETWORK + '.' + HOLOGRAPH_REGISTRY_PROXY + '.address', 'utf8').trim ();

    const HOLOGRAPH_ERC721 = 'HolographERC721';
    const HOLOGRAPH_ERC721_ADDRESS = fs.readFileSync ('./data/' + NETWORK + '.' + HOLOGRAPH_ERC721 + '.address', 'utf8').trim ();

    const FACTORY = new web3.eth.Contract (
        HOLOGRAPH_REGISTRY_CONTRACT.abi,
        HOLOGRAPH_REGISTRY_PROXY_ADDRESS
    );

    const setContractTypeAddressResult = await FACTORY.methods.setContractTypeAddress('0x0000000000000000000000000000000000486f6c6f6772617068455243373231', HOLOGRAPH_ERC721_ADDRESS).send ({
        chainId: network.chain,
        from: provider.addresses [0],
        gas: web3.utils.toHex (1000000),
        gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
    }).catch (web3Error);
    if (!setContractTypeAddressResult.status) {
        throwError (JSON.stringify (setContractTypeAddressResult, null, 4));
    } else {
        console.log ('Set HolographERC721 address to address type 0x0000000000000000000000000000000000486f6c6f6772617068455243373231');
    }

    process.exit ();

}

main ();
