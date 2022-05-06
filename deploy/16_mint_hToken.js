'use strict';

const fs = require ('fs');
const HDWalletProvider = require ('truffle-hdwallet-provider');
const Web3 = require ('web3');
const {
    NETWORK,
    GAS,
    WALLET1,
    WALLET2,
    DEPLOYER
} = require ('../config/env');
const {throwError, web3Error, getContractArtifact, getNetworkInfo, getContractAddress} = require("./helpers/utils");

async function main () {
    const network = getNetworkInfo(NETWORK)
    const provider = new HDWalletProvider ([WALLET1, WALLET2], network.rpc, 0, 2);
    const web3 = new Web3 (provider);

    const H_TOKEN = 'token/hToken';
    const H_TOKEN_ARTIFACT = getContractArtifact(H_TOKEN)
    const H_TOKEN_ADDRESS = getContractAddress(NETWORK, H_TOKEN)

    const HOLOGRAPHER = 'Holographer';
    const HOLOGRAPHER_ARTIFACT = getContractArtifact(HOLOGRAPHER)

    const HOLOGRAPH_ERC20 = 'HolographERC20';
    const HOLOGRAPH_ERC20_ARTIFACT = getContractArtifact(HOLOGRAPH_ERC20)

    const HOLOGRAPH_ERC20_CONTRACT_FACTORY = new web3.eth.Contract (
        H_TOKEN_ARTIFACT.abi.concat (HOLOGRAPHER_ARTIFACT.abi).concat (HOLOGRAPH_ERC20_ARTIFACT.abi),
        H_TOKEN_ADDRESS
    );

    let tokenId = NETWORK == 'local' ? 1 : '0xFFFFFFFE00000000000000000000000000000000000000000000000000000001';

    console.log ("\n");

    const mintResult = await HOLOGRAPH_ERC20_CONTRACT_FACTORY.methods.holographNativeToken ('0x0000000000000000000000000000000000000000', provider.addresses [0]).send ({
        chainId: network.chain,
        from: provider.addresses [0],
        gas: web3.utils.toHex (1000000),
        gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei')),
        value: web3.utils.toHex (web3.utils.toWei ('0.1234567890', 'ether'))
    }).catch (web3Error);
    if (!mintResult.status) {
        throwError (JSON.stringify (mintResult, null, 4));
    }
    console.log ('Minted a total of', web3.utils.fromWei (mintResult.events.Transfer.returnValues._value, 'ether'), 'hTokens.');

    console.log ('balanceOf', await HOLOGRAPH_ERC20_CONTRACT_FACTORY.methods.balanceOf (provider.addresses [0]).call ({
        chainId: network.chain,
        from: provider.addresses [0],
        gas: web3.utils.toHex (1000000),
        gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
    }).catch (web3Error));

    console.log ('totalSupply', await HOLOGRAPH_ERC20_CONTRACT_FACTORY.methods.totalSupply ().call ({
        chainId: network.chain,
        from: provider.addresses [0],
        gas: web3.utils.toHex (1000000),
        gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
    }).catch (web3Error));

    console.log ("\n");

    process.exit ();

}

main ();
