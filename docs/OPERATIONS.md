# HOLOGRAPH PROTOCOL OPERATIONS

Technical guide for operating deployed Holograph contracts.

## System Architecture

```
Base Chain                  LayerZero V2               Ethereum Chain
┌─────────────────┐        ┌─────────────┐           ┌─────────────────┐
│ Doppler Airlock │───────▶│   Message   │──────────▶│ FeeRouter       │
│       ↓         │        │   Passing   │           │       ↓         │
│ HolographFactory│        │   (Fees)    │           │ Uniswap Swap    │
│       ↓         │        │             │           │       ↓         │
│ FeeRouter       │───────▶│             │           │ HLG Burn/Stake  │
└─────────────────┘        └─────────────┘           └─────────────────┘
```

**Fee Flow**: Doppler → Airlock → FeeRouter (50% protocol, 50% treasury) → LayerZero → Ethereum → WETH/HLG swap → configurable burn/stake split

## Bootstrap Strategy

For initial launch, use manual operations instead of automated cross-chain infrastructure. This gets to market faster with same economic outcomes.

### Process Flow
1. **Base Chain**: Multisig collects 0x Protocol trading fees weekly
2. **Split**: 50% treasury, 50% bridge to Ethereum
3. **Ethereum**: Multisig swaps ETH → HLG on Uniswap V3
4. **Distribute**: Call `depositAndDistribute()` on StakingRewards
5. **Outcome**: Configurable burn/stake split (default 50/50)

**Time Required**: ~30 minutes per week

### Bootstrap to Full Protocol Migration
Once validated, deploy full automated protocol while preserving all staking history and balances.

## Fee Collection (Owner Operations)

### Automated Operations (Recommended)
```bash
# Complete fee processing workflow (collect + bridge)
make fee-ops BROADCAST=true

# Individual operations
make fee-collect BROADCAST=true    # Collect from all Airlocks
make fee-bridge BROADCAST=true     # Bridge to Ethereum
make fee-status                    # Check system status
```

### Manual Operations
```bash
# Monitor airlock balances
cast call $AIRLOCK "getIntegratorFees(address,address)" $FEE_ROUTER $TOKEN

# Collect fees (owner-only)
cast send $FEE_ROUTER "collectAirlockFees(address,address,uint256)" \
  $AIRLOCK $TOKEN $AMOUNT --private-key $PRIVATE_KEY

# Bridge to Ethereum (owner-only)
cast send $FEE_ROUTER "bridge(uint256,uint256)" 200000 0 \
  --private-key $PRIVATE_KEY --rpc-url $BASE_RPC
```

## Manual Multisig Fee Flow (Bootstrap)

### Step 1: Bridge ETH from Base to Ethereum

**Recommended**: Use Superbridge (https://superbridge.app)
- Connect multisig via WalletConnect
- Select Base → Ethereum, enter amount
- Bridge fees: ~$2-5, arrival: ~10-20 minutes

**Alternative Bridges**:
- Official Base Bridge (bridge.base.org): 7 days, most secure
- Relay Bridge (relay.link): 2-3 min, higher fees

### Step 2: Convert ETH to HLG

**Option A**: Use multisig CLI (generates Transaction Builder JSON)
```bash
npx tsx script/ts/multisig-cli.ts batch --eth 0.5
```

**Option B**: Manual via Uniswap
1. Wrap ETH → WETH at app.uniswap.org
2. Swap WETH → HLG (check slippage)
3. Call `depositAndDistribute()` on StakingRewards

## Referral Batch Operations

### Pre-Execution Setup
```bash
# Environment variables
PRIVATE_KEY=0x...
STAKING_REWARDS=0x...
HLG_TOKEN=0x...
REFERRAL_CSV_PATH=./referral_data.csv
REFERRAL_RESUME_INDEX=0    # Resume from specific index if needed
```

### Gas Cost Analysis
```bash
# Run before execution for current costs
make gas-analysis
```

### Execution
```bash
# Dry run validation
forge script script/ProcessReferralCSV.s.sol --fork-url $ETH_RPC_URL -vv

# Execute (monitor gas prices first)
BROADCAST=true forge script script/ProcessReferralCSV.s.sol --broadcast --private-key $PRIVATE_KEY
```

**CSV Format**: `address,amount` (amounts in whole HLG, no decimals)
**Constraints**: No duplicates, max 780K HLG per user, max 250M total

## System Monitoring

### Critical Balances
```bash
# FeeRouter ETH balance (Base)
cast balance $BASE_FEE_ROUTER --rpc-url $BASE_RPC

# FeeRouter ETH balance (Ethereum)  
cast balance $ETH_FEE_ROUTER --rpc-url $ETH_RPC

# HLG staking rewards
cast call $STAKING_REWARDS "totalStaked()" --rpc-url $ETH_RPC
```

### Health Checks
```bash
# Verify trusted remotes
cast call $BASE_FEE_ROUTER "trustedRemotes(uint32)" 30101 --rpc-url $BASE_RPC
cast call $ETH_FEE_ROUTER "trustedRemotes(uint32)" 30184 --rpc-url $ETH_RPC

# Check airlock authorization  
cast call $BASE_FEE_ROUTER "trustedAirlocks(address)" $AIRLOCK --rpc-url $BASE_RPC

# Verify DVN configuration
# Visit https://layerzeroscan.com/address/[FEE_ROUTER_ADDRESS]
```

## StakingRewards Operations (Ethereum Only)

### Owner Actions

```bash
# NOTE: During bootstrap phase, use EOA with PRIVATE_KEY
# After multisig handoff, use multisig-cli for Safe transactions

# Emergency controls (available via multisig-cli)
npx tsx script/ts/multisig-cli.ts pause           # Pause staking operations
npx tsx script/ts/multisig-cli.ts unpause         # Resume staking operations

# Administrative functions (currently require cast)
# TODO: Add these to multisig-cli for post-handoff operations
cast send $STAKING_REWARDS "setFeeRouter(address)" $NEW_FEE_ROUTER --private-key $PRIVATE_KEY --rpc-url $ETH_RPC
cast send $STAKING_REWARDS "setBurnPercentage(uint256)" 5000 --private-key $PRIVATE_KEY --rpc-url $ETH_RPC
cast send $STAKING_REWARDS "setStakingCooldown(uint256)" 604800 --private-key $PRIVATE_KEY --rpc-url $ETH_RPC
```

### Monitoring & Health Checks

```bash
# Core metrics
cast call $STAKING_REWARDS "totalStaked()" --rpc-url $ETH_RPC         # Total HLG staked
cast call $STAKING_REWARDS "totalStakers()" --rpc-url $ETH_RPC        # Number of stakers
cast call $STAKING_REWARDS "unallocatedRewards()" --rpc-url $ETH_RPC  # Pending distribution
cast call $STAKING_REWARDS "globalRewardIndex()" --rpc-url $ETH_RPC   # Reward accumulation

# Configuration
cast call $STAKING_REWARDS "owner()" --rpc-url $ETH_RPC               # Contract owner
cast call $STAKING_REWARDS "paused()" --rpc-url $ETH_RPC              # Paused state
cast call $STAKING_REWARDS "feeRouter()" --rpc-url $ETH_RPC           # Reward source
cast call $STAKING_REWARDS "burnPercentage()" --rpc-url $ETH_RPC      # Burn rate (bps)
cast call $STAKING_REWARDS "stakingCooldown()" --rpc-url $ETH_RPC     # Cooldown period

# Contract balances
cast call $HLG "balanceOf(address)" $STAKING_REWARDS --rpc-url $ETH_RPC  # HLG balance
cast call $STAKING_REWARDS "getExtraTokens()" --rpc-url $ETH_RPC         # Surplus tokens
```

### Recovery Operations (Owner Only)

```bash
# NOTE: Recovery operations require multisig execution after bootstrap
# TODO: Add these recovery functions to multisig-cli for post-handoff operations

# Recover surplus HLG tokens (not part of staking accounting)
cast send $STAKING_REWARDS "recoverExtraHLG(address,uint256)" $RECIPIENT $AMOUNT --private-key $PRIVATE_KEY --rpc-url $ETH_RPC

# Recover non-HLG tokens accidentally sent to contract
cast send $STAKING_REWARDS "recoverToken(address,address,uint256)" $TOKEN $RECIPIENT $AMOUNT --private-key $PRIVATE_KEY --rpc-url $ETH_RPC

# Reclaim unallocated rewards (only when no active stakers)
cast send $STAKING_REWARDS "reclaimUnallocatedRewards(address)" $RECIPIENT --private-key $PRIVATE_KEY --rpc-url $ETH_RPC
```

### Emergency Procedures

```bash
# Emergency pause (stops new staking, allows unstaking)
# During bootstrap: use PRIVATE_KEY with EOA
# After handoff: use multisig-cli for Safe transactions
npx tsx script/ts/multisig-cli.ts pause

# Users can still emergency exit even when paused
# (Users call: cast send $STAKING_REWARDS "emergencyExit()" --private-key $USER_PK)
```

### Upgrade Operations

```bash
# Deploy new implementation
forge script script/UpgradeStakingRewards.s.sol --fork-url $ETH_RPC  # Dry run
BROADCAST=true forge script script/UpgradeStakingRewards.s.sol --broadcast --private-key $PRIVATE_KEY

# Manual upgrade (if script fails)
# NOTE: Upgrade operations require multisig execution after bootstrap
# TODO: Add upgrade functionality to multisig-cli for post-handoff operations
cast send $STAKING_REWARDS "upgradeToAndCall(address,bytes)" $NEW_IMPL "0x" --private-key $PRIVATE_KEY --rpc-url $ETH_RPC
```

## Configuration Management

### Treasury Updates
```bash
# Update treasury address (owner-only)
# NOTE: Configuration changes require multisig execution after bootstrap
cast send $FEE_ROUTER "setTreasury(address)" $NEW_TREASURY \
  --private-key $PRIVATE_KEY --rpc-url $BASE_RPC
```

### Airlock Management  
```bash
# Authorize new airlock (owner-only)
# NOTE: Airlock management requires multisig execution after bootstrap
cast send $BASE_FEE_ROUTER "setTrustedAirlock(address,bool)" $AIRLOCK true \
  --private-key $PRIVATE_KEY --rpc-url $BASE_RPC

# Authorize factory for airlock
cast send $FACTORY "setAirlockAuthorization(address,bool)" $AIRLOCK true \
  --private-key $PRIVATE_KEY --rpc-url $BASE_RPC
```

### Protocol Fee Updates
```bash
# Update protocol fee percentage (owner-only, basis points)
# NOTE: Fee updates require multisig execution after bootstrap
cast send $FEE_ROUTER "setHolographFee(uint16)" 5000 \
  --private-key $PRIVATE_KEY --rpc-url $BASE_RPC
```

## Emergency Procedures

### Pause Operations
```bash
# No pause functionality in current contracts
# Emergency: Update treasury to multisig for manual control
```

### Dust Recovery
```bash
# Recover stuck ETH (owner-only)
# NOTE: Dust recovery requires multisig execution after bootstrap
cast send $FEE_ROUTER "rescueDust(address,uint256)" 0x0 $AMOUNT \
  --private-key $PRIVATE_KEY

# Recover stuck ERC20 (owner-only)
cast send $FEE_ROUTER "rescueDust(address,uint256)" $TOKEN $AMOUNT \
  --private-key $PRIVATE_KEY
```

## Key Contracts

### Base Mainnet
- **HolographFactory**: Upgradeable token factory (UUPS proxy)
- **FeeRouter**: Cross-chain fee routing and treasury split
- **HolographERC20**: Token implementation (for clones)

### Ethereum Mainnet  
- **FeeRouter**: Fee processing, WETH/HLG swaps, burn/stake
- **StakingRewards**: HLG staking with 7-day cooldown
- **HLG Token**: Reward and burn token

## Environment Variables

```bash
# Network RPCs
BASE_RPC_URL=https://mainnet.base.org
ETHEREUM_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/KEY

# Private Keys (role-separated)
PRIVATE_KEY=0x...        # Contract administration (bootstrap phase only)
DEPLOYER_PK=0x...        # Deployment only

# LayerZero Endpoints
BASE_LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c  
ETH_LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c

# Endpoint IDs
BASE_EID=30184           # Base mainnet
ETH_EID=30101            # Ethereum mainnet
```

## Troubleshooting

| Issue | Diagnosis | Solution |
|-------|-----------|----------|
| Fees not bridging | Check DVN configuration | Run `make configure-dvn-*` |
| Bridge failures | Trusted remotes not set | Run `make configure-*` |
| Low HLG output | Slippage/liquidity issue | Check Uniswap V3 pool |
| Access denied | Wrong role/ownership | Verify contract owner |

## Automation Setup

For production, implement monitoring for:
- Airlock fee accumulation above thresholds
- Failed cross-chain messages  
- HLG staking pool balance growth
- Treasury balance changes

Example monitoring script:
```bash
#!/bin/bash
# Monitor FeeRouter balances and alert if above threshold
BALANCE=$(cast balance $BASE_FEE_ROUTER --rpc-url $BASE_RPC)
if [ $BALANCE -gt 1000000000000000000 ]; then  # 1 ETH
  echo "FeeRouter balance high: $BALANCE wei"
  # Trigger fee collection/bridging
fi
```