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
export PRIVATE_KEY="0x..."       # Contract administration (bootstrap phase)

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
| `PRIVATE_KEY`       | `configure-*` commands | Private key for contract administration    |
| `BASE_RPC_URL`      | Base operations        | RPC endpoint for Base network              |
| `ETHEREUM_RPC_URL`  | Ethereum operations    | RPC endpoint for Ethereum network          |
| `BASESCAN_API_KEY`  | Base verification      | API key for Basescan contract verification |
| `ETHERSCAN_API_KEY` | Ethereum verification  | API key for Etherscan contract verification|

## StakingRewards Deployment (Ethereum Only)

The StakingRewards contract uses a UUPS (Universal Upgradeable Proxy Standard) proxy pattern for future upgrades.

### Required Environment Variables

```bash
export HLG="0x740df024CE73f589ACD5E8756b377ef8C6558BaB"    # HLG token address
export TREASURY="0x..."                                     # Treasury multisig address
export LZ_ENDPOINT="0x1a44076050125825900e736c501f859c50fE728c" # LayerZero V2 endpoint
export WETH="0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"      # WETH address
export SWAP_ROUTER="0xE592427A0AEce92De3Edee1F18E0157C05861564"  # Uniswap V3 SwapRouter
export BASE_EID=30184                                       # Base chain EID
```

### Deployment Steps

1. **Deploy Implementation + Proxy**:
```bash
forge script script/DeployEthereum.s.sol --fork-url $ETHEREUM_RPC_URL  # Dry run
BROADCAST=true forge script script/DeployEthereum.s.sol --broadcast --private-key $DEPLOYER_PK
```

2. **Verify Deployment**:
```bash
# Check proxy address
cast call <PROXY_ADDRESS> "owner()" --rpc-url $ETHEREUM_RPC_URL

# Check implementation via EIP-1967 slot
cast storage <PROXY_ADDRESS> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $ETHEREUM_RPC_URL

# Verify paused state (should be true after deployment)
cast call <PROXY_ADDRESS> "paused()" --rpc-url $ETHEREUM_RPC_URL
```

3. **Post-Deploy Actions**:
```bash
# NOTE: Post-deploy actions for bootstrap phase only
# After multisig handoff, use Safe UI/SDK instead

# Unpause the contract to activate staking (after referral seeding and multisig handoff)
cast send <PROXY_ADDRESS> "unpause()" --private-key $PRIVATE_KEY --rpc-url $ETHEREUM_RPC_URL

# Optional: Adjust burn percentage (default 50%)
cast send <PROXY_ADDRESS> "setBurnPercentage(uint256)" 5000 --private-key $PRIVATE_KEY --rpc-url $ETHEREUM_RPC_URL
```

### Deployment Output

The script saves addresses to `deployments/ethereum/deployment.json`:
```json
{
  "stakingRewards": "0x...",      // Proxy address (use this)
  "stakingRewardsImpl": "0x...",  // Implementation address
  "feeRouter": "0x...",
  "chainId": 1,
  "deployer": "0x..."
}
```

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

## Bootstrap and Multisig Handoff Flow

### Overview

The deployment follows a three-phase approach:

1. **Bootstrap Phase**: EOA deployment and referral seeding while paused
2. **Ownership Transfer**: Two-step transfer to multisig
3. **Operational Phase**: Multisig unpauses and manages ongoing operations

### Phase 1: Bootstrap Deployment (EOA)

All initial operations use `PRIVATE_KEY` with an EOA for speed and simplicity:

```bash
# 1. Deploy contracts (EOA deploys, remains paused)
export DEPLOYER_PK=0x...
export PRIVATE_KEY=0x...  # Same EOA for bootstrap admin operations
make deploy-eth configure-eth

# 2. Process referral CSV while paused (bootstrap only)
export STAKING_REWARDS=0x...
export HLG_TOKEN=0x...
export REFERRAL_CSV_PATH=./referral_data.csv
export BATCH_SIZE=500                # Optional, defaults to 500
export REFERRAL_RESUME_INDEX=0       # Optional, resume from specific user index

forge script script/ProcessReferralCSV.s.sol --broadcast --private-key $PRIVATE_KEY

# If processing fails mid-way, resume with:
# export REFERRAL_RESUME_INDEX=2500  # Resume from user 2500
# forge script script/ProcessReferralCSV.s.sol --broadcast --private-key $PRIVATE_KEY

# Contract remains paused throughout referral processing
```

### Phase 2: Ownership Transfer (EOA → Multisig)

```bash
# 1. Get transfer instructions and initiate transfer
npx tsx script/ts/multisig-cli.ts transfer-ownership
# This provides cast command for current owner to execute

# 2. Accept ownership via multisig-cli
npx tsx script/ts/multisig-cli.ts accept-ownership
# Generates Safe Transaction Builder JSON for multisig execution

# 3. Verify ownership transferred
cast call $STAKING_REWARDS "owner()" --rpc-url $ETHEREUM_RPC_URL
# Should return multisig address
```

### Phase 3: Operational Phase (Multisig)

After ownership transfer, use multisig-cli for admin operations:

```bash
# Unpause contract to activate staking
npx tsx script/ts/multisig-cli.ts unpause

# Emergency controls
npx tsx script/ts/multisig-cli.ts pause          # Emergency pause
npx tsx script/ts/multisig-cli.ts unpause        # Resume operations

# Fee distribution (ongoing operations)
npx tsx script/ts/multisig-cli.ts batch --eth 0.5    # Convert ETH to HLG and stake
npx tsx script/ts/multisig-cli.ts deposit --hlg 1000  # Direct HLG deposit

# Note: Administrative functions (setBurnPercentage, setFeeRouter, recovery)
# currently require cast commands - see OPERATIONS.md for details
```

### Important Notes

- **Bootstrap Commands**: All `cast send` examples in docs are for bootstrap phase only
- **Multisig Operations**: After handoff, use Safe UI or Safe SDK for all admin functions
- **Emergency Access**: Multisig retains full admin control for emergencies
- **Referral Timing**: Must process referrals while paused and owned by EOA

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
# Switch to admin key for configuration (bootstrap phase)
export PRIVATE_KEY=0x...

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