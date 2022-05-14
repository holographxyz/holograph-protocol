import fs from 'fs';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import 'hardhat-deploy';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import { HardhatUserConfig } from 'hardhat/config';
import dotenv from 'dotenv';
dotenv.config();

import './plugins/hardhat-holograph-address-injector';

const networks = JSON.parse(fs.readFileSync('./config/networks.json', 'utf8'));

const SOLIDITY_VERSION = process.env.SOLIDITY_VERSION || '';

const WALLET1 = process.env.WALLET1 || '0x' + '00'.repeat(32);
const WALLET2 = process.env.WALLET2 || '0x' + '11'.repeat(32);
const WALLET3 = process.env.WALLET3 || '0x' + '22'.repeat(32);
const WALLET4 = process.env.WALLET4 || '0x' + '33'.repeat(32);
const WALLET5 = process.env.WALLET5 || '0x' + '44'.repeat(32);
const WALLET6 = process.env.WALLET6 || '0x' + '55'.repeat(32);
const WALLET7 = process.env.WALLET7 || '0x' + '66'.repeat(32);
const WALLET8 = process.env.WALLET8 || '0x' + '77'.repeat(32);
const WALLET9 = process.env.WALLET9 || '0x' + '88'.repeat(32);
const WALLET10 = process.env.WALLET10 || '0x' + '99'.repeat(32);

const RINKEBY_PRIVATE_KEY = process.env.RINKEBY_PRIVATE_KEY! || WALLET1;
const MAINNET_PRIVATE_KEY = process.env.MAINNET_PRIVATE_KEY || WALLET1;
const CXIP_PRIVATE_KEY = process.env.MAINNET_PRIVATE_KEY || WALLET1;

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
      accounts: [WALLET1, WALLET2, WALLET3, WALLET4, WALLET5, WALLET6, WALLET7, WALLET8, WALLET9, WALLET10],
      // https://github.com/wighawag/hardhat-deploy#companionnetworks
      companionNetworks: {
        l2: 'localhost2',
      },
      saveDeployments: false,
    },
    localhost2: {
      url: networks.localhost2.rpc,
      chainId: networks.localhost2.chain,
      accounts: [WALLET1, WALLET2, WALLET3, WALLET4, WALLET5, WALLET6, WALLET7, WALLET8, WALLET9, WALLET10],
      // https://github.com/wighawag/hardhat-deploy#companionnetworks
      companionNetworks: {
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
    purchaser: 0,
  },
  solidity: {
    version: SOLIDITY_VERSION,
    settings: {
      optimizer: {
        enabled: true,
        runs: 99999,
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
    verbose: false
  },
};

export default config;
