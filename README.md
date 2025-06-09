# Holograph Protocol

An omnichain token launchpad and fee system that collects protocol fees from token launches on Base, bridges them to Ethereum, swaps to HLG tokens, and distributes rewards to stakers while burning a portion for deflationary tokenomics.

## System Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Base Chain    │    │   LayerZero V2   │    │  Ethereum Chain │
│                 │    │                  │    │                 │
│ HolographFactory│───▶│   Cross-Chain    │───▶│   FeeRouter     │
│                 │    │   Messaging      │    │                 │
│ • Token Launches│    │                  │    │ • ETH→WETH→HLG  │
│ • Protocol Fees │    │                  │    │ • 50% Burn      │
│ • Cross-Chain   │    │                  │    │ • 50% Staking   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
                                                ┌─────────────────┐
                                                │ StakingRewards  │
                                                │                 │
                                                │ • HLG Staking   │
                                                │ • Reward Dist.  │
                                                │ • Cooldown      │
                                                └─────────────────┘
```

## Overview

The Holograph Protocol implements a fee management system across Base and Ethereum chains. When users launch tokens on Base, they pay a small protocol fee that gets bridged to Ethereum, swapped for HLG tokens, and distributed to stakers.

## Core Contracts

### HolographFactory.sol

The main entry point for token launches and cross-chain operations.

- Launches new ERC-20 tokens via Doppler Airlock
- Handles cross-chain token bridging via LayerZero V2
- Collects 1.5% protocol fee from token launches
- Forwards protocol fees to FeeRouter

```solidity
function createToken(CreateParams calldata params) external payable returns (address asset)
function bridgeMint(uint32 dstEid, address token, address recipient, uint256 amount, bytes calldata options) external payable
```

### FeeRouter.sol

Manages fee collection and distribution across chains.

- Collects ETH protocol fees on Base
- Bridges fees to Ethereum via LayerZero V2
- Swaps ETH→WETH→HLG on Ethereum
- Burns 50% of HLG, sends 50% to stakers

```solidity
function routeFeeETH() external payable
function bridge(uint256 minGas, uint256 minHlg) external
function swapAndDistribute(uint256 minHlg) external
```

### StakingRewards.sol

HLG token staking with reward distribution.

- Users stake HLG tokens to earn rewards from protocol fees
- Uses reward-per-token accounting for gas efficiency
- 7-day withdrawal cooldown (configurable)
- Owner can pause/unpause and adjust parameters

```solidity
function stake(uint256 amount) external
function withdraw(uint256 amount) external
function claim() external
```

## Table of Contents

- [Fee Flow](#fee-flow)
- [Token Launch & Bridging](#token-launch--bridging)
- [Staking](#staking)
- [Security](#security)
- [Testing](#testing)
- [Integration](#integration)

## Fee Flow

The protocol generates revenue through token launch fees and distributes it to HLG stakers.

### 1. Fee Generation (Base Chain)

User launches token → Pays 0.005 ETH launch fee → 1.5% protocol fee (0.000075 ETH) → FeeRouter

### 2. Fee Bridging (Base → Ethereum)

FeeRouter accumulates ETH → bridge() called → LayerZero V2 message → Ethereum FeeRouter

### 3. Fee Processing (Ethereum Chain)

ETH received → Wrap to WETH → Swap WETH→HLG (Uniswap V3) → Split 50/50

### 4. Distribution (Ethereum Chain)

50% HLG → Burn (transfer to address(0))
50% HLG → StakingRewards → Distributed to stakers pro-rata

## Token Launch & Bridging

### Token Launch Flow

1. User calls `HolographFactory.createToken()` with launch fee
2. Protocol fee calculated (1.5% of launch fee = 0.000075 ETH)
3. Fee forwarded to FeeRouter on Base
4. Token deployed via Doppler Airlock
5. Token available for cross-chain bridging

### Cross-Chain Bridging Flow

1. User calls `HolographFactory.bridgeMint()` on source chain
2. LayerZero message sent to destination chain
3. Destination Factory receives message via `lzReceive()`
4. Tokens minted directly to recipient on destination chain

The bridging system uses a mint payload format: `mintERC20(address token, uint256 amount, address recipient)` with nonce-based replay protection per destination chain.

## Staking

### How It Works

- Users stake HLG tokens to earn rewards from protocol fees
- Rewards are distributed instantly when fees are processed
- Uses reward-per-token accounting for gas efficiency
- 18-decimal precision for fractional rewards

### Staking Process

1. Stake: User deposits HLG tokens
2. Earn: Rewards accumulate automatically from protocol fees
3. Claim: User can claim rewards at any time
4. Withdraw: Remove staked tokens (subject to cooldown)

### Cooldown

- Default 7-day cooldown period between staking and withdrawal
- Prevents rapid stake/unstake gaming
- Configurable by owner
- Claiming rewards has no cooldown

## Security

### Access Control

- Owner-only functions: Pause/unpause, fee adjustments, trusted remotes
- FeeRouter-only: Only FeeRouter can add rewards to staking
- LayerZero-only: Only LZ endpoint can call `lzReceive()`

### Cross-Chain Security

- Trusted Remotes: Whitelist of authorized cross-chain senders
- Endpoint Validation: Messages must come from LayerZero endpoint
- Replay Protection: Nonce-based system prevents double-spending

### Economic Security

- Slippage Protection: Minimum HLG output requirements for swaps
- Pause Functionality: Emergency stop for all major functions
- Cooldown Period: Prevents rapid staking manipulation

### Error Handling

- Custom Errors: Gas-efficient error reporting
- Input Validation: Zero address and zero amount checks
- Reentrancy Guards: Protection against reentrancy attacks

## Testing

### Test Coverage

- Unit tests for individual contract functionality
- Integration tests for end-to-end fee flow simulation
- Fuzz tests with random inputs
- Mock contracts for isolated testing

### Running Tests

```bash
# Run all tests
forge test

# Run specific test suite
forge test --match-contract FeeRouterTest

# Run with verbose output
forge test -vv

# Run integration tests
forge test --match-path test/integration/
```

### Test Scenarios

- End-to-end fee flow (Base → Ethereum)
- Multiple fee cycles and reward accumulation
- Reward distribution mathematics
- Cross-chain security validation
- Pause/unpause functionality
- Slippage protection
- Staking cooldown mechanics
- LayerZero options encoding

## Integration

### For Token Launchers

```solidity
// Launch a new omnichain token
CreateParams memory params = CreateParams({
    name: "My Token",
    symbol: "MTK",
    // ... other parameters
});

address newToken = holographFactory.createToken{value: 0.005 ether}(params);
```

### For Cross-Chain Users

```solidity
// Bridge tokens to another chain
holographFactory.bridgeMint{value: bridgeFee}(
    destinationEid,    // e.g., Ethereum EID
    tokenAddress,      // Token to bridge
    recipient,         // Destination recipient
    amount,           // Amount to bridge
    lzOptions         // LayerZero options
);
```

### For HLG Stakers

```solidity
// Stake HLG tokens
hlgToken.approve(address(stakingRewards), stakeAmount);
stakingRewards.stake(stakeAmount);

// Claim rewards
stakingRewards.claim();

// Withdraw after cooldown
stakingRewards.withdraw(withdrawAmount);
```

### For Protocol Integration

```solidity
// Check earned rewards
uint256 pendingRewards = stakingRewards.earned(userAddress);

// Check staking balance
uint256 stakedBalance = stakingRewards.balanceOf(userAddress);

// Check total staked
uint256 totalStaked = stakingRewards.totalStaked();
```

## Key Metrics

### Fee Economics

- Launch Fee: 0.005 ETH per token launch
- Protocol Fee: 1.5% of launch fee (0.000075 ETH)
- Conversion Rate: ~0.000000139 WETH per 1 HLG at time of writing
- Distribution: 50% burn, 50% staking rewards

### Performance

- Cross-Chain: ~2-5 minute LayerZero delivery
- Slippage: Configurable minimum output protection
- Cooldown: 7-day default withdrawal period

## Dependencies

- LayerZero V2: Cross-chain messaging protocol
- Uniswap V3: DEX for WETH→HLG swaps (0.3% fee tier)
- OpenZeppelin: Security and utility contracts
- Doppler Airlock: Token launch mechanism

## License

MIT License - see [LICENSE](LICENSE) file for details.
