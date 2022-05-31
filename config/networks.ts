import dotenv from 'dotenv';
import { Networks } from '../scripts/utils/helpers';
dotenv.config();

const networks: Networks = {
  hardhat: {
    chain: 31337,
    rpc: 'http://localhost:8545',
    holographId: 4294967295,
    tokenName: 'Hardhat',
    tokenSymbol: 'HRD',
    lzEndpoint: '0x0000000000000000000000000000000000000000'.toLowerCase(),
  },
  localhost: {
    chain: 1338,
    rpc: 'http://localhost:8545',
    holographId: 4294967295,
    tokenName: 'Localhost',
    tokenSymbol: 'LH',
    lzEndpoint: '0x0000000000000000000000000000000000000000'.toLowerCase(),
  },
  localhost2: {
    chain: 1339,
    rpc: 'http://localhost:9545',
    holographId: 4294967294,
    tokenName: 'Localhost 2',
    tokenSymbol: 'LH2',
    lzEndpoint: '0x0000000000000000000000000000000000000000'.toLowerCase(),
  },
  cxip: {
    chain: 1337,
    rpc: 'https://rpc.cxip.dev',
    holographId: 4000000000,
    tokenName: 'Cxip Token',
    tokenSymbol: 'CXIP',
    lzEndpoint: '0x0000000000000000000000000000000000000000'.toLowerCase(),
  },
  eth: {
    chain: 1,
    rpc: 'https://eth.getblock.io/mainnet/?api_key=7bf62a30-d403-4afc-99dc-462dfbfb10de',
    holographId: 1,
    tokenName: 'Ethereum',
    tokenSymbol: 'ETH',
    lzEndpoint: '0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675'.toLowerCase(),
  },
  eth_rinkeby: {
    chain: 4,
    rpc: process.env.RINKEBY_RPC_URL || 'https://eth.getblock.io/rinkeby/?api_key=7bf62a30-d403-4afc-99dc-462dfbfb10de',
    holographId: 4000000001,
    tokenName: 'Ethereum Rinkeby',
    tokenSymbol: 'RIN',
    lzEndpoint: '0x79a63d6d8BBD5c6dfc774dA79bCcD948EAcb53FA'.toLowerCase(),
  },
  bsc: {
    chain: 56,
    rpc: 'https://bsc.getblock.io/mainnet/?api_key=7bf62a30-d403-4afc-99dc-462dfbfb10de',
    holographId: 2,
    tokenName: 'BNB',
    tokenSymbol: 'BNB',
    lzEndpoint: '0x3c2269811836af69497E5F486A85D7316753cf62'.toLowerCase(),
  },
  bsc_testnet: {
    chain: 97,
    rpc: 'https://bsc.getblock.io/testnet/?api_key=7bf62a30-d403-4afc-99dc-462dfbfb10de',
    holographId: 4000000002,
    tokenName: 'BNB Testnet',
    tokenSymbol: 'tBNB',
    lzEndpoint: '0x6Fcb97553D41516Cb228ac03FdC8B9a0a9df04A1'.toLowerCase(),
  },
  avax: {
    chain: 43114,
    rpc: 'https://api.avax.network/ext/bc/C/rpc',
    holographId: 3,
    tokenName: 'Avalanche',
    tokenSymbol: 'AVAX',
    lzEndpoint: '0x3c2269811836af69497E5F486A85D7316753cf62'.toLowerCase(),
  },
  fuji: {
    chain: 43113,
    rpc: process.env.FUJI_RPC_URL || 'https://api.avax-test.network/ext/bc/C/rpc',
    holographId: 4000000003,
    tokenName: 'Avalanche Fuji',
    tokenSymbol: 'AVAX',
    lzEndpoint: '0x93f54D755A063cE7bB9e6Ac47Eccc8e33411d706'.toLowerCase(),
  },
  matic: {
    chain: 137,
    rpc: 'https://rpc-mainnet.matic.network',
    holographId: 4,
    tokenName: 'Polygon',
    tokenSymbol: 'MATIC',
    lzEndpoint: '0x3c2269811836af69497E5F486A85D7316753cf62'.toLowerCase(),
  },
  mumbai: {
    chain: 80001,
    rpc: process.env.MUMBAI_RPC_URL || 'https://rpc-mumbai.maticvigil.com',
    holographId: 4000000004,
    tokenName: 'Polygon Mumbai',
    tokenSymbol: 'MATIC',
    lzEndpoint: '0xf69186dfBa60DdB133E91E9A4B5673624293d8F8'.toLowerCase(),
  },
  ftm: {
    chain: 250,
    rpc: 'https://rpc.fantom.network',
    holographId: 5,
    tokenName: 'Fantom',
    tokenSymbol: 'FTM',
    lzEndpoint: '0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7'.toLowerCase(),
  },
  ftm_testnet: {
    chain: 4002,
    rpc: 'https://rpc.testnet.fantom.network',
    holographId: 4000000005,
    tokenName: 'Fantom Testnet',
    tokenSymbol: 'FTM',
    lzEndpoint: '0x7dcAD72640F835B0FA36EFD3D6d3ec902C7E5acf'.toLowerCase(),
  },
  arbitrum: {
    chain: 42161,
    rpc: 'https://arb1.arbitrum.io/rpc',
    holographId: 6,
    tokenName: 'Arbitrum',
    tokenSymbol: 'ETH',
    lzEndpoint: '0x3c2269811836af69497E5F486A85D7316753cf62'.toLowerCase(),
  },
  arbitrum_rinkeby: {
    chain: 421611,
    rpc: 'https://rinkeby.arbitrum.io/rpc',
    holographId: 4000000006,
    tokenName: 'Arbitrum Rinkeby',
    tokenSymbol: 'ARETH',
    lzEndpoint: '0x4D747149A57923Beb89f22E6B7B97f7D8c087A00'.toLowerCase(),
  },
  optimism: {
    chain: 10,
    rpc: 'https://mainnet.optimism.io',
    holographId: 7,
    tokenName: 'Optimism',
    tokenSymbol: 'ETH',
    lzEndpoint: '0x3c2269811836af69497E5F486A85D7316753cf62'.toLowerCase(),
  },
  optimism_kovan: {
    chain: 69,
    rpc: 'https://kovan.optimism.io',
    holographId: 4000000007,
    tokenName: 'Optimism Kovan',
    tokenSymbol: 'KOR',
    lzEndpoint: '0x72aB53a133b27Fa428ca7Dc263080807AfEc91b5'.toLowerCase(),
  },
  gno: {
    chain: 100,
    rpc: 'https://rpc.gnosischain.com',
    holographId: 8,
    tokenName: 'Gnosis Chain',
    tokenSymbol: 'GNO',
    lzEndpoint: '0x0000000000000000000000000000000000000000'.toLowerCase(),
  },
  gno_sokol: {
    chain: 77,
    rpc: 'https://sokol.poa.network',
    holographId: 4000000008,
    tokenName: 'Gnosis Chain Sokol',
    tokenSymbol: 'GNO',
    lzEndpoint: '0x0000000000000000000000000000000000000000'.toLowerCase(),
  },
};

export default networks;
