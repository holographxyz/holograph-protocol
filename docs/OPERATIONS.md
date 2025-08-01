# Holograph Protocol Operations

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

**Fee Flow**: Doppler → Airlock → FeeRouter (50% protocol, 50% treasury) → LayerZero → Ethereum → WETH/HLG swap → 50% burn, 50% stake

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
  $AIRLOCK $TOKEN $AMOUNT --private-key $OWNER_PK

# Bridge to Ethereum (owner-only) 
cast send $FEE_ROUTER "bridge(uint256,uint256)" 200000 0 \
  --private-key $OWNER_PK --rpc-url $BASE_RPC
```

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

## Configuration Management

### Treasury Updates
```bash
# Update treasury address (owner-only)
cast send $FEE_ROUTER "setTreasury(address)" $NEW_TREASURY \
  --private-key $OWNER_PK --rpc-url $BASE_RPC
```

### Airlock Management  
```bash
# Authorize new airlock (owner-only)
cast send $BASE_FEE_ROUTER "setTrustedAirlock(address,bool)" $AIRLOCK true \
  --private-key $OWNER_PK --rpc-url $BASE_RPC

# Authorize factory for airlock
cast send $FACTORY "setAirlockAuthorization(address,bool)" $AIRLOCK true \
  --private-key $OWNER_PK --rpc-url $BASE_RPC
```

### Protocol Fee Updates
```bash
# Update protocol fee percentage (owner-only, basis points)
cast send $FEE_ROUTER "setHolographFee(uint16)" 5000 \
  --private-key $OWNER_PK --rpc-url $BASE_RPC
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
cast send $FEE_ROUTER "rescueDust(address,uint256)" 0x0 $AMOUNT \
  --private-key $OWNER_PK

# Recover stuck ERC20 (owner-only)  
cast send $FEE_ROUTER "rescueDust(address,uint256)" $TOKEN $AMOUNT \
  --private-key $OWNER_PK
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
OWNER_PK=0x...           # Contract administration
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