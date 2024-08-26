Soon™️

## Deploy an isolated environment

### Configure your .env file

#### Environment configuration
```bash
HOLOGRAPH_ENVIRONMENT="testnet"
FORCE_DEPLOY_GENESIS="true"
DEPLOYER=<your_deployer_private_key>
```

#### RPC configuration
```bash
ETHEREUM_TESTNET_SEPOLIA_RPC_URL=""
POLYGON_TESTNET_RPC_URL=""
AVALANCHE_TESTNET_RPC_URL=""
BINANCE_SMART_CHAIN_TESTNET_RPC_URL=""
OPTIMISM_TESTNET_SEPOLIA_RPC_URL=""
ARBITRUM_TESTNET_SEPOLIA_RPC_URL=""
ZORA_TESTNET_SEPOLIA_RPC_URL=""
MANTLE_TESTNET_RPC_URL=""
BASE_TESTNET_SEPOLIA_RPC_URL=""
```

### Deploy on optimisim sepolia

```bash
pnpm deploy:opsepolia
```

### Deploy on arbitrum sepolia

```bash
pnpm deploy:arbsepolia
```

### Deploy on other testnets

```bash
pnpm deploy --network <network>
```

#### Available networks
- Base sepolia: `baseTestnetSepolia`
- Zora testnet: `zoraTestnetSepolia`
- Matle testnet: `mantleTestnet`
- Linea testnet: `lineaTestnetGoerli`
--- 
- Arbitrum sepolia: `arbitrumTestnetSepolia`
- Optimism sepolia: `optimismTestnetSepolia`
