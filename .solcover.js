module.exports = {
  skipFiles: ['mock', 'interfaces'],
  client: require('ganache-cli'),
  providerOptions: {
    port: 8545,
    hostname: '127.0.0.1',
    _chainId: 1338,
    _chainIdRpc: 1338,
    gasPrice: 0,
    gasLimit: 10000000000000000, // 10000000 Gwei
    networkId: 1338,
    chainId: 1338,
    default_balance_ether: 100,
    mnemonic: process.env.MNEMONIC,
    deterministic: true,
    total_accounts: 11,
    // db: './ganache/db',
    // acct_keys: './ganache/keys.json',
  },
};
