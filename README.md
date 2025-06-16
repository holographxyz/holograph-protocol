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

### 🆕 New: Doppler Integration & Single-Slice Fee Model

Version 2.0 introduces deep integration with Doppler's "integrator-pull" pattern and implements a unified single-slice fee model:

- **Single-Slice Processing**: All fees (launch ETH, Airlock pulls, manual routes) processed through one 1.5% protocol skim
- **Treasury Integration**: 98.5% of all fees automatically routed to governance-controlled treasury
- **Keeper Automation**: Role-based automation for fee collection and cross-chain bridging
- **ERC-20 Support**: Full end-to-end support for token fee routing and bridging
- **Dust Protection**: Minimum bridge values prevent failed micro-transactions

## Core Features

### Omnichain Token Launches

- Launch tokens on Base with cross-chain availability
- Same contract address across all supported chains
- Built on Doppler Airlock technology
- Multi-chain tokens with automatic integrator fee collection

### Cross-Chain Bridging

- LayerZero V2 integration for secure messaging
- Direct token minting on destination chains
- No lock/unlock mechanisms - true omnichain tokens
- Nonce-based replay protection

### Advanced Fee System

- **Single-slice model**: All fees processed at one point for consistency
- **Cross-chain distribution**: Base → Ethereum via LayerZero V2
- **Automated token economics**: Swap to HLG, burn 50%, stake 50%
- **Role-based automation**: Keeper bots handle fee collection and bridging
- **Treasury governance**: 98.5% of fees route to multisig treasury

### Developer Integration

- Simple integration with existing dApps
- Standard ERC-20 interface on all chains
- Comprehensive testing suite included
- Keeper automation scripts provided
- Open source with MIT license

## Core Contracts

### HolographFactory.sol

The main entry point for token launches and cross-chain operations.

- Launches new ERC-20 tokens via Doppler Airlock
- Implements single-slice fee model (forwards full launch ETH to FeeRouter)
- Sets FeeRouter as integrator for automatic Doppler fee collection
- Handles cross-chain token bridging via LayerZero V2
- Manages omnichain token deployments

```solidity
function createToken(CreateParams calldata params) external payable returns (address asset)
function bridgeToken(uint32 dstEid, address token, address recipient, uint256 amount, bytes calldata options) external payable
```

### FeeRouter.sol (Enhanced)

Upgraded omnichain fee router with Doppler integration and single-slice processing.

**New Features:**

- **Single-slice processing**: `_takeAndSlice()` handles all fee types consistently
- **Doppler integration**: `pullAndSlice()` for keeper-driven Airlock fee collection
- **ERC-20 support**: `routeFeeToken()` and `bridgeToken()` for full token lifecycle
- **Role-based access**: KEEPER_ROLE for automation functions
- **Dust protection**: MIN_BRIDGE_VALUE prevents micro-transaction failures
- **Treasury routing**: Configurable treasury address for governance flexibility

```solidity
// Core fee intake (single-slice model)
function receiveFee() external payable
function routeFeeToken(address token, uint256 amt) external

// Doppler integrator pull (keeper-only)
function pullAndSlice(address airlock, address token, uint128 amt) external

// Cross-chain bridging (keeper-only)
function bridge(uint256 minGas, uint256 minHlg) external
function bridgeToken(address token, uint256 minGas, uint256 minHlg) external

// Admin functions
function setTreasury(address newTreasury) external
```

### StakingRewards.sol (Unchanged)

Single-token staking contract for HLG with reward distribution from protocol fees.

## Table of Contents

- [Token Launch & Bridging](#token-launch--bridging)
- [Fee System (New)](#fee-system-new)
- [Keeper Automation](#keeper-automation)
- [Integration](#integration)
- [Security](#security)
- [Testing](#testing)
- [Staking](#staking)

## Token Launch & Bridging

### Token Launch Flow (Updated)

1. User calls `HolographFactory.createToken()` with launch fee (0.005 ETH)
2. **Single-slice processing**: Full launch ETH forwarded to FeeRouter
3. **Fee slicing**: 1.5% kept for protocol, 98.5% sent to treasury
4. **Integrator setup**: FeeRouter set as integrator for Doppler fee collection
5. Token deployed via Doppler Airlock
6. Token available for cross-chain bridging

### Cross-Chain Bridging Flow

1. User calls `HolographFactory.bridgeToken()` on source chain
2. LayerZero message sent to destination chain
3. Destination Factory receives message via `lzReceive()`
4. Tokens minted directly to recipient on destination chain

The bridging system uses a mint payload format: `mintERC20(address token, uint256 amount, address recipient)` with nonce-based replay protection per destination chain.

## Fee System (New)

The new single-slice fee model provides consistent processing for all fee types with enhanced cross-chain distribution.

### 1. Single-Slice Processing

**All fees processed through `FeeRouter._takeAndSlice()`:**

- Launch ETH from HolographFactory
- Doppler Airlock fee pulls (keeper-driven)
- Manual ERC-20 token routes
- Direct ETH transfers

**Consistent 1.5% / 98.5% split:**

- 1.5% → Protocol (bridged to Ethereum for HLG rewards)
- 98.5% → Treasury (governance-controlled multisig)

### 2. Fee Collection Sources

```solidity
// Launch fees (automatic)
factory.createToken{value: 0.005 ether}(params);

// Airlock fees (keeper-driven)
feeRouter.pullAndSlice(airlockAddress, tokenAddress, amount);

// Manual routes (integrations)
feeRouter.routeFeeToken(tokenAddress, amount);

// Direct transfers
address(feeRouter).call{value: amount}("");
```

### 3. Cross-Chain Distribution (Base → Ethereum)

```
Base Chain:
  Fee Collection → 1.5% Protocol Skim → Buffer for Bridging

Keeper Automation:
  bridge() or bridgeToken() → LayerZero V2 Message

Ethereum Chain:
  lzReceive() → Wrap ETH → Swap to HLG → 50% Burn | 50% Stake
```

### 4. Token Economics

- **HLG Acquisition**: WETH → HLG via Uniswap V3 (0.3% fee tier)
- **Burn Mechanism**: 50% transferred to `address(0)`
- **Staking Rewards**: 50% sent to `StakingRewards` contract
- **Slippage Protection**: Configurable minimum HLG output

## Keeper Automation

### Keeper Bot Architecture

Holograph uses role-based keeper automation for fee collection and cross-chain operations:

```solidity
// Keeper role required for automation functions
bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

// Grant keeper access
feeRouter.grantRole(KEEPER_ROLE, keeperAddress);
```

### Automated Operations

1. **Fee Collection**: Pull accumulated fees from Doppler Airlock contracts
2. **Cross-Chain Bridging**: Bridge ETH and tokens when balances exceed dust threshold
3. **Gas Optimization**: Skip operations below `MIN_BRIDGE_VALUE` (0.01 ETH)

### Keeper Script Usage

```bash
# Run keeper automation
forge script script/KeeperPullAndBridge.s.sol \
  --rpc-url $BASE_RPC --broadcast --legacy \
  --gas-price 100000000 --private-key $KEEPER_PK

# Emergency pause (governance)
forge script script/KeeperPullAndBridge.s.sol \
  --sig "emergencyPause()" --rpc-url $BASE_RPC --broadcast

# Check balances
forge script script/KeeperPullAndBridge.s.sol \
  --sig "checkBalances()" --rpc-url $BASE_RPC
```

### Dust Protection

- **MIN_BRIDGE_VALUE**: 0.01 ETH minimum for cross-chain operations
- **Gas Efficiency**: Prevents failed micro-transactions
- **Accumulation**: Small amounts accumulate until threshold is reached
- **Owner Configurable**: Threshold adjustable via governance

## Integration

### For Token Launchers

```solidity
// Launch a new omnichain token (single-slice model)
CreateParams memory params = CreateParams({
    name: "My Token",
    symbol: "MTK",
    decimals: 18,
    initialSupply: 1000000e18,
    salt: bytes32(uint256(1)),
    integrator: address(0), // Will be set to FeeRouter automatically
    royaltyFeePercentage: 500, // 5%
    royaltyRecipient: msg.sender
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

### For Protocol Integrators

```solidity
// Route ERC-20 fees through single-slice model
IERC20(token).approve(address(feeRouter), amount);
feeRouter.routeFeeToken(token, amount);

// Check fee distribution
uint256 treasuryPortion = (amount * 9850) / 10000; // 98.5%
uint256 protocolPortion = amount - treasuryPortion; // 1.5%
```

### For Keeper Operators

```solidity
// Pull fees from Doppler Airlock
feeRouter.pullAndSlice(airlockAddress, tokenAddress, amount);

// Bridge accumulated ETH
feeRouter.bridge(200_000, minHlgOut);

// Bridge accumulated tokens
feeRouter.bridgeToken(tokenAddress, 200_000, minHlgOut);
```

## Security

### Access Control

- **Owner-only functions**: Pause/unpause, fee adjustments, trusted remotes, treasury updates
- **Keeper-only functions**: Fee collection, cross-chain bridging
- **FeeRouter-only**: Only FeeRouter can add rewards to staking
- **LayerZero-only**: Only LZ endpoint can call `lzReceive()`

### Cross-Chain Security

- **Trusted Remotes**: Whitelist of authorized cross-chain senders
- **Endpoint Validation**: Messages must come from LayerZero endpoint
- **Replay Protection**: Nonce-based system prevents double-spending
- **Payload Validation**: Strict decoding and validation of cross-chain messages

### Economic Security

- **Single-slice consistency**: All fees processed through one secure path
- **Slippage Protection**: Minimum HLG output requirements for swaps
- **Dust Protection**: Prevents failed micro-transactions
- **Pause Functionality**: Emergency stop for all major functions
- **Treasury Security**: Governance-controlled multisig for 98.5% of fees
- **Cooldown Period**: Prevents rapid staking manipulation

### Error Handling

- **Custom Errors**: Gas-efficient error reporting
- **Input Validation**: Zero address and zero amount checks
- **Reentrancy Guards**: Protection against reentrancy attacks
- **Graceful Failures**: Dust amounts skip bridging without reverting

## Testing

### Test Coverage

- **Unit tests**: Individual contract functionality and edge cases
- **Integration tests**: End-to-end fee flow simulation from launch to rewards
- **Fuzz tests**: Random inputs and boundary conditions
- **Mock contracts**: Isolated testing without external dependencies
- **Cross-chain simulation**: Mock LayerZero endpoints for testing

### Running Tests

```bash
# Run all tests
forge test

# Run specific test suite
forge test --match-contract FeeRouterSliceTest

# Run integration tests
forge test --match-path test/integration/

# Run with verbose output
forge test -vv

# Run fuzz tests with more iterations
forge test --fuzz-runs 10000
```

### Test Scenarios

- **Single-slice processing**: 1.5% / 98.5% split accuracy
- **End-to-end fee flow**: Launch → Collection → Bridge → Swap → Distribute
- **Multiple fee cycles and reward accumulation**
- **Reward distribution mathematics**
- **Cross-chain security validation**
- **Pause/unpause functionality**
- **Slippage protection**
- **Keeper role enforcement and automation**
- **Dust protection and accumulation**
- **LayerZero options encoding**
- **ERC-20 token fee flows**

## Staking

### How It Works

- Users stake HLG tokens to earn rewards from protocol fees
- Rewards are distributed when fees are processed on Ethereum
- Uses reward-per-token accounting for gas efficiency
- 18-decimal precision for fractional rewards

### Staking Process

1. **Stake**: User deposits HLG tokens
2. **Earn**: Rewards accumulate automatically from protocol fees
3. **Claim**: User can claim rewards at any time
4. **Withdraw**: Remove staked tokens (subject to cooldown)

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

// Exit (withdraw all + claim)
stakingRewards.exit();
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

### Fee Economics (Updated)

- **Launch Fee**: 0.005 ETH per token launch
- **Protocol Fee**: 1.5% of all fees (0.000075 ETH per launch)
- **Treasury Allocation**: 98.5% of all fees
- **Cross-chain Gas**: ~200,000 gas for LayerZero message processing
- **Distribution**: 50% burn, 50% staking rewards

### Performance

- **Cross-Chain Delivery**: ~2-5 minutes via LayerZero V2
- **Slippage Protection**: Configurable minimum output protection
- **Staking Cooldown**: 7-day default withdrawal period
- **Dust Threshold**: 0.01 ETH minimum bridge value
- **Keeper Automation**: Role-based automation with dust protection

### Economic Impact

- **Fee Consistency**: Single-slice model eliminates fee fragmentation
- **Treasury Growth**: 98.5% of all protocol revenue
- **HLG Tokenomics**: Continuous burn pressure + staking rewards
- **Cross-chain Efficiency**: Batched bridging reduces gas costs

## Dependencies

- **LayerZero V2**: Enhanced cross-chain messaging protocol
- **Uniswap V3**: DEX for WETH→HLG swaps (0.3% fee tier)
- **OpenZeppelin**: Security and utility contracts (AccessControl, Pausable, etc.)
- **Doppler Airlock**: Token launch mechanism with integrator fee collection
- **Foundry**: Testing framework and automation scripts

## Deployment Guide

### Prerequisites

1. Deploy contracts on both Base and Ethereum
2. Configure LayerZero trusted remotes
3. Set up keeper roles and treasury addresses
4. Fund swap router with initial HLG liquidity

### Base Chain Setup

```bash
# Deploy FeeRouter on Base
forge create --rpc-url $BASE_RPC \
  --constructor-args $LZ_ENDPOINT $ETH_EID 0 0 0 0 $TREASURY \
  --private-key $DEPLOYER_PK src/FeeRouter.sol:FeeRouter

# Deploy HolographFactory
forge create --rpc-url $BASE_RPC \
  --constructor-args $LZ_ENDPOINT $DOPPLER_AIRLOCK $FEE_ROUTER \
  --private-key $DEPLOYER_PK src/HolographFactory.sol:HolographFactory

# Grant keeper role
cast send $FEE_ROUTER "grantRole(bytes32,address)" \
  $(cast keccak "KEEPER_ROLE") $KEEPER_ADDRESS \
  --rpc-url $BASE_RPC --private-key $OWNER_PK
```

### Ethereum Chain Setup

```bash
# Deploy FeeRouter on Ethereum
forge create --rpc-url $ETH_RPC \
  --constructor-args $LZ_ENDPOINT $BASE_EID $STAKING_REWARDS $HLG $WETH $SWAP_ROUTER $TREASURY \
  --private-key $DEPLOYER_PK src/FeeRouter.sol:FeeRouter

# Configure trusted remotes
cast send $FEE_ROUTER "setTrustedRemote(uint32,bytes32)" \
  $BASE_EID $(cast address-to-bytes32 $BASE_FEE_ROUTER) \
  --rpc-url $ETH_RPC --private-key $OWNER_PK
```

### Keeper Automation

```bash
# Run keeper script
forge script script/KeeperPullAndBridge.s.sol \
  --rpc-url $BASE_RPC --broadcast --private-key $KEEPER_PK

# Set up cron job for automation
echo "*/10 * * * * cd /path/to/holograph && make keeper-run" | crontab -
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

## Migration Notes (v1 → v2)

### Breaking Changes

- HolographFactory now forwards full launch ETH (was: partial percentage)
- FeeRouter requires treasury parameter in constructor
- New keeper role required for automation functions

### Storage Safety

- All changes are storage-layout safe (append-only)
- Existing deployments can be upgraded without data loss
- New functionality is additive only

### Recommended Upgrade Path

1. Deploy new FeeRouter with treasury parameter
2. Update HolographFactory to use new forwarding logic
3. Grant keeper roles to automation addresses
4. Configure cross-chain trusted remotes
5. Test with small amounts before full deployment
