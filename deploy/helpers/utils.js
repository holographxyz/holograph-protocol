const fs = require('fs')
const HDWalletProvider = require('truffle-hdwallet-provider')
const Web3 = require('web3')

function getContractArtifact(name) {
    const isProxy = name.toLowerCase().includes("proxy");
    if(isProxy) {
        return JSON.parse (fs.readFileSync ('./build/combined.json')).contracts ['proxy/' + name + '.sol:' + name];
    } else {
        return JSON.parse (fs.readFileSync ('./build/combined.json')).contracts[name + '.sol:' + name];
    }
}

function getNetworkInfo(name) {
    return JSON.parse (fs.readFileSync ('./networks.json', 'utf8')) [name];
}

function createProvider(privateKey, rpc) {
    return new HDWalletProvider (privateKey, rpc);
}

function createWeb3(provider) {
    return new Web3 (provider);
}

function createProviderAndWeb3(privateKey, rpc) {
    const provider = createProvider(privateKey, rpc)
    const web3 = createWeb3(provider)
    return {
        provider,
        web3,
    }
}

function createNetworkPropsForUser(privateKey, networkName) {
    const network = getNetworkInfo(networkName)
    const { provider, web3 } = createProviderAndWeb3(privateKey, network.rpc)
    return {
        network,
        provider,
        web3
    }
}

function createFactoryFromABI(web3, abi) {
    return new web3.eth.Contract (abi);
}

function saveContractResult(networkName, contractName, contractInstance) {
    fs.writeFileSync (
        './data/' + networkName + '.' + contractName + '.address',
        contractInstance.options.address
    );
    console.log(`Deployed ${contractName} Contract : ${contractInstance.options.address}`)
}


const removeX = function (input) {
    if (input.startsWith ('0x')) {
        return input.substring (2);
    } else {
        return input;
    }
};

const hexify = function (input, prepend) {
    input = input.toLowerCase ().trim ();
    if (input.startsWith ('0x')) {
        input = input.substring (2);
    }
    input = input.replace (/[^0-9a-f]/g, '');
    if (prepend) {
        input = '0x' + input;
    }
    return input;
};

const throwError = function (err) {
    process.stderr.write (err + '\n');
    process.exit (1);
};

const web3Error = function (err) {
    throwError (err.toString ())
};


module.exports = {
    getContractArtifact,
    getNetworkInfo,
    createProvider,
    createWeb3,
    createProviderAndWeb3,
    createNetworkPropsForUser,
    createFactoryFromABI,
    saveContractResult,
    removeX,
    hexify,
    throwError,
    web3Error
}