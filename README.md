# Holograph Protocol

An omnichain token launchpad powered by Doppler that enables token creation and cross-chain bridging. Launch tokens on Base and make them available across multiple chains via LayerZero V2.

## System Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Base Chain    │    │   LayerZero V2   │    │  Ethereum Chain │
│                 │    │                  │    │                 │
│ HolographFactory│───▶│   Cross-Chain    │───▶│   Token Minting │
│                 │    │   Messaging      │    │                 │
│ • Token Launches│    │                  │    │ • Omnichain     │
│ • Doppler Airlock│   │                  │    │ • Instant Mint  │
│ • Cross-Chain   │    │                  │    │ • Same Address  │
│                 │    │                  │    │                 │
│   FeeRouter     │    │                  │    │   FeeRouter     │
│ • Fee Collection│───▶│   Fee Bridging   │───▶│ • WETH→HLG Swap │
│ • ETH Bridging  │    │                  │    │ • 50% Burn      │
│                 │    │                  │    │ • 50% Staking   │
│                 │    │                  │    │                 │
│                 │    │                  │    │ StakingRewards  │
│                 │    │                  │    │ • HLG Staking   │
│                 │    │                  │    │ • Reward Distrib│
│                 │    │                  │    │ • Cooldown      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Overview

The Holograph Protocol is an omnichain token launchpad for creating and deploying tokens across multiple blockchains. Built on Doppler Airlock technology and powered by LayerZero V2, tokens launched through Holograph are available on any supported chain with the same contract address.

## Core Features

### Omnichain Token Launches

- Launch tokens on Base with cross-chain availability
- Same contract address across all supported chains
- Built on Doppler Airlock technology
- Multi-chain tokens

### Cross-Chain Bridging

- LayerZero V2 integration for secure messaging
- Direct token minting on destination chains
- No lock/unlock mechanisms - true omnichain tokens
- Nonce-based replay protection

### Developer Integration

- Simple integration with existing dApps
- Standard ERC-20 interface on all chains
- Testing suite included
- Open source

## Core Contracts

### HolographFactory.sol

The main entry point for token launches and cross-chain operations.

- Launches new ERC-20 tokens via Doppler Airlock
- Handles cross-chain token bridging via LayerZero V2
- Manages omnichain token deployments
- Provides interface for multi-chain operations

```solidity
function createToken(CreateParams calldata params) external payable returns (address asset)
function bridgeToken(uint32 dstEid, address token, address recipient, uint256 amount, bytes calldata options) external payable
```

## Table of Contents

- [Token Launch & Bridging](#token-launch--bridging)
- [Integration](#integration)
- [Security](#security)
- [Testing](#testing)
- [Fee Structure](#fee-structure)
- [Staking](#staking)

## Token Launch & Bridging

### Token Launch Flow

1. User calls `HolographFactory.createToken()` with launch fee
2. Protocol fee calculated (1.5% of launch fee = 0.000075 ETH)
3. Fee forwarded to FeeRouter on Base
4. Token deployed via Doppler Airlock
5. Token available for cross-chain bridging

### Cross-Chain Bridging Flow

1. User calls `HolographFactory.bridgeToken()` on source chain
2. LayerZero message sent to destination chain
3. Destination Factory receives message via `lzReceive()`
4. Tokens minted directly to recipient on destination chain

The bridging system uses a mint payload format: `mintERC20(address token, uint256 amount, address recipient)` with nonce-based replay protection per destination chain.

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
holographFactory.bridgeToken{value: bridgeFee}(
    destinationEid,    // e.g., Ethereum EID
    tokenAddress,      // Token to bridge
    recipient,         // Destination recipient
    amount,           // Amount to bridge
    lzOptions         // LayerZero options
);
```

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

## Fee Structure

The protocol collects fees from token launches and distributes them to HLG stakers.

### 1. Fee Generation (Base Chain)

User launches token → Pays 0.005 ETH launch fee → 1.5% protocol fee (0.000075 ETH) → FeeRouter

### 2. Fee Bridging (Base → Ethereum)

FeeRouter accumulates ETH → bridge() called → LayerZero V2 message → Ethereum FeeRouter

### 3. Fee Processing (Ethereum Chain)

ETH received → Wrap to WETH → Swap WETH→HLG (Uniswap V3) → Split 50/50

### 4. Distribution (Ethereum Chain)

50% HLG → Burn (transfer to address(0))
50% HLG → StakingRewards → Distributed to stakers pro-rata

## Staking

### How It Works

- Users stake HLG tokens to earn rewards from protocol fees
- Rewards are distributed when fees are processed
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

- TODO: Integrate Doppler fee mechanism
- Launch Fee: 0.005 ETH per token launch (This is a temporary hardcoded value that will be reworked once the above is done)
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
