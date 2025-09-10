# Holograph Protocol Rewards Bootstrap Strategy

## Overview

I propose we launch HLG staking rewards with a manual operational model instead of our full automated cross-chain infrastructure. This gets us to market faster with the same economic outcomes while drastically reducing technical complexity.

**Epoch-Based Protection**: The staking pool now implements 7-day epochs to prevent sandwich attacks and ensure fair reward distribution:
- Weekly epochs (7 days duration)
- Stakes and compounded rewards activate next epoch
- Withdrawals finalize next epoch  
- Distributions can be done while paused for MEV protection

## Why Bootstrap?

Our full protocol design requires:
- Cross-chain messaging via LayerZero V2
- Automated Uniswap V3 swaps in smart contracts
- Complex fee routing across Base and Ethereum
- Extensive audits across multiple contracts

The bootstrap approach achieves the same result with:
- Manual weekly operations (30 minutes)
- Existing bridge and DEX infrastructure  
- Enhanced StakingRewards with epoch protection
- Minimal audit scope

## Process Flow

```mermaid
flowchart TD
    %% Base Chain
    ZX[0x Protocol Trading] --> |Weekly Fees| MS[Multisig on Base]
    MS --> |50%| TR[Treasury]
    MS --> |50% Direct Bridge| BR[Bridge to Ethereum]
    
    %% Ethereum Chain Operations
    BR --> ETHMS[Multisig on Ethereum]
    ETHMS --> |Swap via Uniswap| HLG[HLG Tokens]
    HLG --> |depositAndDistribute| SR[StakingRewards]
    
    %% Distribution (configurable percentages)
    SR --> |X%| BURN[Burn to address 0]
    SR --> |(100-X)%| STAKE[Accrue to Current Epoch]
    
    style MS fill:#fff3e0
    style ETHMS fill:#fff3e0
    style SR fill:#e8f5e8
    style BURN fill:#ffebee
    style STAKE fill:#c8e6c9
```

## Technical Implementation

### Core Distribution Function

The StakingRewards contract includes:

```solidity
function depositAndDistribute(uint256 hlgAmount) external onlyOwner {
    hlg.transferFrom(msg.sender, address(this), hlgAmount);
    
    uint256 burnAmount = (hlgAmount * burnBps) / 10_000;
    uint256 rewardAmount = hlgAmount - burnAmount;
    
    hlg.transfer(address(0), burnAmount);
    _distributeRewards(rewardAmount);
    
    emit HLGDeposited(hlgAmount, burnAmount, rewardAmount);
}
```

### Epoch Protection Mechanism

```solidity
// Epochs advance automatically when any user interaction occurs
function _advanceEpoch() internal {
    uint256 currentEpoch = (block.timestamp - epochStartTime) / EPOCH_DURATION;
    if (currentEpoch > lastProcessedEpoch) {
        // Process scheduled additions and removals
        _processScheduledChanges();
        lastProcessedEpoch = currentEpoch;
        emit EpochAdvanced(currentEpoch);
    }
}
```

Key epoch features:
- **Activation Delay**: New stakes become eligible in epoch N+1
- **Withdrawal Delay**: Unstake requests finalize in epoch N+1
- **Compounding Schedule**: Auto-compounded rewards activate next epoch
- **MEV Protection**: No same-block sandwich attacks possible

## Weekly Operations

### Standard Process

1. **Collect fees on Base** (from 0x protocol trading)
2. **Execute multisig**: 50% to treasury, 50% bridge to Ethereum
3. **From Ethereum multisig**: Swap ETH → HLG on Uniswap V3
4. **Optional: Pause StakingRewards** (for private mempool distribution)
5. **Call `depositAndDistribute(hlgAmount)`** (works while paused)
6. **Optional: Unpause StakingRewards**
7. **Verify burn and distribution events**

Total time: ~30 minutes per week.

### Epoch Timing Considerations

- **Distribution Timing**: Can distribute anytime during the epoch
- **Eligible Set**: Only users who were eligible at epoch start participate
- **Maturity**: Rewards from epoch N mature and become claimable in epoch N+1
- **Compounding**: Auto-compounded rewards increase eligibility in N+1

### Operational Notes

- Distributions accrue to the current epoch's reward index
- The eligible total is fixed at epoch boundaries
- Late epoch distributions still distribute fairly to all eligible users
- Pausing is optional but recommended for MEV protection
- On first unpause, `EpochInitialized(startTime)` is emitted

## Migration Path

### Phase 1: Bootstrap Launch (Current)
- Manual weekly operations
- Epoch-based protection active
- Monitor user adoption and feedback

### Phase 2: Validate Product-Market Fit
- Analyze staking metrics
- Gather user feedback
- Adjust parameters if needed

### Phase 3: Full Automation (Future)
1. Deploy the full automated protocol
2. Audit the complete cross-chain infrastructure
3. Gradually transition from manual to automated operations
4. Preserve all staking history and balances

### Migration Process

When ready to migrate to a new pool:
1. Deploy epoch-enabled pool
2. Pause old pool
3. Optional: Seed stakes via `stakeFor` (paused-only) for batch migration
4. Unpause to start epochs
5. Communicate migration window for self-service users

## Benefits vs Full Protocol

### Bootstrap Advantages
- **Ship immediately** with minimal contract changes
- **Test tokenomics** with real users and real value
- **Adjust parameters** based on market feedback
- **Minimal audit requirements** (single contract function)
- **Epoch protection** prevents sandwich attacks
- **MEV resistant** distribution mechanism

### Full Protocol (Later)
- **Fully automated** cross-chain operations
- **No manual intervention** required
- **Scale** to handle any volume
- **Complex integrations** with LayerZero and Uniswap

## Security Considerations

### Epoch-Based Security
- **No sandwich attacks**: Activation delay prevents same-block exploitation
- **Fair distribution**: All eligible users treated equally per epoch
- **Predictable rewards**: Users know their share before distributions
- **MEV protection**: Optional pause during distribution

### Operational Security
- **Multisig control**: All operations require multiple signatures
- **Private mempool**: Distributions can use Flashbots for privacy
- **Event monitoring**: All actions emit events for transparency
- **Accounting checks**: System detects and reports any discrepancies

## Economic Model

### Distribution Split (Configurable)
- **Burn**: X% (default 50%) - Deflationary pressure
- **Staking Rewards**: (100-X)% - Incentivize long-term holding
- **Auto-compound**: Rewards automatically increase stake

### Epoch Economics
- **Weekly cycles**: Align with operational schedule
- **Compound delay**: Prevents recursive reward farming
- **Stable APR**: Predictable returns for stakers

## Telemetry and Monitoring

### Key Events
```solidity
event EpochInitialized(uint256 startTime);
event EpochAdvanced(uint256 newEpoch);
event HLGDeposited(uint256 total, uint256 burned, uint256 distributed);
event AccountingError(uint256 eligibleBefore, uint256 removals);
```

### Monitoring Points
- Weekly distribution amounts
- Burn rate tracking
- Staker participation metrics
- Epoch transition timing
- Gas costs per operation

## Recommendation

Let's start with the bootstrap approach enhanced with epoch protection. We can validate demand for HLG staking rewards without the complexity of cross-chain automation, while maintaining security against sandwich attacks and MEV.

The economics are identical to the full protocol - users get the same rewards whether we automate or operate manually. The epoch system ensures fairness regardless of operational model. The only difference is 30 minutes of our time each week until we're ready to scale.

## Appendix: Epoch Timing Examples

### Example Timeline
```
Epoch 0 (Days 0-6):
  Day 0: Alice stakes 1000 HLG (scheduled for Epoch 1)
  Day 3: Distribution of 100 HLG (no effect, eligibleTotal = 0)
  Day 6: Bob stakes 1000 HLG (scheduled for Epoch 1)

Epoch 1 (Days 7-13):
  Day 7: Alice activated (eligible = 1000)
         Bob activated (eligible = 1000)
  Day 9: Distribution of 100 HLG (50 to each staker, matures Epoch 2)
  Day 10: Charlie stakes 1000 HLG (scheduled for Epoch 2)

Epoch 2 (Days 14-20):
  Day 14: Alice's rewards mature (auto-compounds to 1050)
          Bob's rewards mature (auto-compounds to 1050)
          Charlie activated (eligible = 1000)
  Day 16: Distribution of 150 HLG (50 to Alice, 50 to Bob, 50 to Charlie)
```

This demonstrates how the epoch system ensures fair distribution while preventing exploitation.
