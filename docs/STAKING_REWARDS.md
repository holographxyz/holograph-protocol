# STAKING REWARDS

Auto-compounding HLG staking with configurable burn/reward distribution.

## Key Features
- **Auto-Compounding**: Rewards automatically increase stake balances
- **O(1) Gas Efficiency**: Constant gas costs regardless of user count
- **Configurable Burn/Reward Split**: Default 50% burn, 50% rewards
- **7-Day Cooldown**: Protection against sandwich attacks
- **Emergency Controls**: Pause/recovery mechanisms

## Economic Model

Incoming HLG tokens are split: X% burned, (100-X)% distributed to stakers.
Default: 50% burn, 50% rewards. Owner-configurable via `setBurnPercentage()`.

```
Incoming HLG → [50% Burn] → address(0)
            → [50% Rewards] → Auto-compound to stakers
```

Auto-compounding eliminates the need for manual claiming/restaking. Rewards automatically increase stake balances using the proven MasterChef V2 algorithm.

## Core Functions

### User Operations
```solidity
stake(uint256 amount)         // Stake HLG tokens
unstake()                     // Withdraw all tokens (7-day cooldown)
emergencyExit()              // Emergency withdrawal (bypasses cooldown)
```

### Owner Operations
```solidity
setBurnPercentage(uint256)    // Configure burn/reward split
setStakingCooldown(uint256)   // Set cooldown period
depositAndDistribute(uint256) // Add rewards and distribute
pause() / unpause()          // Emergency controls
```

### Bootstrap Operations
```solidity
batchStakeFor(address[], uint256[], uint256, uint256)  // Batch referral staking
```

## Security Features

- **7-Day Cooldown**: Prevents sandwich attacks on reward distributions
- **Reentrancy Protection**: ReentrancyGuard on all critical functions
- **Emergency Controls**: Pause/unpause, emergency exit
- **Access Control**: Owner-only administrative functions
- **Recovery**: Mechanisms for stuck or extra tokens

## MasterChef V2 Algorithm

Tracks global reward index representing cumulative rewards per staked token. O(1) gas efficiency regardless of user count.

```solidity
globalRewardIndex += (newRewards * 1e12) / totalStaked;  // Add rewards
pendingRewards = userBalance * (globalRewardIndex - userSnapshot) / 1e12;  // Calculate user rewards
userBalance += pendingRewards;  // Auto-compound
```

## UUPS Upgradeability

Contract uses OpenZeppelin's UUPS (Universal Upgradeable Proxy Standard) pattern:
- **Proxy Deployment**: Use ERC1967Proxy with initialize() call
- **Upgrades**: Only owner can upgrade via upgradeToAndCall()
- **Storage**: Variables use storage slots, not immutable
- **Initialization**: Use initialize() instead of constructor

```solidity
// Deploy proxy
proxy = new ERC1967Proxy(implementation, initData);

// Upgrade
stakingRewards.upgradeToAndCall(newImpl, "");
```
