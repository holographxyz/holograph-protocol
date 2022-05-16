import fs from 'fs';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import 'hardhat-deploy-holographed';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import { HardhatUserConfig } from 'hardhat/config';
import dotenv from 'dotenv';
dotenv.config();

import './plugins/hardhat-holograph-address-injector';

const networks = JSON.parse(fs.readFileSync('./config/networks.json', 'utf8'));

const SOLIDITY_VERSION = process.env.SOLIDITY_VERSION || '0.8.13';

const MNEMONIC = process.env.MNEMONIC || 'test '.repeat(11) + 'junk';

const DEPLOYER = process.env.DEPLOYER || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

const RINKEBY_PRIVATE_KEY = process.env.RINKEBY_PRIVATE_KEY! || DEPLOYER;
const MAINNET_PRIVATE_KEY = process.env.MAINNET_PRIVATE_KEY || DEPLOYER;
const CXIP_PRIVATE_KEY = process.env.MAINNET_PRIVATE_KEY || DEPLOYER;

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;

/**
 * Go to https://hardhat.org/config/ to learn more
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
    defaultNetwork: 'localhost',
    networks: {
        localhost: {
            url: networks.localhost.rpc,
            chainId: networks.localhost.chain,
            accounts: {
                mnemonic: MNEMONIC,
                path: "m/44'/60'/0'/0",
                initialIndex: 0,
                count: 11,
                passphrase: '',
            },
            companionNetworks: {
                // https://github.com/wighawag/hardhat-deploy#companionnetworks
                l2: 'localhost2',
            },
            saveDeployments: false,
        },
        localhost2: {
            url: networks.localhost2.rpc,
            chainId: networks.localhost2.chain,
            accounts: {
                mnemonic: MNEMONIC,
                path: "m/44'/60'/0'/0",
                initialIndex: 0,
                count: 11,
                passphrase: '',
            },
            companionNetworks: {
                // https://github.com/wighawag/hardhat-deploy#companionnetworks
                l2: 'localhost',
            },
            saveDeployments: false,
        },
        eth: {
            url: networks.eth.rpc,
            chainId: networks.eth.chain,
            accounts: [MAINNET_PRIVATE_KEY],
        },
        eth_rinkeby: {
            url: networks.eth_rinkeby.rpc,
            chainId: networks.eth_rinkeby.chain,
            accounts: [RINKEBY_PRIVATE_KEY],
        },
        cxip: {
            url: networks.cxip.rpc,
            chainId: networks.cxip.chain,
            accounts: [CXIP_PRIVATE_KEY],
        },
        coverage: {
            url: 'http://127.0.0.1:8555',
        },
    },
    namedAccounts: {
        deployer: 0,
    },
    solidity: {
        version: SOLIDITY_VERSION,
        settings: {
            optimizer: {
                enabled: true,
                runs: 999999,
            },
            metadata: {
                bytecodeHash: 'none',
            },
        },
    },
    mocha: {
        timeout: 60000,
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS ? true : false,
        currency: 'USD',
        gasPrice: 100,
        coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY,
    },
    holographAddressInjector: {
        runOnCompile: true,
        verbose: false,
    },
};

export default config;
