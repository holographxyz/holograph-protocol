# Holograph Protocol v2

A protocol for deploying omnichain tokens with deterministic addresses across multiple blockchains. Built on Doppler Airlock technology and LayerZero V2 for secure cross-chain messaging.

## Overview

Holograph Protocol enables the creation of ERC-20 tokens that exist natively across multiple chains with identical contract addresses. Rather than traditional bridge mechanisms, tokens are minted directly on destination chains through LayerZero V2 messaging.

### Key Features

- **Deterministic Addresses**: Same contract address across all supported chains
- **Direct Minting**: No lock/unlock bridge mechanisms required
- **Doppler Integration**: Built on Doppler Airlock for token launches
- **Fee Automation**: Automated fee collection and cross-chain distribution
- **LayerZero V2**: Secure cross-chain messaging infrastructure

### Architecture

```
Base Chain                   LayerZero V2              Ethereum Chain
┌─────────────────┐         ┌─────────────┐          ┌─────────────────┐
│ HolographFactory│────────▶│   Message   │─────────▶│   Token Mint    │
│                 │         │   Passing   │          │                 │
│ FeeRouter       │────────▶│             │─────────▶│ Fee Processing  │
│                 │         │             │          │                 │
│ Doppler Airlock │         │             │          │ StakingRewards  │
└─────────────────┘         └─────────────┘          └─────────────────┘
```

## Development & Deployment

### Quick Start with Makefile

The project includes a streamlined Makefile for common development tasks. All deployment operations default to **dry-run mode** for safety - no real transactions are sent unless explicitly enabled.

#### Basic Commands

```bash
# Development
make build          # Compile all contracts
make test           # Run the full test suite
make fmt            # Format Solidity code
make clean          # Clean build artifacts

# View all available commands
make help
```

#### Deployment Commands

**Dry-run mode (default - safe for testing):**

```bash
make deploy-base    # Simulate Base deployment
make deploy-eth     # Simulate Ethereum deployment
make configure-base # Simulate Base configuration
make configure-eth  # Simulate Ethereum configuration
make keeper         # Simulate keeper operations
```

**Live deployment mode:**

```bash
# Set environment variables
export BROADCAST=true
export DEPLOYER_PK=0x...  # For deploy-base and deploy-eth
export OWNER_PK=0x...     # For configure-base and configure-eth
export KEEPER_PK=0x...    # For keeper operations

# Required RPC URLs
export BASE_RPC_URL=https://mainnet.base.org
export ETHEREUM_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY

# Required API keys for verification
export BASESCAN_API_KEY=your_basescan_key
export ETHERSCAN_API_KEY=your_etherscan_key

# Now run actual deployments
make deploy-base    # Deploy to Base mainnet
make deploy-eth     # Deploy to Ethereum mainnet
```

#### Environment Variables

| Variable            | Required For           | Description                                 |
| ------------------- | ---------------------- | ------------------------------------------- |
| `BROADCAST`         | Live deployments       | Set to `true` to send real transactions     |
| `DEPLOYER_PK`       | `deploy-*` commands    | Private key for contract deployment         |
| `OWNER_PK`          | `configure-*` commands | Private key for contract administration     |
| `KEEPER_PK`         | `keeper` command       | Private key for automated operations        |
| `BASE_RPC_URL`      | Base operations        | RPC endpoint for Base network               |
| `ETHEREUM_RPC_URL`  | Ethereum operations    | RPC endpoint for Ethereum network           |
| `BASESCAN_API_KEY`  | Base verification      | API key for Basescan contract verification  |
| `ETHERSCAN_API_KEY` | Ethereum verification  | API key for Etherscan contract verification |

#### Typical Deployment Flow

1. **Test everything in dry-run mode first:**

   ```bash
   make deploy-base deploy-eth configure-base configure-eth
   ```

2. **Deploy to mainnet:**

   ```bash
   export BROADCAST=true
   export DEPLOYER_PK=0x...
   make deploy-base deploy-eth
   ```

3. **Configure the deployed contracts:**

   ```bash
   export OWNER_PK=0x...  # Different key for admin operations
   make configure-base configure-eth
   ```

4. **Set up automation:**
   ```bash
   export KEEPER_PK=0x...
   make keeper  # Test keeper operations
   ```

#### Contract Verification

Contracts are automatically verified during deployment when `BROADCAST=true` and the appropriate API keys are set. If verification fails during deployment, you can retry later:

```bash
# Re-run deployment with --resume --verify
forge script script/DeployBase.s.sol --rpc-url $BASE_RPC_URL --resume --verify --etherscan-api-key $BASESCAN_API_KEY
```

#### Deployment Artifacts

Deployed contract addresses are automatically saved to:

- `deployments/base/` - Base network deployments
- `broadcast/` - Complete transaction logs and artifacts

#### Safety Features

- **Dry-run by default**: Scripts never broadcast without explicit `BROADCAST=true`
- **Environment validation**: Scripts check for required environment variables
- **Chain validation**: Scripts warn when deploying to unexpected networks
- **Role separation**: Different private keys for deployment vs. administration
- **Colored output**: Clear visual feedback on operation status

## Core Contracts

### HolographFactory

Entry point for token launches and cross-chain operations.

```solidity
function createToken(CreateParams calldata params) external payable returns (address asset);
function bridgeToken(uint32 dstEid, address token, address recipient, uint256 amount, bytes calldata options) external payable;
```

### FeeRouter

Handles fee collection from Doppler Airlock contracts and cross-chain fee distribution.

```solidity
function collectAirlockFees(address airlock, address token, uint256 amt) external; // KEEPER_ROLE
function bridge(uint256 minGas, uint256 minHlg) external; // KEEPER_ROLE
function setTrustedAirlock(address airlock, bool trusted) external; // Owner only
```

### StakingRewards

Single-token HLG staking with reward distribution, cooldown periods, and emergency controls.

```solidity
function stake(uint256 amount) external; // Stake HLG tokens
function withdraw(uint256 amount) external; // Withdraw after cooldown (default 7 days)
function claim() external; // Claim accumulated rewards
function addRewards(uint256 amount) external; // FeeRouter only
```

## Token Launch Process

1. Call `HolographFactory.createToken()` with token parameters - **no launch fees required**
2. Factory automatically sets FeeRouter as integrator for Doppler trading fee collection
3. Token deployed through Doppler Airlock with deterministic CREATE2 address
4. Identical contract address immediately available for cross-chain bridging

## Fee Model

- **Source**: Trading fees from Doppler auctions (collected by Airlock contracts)
- **Protocol Split**: 1.5% of collected fees (HOLO_FEE_BPS = 150)
- **Treasury Split**: 98.5% of collected fees forwarded to treasury address
- **HLG Distribution**: Protocol fees bridged to Ethereum, swapped WETH→HLG, 50% burned / 50% staked
- **Security**: Trusted Airlock whitelist prevents unauthorized ETH transfers to FeeRouter

## Integration

### Token Launch

```solidity
CreateParams memory params = CreateParams({
    name: "MyToken",
    symbol: "MTK",
    decimals: 18,
    initialSupply: 1000000e18,
    salt: bytes32(uint256(1)),
    integrator: address(0), // Auto-set to FeeRouter
    royaltyFeePercentage: 500,
    royaltyRecipient: msg.sender
});

// Free token launch - no ETH required
address token = holographFactory.createToken(params);
```

### Cross-Chain Bridging

```solidity
holographFactory.bridgeToken{value: bridgeFee}(
    destinationEid,
    tokenAddress,
    recipient,
    amount,
    lzOptions
);
```

### Keeper Operations

```solidity
// Collect fees from Doppler Airlock
feeRouter.collectAirlockFees(airlockAddress, tokenAddress, amount);

// Bridge accumulated fees
feeRouter.bridge(minGas, minHlgOut);
```

## Security

### Access Control

- **Owner**: Contract administration, trusted remote management, treasury updates
- **KEEPER_ROLE**: Automated fee collection (`collectAirlockFees`) and cross-chain bridging
- **FeeRouter Authorization**: Only designated FeeRouter can add rewards to StakingRewards

### Cross-Chain Security

- **Trusted Remotes**: Per-endpoint whitelist of authorized cross-chain message senders
- **Endpoint Validation**: LayerZero V2 endpoint verification for all cross-chain messages
- **Trusted Airlocks**: Whitelist preventing unauthorized ETH transfers to FeeRouter
- **Replay Protection**: Nonce-based system preventing message replay attacks

### Economic Security

- **Dust Protection**: MIN_BRIDGE_VALUE (0.01 ETH) prevents uneconomical bridging
- **Slippage Protection**: Configurable minimum HLG output for swaps
- **Cooldown Period**: 7-day default withdrawal cooldown prevents staking manipulation
- **Emergency Controls**: Owner can pause all major contract functions

## Testing

```bash
# Run all tests
forge test

# Unit tests
forge test --match-path test/unit/

# Integration tests
forge test --match-path test/integration/

# Gas reports
forge test --gas-report
```

## Environment Setup

Set up the following environment variables for deployment and operations:

```bash
# Network RPCs
export BASE_RPC="https://mainnet.base.org"
export ETH_RPC="https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY"

# Private Keys
export DEPLOYER_PK="0x..."      # Contract deployment
export OWNER_PK="0x..."         # Contract administration
export KEEPER_PK="0x..."        # Automation operations

# LayerZero Endpoint IDs
export BASE_EID=30184           # Base mainnet
export ETH_EID=30101            # Ethereum mainnet

# Contract Addresses (update after deployment)
export DOPPLER_AIRLOCK="0x..."
export LZ_ENDPOINT="0x..."      # LayerZero V2 endpoint
export TREASURY="0x..."         # Treasury multisig
export HLG="0x..."              # HLG token address
export WETH="0x..."             # WETH address
export SWAP_ROUTER="0x..."      # Uniswap V3 SwapRouter
export STAKING_REWARDS="0x..."  # StakingRewards contract

# Addresses (set after deployment)
export FEE_ROUTER="0x..."
export HOLOGRAPH_FACTORY="0x..."
export KEEPER_ADDRESS="0x..."
```

## Deployment

> **💡 Quick Start**: Use the simplified Makefile commands documented in the [Development & Deployment](#development--deployment) section above for streamlined deployment.

### Using Makefile (Recommended)

```bash
# Set up environment
export BROADCAST=true
export DEPLOYER_PK=0x...
export BASE_RPC_URL=https://mainnet.base.org
export ETHEREUM_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY

# Deploy to both chains
make deploy-base deploy-eth
```

### Manual Deployment (Advanced)

For advanced users who need more control over deployment parameters:

#### Base Chain

```bash
# Deploy using deployment script
forge script script/DeployBase.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast --private-key $DEPLOYER_PK \
  --verify --etherscan-api-key $BASESCAN_API_KEY
```

#### Ethereum Chain

```bash
# Deploy using deployment script
forge script script/DeployEthereum.s.sol \
  --rpc-url $ETHEREUM_RPC_URL \
  --broadcast --private-key $DEPLOYER_PK \
  --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

## Operations

### Initial Setup

After deployment, configure the system using the keeper script:

```bash
# 1. Update script/KeeperPullAndBridge.s.sol with actual addresses
# 2. Whitelist Airlock contracts (Owner only)
forge script script/KeeperPullAndBridge.s.sol \
  --sig "setupTrustedAirlocks()" \
  --rpc-url $BASE_RPC --broadcast --private-key $OWNER_PK

# 3. Grant keeper role to automation address
cast send $FEE_ROUTER "grantRole(bytes32,address)" \
  $(cast keccak "KEEPER_ROLE") $KEEPER_ADDRESS \
  --rpc-url $BASE_RPC --private-key $OWNER_PK

# 4. Configure LayerZero trusted remotes
cast send $FEE_ROUTER "setTrustedRemote(uint32,bytes32)" \
  $ETH_EID $(cast address-to-bytes32 $ETH_FEE_ROUTER) \
  --rpc-url $BASE_RPC --private-key $OWNER_PK

cast send $FEE_ROUTER "setTrustedRemote(uint32,bytes32)" \
  $BASE_EID $(cast address-to-bytes32 $BASE_FEE_ROUTER) \
  --rpc-url $ETH_RPC --private-key $OWNER_PK
```

### Keeper Automation

```bash
# Monitor system status
forge script script/KeeperPullAndBridge.s.sol \
  --sig "checkBalances()" --rpc-url $BASE_RPC

# Run fee collection and bridging (automated/cron)
forge script script/KeeperPullAndBridge.s.sol \
  --rpc-url $BASE_RPC --broadcast --private-key $KEEPER_PK

# Set up automated execution (example cron)
echo "*/10 * * * * cd /path/to/holograph && forge script script/KeeperPullAndBridge.s.sol --rpc-url \$BASE_RPC --broadcast --private-key \$KEEPER_PK" | crontab -
```

### Emergency Controls

```bash
# Pause operations (Owner only)
forge script script/KeeperPullAndBridge.s.sol \
  --sig "emergencyPause()" \
  --rpc-url $BASE_RPC --broadcast --private-key $OWNER_PK

# Unpause operations (Owner only)
cast send $FEE_ROUTER "unpause()" \
  --rpc-url $BASE_RPC --private-key $OWNER_PK

# Update treasury address (Owner only)
cast send $FEE_ROUTER "setTreasury(address)" $NEW_TREASURY \
  --rpc-url $BASE_RPC --private-key $OWNER_PK
```

## Dependencies

- **LayerZero V2**: Cross-chain messaging protocol
- **Doppler Airlock**: Token launch mechanism
- **OpenZeppelin**: Access control and security utilities
- **Uniswap V3**: WETH/HLG swapping on Ethereum

## Quick Reference

### Common Tasks

```bash
# Check system status
forge script script/KeeperPullAndBridge.s.sol --sig "checkBalances()" --rpc-url $BASE_RPC

# Manual fee collection
forge script script/KeeperPullAndBridge.s.sol --rpc-url $BASE_RPC --broadcast --private-key $KEEPER_PK

# Emergency pause
forge script script/KeeperPullAndBridge.s.sol --sig "emergencyPause()" --rpc-url $BASE_RPC --broadcast --private-key $OWNER_PK

# Check FeeRouter ETH balance
cast balance $FEE_ROUTER --rpc-url $BASE_RPC

# Check if Airlock is whitelisted
cast call $FEE_ROUTER "trustedAirlocks(address)" $AIRLOCK_ADDRESS --rpc-url $BASE_RPC

# Grant keeper role
cast send $FEE_ROUTER "grantRole(bytes32,address)" $(cast keccak "KEEPER_ROLE") $KEEPER_ADDRESS --rpc-url $BASE_RPC --private-key $OWNER_PK
```

### Monitoring

- **FeeRouter Balance**: Should accumulate fees between keeper runs
- **Trusted Airlocks**: Must be whitelisted before fee collection
- **LayerZero Messages**: Monitor cross-chain message delivery
- **HLG Distribution**: Verify burn/stake operations on Ethereum

### Troubleshooting

- **"UntrustedSender" Error**: Airlock not whitelisted - run `setupTrustedAirlocks()`
- **"AccessControl" Error**: Address missing KEEPER_ROLE or owner permissions
- **Bridge Failures**: Check LayerZero trusted remotes configuration
- **Low HLG Output**: Adjust slippage protection or check Uniswap liquidity

## License

MIT
