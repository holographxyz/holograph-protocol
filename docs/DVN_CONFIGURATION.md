# LayerZero V2 DVN Configuration

LayerZero V2 requires explicit DVN (Decentralized Verifier Network) configuration before cross-chain messages are delivered. Without DVN setup, contracts deploy but cross-chain bridging fails silently.

## Quick Start

```bash
# After deploying contracts
make deploy-base deploy-eth BROADCAST=true
make configure-base configure-eth BROADCAST=true

# Configure DVN security stack
make configure-dvn-base configure-dvn-eth BROADCAST=true
```

## Manual Configuration

```bash
# Base → Ethereum
FEE_ROUTER=$(cat deployments/base/FeeRouter.txt) \
LZ_ENDPOINT=$BASE_LZ_ENDPOINT \
REMOTE_EID=30101 \
forge script script/ConfigureDVN.s.sol --rpc-url $BASE_RPC --broadcast

# Ethereum → Base  
FEE_ROUTER=$(cat deployments/ethereum/FeeRouter.txt) \
LZ_ENDPOINT=$ETH_LZ_ENDPOINT \
REMOTE_EID=30184 \
forge script script/ConfigureDVN.s.sol --rpc-url $ETH_RPC --broadcast
```

## DVN Addresses

LayerZero Labs DVN (primary):
- Ethereum: `0xF4DA94b4EE9D8e209e3bf9f469221CE2731A7112`
- Ethereum Sepolia: `0x53f488E93b4f1b60E8E83aa374dBe1780A1EE8a8`
- Base: **Update needed** - Get from [LayerZero docs](https://docs.layerzero.network/v2/deployments/dvn-addresses)

Polyhedra zkBridge DVN (secondary):
- All chains: `0x8ddF05F9A5c488b4973897E278B58895bF87Cb24`

## Configuration Details

**Security Model**: 1 required DVN (LayerZero Labs) + 1 optional DVN (Polyhedra)  
**Block Confirmations**: 15 blocks on both chains  
**Gas Limits**: 250k (Ethereum), 150k (Base)

## Environment Variables

```bash
FEE_ROUTER=0x...      # Contract address
LZ_ENDPOINT=0x...     # LayerZero V2 endpoint  
REMOTE_EID=30101      # Remote chain endpoint ID
DEPLOYER_PK=0x...     # Private key
BROADCAST=true        # Execute transactions
```

## Verification

Check configuration at [LayerZero Scan](https://layerzeroscan.com) by searching for your FeeRouter address. DVN settings should show "LayerZero Labs + Polyhedra" under Security Stack.

## Troubleshooting

**Messages not delivered**: DVNs not configured  
**"DVN not configured for this chain"**: Update Base DVN addresses in `script/config/DeploymentConstants.sol`  
**Bridge failures**: Check trusted remotes are set via `make configure-*`