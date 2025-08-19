# Deployment Quick Start

Streamlined deployment guide for Holograph Protocol. For detailed script documentation, see [SCRIPTS_OVERVIEW.md](SCRIPTS_OVERVIEW.md).

## Quick Start

```bash
# Install dependencies
git submodule update --init --recursive
npm install

# Set up environment
cp .env.example .env
# Configure your private keys and RPC URLs in .env

# Test deployment (dry-run)
make deploy-base deploy-eth

# Deploy to mainnet
export BROADCAST=true
export DEPLOYER_PK=0x...
make deploy-base deploy-eth
```

## Environment Variables

### Complete Environment Setup

```bash
# Network RPCs
export BASE_RPC_URL="https://mainnet.base.org"
export ETHEREUM_RPC_URL="https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY"
export UNICHAIN_RPC_URL="https://mainnet.unichain.org"

# Private Keys
export DEPLOYER_PK="0x..."      # Contract deployment
export OWNER_PK="0x..."         # Contract administration and operations

# API Keys for Verification
export BASESCAN_API_KEY="your_basescan_key"
export ETHERSCAN_API_KEY="your_etherscan_key"
export UNISCAN_API_KEY="your_uniscan_key"

# LayerZero Endpoint IDs
export BASE_EID=30184           # Base mainnet
export ETH_EID=30101            # Ethereum mainnet

# Protocol Addresses (update after deployment)
export DOPPLER_AIRLOCK="0x..."
export LZ_ENDPOINT="0x..."      # LayerZero V2 endpoint
export TREASURY="0x..."         # Treasury multisig
export HLG="0x..."              # HLG token address
export WETH="0x..."             # WETH address
export SWAP_ROUTER="0x..."      # Uniswap V3 SwapRouter
export STAKING_REWARDS="0x..."  # StakingRewards contract

# Deployed Contract Addresses (set after deployment)
export FEE_ROUTER="0x..."
export HOLOGRAPH_FACTORY="0x..."
```

### Testnet Configuration

```bash
# Sepolia Testnet RPCs
export BASE_SEPOLIA_RPC_URL="https://sepolia.base.org"
export ETHEREUM_SEPOLIA_RPC_URL="https://eth-sepolia.alchemyapi.io/v2/YOUR_KEY"
export UNICHAIN_SEPOLIA_RPC_URL="https://sepolia.unichain.org"

# Testnet Endpoint IDs
export BASE_SEPOLIA_EID=40245
export ETH_SEPOLIA_EID=40161
```

### Required Variables Summary

| Variable            | Required For           | Description                                 |
| ------------------- | ---------------------- | ------------------------------------------- |
| `BROADCAST`         | Live deployments       | Set to `true` to send real transactions    |
| `DEPLOYER_PK`       | `deploy-*` commands    | Private key for contract deployment        |
| `OWNER_PK`          | `configure-*` commands | Private key for contract administration    |
| `BASE_RPC_URL`      | Base operations        | RPC endpoint for Base network              |
| `ETHEREUM_RPC_URL`  | Ethereum operations    | RPC endpoint for Ethereum network          |
| `BASESCAN_API_KEY`  | Base verification      | API key for Basescan contract verification |
| `ETHERSCAN_API_KEY` | Ethereum verification  | API key for Etherscan contract verification|

## Deployment Commands

### Primary Chains (Required)

```bash
# Base deployment
make deploy-base        # Deploy HolographFactory + FeeRouter
make configure-base     # Configure contracts

# Ethereum deployment  
make deploy-eth         # Deploy StakingRewards + FeeRouter
make configure-eth      # Configure contracts
```

### Additional Chains (Optional)

```bash
# Unichain deployment
make deploy-unichain    # Deploy HolographFactory
make configure-unichain # Configure contracts
```

### Testnet Deployment

```bash
# Base Sepolia
make deploy-base-sepolia
make configure-base-sepolia

# Ethereum Sepolia
make deploy-eth-sepolia
make configure-eth-sepolia

# Unichain Sepolia
make deploy-unichain-sepolia
make configure-unichain-sepolia
```

## Complete Deployment Flow

### 1. Test in Dry-Run Mode

Always test deployment without broadcasting first:

```bash
# No BROADCAST environment variable = dry-run mode
make deploy-base deploy-eth
make configure-base configure-eth
```

### 2. Deploy to Mainnet

```bash
# Set deployment credentials
export BROADCAST=true
export DEPLOYER_PK=0x...

# Deploy contracts
make deploy-base deploy-eth

# Verify addresses match across chains
make verify-addresses
```

### 3. Configure Contracts

```bash
# Switch to owner key for configuration
export OWNER_PK=0x...

# Configure deployed contracts
make configure-base configure-eth

# Configure LayerZero DVN security
make configure-dvn-base configure-dvn-eth
```

### 4. Initial Setup

```bash
# Set up trusted Airlocks (update FeeOperations.s.sol first)
make fee-setup

# Check system status
make fee-status
```

## Contract Verification

Contracts are automatically verified during deployment when API keys are provided. If verification fails:

```bash
# Retry verification
forge script script/DeployBase.s.sol \
  --rpc-url $BASE_RPC_URL \
  --resume --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

## Deployment Artifacts

Deployment information is saved to:

- `deployments/base/` - Base network addresses
- `deployments/ethereum/` - Ethereum network addresses  
- `deployments/unichain/` - Unichain network addresses
- `broadcast/` - Complete transaction logs

Each deployment directory contains:
- `deployment.json` - Full deployment data
- Individual `.txt` files for each contract address

## HolographDeployer System

All contracts deploy through HolographDeployer for deterministic addresses:

- **CREATE2**: Same address on all chains
- **Salt Validation**: First 20 bytes must match deployer address
- **Batch Operations**: Deploy and initialize in one transaction
- **Signed Deployments**: Support for gasless deployment

## Safety Features

- **Dry-run default**: No transactions without explicit `BROADCAST=true`
- **Environment validation**: Scripts check required variables
- **Chain validation**: Warnings for unexpected networks
- **Role separation**: Different keys for deploy vs admin
- **Colored output**: Clear operation status feedback

## Advanced Deployment

For manual deployment with custom parameters:

```bash
# Base Chain
forge script script/DeployBase.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast --private-key $DEPLOYER_PK \
  --verify --etherscan-api-key $BASESCAN_API_KEY

# Ethereum Chain
forge script script/DeployEthereum.s.sol \
  --rpc-url $ETHEREUM_RPC_URL \
  --broadcast --private-key $DEPLOYER_PK \
  --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

## Troubleshooting

- **Verification fails**: Check API key and network match
- **Wrong addresses**: Ensure same salt and deployer address
- **Transaction reverts**: Check gas price and account balance
- **Access denied**: Verify correct private key for operation