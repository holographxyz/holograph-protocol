# Referral Reward Batch Operations Guide

## Overview

This guide documents the operational procedures for executing the referral waitlist reward distribution using the batch staking functionality in the StakingRewards contract.

## Gas Cost Analysis

### Gas Cost Analysis Tool

The protocol includes a single, focused gas analysis tool that provides real-time cost optimization:

**Gas Analysis** (`make gas-analysis`):
- Fetches live ETH/USD prices from Chainlink mainnet oracle
- Tests gas consumption via mainnet fork testing
- Dynamically determines optimal batch size (typically 500 users)
- Provides essential cost information: total cost in ETH and USD

### Gas Cost Analysis Results

**Current Measurements:**
- **Gas per user**: ~1,139 gas (measured via mainnet fork)
- **Optimal batch size**: 500 users per batch
- **Total gas for 5,000 users**: 5,695,000 gas
- **Total batches needed**: 10 batches

### Live Cost Analysis (5,000 users)

**Real-Time Cost Analysis** (Live ETH Price via Chainlink):

| Gas Price | Total ETH Cost | Total USD Cost | Cost Per User |
|-----------|----------------|----------------|---------------|
| 0.2 gwei  | 0.001 ETH      | $4.18          | $0.0008       |
| 0.5 gwei  | 0.003 ETH      | $10.45         | $0.002        |
| 1 gwei    | 0.006 ETH      | $20.89         | $0.004        |
| 2 gwei    | 0.011 ETH      | $41.79         | $0.008        |
| 5 gwei    | 0.028 ETH      | $104.48        | $0.02         |
| 10 gwei   | 0.057 ETH      | $208.96        | $0.04         |

**Important**: These are **ETH gas costs only** for executing batch transactions. They do NOT include the HLG tokens being distributed to users. Live ETH price via Chainlink oracle. Gas measurements via mainnet fork testing.

### Execution Strategy

**Optimal Execution Windows:**
- **Best**: Weekends Saturday/Sunday 2-6 AM UTC (0.2-0.5 gwei typical)
- **Good**: Weekdays Tuesday-Thursday 3-5 AM UTC (0.5-1 gwei)  
- **Avoid**: High-activity periods (5+ gwei)
- **Target gas price**: 0.2-1 gwei for optimal costs

**Real-Time Monitoring:**
1. Run `make gas-analysis` before execution for current costs
2. Monitor https://etherscan.io/gastracker for live gas prices
3. Set alerts on Blocknative for <1 gwei notifications
4. Check current ETH price impact on total costs

**Cost Optimization:**
- **Very low gas environment** makes execution extremely cost-effective
- **Target 0.2-1 gwei** for optimal execution costs
- Share gas analysis output with team for approval before execution
- Remember: Gas costs are only for transaction execution, not HLG token distribution

## Pre-Execution Checklist

### 1. Contract Preparation
- [ ] Deploy StakingRewards contract with owner address
- [ ] Verify contract is paused (starts paused by default)
- [ ] Verify HLG token address is correctly set
- [ ] Set FeeRouter address if needed

### 2. CSV Preparation
- [ ] Export referral data from waitlist system
- [ ] Format: `address,amount` (amounts in whole HLG, no decimals)
- [ ] Validate no duplicate addresses
- [ ] Verify no user exceeds 780,000 HLG cap
- [ ] Confirm total allocation ≤ 250M HLG

### 3. HLG Token Preparation
- [ ] Transfer required HLG to deployer wallet
- [ ] Add 0.1% buffer for gas variations
- [ ] Verify deployer has enough ETH for gas

### 4. Environment Setup
```bash
# Create .env file
PRIVATE_KEY=0x...
STAKING_REWARDS=0x...
HLG_TOKEN=0x...
REFERRAL_CSV_PATH=./referral_data.csv
```

## Execution Procedures

### Step 1: Generate Sample Data (Testing)
```bash
forge script script/ProcessReferralCSV.s.sol:GenerateSampleCSV \
  --sig "run()" \
  -vvv
```

### Step 2: Validate CSV Data
```bash
# Dry run to validate without broadcasting
forge script script/ProcessReferralCSV.s.sol:ProcessReferralCSV \
  --sig "run()" \
  --fork-url $ETH_RPC_URL \
  -vvv
```

### Step 3: Run Gas Analysis
```bash
# Run gas cost analysis
make gas-analysis

# This provides:
# - Current ETH price via Chainlink oracle
# - Gas per user measurement via mainnet fork
# - Total cost in ETH and USD across different gas price scenarios
# - Optimal batch size and execution plan
```

### Step 4: Monitor Gas Prices
- Check https://etherscan.io/gastracker
- Set alerts on Blocknative for < 5 gwei
- Use gas analysis tools to determine optimal execution timing
- Use Flashbots RPC to avoid MEV: https://rpc.flashbots.net

### Step 5: Execute Batch Staking
```bash
# When gas is favorable, execute with broadcast
forge script script/ProcessReferralCSV.s.sol:ProcessReferralCSV \
  --sig "run()" \
  --fork-url $ETH_RPC_URL \
  --broadcast \
  --verify \
  --gas-price 1gwei \
  -vvv
```

### Step 6: Post-Execution Verification
1. Verify all batches completed successfully
2. Check a sample of user balances
3. Verify total staked matches expected amount
4. Document actual gas used and costs

## Batch Execution Details

For 5,000 users (with dynamically optimized batch size):
- **Total batches**: 10 (at 500 users/batch)
- **Batch breakdown**:
  - Batches 1-10: 500 users each
- **Estimated time**: 15-20 minutes total
- **Time between batches**: 2-3 minutes for confirmation

### Batch Schedule (Dynamic Optimization)
| Batch | User Range  | Size | Cumulative |
|-------|-------------|------|------------|
| 1     | 0-499       | 500  | 500        |
| 2     | 500-999     | 500  | 1,000      |
| 3     | 1000-1499   | 500  | 1,500      |
| 4     | 1500-1999   | 500  | 2,000      |
| 5     | 2000-2499   | 500  | 2,500      |
| 6     | 2500-2999   | 500  | 3,000      |
| 7     | 3000-3499   | 500  | 3,500      |
| 8     | 3500-3999   | 500  | 4,000      |
| 9     | 4000-4499   | 500  | 4,500      |
| 10    | 4500-4999   | 500  | 5,000      |

*Batch sizes are dynamically optimized by the gas analysis tools. The above shows typical optimization results.*

## Emergency Procedures

### If Batch Fails
1. Note the last successful batch index
2. Fix the issue (gas price spike, network congestion)
3. Resume from the failed batch using startIndex parameter
4. Verify no users were double-initialized

### If Wrong Amounts Distributed
1. Contract is paused - users cannot unstake yet
2. Deploy new StakingRewards contract
3. Re-execute batch staking with correct amounts
4. Update FeeRouter to point to new contract

## Post-Launch Operations

1. **Unpause Contract**: After all batches complete successfully
2. **Monitor Initial Claims**: Watch for users unstaking
3. **Verify Rewards**: Ensure future rewards distribute correctly
4. **Document Results**: Record actual gas costs and any issues

## Security Considerations

- **Private Key Security**: Use hardware wallet or secure key management
- **Transaction Monitoring**: Watch each batch for anomalies
- **Verification**: Always dry-run before broadcasting
- **Backup Plan**: Have contingency contract ready if issues arise

## Cost Optimization Tips

1. **Use Gas Tokens**: If available, use CHI or GST2 for additional savings
2. **Flashbots Bundle**: Group transactions to ensure atomic execution
3. **Weekend Execution**: Consistently lowest gas prices
4. **Gas Price Alerts**: Set multiple alerts at different thresholds
5. **Prepare Everything**: Have all transactions ready to execute quickly

## Reporting Template

```markdown
## Referral Distribution Report

**Date**: [Date]
**Executor**: [Address]
**Total Users**: 5,000
**Total HLG Distributed**: [Amount]

### Gas Costs
- Gas Price Used: [X] gwei
- Total Gas Used: [Amount]
- Total ETH Cost: [Amount]
- Total USD Cost: $[Amount]
- Cost Per User: $[Amount]

### Execution Timeline
- Start Time: [Time]
- End Time: [Time]  
- Total Duration: [Minutes]

### Issues Encountered
[List any issues]

### Verification
- [ ] All users initialized correctly
- [ ] Total staked matches expected
- [ ] No duplicate initializations
- [ ] Contract unpaused successfully
```

This completes the operational guide for the referral reward batch distribution system.