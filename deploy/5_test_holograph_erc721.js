'use strict';

const fs = require ('fs');
const HDWalletProvider = require ('truffle-hdwallet-provider');
const Web3 = require ('web3');
const {
    NETWORK,
    GAS,
    DEPLOYER
} = require ('../config/env');
const {web3Error, createNetworkPropsForUser, getContractArtifact} = require("./helpers/utils");

const HOLOGRAPH_ERC721 = 'HolographERC721';
const HOLOGRAPH_ERC721_CONTRACT = getContractArtifact(HOLOGRAPH_ERC721)

const { network, provider, web3 } = createNetworkPropsForUser(DEPLOYER, NETWORK)

async function main () {

    const HOLOGRAPH_ERC721_ADDRESS = fs.readFileSync ('./data/' + NETWORK + '.' + HOLOGRAPH_ERC721 + '.address', 'utf8').trim ();

    const FACTORY = new web3.eth.Contract (
        HOLOGRAPH_ERC721_CONTRACT.abi,
        HOLOGRAPH_ERC721_ADDRESS
    );

    console.log ("\n");

    console.log ('contractURI', await FACTORY.methods.contractURI ().call ({
        chainId: network.chain,
        from: provider.addresses [0],
        gas: web3.utils.toHex (1000000),
        gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
    }).catch (web3Error));

    console.log ('name', await FACTORY.methods.name ().call ({
        chainId: network.chain,
        from: provider.addresses [0],
        gas: web3.utils.toHex (1000000),
        gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
    }).catch (web3Error));

    console.log ('symbol', await FACTORY.methods.symbol ().call ({
        chainId: network.chain,
        from: provider.addresses [0],
        gas: web3.utils.toHex (1000000),
        gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
    }).catch (web3Error));

    console.log ("\n");

    process.exit ();

}

main ();
