# Referral Reward Distribution System & StakingRewards Hardening

## Summary

Implements a complete referral reward distribution system for HLG token waitlist participants, including batch processing infrastructure, Merkle tree distribution, and hardened StakingRewards contract with virtual compounding model.

## Major Features

### 🎯 Referral Reward System
- **Batch Processing**: CSV-driven batch staking for up to 250M HLG across 5,000+ referral recipients
- **Gas Optimization**: Sub-1,200 gas per user with dynamic batch sizing (typically 500 users per tx)
- **Safety Constraints**: Per-user caps (780k HLG), total allocation limits, duplicate prevention
- **Real-time Cost Analysis**: Chainlink ETH/USD pricing with gas cost projections across multiple scenarios

### 🌳 Merkle Distribution Infrastructure  
- **MerkleDistributor**: Trustless claim system with automatic staking integration
- **Campaign Management**: Time-bounded campaigns with allocation caps and recovery mechanisms
- **Proof Verification**: Standard Merkle proof validation with single-use claim enforcement
- **Distributor Registry**: Whitelist system in StakingRewards for authorized campaign contracts

### ⚡ StakingRewards V2 Architecture
- **Virtual Compounding**: Pre-credit model using proven MasterChef V2 algorithm
- **Configurable Tokenomics**: Dynamic burn/reward split (default 50/50, owner adjustable)
- **Emergency Controls**: Escape hatch for stuck funds, dust prevention guards
- **O(1) Gas Efficiency**: Constant gas costs regardless of user count

## Technical Implementation

### Batch Operations
The system processes large-scale referral rewards efficiently:

```solidity
function batchStakeFor(
    address[] calldata users, 
    uint256[] calldata amounts,
    uint256 startIndex, 
    uint256 endIndex
) external onlyOwner whenPaused {
    // Validates inputs, pulls total HLG upfront
    // Processes users in configurable batches
    // Updates all users with compounded rewards
}
```

### Merkle Distribution
Campaign distributors integrate seamlessly with staking:

```solidity
function claim(uint256 amount, bytes32[] calldata merkleProof) external {
    _verifyProof(msg.sender, amount, merkleProof);
    claimed[msg.sender] = true;
    
    // Approve and stake in one transaction
    hlg.safeIncreaseAllowance(address(stakingRewards), amount);
    stakingRewards.stakeFromDistributor(msg.sender, amount);
}
```

### Virtual Compounding Model
Eliminates complex checkpoint logic with immediate reward tracking:

```solidity
// Distribution: immediate index bump + pre-credit
globalRewardIndex += (rewardAmount * 1e12) / _activeStaked();
unallocatedRewards += rewardAmount;
totalStaked += rewardAmount;

// User interaction: consume from unallocated pool
uint256 pending = (userBalance * indexDelta) / 1e12;
balanceOf[account] += pending;
unallocatedRewards -= pending;
```

## Operational Tools

### Gas Analysis (`make gas-analysis`)
- Live ETH price feeds via Chainlink oracle
- Mainnet fork testing for accurate gas measurements  
- Cost breakdown across 0.2-10 gwei scenarios
- Optimal batch sizing recommendations

### CSV Processing (`ProcessReferralCSV.s.sol`)
- Parses CSV files with address/amount columns
- Validates against program constraints
- Executes batched staking operations
- Built-in safety checks and progress tracking

### Deployment Scripts
- `DeployMerkleDistributor.s.sol`: Campaign deployment automation
- Updated deployment configs with new contract addresses
- Enhanced DVN configuration for cross-chain operations

## Security Improvements

### StakingRewards Hardening
- **Burn Verification**: Ensures HLG transfers to address(0) actually reduce totalSupply
- **Active Stake Math**: Uses `_activeStaked()` for reward distribution to prevent dilution
- **Strict Validation**: Replaced unsafe clamping with explicit error handling
- **Escape Hatch**: `reclaimUnallocatedRewards()` for scenarios where all users emergency exit
- **Dust Guards**: Prevents micro-rewards that can't move the global index

### Distribution Security
- **Single-use Claims**: Bitmap tracking prevents double-claiming
- **Allocation Caps**: Per-user and total campaign limits
- **Time Bounds**: Start/end timestamps for campaign windows
- **Whitelist System**: Only authorized distributors can stake on behalf of users

## Testing & Validation

- **36 StakingRewards tests**: Full coverage including edge cases and invariants
- **Fuzz testing**: Property-based testing across random operation sequences
- **Integration tests**: End-to-end referral processing workflows
- **Gas benchmarking**: Verified sub-1,200 gas per user efficiency target

## Documentation Updates

- **REFERRAL_BATCH_OPERATIONS.md**: Complete operational procedures guide
- **STAKING_REWARDS.md**: Technical documentation for virtual compounding model
- **Gas analysis tooling**: Real-time cost calculation examples
- **README updates**: New contract interfaces and deployment procedures

## Breaking Changes

None for existing users:
- All current staking functions maintain identical behavior
- Auto-compounding mechanics preserved 
- Emergency exit and unstaking unchanged
- Existing reward calculations unaffected

New functionality is purely additive via:
- Owner-only batch operations (when paused)
- Whitelisted distributor system
- Optional Merkle campaign deployments

## Deployment Checklist

- [ ] Deploy StakingRewards with hardened security features
- [ ] Configure burn percentage (default 50%)
- [ ] Process referral CSV via batch operations
- [ ] Deploy MerkleDistributor campaigns as needed
- [ ] Whitelist approved distributors
- [ ] Unpause StakingRewards for normal operation

---

**Net Addition**: +3,590 lines, -404 lines  
**New Contracts**: MerkleDistributor  
**Enhanced**: StakingRewards, FeeRouter, deployment infrastructure  
**Ready**: Referral reward distribution for 5,000+ users