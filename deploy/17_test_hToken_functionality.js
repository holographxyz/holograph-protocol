'use strict';
const HDWalletProvider = require ('truffle-hdwallet-provider');
const Web3 = require ('web3');
const {
    NETWORK,
    GAS,
    WALLET1,
    WALLET2,
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

    let tokenAmount = 0;

    console.log ("\n");

    let firstWalletTokenBalance = await HOLOGRAPH_ERC20_CONTRACT_FACTORY.methods.balanceOf (provider.addresses [0]).call ({
        chainId: network.chain,
        from: provider.addresses [0],
        gas: web3.utils.toHex (1000000),
        gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
    }).catch (web3Error);
    console.log ('balanceOf', provider.addresses [0], '==', web3.utils.fromWei (firstWalletTokenBalance, 'ether'), 'hTokens');
    const transferResult = await HOLOGRAPH_ERC20_CONTRACT_FACTORY.methods.transferFrom (provider.addresses [0], provider.addresses [1], firstWalletTokenBalance).send ({
        chainId: network.chain,
        from: provider.addresses [0],
        gas: web3.utils.toHex (1000000),
        gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
    }).catch (web3Error);
    if (!transferResult.status) {
        throwError (JSON.stringify (transferResult, null, 4));
    }
    console.log (
        "\n" + 'A total of',
        web3.utils.fromWei (transferResult.events.Transfer.returnValues._value, 'ether'), 'hTokens',
        'transfered from',
        transferResult.events.Transfer.returnValues._from,
        'to',
        transferResult.events.Transfer.returnValues._to,
        "\n"
    );

    let secondWalletTokenBalance = await HOLOGRAPH_ERC20_CONTRACT_FACTORY.methods.balanceOf (provider.addresses [1]).call ({
        chainId: network.chain,
        from: provider.addresses [0],
        gas: web3.utils.toHex (1000000),
        gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
    }).catch (web3Error);
    console.log ('balanceOf', provider.addresses [0], '==', web3.utils.fromWei (secondWalletTokenBalance, 'ether'), 'hTokens');
    const transferBackResult = await HOLOGRAPH_ERC20_CONTRACT_FACTORY.methods.transferFrom (provider.addresses [1], provider.addresses [0], secondWalletTokenBalance).send ({
        chainId: network.chain,
        from: provider.addresses [1],
        gas: web3.utils.toHex (1000000),
        gasPrice: web3.utils.toHex (web3.utils.toWei (GAS, 'gwei'))
    }).catch (web3Error);
    if (!transferBackResult.status) {
        throwError (JSON.stringify (transferBackResult, null, 4));
    }
    console.log (
        "\n" + 'A total of',
        web3.utils.fromWei (transferBackResult.events.Transfer.returnValues._value, 'ether'), 'hTokens',
        'transfered from',
        transferBackResult.events.Transfer.returnValues._from,
        'to',
        transferBackResult.events.Transfer.returnValues._to,
        "\n"
    );

    if (firstWalletTokenBalance != secondWalletTokenBalance) {
        throwError ('hToken amounts do not match!');
    }

    console.log ("\n");

    process.exit ();

}

main ();
