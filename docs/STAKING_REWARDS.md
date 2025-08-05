# StakingRewards Contract - Technical Documentation

## Overview

The StakingRewards contract is the core component of Holograph's HLG tokenomics, implementing an auto-compounding staking mechanism that burns 50% of incoming rewards and distributes the remaining 50% to stakers. Unlike traditional staking contracts where users must claim rewards separately, this contract automatically compounds rewards into user balances.

The contract implements a deterministic 50/50 split: when HLG tokens are received, half are permanently burned (sent to address(0)) and half are distributed proportionally to current stakers. Built on the proven MasterChef V2 algorithm, it provides O(1) gas efficiency regardless of the number of users.

**Key Features:**

- **Auto-Compounding**: Rewards automatically increase stake balances without claiming
- **O(1) Gas Efficiency**: Constant gas costs regardless of user count
- **50/50 Tokenomics**: Every HLG token is split between burning (deflationary) and rewards
- **Genesis Bonus System**: First stakers receive accumulated rewards from zero-staker periods
- **Dual Operational Flows**: Supports both bootstrap manual operations and automated integration
- **Security Features**: Reentrancy protection, emergency functions, and access controls

> **Note**: Throughout this documentation, `100 ether` in code examples refers to 100 HLG tokens (both use 18 decimals). The contract only handles HLG tokens, never ETH directly.

## Table of Contents

1. [Economic Model](#economic-model)
2. [MasterChef V2 Algorithm](#masterchef-v2-algorithm)
3. [Dual Operational Flows](#dual-operational-flows)
4. [Genesis Bonus (Zero-Staker Buffer)](#genesis-bonus-zero-staker-buffer)
5. [User Journey & State Transitions](#user-journey--state-transitions)
6. [Security Features](#security-features)
7. [Technical Implementation](#technical-implementation)
8. [Integration Patterns](#integration-patterns)
9. [Code Examples & Scenarios](#code-examples--scenarios)
10. [Deployment & Operations](#deployment--operations)
11. [Mathematical Appendix](#mathematical-appendix)

---

## Economic Model

### 50/50 Burn/Reward Tokenomics

Every HLG token that enters the StakingRewards contract follows a deterministic split:

```
Incoming HLG → [50% Burn] → address(0) (permanently removed)
            → [50% Rewards] → Auto-compound to stakers
```

This creates two economic forces:

- **Deflationary**: Continuous token burning reduces total supply
- **Incentive Alignment**: Stakers are rewarded for long-term commitment

### Auto-Compounding vs Traditional Staking

Traditional staking requires multiple transactions and gas costs for claiming and restaking rewards. The StakingRewards contract eliminates this friction through automatic compounding.

| Traditional Staking      | StakingRewards Auto-Compounding    |
| ------------------------ | ---------------------------------- |
| Stake 100 tokens         | Stake 100 tokens                   |
| Earn 10 reward tokens    | Rewards auto-compound into balance |
| Pay gas to claim rewards | Balance automatically becomes 110  |
| Pay gas to restake       | Single growing balance             |
| Multiple transactions    | Set and forget                     |

The auto-compounding works by using the MasterChef algorithm that's been used across DeFi for years. When rewards come in, your stake balance just grows automatically based on your share of the total pool.

---

## MasterChef V2 Algorithm

### Core Concept

The contract tracks a global reward index that represents cumulative rewards per staked token. Each user maintains a snapshot of this index from their last interaction, so calculating rewards is always fast regardless of how many users there are.

```solidity
uint256 public globalRewardIndex;              // Cumulative rewards per token (scaled by 1e12)
mapping(address => uint256) userIndexSnapshot; // User's last seen global index
mapping(address => uint256) balanceOf;         // User's stake balance (includes compounded rewards)
uint256 public totalStaked;                    // Sum of all user balances
```

### The Algorithm

When rewards are added to the pool:

```solidity
globalRewardIndex += (newRewards * INDEX_PRECISION) / totalStaked;
```

When a user interacts with the contract:

```solidity
pendingRewards = userBalance * (globalRewardIndex - userIndexSnapshot) / INDEX_PRECISION;
userBalance += pendingRewards;  // Auto-compound
userIndexSnapshot = globalRewardIndex;  // Update snapshot
```

### Precision Handling

The contract uses `INDEX_PRECISION = 1e12` following the MasterChef V2 standard. While this provides less precision than 1e18, it offers significant gas savings with negligible precision loss. The rounding always favors the protocol, with users potentially losing wei-level amounts.

### Mathematical Invariant

The fundamental invariant that ensures correctness:

```
totalStaked == sum(balanceOf[user] for all users)
```

We test this constantly to make sure the math always works correctly.

---

## Dual Operational Flows

The contract supports two operational modes: manual bootstrap operations for immediate launch and automated integration for long-term scaling. Both can run at the same time and users get the same rewards either way.

### Bootstrap Flow (Phase 1)

Manual operations for initial launch:

```solidity
function depositAndDistribute(uint256 hlgAmount) external onlyOwner {
    // Owner manually deposits HLG from weekly operations
    // 50% burned, 50% distributed to stakers
}
```

**Weekly Process:**

1. Collect fees from 0x Protocol trading
2. Swap ETH → HLG on Uniswap V3
3. Call `depositAndDistribute()` with acquired HLG
4. Contract automatically splits and distributes

**Benefits:**

- Immediate deployment with minimal complexity
- Test tokenomics with real users
- Validate product-market fit
- Reduced audit scope

### Automated Flow (Phase 2)

Full cross-chain automation via FeeRouter integration:

```solidity
function addRewards(uint256 amount) external {
    require(msg.sender == feeRouter);
    // FeeRouter automatically sends HLG from cross-chain operations
}
```

**Automated Process:**

1. Doppler Airlock fees collected on Base
2. LayerZero V2 bridge to Ethereum
3. ETH → HLG swap via Uniswap V3
4. `addRewards()` called by FeeRouter
5. No manual intervention required

**Benefits:**

- Fully automated operations
- Scales to handle any volume
- Battle-tested cross-chain infrastructure

### Migration Strategy

The contract supports both flows simultaneously, so we can gradually move from manual to automated without losing any user data.

---

## Genesis Bonus (Zero-Staker Buffer)

### The Problem

When rewards arrive but no users are staking, other contracts either waste those rewards or get really complicated trying to handle them. The mathematical issue is straightforward: you cannot divide by zero when `totalStaked = 0`.

### The Solution: Genesis Bonus

The contract implements an unallocated buffer that accumulates rewards when no stakers are present, then distributes all buffered rewards to the first staker as a "genesis bonus."

```solidity
uint256 public unallocatedBuffer;  // Accumulated rewards when totalStaked == 0
```

### Buffer Accumulation

```solidity
function _addRewards(uint256 rewardAmount) internal {
    if (totalStaked == 0) {
        // No stakers - accumulate in buffer
        unallocatedBuffer += rewardAmount;
        return;
    }
    // Normal distribution to existing stakers
    globalRewardIndex += (rewardAmount * INDEX_PRECISION) / totalStaked;
}
```

### Genesis Bonus Distribution

```solidity
function stake(uint256 amount) external {
    // ... stake logic ...

    // If first staker and we have buffered rewards
    if (isFirstStaker && unallocatedBuffer > 0) {
        uint256 bufferedRewards = unallocatedBuffer;
        unallocatedBuffer = 0;

        // Give all buffered rewards to first staker as genesis bonus
        balanceOf[msg.sender] += bufferedRewards;
        totalStaked += bufferedRewards;

        emit RewardsCompounded(msg.sender, bufferedRewards);
    }
}
```

### Economic Benefits

- **Early Adopter Incentive**: First stakers receive bonus rewards for bootstrapping the pool
- **Zero Waste**: All rewards are distributed, maintaining tokenomics integrity
- **Simple Logic**: No complicated delayed rewards or extra state tracking

---

## User Journey & State Transitions

### Typical Flow

1. **User stakes 100 HLG**

   ```solidity
   stake(100 ether);
   // balanceOf[user] = 100, userSnapshot = current globalIndex
   ```

2. **Rewards come in (say 100 HLG total)**

   ```solidity
   addRewards(100 ether);  // 100 HLG tokens: 50 burned, 50 distributed
   // globalRewardIndex increases
   // User now has pending rewards but balance unchanged
   ```

3. **User does anything (stake more, check balance, whatever)**

   ```solidity
   // Auto-compounding triggers
   pending = calculate_pending_rewards(user);
   balanceOf[user] += pending;  // Balance grows automatically
   ```

4. **Rinse and repeat**
   - User's balance keeps growing with each reward distribution
   - No manual claiming needed
   - Compound growth over time

### Exit Options

**Normal exit:**

```solidity
unstake();  // Get your full balance (original stake + all compounded rewards)
```

**Emergency exit:**

```solidity
emergencyExit();  // Get current balance only, forfeit pending rewards
```

The emergency exit is for during a critical incident when you need to exit immediately, even if it means forfeiting pending rewards.

---

## Security Features

### Standard Protections

**Reentrancy guards** on all external functions:

```solidity
function stake(uint256 amount) external nonReentrant whenNotPaused
```

**Fee-on-transfer protection** (some tokens take fees on transfers):

```solidity
uint256 before = HLG.balanceOf(address(this));
HLG.safeTransferFrom(msg.sender, address(this), amount);
uint256 after = HLG.balanceOf(address(this));
if (after - before != amount) revert FeeOnTransferNotSupported();
```

**Ownable2Step** for safe ownership transfers (two-step process prevents accidents).

### Emergency Functions

**Pause everything:**

```solidity
pause();  // Stops all staking, but unstaking still works
```

**Emergency exit** (works even when paused):

```solidity
emergencyExit();  // Get out fast if needed
```

**Token recovery** (for tokens accidentally sent to contract):

```solidity
recoverToken(address token, address to, uint256 minimum);
// Sweeps full balance of any token except HLG
```

**ETH sweep** (protection against selfdestruct attacks):

```solidity
sweepETH(address to);
// Removes any ETH that got forced into the contract
```

### Access Control

- Owner can pause/unpause and do emergency operations
- Only FeeRouter can call `addRewards()`
- Users can always unstake (even when paused)
- Clear separation between admin and user functions

---

## Technical Implementation

### Contract Structure

```solidity
contract StakingRewards is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Core stuff
    IERC20 public immutable HLG;
    uint256 public totalStaked;
    mapping(address => uint256) public balanceOf;

    // MasterChef state
    uint256 public globalRewardIndex;
    mapping(address => uint256) public userIndexSnapshot;
    uint256 public unallocatedBuffer;

    // Config
    address public feeRouter;
}
```

### Gas Optimizations

- **_O(1)_ everything**: Doesn't matter if you have 1 user or 1 million, gas stays constant
- **1e12 precision**: Less precision than 1e18 but way more gas efficient
- **Custom errors**: Instead of strings (saves gas on reverts)
- **Packed storage**: Related vars grouped together

### Events

We emit events for everything important:

```solidity
event Staked(address indexed user, uint256 amount);
event Unstaked(address indexed user, uint256 amount);
event RewardsCompounded(address indexed user, uint256 rewardAmount);
event RewardsDistributed(uint256 totalAmount, uint256 burnAmount, uint256 rewardAmount);
```

The `indexed` parameters make it easy to filter events by user address.

---

## Integration Patterns

### FeeRouter Integration

The FeeRouter is our automated reward source. It handles cross-chain fee collection and swaps, then calls us:

```solidity
function addRewards(uint256 amount) external {
    require(msg.sender == feeRouter);
    // Split 50/50 and distribute
}
```

The flow: Base fees → LayerZero bridge → Ethereum FeeRouter → our contract.

### Manual Operations

For bootstrap phase:

```solidity
function depositAndDistribute(uint256 amount) external onlyOwner {
    // Owner manually deposits HLG from weekly operations
}
```

### Configuration

```solidity
function setFeeRouter(address router) external onlyOwner {
    // Point to the FeeRouter contract
}

function pause() / unpause() external onlyOwner {
    // Emergency controls
}
```

---

## Code Examples & Scenarios

### Single User Example

```solidity
// User stakes 100 HLG tokens
stake(100 ether);  // 100 HLG (ether = 10^18, same as HLG decimals)
// balanceOf[user] = 100, totalStaked = 100

// 100 HLG tokens arrive as rewards (50 burned, 50 distributed)
addRewards(100 ether);  // 100 HLG tokens
// globalRewardIndex increases by (50 * 1e12) / 100

// User stakes 25 more HLG tokens (auto-compound triggers)
stake(25 ether);  // 25 HLG tokens
// Pending: 100 * (newIndex - oldIndex) / 1e12 = 50 HLG
// Final balance: 100 + 50 + 25 = 175 HLG tokens
```

### Multiple Users

```solidity
// Alice stakes 100 HLG, Bob stakes 200 HLG
// totalStaked = 300

// 120 HLG tokens arrive as rewards (60 burned, 60 distributed)
addRewards(120 ether);  // 120 HLG tokens

// Proportional split:
// Alice gets: 100/300 * 60 = 20 HLG tokens
// Bob gets: 200/300 * 60 = 40 HLG tokens
```

### Zero-Staker Buffer

```solidity
// HLG rewards arrive with no stakers
addRewards(100 ether);  // 100 HLG: 50 burned, 50 buffered
addRewards(100 ether);  // 100 HLG: 50 burned, 50 buffered
// unallocatedBuffer = 100 HLG tokens

// First person stakes
stake(100 ether);  // Stakes 100 HLG
// Gets 100 HLG (stake) + 100 HLG (buffer) = 200 HLG total
```

### Emergency Scenarios

```solidity
// Contract paused due to emergency
owner.pause();

// Users can still exit safely
user.emergencyExit();  // Withdraws current balance, forfeits pending rewards
user.unstake();        // Normal exit (works even when paused)

// New staking is blocked
user.stake(100 ether);  // Reverts: contract paused
```

---

## Deployment & Operations

### Deployment

```solidity
constructor(address _hlg, address _owner) {
    HLG = IERC20(_hlg);
    _pause();  // Starts paused for safety
}
```

**Setup steps:**

1. Deploy with HLG token address and owner
2. `setFeeRouter(address)` if using automated flow
3. `unpause()` when ready to accept staking
4. Transfer ownership to multisig (two-step process)

### Operations

**Bootstrap weekly process:**

1. Collect 0x Protocol fees
2. Swap ETH → HLG on Uniswap
3. Call `depositAndDistribute(hlgAmount)`
4. Check events, monitor growth

**Monitoring:**

```solidity
// Critical invariant (must always be true)
totalStaked == sum(all user balances)

// Buffer state
if (totalStaked > 0) then unallocatedBuffer == 0

// Solvency check
HLG.balanceOf(contract) >= totalStaked
```

**Emergency Procedures:**

- **Pause Contract**: `pause()` stops new staking if critical issue discovered
- **Allow Exits**: Users can still `unstake()` and `emergencyExit()` when paused
- **Token Recovery**: `recoverToken()` for accidentally sent tokens (except HLG)
- **ETH Sweep**: `sweepETH()` removes ETH that may have been force-sent via selfdestruct

### Future Upgrades

Contract is not upgradeable (by design). To upgrade:

1. **Deploy New Contract**: With enhanced features
2. **Migrate State**: Transfer all user balances and rewards
3. **Update Integrations**: Point FeeRouter to new contract
4. **Preserve History**: Maintain all staking and reward history

---

## Mathematical Appendix

### The Core Formula

```
pending = userBalance * (globalIndex - userSnapshot) / 1e12
```

That's it. Everything else is just implementation details.

**When rewards come in:**

```
globalIndex += (newRewards * 1e12) / totalStaked
```

### Precision Stuff

We use 1e12 instead of 1e18 for gas efficiency. Precision loss is minimal:

```
// Worst case: 1 wei balance, 1 wei reward
pending = 1 * (someIndex - otherIndex) / 1e12 = 0 (rounds down)
```

In practice, this never matters because HLG has 18 decimals and real balances are much larger.

### The Critical Invariant

```
totalStaked == sum(all user balances)
```

If this breaks, the contract state is invalid. We test it constantly.

### Performance Characteristics

All operations are _O(1)_ regardless of user count, thanks to the MasterChef algorithm's cumulative index approach. Gas costs scale with transaction complexity, not the number of stakers.

---

## MasterChef V2 Comparison

While StakingRewards builds on the proven MasterChef V2 algorithm, several key differences optimize it for HLG tokenomics:

| Aspect                   | MasterChef V2              | StakingRewards                      |
| ------------------------ | -------------------------- | ----------------------------------- |
| **Reward Source**        | Pre-funded token emissions | Dynamic fee-based rewards           |
| **Reward Cadence**       | Fixed emission schedule    | Variable based on protocol activity |
| **Asset Custody**        | Multiple LP tokens         | Single HLG token only               |
| **User Experience**      | Manual harvest required    | Auto-compounding rewards            |
| **Zero-Staker Handling** | Rewards wasted/delayed     | Genesis bonus buffer system         |
| **Burn Mechanism**       | No burning                 | 50% of rewards burned               |
| **Security Additions**   | Basic protections          | Enhanced with emergency exits       |
| **Precision/Arithmetic** | Standard 1e12              | Optimized 1e12 with gas savings     |
| **Pool Design**          | Multiple pools/farms       | Single unified pool                 |
| **Emission Governance**  | DAO-controlled rates       | Market-driven via protocol fees     |

The core mathematical algorithm remains identical, keeping the proven reliability while adding features we need for Holograph's cross-chain setup.

---

## Conclusion

The StakingRewards contract provides a robust foundation for Holograph's tokenomics through auto-compounding staking with 50/50 burn/reward distribution. By building on the proven MasterChef V2 algorithm and adding innovative features like zero-staker buffers, it balances simplicity with sophistication.

**Key Strengths:**

- **Proven Algorithm**: MasterChef V2 has been used across DeFi for years
- **Auto-Compounding**: Maximizes user rewards without gas overhead
- **Dual Operation Support**: Seamless transition from bootstrap to full automation
- **Solid Security**: Protection against the usual smart contract attacks
- **Economic Alignment**: 50/50 burn/reward model creates sustainable tokenomics

---

_For technical questions or contributions to this documentation, please reach out to the Holograph development team._
