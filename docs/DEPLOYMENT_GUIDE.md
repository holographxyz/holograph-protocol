# Holograph Protocol Deployment Guide

## Overview

Holograph Protocol enables omnichain token creation with deterministic addresses across Ethereum, Base, and Unichain. The protocol uses a UUPS proxy pattern for the factory contract and EIP-1167 minimal proxy pattern for token deployments.

## Architecture

### Core Contracts

1. **HolographFactory** (UUPS Upgradeable)
   - Deploys omnichain ERC20 tokens via minimal proxy pattern
   - Integrates with Doppler Airlock for token launches
   - Manages token registry and fees

2. **HolographERC20** (Implementation)
   - Base implementation for all tokens
   - Supports pre-mints, vesting, and metadata
   - Currently without bridging (to be added in v2)

3. **FeeRouter** 
   - Collects protocol fees from Doppler Airlocks
   - Bridges fees cross-chain via LayerZero
   - Routes to treasury and staking rewards

4. **StakingRewards** (Ethereum only)
   - Receives HLG from fee burns
   - Distributes rewards to stakers

5. **HolographDeployer**
   - Singleton CREATE2 deployer for deterministic addresses
   - Ensures same addresses across all chains

## Deployment Process

### Prerequisites

1. Install dependencies:
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone repository and install
git clone <repo>
cd holograph-2.0
git submodule update --init --recursive
npm install
```

2. Configure environment:
```bash
cp .env.example .env
# Edit .env with your values:
# - Private keys
# - RPC URLs  
# - API keys
# - Protocol addresses
```

### Deployment Order

**Important**: Contracts can be deployed to any chain in any order thanks to deterministic addressing.

#### 1. Deploy to Base Sepolia (Testnet)

```bash
# Dry run first
make deploy-base-sepolia

# Deploy with broadcast
BROADCAST=true make deploy-base-sepolia
```

This deploys:
- HolographDeployer (if not exists)
- HolographERC20 implementation
- HolographFactory implementation
- HolographFactory proxy
- FeeRouter

#### 2. Deploy to Ethereum Sepolia (Testnet)

```bash
# Dry run
make deploy-eth-sepolia

# Deploy with broadcast
BROADCAST=true make deploy-eth-sepolia
```

This deploys:
- HolographDeployer (if not exists)
- StakingRewards
- FeeRouter

#### 3. Deploy to Unichain Sepolia (Testnet)

```bash
# Dry run
make deploy-unichain-sepolia

# Deploy with broadcast
BROADCAST=true make deploy-unichain-sepolia
```

This deploys:
- HolographDeployer (if not exists)
- HolographERC20 implementation
- HolographFactory implementation
- HolographFactory proxy

### Mainnet Deployment

Replace `-sepolia` with mainnet targets:

```bash
# Base Mainnet
BROADCAST=true make deploy-base

# Ethereum Mainnet  
BROADCAST=true make deploy-eth

# Unichain Mainnet
BROADCAST=true make deploy-unichain
```

### Verify Deployment

After deploying to multiple chains:

```bash
make verify-addresses
```

This checks:
- All contracts deployed successfully
- Addresses are consistent across chains
- No configuration mismatches

## Configuration

### 1. Cross-Chain Setup

After deployment, configure LayerZero trusted remotes:

```bash
# Configure Base
BROADCAST=true make configure-base

# Configure Ethereum
BROADCAST=true make configure-eth  

# Configure Unichain
BROADCAST=true make configure-unichain
```

The Configure script:
- Sets trusted remote addresses for FeeRouter
- Configures cross-chain messaging paths
- Validates endpoint settings

### 2. Factory Authorization

Set Doppler Airlock authorization on each factory:

```solidity
// Via script or direct call
factory.setAirlockAuthorization(dopplerAirlock, true);
```

### 3. Fee Router Setup

Configure trusted factories and airlocks:

```solidity
// Trust the factory
feeRouter.setTrustedFactory(factoryProxy, true);

// Trust Doppler Airlock
feeRouter.setTrustedAirlock(dopplerAirlock, true);
```

### 4. Staking Rewards (Ethereum only)

Update StakingRewards to use deployed FeeRouter:

```solidity
stakingRewards.setFeeRouter(feeRouterAddress);
```

## Upgrade Procedures

### Factory Upgrade (UUPS Pattern)

The HolographFactory uses UUPS proxy pattern for upgrades:

1. **Deploy new implementation**:
```solidity
// Deploy new factory implementation
HolographFactory newImpl = new HolographFactory(erc20Implementation);
```

2. **Prepare upgrade**:
```solidity
// Only owner can upgrade
factory.upgradeToAndCall(
    address(newImpl),
    "" // or initialization data if needed
);
```

3. **Verify upgrade**:
```bash
# Check implementation address changed
cast call $FACTORY_PROXY "implementation()(address)"
```

### Token Implementation Updates

For new token features (e.g., adding bridging):

1. **Deploy new HolographERC20 implementation**:
```solidity
HolographERC20 newERC20Impl = new HolographERC20();
```

2. **Deploy new factory pointing to new implementation**:
```solidity
HolographFactory newFactory = new HolographFactory(address(newERC20Impl));
```

3. **Upgrade factory to new implementation**:
```solidity
factory.upgradeToAndCall(address(newFactory), "");
```

**Note**: Existing tokens keep their current implementation. Only new tokens use the updated implementation.

### Emergency Procedures

1. **Pause Operations**:
   - Factory: Transfer ownership to multisig
   - FeeRouter: Use keeper role restrictions

2. **Upgrade Path**:
   - Deploy fixes
   - Test on testnet
   - Upgrade via multisig

## Operational Procedures

### Keeper Operations

Run keeper to collect and bridge fees:

```bash
# Collect fees from Airlocks and bridge to Ethereum
BROADCAST=true make keeper
```

The keeper:
1. Pulls fees from Doppler Airlocks
2. Bridges collected fees to Ethereum
3. Burns HLG portion for staking rewards
4. Sends treasury portion to treasury address

### Token Creation

Users create tokens through the factory:

```typescript
// Using create-token.ts utility
npm run create-token

// Or direct contract call
factory.createToken({
    name: "Token Name",
    symbol: "TKN",
    initialSupply: 1000000e18,
    recipient: deployer,
    owner: deployer,
    yearlyMintRate: 200, // 2%
    vestingDuration: 365 days,
    recipients: [],
    amounts: [],
    tokenURI: "https://..."
});
```

### Monitoring

Track deployment addresses in:
- `deployments/base/` - Base mainnet
- `deployments/base-sepolia/` - Base testnet
- `deployments/ethereum/` - Ethereum mainnet
- `deployments/ethereum-sepolia/` - Ethereum testnet
- `deployments/unichain/` - Unichain mainnet
- `deployments/unichain-sepolia/` - Unichain testnet

## Security Considerations

1. **Deployment Security**:
   - Use hardware wallets for mainnet deployments
   - Verify all addresses before configuration
   - Test thoroughly on testnets first

2. **Upgrade Security**:
   - Use multisig for factory ownership
   - Time-lock upgrades when possible
   - Audit new implementations

3. **Operational Security**:
   - Limit keeper permissions
   - Monitor for unusual activity
   - Have emergency pause procedures

## Troubleshooting

### Common Issues

1. **Deployment fails with "contract too large"**:
   - Contracts are already optimized with proxy patterns
   - Check compilation settings in foundry.toml

2. **Different addresses across chains**:
   - Ensure using same deployer private key
   - Check HolographDeployer is at same address
   - Verify salt generation is consistent

3. **Configuration transaction fails**:
   - Ensure contracts are deployed first
   - Check owner/role permissions
   - Verify chain IDs and endpoints

### Debug Commands

```bash
# Check deployment sizes
forge build --sizes

# Verify contract at address
cast code $ADDRESS

# Check proxy implementation
cast call $PROXY "implementation()(address)"

# Get factory owner
cast call $FACTORY "owner()(address)"
```

## Support

For issues or questions:
- Review test files in `test/` for examples
- Check `script/` for deployment patterns
- Open issues on GitHub