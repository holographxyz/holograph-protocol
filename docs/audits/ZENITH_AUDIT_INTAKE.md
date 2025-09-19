1. Please list all chains that you plan to deploy the protocol on (now and in the future)

Ethereum mainnet only. The StakingRewards contract will only be deployed on Ethereum mainnet (Chain ID 1). The HLG token already exists at 0x740dF024Ce73F589AcD5E8756B377eF8C6558BaB on Ethereum mainnet, and this staking contract is designed specifically to work with that token.

2. Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?

Yes, several limitations exist:

Admin Role Limitations:
- burnPercentage: Limited to ≤ 10000 (100%) via InvalidBurnPercentage check
- feeRouter: Cannot be zero address
- Distributor addresses: Cannot be zero address
- Recovery addresses: Cannot be zero address

Array Length Restrictions:
- batchStakeFor(): No explicit array length limit, but gas limits will naturally constrain batch sizes. Arrays must have matching lengths (users.length == amounts.length)
- Processing ranges controlled by startIndex and endIndex parameters for gas management

Protocol Integration Dependencies:
- HLG Token: Must implement ERC20Burnable interface with a functioning burn() method
- Burn verification: Relies on HLG token's totalSupply() reducing by exact burn amount

3. Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)?

Yes, the protocol relies on manual off-chain operations for the bootstrap strategy:

Weekly Manual Process:
1. Multisig collects trading fees from Base chain (0x Protocol)
2. Multisig bridges 50% of fees from Base to Ethereum
3. Multisig swaps ETH → HLG on Uniswap
4. Multisig calls depositAndDistribute() with HLG amount

Critical Assumptions:
- Multisig operators will perform weekly reward distributions
- Multisig will accurately calculate and provide correct HLG amounts
- Manual operations will not be delayed or go offline for extended periods
- Eventual automation via feeRouter (when implemented) will call addRewards() properly

4. What properties/invariants do you want to hold even if breaking them has a low/unknown impact?

Critical Accounting Invariants:
1. HLG.balanceOf(contract) >= totalStaked at all times
2. totalStaked == sum of all user balances + unallocatedRewards
3. unallocatedRewards can only decrease when users compound rewards
4. Total supply reduction after burn equals burn amount exactly
5. User reward calculations are monotonic (rewards can only increase, never decrease)

Auto-Compounding Math Invariants:
1. globalRewardIndex only increases (never decreases)
2. Pending rewards calculation: (userBalance * indexDelta) / INDEX_PRECISION maintains precision
3. Reward distribution: rewardAmount * INDEX_PRECISION / activeStaked > 0 (prevents dust rewards)

State Consistency:
1. If balanceOf[user] == 0, then user should not be counted in totalStakers
2. Emergency exit preserves user balance without compounding
3. Normal unstake compounds first, then withdraws full balance

5. Please discuss any design choices you made.

Auto-Compounding Architecture:
- Chose MasterChef V2 algorithm for O(1) gas complexity regardless of staker count
- 1e12 precision scaling balances accuracy vs gas efficiency
- Rewards automatically compound without user action, maximizing yields

Bootstrap vs Automation:
- Manual weekly operations chosen over complex cross-chain automation for faster time-to-market
- Single depositAndDistribute() function simplifies operational procedures
- Future addRewards() function prepared for automated FeeRouter integration

Security-First Design:
- Contract starts paused, requires explicit unpausing
- Emergency exit works even when paused (critical for user funds safety)
- Fee-on-transfer protection prevents gaming with rebasing tokens
- Burn verification ensures actual supply reduction

Burn/Reward Split:
- Configurable burn percentage (default 50%) allows tokenomics tuning
- Burn-first approach: validate rewards will move index before executing irreversible burn
- RewardTooSmall check prevents dust distributions that don't meaningfully update rewards

6. Please provide links to previous audits (if any).

N/A - This is a new contract that has not been previously audited.

7. Please list any relevant protocol resources.

Documentation:
- AUDIT_SCOPE.md - Primary contract overview
- docs/BOOTSTRAP_STRATEGY.md - Operational model details
- docs/STAKING_REWARDS.md - Technical documentation
- docs/MULTISIG_FEE_FLOW.md - Operational procedures

Testing:
- test/StakingRewards.t.sol - Unit tests
- test/invariant/StakingRewardsInvariants.t.sol - Property-based testing

Dependencies:
- HLG Token: 0x740dF024Ce73F589AcD5E8756B377eF8C6558BaB (Ethereum mainnet)
- OpenZeppelin Contracts v4.x (AccessControl, ReentrancyGuard, Pausable, SafeERC20)

Operational Tools:
- script/DeployEthereum.s.sol - Deployment script
- script/ts/multisig-cli.ts - Multisig operation tooling

8. Additional audit information.

Focus Areas for Auditors:
1. Auto-compounding math precision - Verify 1e12 scaling prevents rounding errors
2. Burn mechanism integrity - Ensure HLG burns actually reduce total supply
3. Emergency scenarios - Test pausable functionality and emergency exit paths
4. Batch operations - Validate gas efficiency and error handling in batchStakeFor()
5. Reward distribution edge cases - Test zero stakers, dust amounts, reward too small scenarios

Known Limitations:
- No upgradeability - contract is immutable once deployed
- Manual operational dependency during bootstrap phase
- Single HLG token support only (by design)