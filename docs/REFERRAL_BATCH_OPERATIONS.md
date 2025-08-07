# Referral Reward Batch Operations Guide

## Overview

This guide documents the operational procedures for executing the referral waitlist reward distribution using the batch staking functionality in the StakingRewards contract.

## Gas Cost Analysis

### Production Gas Analysis Tools

The protocol now includes sophisticated gas analysis tools that provide real-time cost optimization:

#### Gas Analysis Scripts

**Understanding the Two Scripts:**

The protocol includes two complementary gas analysis scripts that serve different purposes:

1. **GasAnalysis** (`make gas-analysis`) - **MAIN PRODUCTION PLANNING TOOL**
   - **Purpose**: Production-ready cost estimation for large-scale distribution
   - **How it works**:
     - Fetches live ETH/USD prices from Chainlink mainnet oracle
     - Tests batch sizes (10-100 users) then scales up for production efficiency
     - Recommends **500 users/batch** for optimal production execution
   - **Current measurement**: 1,139 gas per user at scale
   - **Use this for**: Planning actual execution and sharing with stakeholders

2. **GasAnalysisLive** (`make gas-analysis-live`) - **VALIDATION TOOL**
   - **Purpose**: Conservative batch size validation with actual deployments
   - **How it works**:
     - Deploys real StakingRewards contract on mainnet fork
     - Tests exact gas consumption for small batches (10-50 users)
     - Recommends **50 users/batch** as conservative baseline
   - **Current measurement**: 1,578 gas per user for 50-user batches
   - **Use this for**: Validating gas estimates or if you prefer smaller, safer batches

3. **Combined Analysis** (`make gas-analysis-all`)
   - Runs both scripts with clear explanations
   - Provides complete context for decision-making
   - Best for sharing comprehensive analysis with team

### Real-Time Gas Measurements

**Latest Gas Measurements (Production Analysis):**

| Batch Size | Gas Per User | Efficiency | Recommendation |
|------------|--------------|------------|----------------|
| 10 users   | ~7,374       | Low        | Testing only   |
| 25 users   | ~3,190       | Medium     | Small campaigns|
| 50 users   | ~1,823       | Good       | Conservative   |
| 100 users  | ~1,139       | Excellent  | Test baseline  |
| **500 users** | **~1,139** | **Optimal** | **Production** |

- **Production recommendation**: 500 users/batch (scaled from 100-user test)
- **Conservative recommendation**: 50 users/batch (GasAnalysisLive result)
- **Dynamic optimization**: Scripts determine optimal size based on current conditions

### Live Cost Analysis (5,000 users)

**Real-Time Analysis Results** (Live ETH Price via Chainlink):

Based on optimized 500 users/batch (1,139 gas/user):

| Gas Price | Total ETH Cost | Total USD Cost | Cost Per User | Savings vs 30 gwei |
|-----------|----------------|----------------|---------------|-----------------|
| 1 gwei    | 0.006 ETH      | $20.88         | $0.00         | 96%             |
| 5 gwei    | 0.028 ETH      | $104.41        | $0.02         | 83%             |
| 10 gwei   | 0.057 ETH      | $208.82        | $0.04         | 66%             |
| 15 gwei   | 0.085 ETH      | $313.23        | $0.06         | 50%             |
| 30 gwei   | 0.171 ETH      | $626.47        | $0.12         | baseline        |
| 50 gwei   | 0.285 ETH      | $1,044.12      | $0.21         | -67%            |
| 100 gwei  | 0.570 ETH      | $2,088.25      | $0.42         | -233%           |

*Live ETH price via Chainlink oracle. Gas measurements via mainnet fork testing.

### Execution Strategy

**Script Recommendations Summary:**
- **GasAnalysis (Production)**: Use 500 users/batch for maximum efficiency
- **GasAnalysisLive (Conservative)**: Use 50 users/batch for safety
- **Hybrid Approach**: Start with 50 users/batch, increase if comfortable

**Optimal Execution Windows:**
- **Best**: Weekends Saturday/Sunday 2-6 AM UTC (1-5 gwei typical)
- **Good**: Weekdays Tuesday-Thursday 3-5 AM UTC
- **Avoid**: Weekday business hours (10+ gwei common)
- **Target gas price**: 1-5 gwei for optimal savings

**Real-Time Monitoring:**
1. Run `make gas-analysis-all` before execution for current costs
2. Monitor https://etherscan.io/gastracker for live gas prices
3. Set alerts on Blocknative/MevBlocker for <5 gwei notifications
4. Check current ETH price impact on total costs

**Cost Optimization:**
- **96% savings** possible with optimal timing (1 gwei vs 30 gwei)
- **83% savings** at reasonable 5 gwei execution
- Share gas analysis output with team for approval before execution

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
# Run comprehensive analysis with both scripts (RECOMMENDED)
make gas-analysis-all

# Or run individual scripts:
make gas-analysis      # Production planning (500 users/batch)
make gas-analysis-live # Conservative validation (50 users/batch)

# Understanding the output:
# - First script shows production-optimized costs
# - Second script validates with conservative estimates
# - Use the data to choose your risk tolerance
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
  --gas-price 5gwei \
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