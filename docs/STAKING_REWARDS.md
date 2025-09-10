# StakingRewards Contract - Technical Documentation

## Overview

The StakingRewards contract is the core component of Holograph's HLG tokenomics, implementing an auto-compounding staking mechanism with configurable burn/reward distribution (default 50% burn, 50% rewards). Unlike traditional staking contracts where users must claim rewards separately, this contract automatically compounds rewards into user balances.

The contract implements a configurable burn/reward split: when HLG tokens are received, a percentage is permanently burned (sent to address(0)) and the remainder is distributed proportionally to current stakers. The burn percentage is configurable by the contract owner (default 50%). Built on the proven MasterChef V2 algorithm, it provides O(1) gas efficiency regardless of the number of users.

**Key Features:**

- **Auto-Compounding**: Rewards automatically increase stake balances without claiming
- **Epoch-Based Protection**: 7-day epochs prevent sandwich attacks and compounding frequency advantages
- **O(1) Gas Efficiency**: Constant gas costs regardless of user count
- **Configurable Tokenomics**: Every HLG token is split between burning (deflationary) and rewards based on owner-configurable percentage
- **Extra Token Recovery**: Recovers HLG tokens sent directly to contract outside funding operations
- **Dual Operational Flows**: Supports both bootstrap manual operations and automated integration
- **Security Features**: Reentrancy protection, emergency functions, and access controls

> **Note**: Throughout this documentation, `100 ether` in code examples refers to 100 HLG tokens (both use 18 decimals). The contract only handles HLG tokens, never ETH directly.

## Table of Contents

1. [Economic Model](#economic-model)
2. [Epoch System](#epoch-system)
3. [MasterChef V2 Algorithm](#masterchef-v2-algorithm)
4. [Dual Operational Flows](#dual-operational-flows)
5. [Stray Token Handling](#stray-token-handling)
6. [User Journey & State Transitions](#user-journey--state-transitions)
7. [Security Features](#security-features)
8. [Technical Implementation](#technical-implementation)
9. [Integration Patterns](#integration-patterns)
10. [Code Examples & Scenarios](#code-examples--scenarios)
11. [Deployment & Operations](#deployment--operations)
12. [Mathematical Appendix](#mathematical-appendix)

---

## Economic Model

### Configurable Burn/Reward Tokenomics

Every HLG token that enters the StakingRewards contract follows a configurable split:

```
Incoming HLG → [X% Burn] → address(0) (permanently removed)
            → [(100-X)% Rewards] → Auto-compound to stakers
```

Where X is the `burnPercentage` (default 50%, configurable by owner).

This creates two economic forces:

- **Deflationary**: Continuous token burning reduces total supply
- **Incentive Alignment**: Stakers are rewarded for long-term commitment

### Burn Percentage Configuration

The burn percentage is configurable by the contract owner, providing flexibility to adjust tokenomics based on market conditions and protocol needs:

```solidity
function setBurnPercentage(uint256 _burnPercentage) external onlyOwner {
    // _burnPercentage in basis points (0-10000, where 10000 = 100%)
}
```

**Examples:**
- `burnPercentage = 5000` → 50% burn, 50% rewards (default)
- `burnPercentage = 3000` → 30% burn, 70% rewards (more rewards to stakers)
- `burnPercentage = 7000` → 70% burn, 30% rewards (more deflationary pressure)
- `burnPercentage = 0` → 0% burn, 100% rewards (all rewards to stakers)

**Important Notes:**
- Changes only affect future reward distributions, not existing balances
- Only the contract owner can modify the burn percentage
- All changes emit `BurnPercentageUpdated` events for transparency

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

## Epoch System

### Overview

The contract implements a 7-day epoch system to prevent sandwich attacks and eliminate compounding frequency advantages. This ensures fair reward distribution regardless of how often users interact with the contract.

### Key Concepts

- **Epoch Duration**: Each epoch lasts exactly 7 days (604,800 seconds)
- **Activation Delay**: New stakes become eligible for rewards in the next epoch
- **Withdrawal Delay**: Unstaking is a two-step process with epoch-based finalization
- **Reward Maturation**: Rewards distributed in an epoch mature when that epoch completes

### Epoch State Variables

```solidity
uint256 public constant EPOCH_DURATION = 7 days;
uint256 public epochStartTime;              // When epoch 0 started
uint256 public lastProcessedEpoch;          // Last fully matured epoch
uint256 public currentEpochRewardIndex;     // Rewards for current epoch
uint256 public globalRewardIndex;           // All matured rewards
uint256 public eligibleTotal;               // Total stake eligible this epoch
```

### Epoch Advancement

The contract automatically advances epochs when any user interacts with it:

```solidity
function _advanceEpoch() internal {
    // Calculate current epoch based on time
    uint256 epochNow = (block.timestamp - epochStartTime) / EPOCH_DURATION;
    
    // Process any elapsed epochs
    while (lastProcessedEpoch < epochNow) {
        // Mature current epoch rewards into global index
        globalRewardIndex += currentEpochRewardIndex;
        currentEpochRewardIndex = 0;
        
        // Apply scheduled stake changes
        eligibleTotal = eligibleTotal + scheduledAdditionsNextEpoch - scheduledRemovalsNextEpoch;
        
        lastProcessedEpoch++;
        emit EpochAdvanced(lastProcessedEpoch, delta, eligibleTotal);
    }
}
```

### Protection Mechanisms

1. **Sandwich Attack Prevention**: Stakes activate next epoch, preventing same-block manipulation
2. **Fair Compounding**: All users compound at the same rate based on eligibility
3. **No Timing Games**: Reward calculations use epoch snapshots, not real-time balances

---

## MasterChef V2 Algorithm

### Virtual Compounding Model

The StakingRewards contract implements the MasterChef V2 algorithm, which has been battle-tested across thousands of DeFi protocols. This algorithm achieves O(1) gas efficiency by using a global reward index and per-user snapshots.

#### Core Formula

The fundamental equation for calculating a user's pending rewards is:

```
pendingRewards = userBalance × (globalRewardIndex - userIndexSnapshot) / INDEX_PRECISION
```

Where:
- `userBalance`: The user's current staked balance (including previously compounded rewards)
- `globalRewardIndex`: The cumulative reward-per-token index for all matured epochs
- `userIndexSnapshot`: The global index value when the user last updated
- `INDEX_PRECISION`: 10^12 for precision in integer math

#### Index Accumulation

When rewards are distributed:

```solidity
function _addRewards(uint256 rewardAmount, uint256 indexDelta) internal {
    // Add to current epoch's index (not global yet)
    currentEpochRewardIndex += indexDelta;
    
    // Track unallocated rewards
    unallocatedRewards += rewardAmount;
    totalStaked += rewardAmount;
}
```

The index delta calculation:
```
indexDelta = (rewardAmount × INDEX_PRECISION) / eligibleTotal
```

### Precision Handling

The contract uses 1e12 precision for the reward index to maintain accuracy even with small reward amounts relative to large stake pools.

**Example:**
- Total Staked: 1,000,000 HLG
- Reward Amount: 1 HLG
- Index Delta = (1 × 10^12) / 1,000,000 = 1,000,000

This ensures even tiny rewards are accurately tracked and distributed.

---

## Dual Operational Flows

The contract supports two distinct operational modes:

### 1. Bootstrap Mode (Owner-Operated)

During initial protocol phases, the owner manually manages reward distributions:

```solidity
// Owner deposits and distributes rewards
stakingRewards.depositAndDistribute(1000 ether);

// Owner can stake on behalf of users (only while paused)
stakingRewards.pause();
stakingRewards.stakeFor(userAddress, 100 ether);
stakingRewards.unpause();

// Batch operations for gas efficiency
stakingRewards.batchStakeFor(users, amounts, 0, users.length);
```

**Key Features:**
- Direct owner control for initial distribution
- Batch operations for airdrops and migrations
- Emergency pause/unpause capabilities
- Manual treasury management

### 2. Automated Mode (FeeRouter Integration)

Once the FeeRouter is deployed, the system operates autonomously:

```solidity
// FeeRouter automatically calls this
stakingRewards.addRewards(rewardAmount);

// Distributor contracts can stake for users
stakingRewards.stakeFromDistributor(user, amount);
```

**Key Features:**
- Automated fee collection and distribution
- Permissionless reward compounding
- Integration with quest engines and airdrops
- No manual intervention required

---

## Stray Token Handling

### The Problem

Users sometimes accidentally send HLG tokens directly to the contract address instead of using the proper staking functions. These "stray" tokens would normally be locked forever.

### The Solution

The contract provides recovery mechanisms:

```solidity
// Get amount of recoverable tokens
uint256 extra = stakingRewards.getExtraTokens();
// Returns: HLG.balanceOf(contract) - totalStaked

// Owner recovers extra tokens
stakingRewards.recoverExtraHLG(treasuryAddress, extra);
```

**Safety Guarantees:**
- Only tokens beyond `totalStaked` can be recovered
- Cannot withdraw user stakes or allocated rewards
- Owner-only function with reentrancy protection
- Emits `TokensRecovered` event for transparency

**Example Scenario:**
1. Contract has 1000 HLG staked by users
2. Someone accidentally sends 50 HLG directly
3. `getExtraTokens()` returns 50
4. Owner can recover exactly 50 HLG

---

## User Journey & State Transitions

### Complete User Lifecycle

```mermaid
graph LR
    A[No Stake] -->|stake()| B[Pending Activation]
    B -->|Next Epoch| C[Active Stake]
    C -->|Rewards Distributed| D[Earning]
    D -->|updateUser()| E[Compounded]
    E -->|unstake()| F[Pending Withdrawal]
    F -->|Next Epoch + finalizeUnstake()| G[Withdrawn]
    C -->|emergencyExit()| F
```

### State Variables Per User

```solidity
mapping(address => uint256) public balanceOf;                 // Total balance including compounds
mapping(address => uint256) public eligibleBalanceOf;         // Eligible for current epoch
mapping(address => uint256) public pendingActivationAmount;   // Waiting to activate
mapping(address => uint256) public pendingActivationEpoch;    // When activation occurs
mapping(address => uint256) public pendingWithdrawalAmount;   // Scheduled withdrawal
mapping(address => uint256) public pendingWithdrawalEpoch;    // When withdrawal unlocks
mapping(address => uint256) public userIndexSnapshot;         // Last reward index
```

### Staking Flow

1. **Initial Stake**
   ```solidity
   hlg.approve(stakingRewards, 100 ether);
   stakingRewards.stake(100 ether);
   // Balance: 100, Eligible: 0 (pending activation)
   ```

2. **Epoch Advance** (automatic on next interaction)
   ```solidity
   // After 7 days, any transaction triggers epoch advance
   // Balance: 100, Eligible: 100
   ```

3. **Reward Distribution**
   ```solidity
   // Owner distributes rewards
   stakingRewards.depositAndDistribute(1000 ether);
   // 500 burned, 500 to stakers
   ```

4. **Compounding**
   ```solidity
   stakingRewards.updateUser(userAddress);
   // Rewards auto-compound into balance
   // Balance: 125, Eligible: 100 (compound pending activation)
   ```

### Withdrawal Flow

1. **Initiate Unstake**
   ```solidity
   stakingRewards.unstake();
   // Schedules withdrawal for next epoch
   // Cannot stake while withdrawal pending
   ```

2. **Wait for Epoch**
   ```solidity
   // Must wait until next epoch (up to 7 days)
   // User retains eligibility during waiting period
   ```

3. **Finalize**
   ```solidity
   stakingRewards.finalizeUnstake();
   // Receives full balance including compounds
   ```

---

## Security Features

### Access Control

- **Owner Functions**: Pause, unpause, set parameters, recover tokens
- **FeeRouter Only**: `addRewards()` restricted to FeeRouter
- **Distributor Registry**: Whitelisted distributors for campaigns
- **User Functions**: Stake, unstake, emergency exit

### Reentrancy Protection

All state-changing functions use OpenZeppelin's `ReentrancyGuard`:

```solidity
function stake(uint256 amount) external nonReentrant whenNotPaused {
    // Protected against reentrancy
}
```

### Emergency Functions

1. **Pause System**
   ```solidity
   stakingRewards.pause();    // Stops staking, allows withdrawals
   stakingRewards.unpause();  // Resumes normal operation
   ```

2. **Emergency Exit**
   ```solidity
   stakingRewards.emergencyExit(); // Skip compounding, schedule withdrawal
   ```

3. **Token Recovery**
   ```solidity
   stakingRewards.recoverToken(tokenAddress, recipient, minAmount);
   stakingRewards.recoverExtraHLG(recipient, amount);
   ```

### Invariants

The contract maintains critical invariants:

1. **Solvency**: `HLG.balanceOf(contract) >= totalStaked`
2. **User Balance**: `sum(all user balances) + unallocatedRewards == totalStaked`
3. **Index Monotonicity**: `globalRewardIndex` only increases
4. **Epoch Ordering**: `lastProcessedEpoch <= currentEpoch`

---

## Technical Implementation

### State Variables

```solidity
// Core accounting
uint256 public totalStaked;                    // Total HLG in contract
uint256 public totalStakers;                   // Number of unique stakers
mapping(address => uint256) public balanceOf;  // User balances

// Reward tracking
uint256 public globalRewardIndex;              // Matured reward index
uint256 public currentEpochRewardIndex;        // Current epoch rewards
mapping(address => uint256) public userIndexSnapshot;  // User snapshots
uint256 public unallocatedRewards;            // Distributed but not claimed

// Epoch management
uint256 public constant EPOCH_DURATION = 7 days;
uint256 public epochStartTime;                // First epoch timestamp
uint256 public lastProcessedEpoch;            // Last matured epoch
uint256 public eligibleTotal;                 // Current eligible stake

// Configuration
uint256 public burnPercentage = 5000;         // 50% default
address public feeRouter;                     // Automation address
mapping(address => bool) public isDistributor; // Whitelisted distributors
```

### Key Functions

#### User Functions

```solidity
function stake(uint256 amount) external
function unstake() external
function finalizeUnstake() external
function emergencyExit() external
function updateUser(address account) public
```

#### Owner Functions

```solidity
function depositAndDistribute(uint256 amount) external onlyOwner
function pause() external onlyOwner
function unpause() external onlyOwner
function setBurnPercentage(uint256 percentage) external onlyOwner
function setFeeRouter(address router) external onlyOwner
function setDistributor(address distributor, bool status) external onlyOwner
function recoverExtraHLG(address to, uint256 amount) external onlyOwner
```

#### Integration Functions

```solidity
function addRewards(uint256 amount) external  // FeeRouter only
function stakeFromDistributor(address user, uint256 amount) external  // Distributors only
```

### Events

```solidity
event Staked(address indexed user, uint256 amount);
event Unstaked(address indexed user, uint256 amount);
event UnstakeScheduled(address indexed user, uint256 amount, uint256 availableEpoch);
event EmergencyExit(address indexed user, uint256 amount);
event RewardsCompounded(address indexed user, uint256 rewardAmount);
event RewardsDistributed(uint256 totalAmount, uint256 burnAmount, uint256 rewardAmount);
event EpochAdvanced(uint256 indexed newEpoch, uint256 maturedIndexDelta, uint256 newEligibleTotal);
event EpochInitialized(uint256 startTime);
event BurnPercentageUpdated(uint256 oldPercentage, uint256 newPercentage);
event FeeRouterUpdated(address indexed newFeeRouter);
event DistributorUpdated(address indexed distributor, bool status);
event StakeActivated(address indexed user, uint256 amount, uint256 epoch);
event AccountingError(string reason, uint256 removals, uint256 eligibleBefore);
```

---

## Integration Patterns

### For Frontend Applications

```javascript
// Read user state
const balance = await stakingRewards.balanceOf(userAddress);
const eligibleBalance = await stakingRewards.eligibleBalanceOf(userAddress);
const pendingRewards = await stakingRewards.earned(userAddress);
const totalBalance = await stakingRewards.balanceWithPendingRewards(userAddress);

// Check epoch status
const currentEpoch = await stakingRewards.currentEpoch();
const timeUntilNext = await stakingRewards.timeUntilNextEpoch();

// Check withdrawal status
const pendingWithdrawal = await stakingRewards.pendingWithdrawalAmount(userAddress);
const withdrawalEpoch = await stakingRewards.pendingWithdrawalEpoch(userAddress);
const canFinalize = currentEpoch >= withdrawalEpoch && pendingWithdrawal > 0;

// Display APR
const yearlyRewards = calculateYearlyRewards();
const apr = (yearlyRewards / totalStaked) * 100;
```

### For Smart Contracts

```solidity
interface IStakingRewards {
    function stake(uint256 amount) external;
    function unstake() external;
    function finalizeUnstake() external;
    function updateUser(address account) external;
    function earned(address account) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

contract YourContract {
    IStakingRewards public stakingRewards;
    
    function stakeUserTokens(uint256 amount) external {
        // Transfer HLG from user
        hlg.transferFrom(msg.sender, address(this), amount);
        
        // Approve staking contract
        hlg.approve(address(stakingRewards), amount);
        
        // Stake on behalf of user
        stakingRewards.stake(amount);
    }
}
```

### For Distributor Contracts

```solidity
contract QuestRewards {
    IStakingRewards public stakingRewards;
    IERC20 public hlg;
    
    function distributeReward(address user, uint256 amount) external {
        // Ensure we're whitelisted
        require(stakingRewards.isDistributor(address(this)), "Not whitelisted");
        
        // Approve tokens
        hlg.approve(address(stakingRewards), amount);
        
        // Stake for user
        stakingRewards.stakeFromDistributor(user, amount);
    }
}
```

---

## Code Examples & Scenarios

### Scenario 1: Basic Staking and Compounding

```solidity
// Alice stakes 1000 HLG
alice.approve(stakingRewards, 1000 ether);
alice.stake(1000 ether);

// Wait for next epoch (7 days)
// ... time passes ...

// Owner distributes 100 HLG (50 burn, 50 rewards)
owner.depositAndDistribute(100 ether);

// Wait for rewards to mature (next epoch)
// ... time passes ...

// Alice's rewards auto-compound
stakingRewards.updateUser(alice);
// Alice now has 1050 HLG staked
```

### Scenario 2: Multiple Users, Proportional Rewards

```solidity
// Initial stakes (must wait for activation)
alice.stake(600 ether);   // 60% of pool
bob.stake(400 ether);     // 40% of pool

// After epoch advance...

// Distribute 1000 HLG
owner.depositAndDistribute(1000 ether);
// 500 burned, 500 to rewards

// After maturation...
// Alice earns: 500 * 0.6 = 300 HLG
// Bob earns: 500 * 0.4 = 200 HLG
```

### Scenario 3: Withdrawal Process

```solidity
// Alice initiates withdrawal
alice.unstake();
// Status: Scheduled for next epoch

// Cannot stake while withdrawal pending
alice.stake(100 ether); // Reverts: PendingWithdrawalExists

// After epoch advance...
alice.finalizeUnstake();
// Receives full balance including all compounds
```

### Scenario 4: Emergency Exit

```solidity
// Market crash - Bob wants out immediately
bob.emergencyExit();
// Scheduled for next epoch, skips compounding

// After epoch advance...
bob.finalizeUnstake();
// Receives exact balance without latest rewards
```

---

## Deployment & Operations

### Initial Deployment

```solidity
// 1. Deploy contract
StakingRewards stakingRewards = new StakingRewards(
    hlgTokenAddress,
    ownerAddress
);

// 2. Configure parameters
stakingRewards.setBurnPercentage(5000); // 50% burn

// 3. Set FeeRouter when ready
stakingRewards.setFeeRouter(feeRouterAddress);

// 4. Whitelist distributors
stakingRewards.setDistributor(merkleDropAddress, true);
stakingRewards.setDistributor(questEngineAddress, true);

// 5. Unpause to start epochs
stakingRewards.unpause();
```

### Operational Procedures

#### Manual Distribution (Bootstrap Phase)

```solidity
// Daily/weekly distribution
function distributeRewards(uint256 amount) external onlyOwner {
    hlg.approve(address(stakingRewards), amount);
    stakingRewards.depositAndDistribute(amount);
}
```

#### Migration from Another Contract

```solidity
// Pause for migration
stakingRewards.pause();

// Batch stake for users
address[] memory users = getOldStakers();
uint256[] memory amounts = getOldBalances();
stakingRewards.batchStakeFor(users, amounts, 0, users.length);

// Resume normal operation
stakingRewards.unpause();
```

#### Monitoring and Maintenance

```solidity
// Check system health
uint256 totalStaked = stakingRewards.totalStaked();
uint256 contractBalance = hlg.balanceOf(address(stakingRewards));
require(contractBalance >= totalStaked, "Invariant broken!");

// Monitor epoch progression
uint256 currentEpoch = stakingRewards.currentEpoch();
uint256 lastProcessed = stakingRewards.lastProcessedEpoch();
require(lastProcessed <= currentEpoch, "Epoch ordering broken!");

// Check for stuck tokens
uint256 extraTokens = stakingRewards.getExtraTokens();
if (extraTokens > threshold) {
    stakingRewards.recoverExtraHLG(treasury, extraTokens);
}
```

---

## Mathematical Appendix

### Compound Interest Calculation

The effective APY from auto-compounding:

```
APY = (1 + r/n)^n - 1
```

Where:
- `r` = annual reward rate
- `n` = number of compounding periods per year (52 for weekly epochs)

### Reward Distribution Formula

For a distribution of amount `D` with burn percentage `B`:

```
Burned = D × B / 10000
Rewarded = D × (10000 - B) / 10000

Per Token Reward = Rewarded / EligibleTotal
User Reward = UserEligibleBalance × Per Token Reward
```

### Precision Loss Analysis

Maximum precision loss per distribution:

```
Max Loss = EligibleTotal / INDEX_PRECISION
         = EligibleTotal / 10^12
```

For 1 million HLG staked:
```
Max Loss = 10^6 × 10^18 / 10^12 = 10^12 wei = 0.000001 HLG
```

This is negligible for practical purposes.

### Gas Cost Analysis

| Operation | Gas Cost | Complexity |
|-----------|----------|------------|
| stake() | ~150k | O(1) |
| unstake() | ~100k | O(1) |
| finalizeUnstake() | ~80k | O(1) |
| updateUser() | ~70k | O(1) |
| depositAndDistribute() | ~120k | O(1) |
| _advanceEpoch() | ~50k per epoch | O(epochs elapsed) |

### Economic Security

The epoch system provides economic security against attacks:

1. **Sandwich Attack Cost**: Attacker must lock capital for 7-14 days
2. **Compounding Advantage**: Eliminated - all users compound equally per epoch
3. **Front-running Protection**: Activation delay prevents instant profit
4. **Capital Efficiency**: Large stakes required for meaningful extraction

---

## Conclusion

The StakingRewards contract provides a robust, gas-efficient, and user-friendly staking mechanism for HLG tokens. The combination of auto-compounding, epoch-based protection, and configurable tokenomics creates a sustainable economic model that rewards long-term participants while maintaining security against common DeFi attack vectors.

For questions or support, please refer to the main Holograph documentation or contact the development team.