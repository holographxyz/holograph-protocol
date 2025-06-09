# Integration Tests

This directory contains integration tests for the Holograph fee management system.

## FeeRouter.t.sol

A complete end-to-end integration test suite that validates the entire fee routing workflow from Base to Ethereum.

### Mock Contracts

The integration tests use mock contracts located in `test/mock/` to simulate external dependencies:

- **MockLZEndpoint**: Simulates LayerZero V2 endpoint for cross-chain messaging
- **MockWETH**: WETH9-compatible wrapper with deposit/withdraw functionality
- **MockSwapRouter**: Uniswap V3 router simulation with 1:1000 ETH:HLG exchange rate
- **MockERC20**: Standard ERC20 token for testing HLG functionality

### Test Coverage

#### Core Functionality Tests

1. **`test_EndToEndFeeFlow()`** - Complete workflow test:

   - Users stake HLG tokens
   - Fee collection on Base chain
   - Cross-chain bridging via LayerZero V2
   - WETH wrapping and Uniswap V3 swapping
   - 50/50 burn/stake distribution
   - Proportional reward distribution to stakers
   - Reward claiming functionality

2. **`test_MultipleFeeCycles()`** - Tests multiple fee collection cycles:

   - Validates reward accumulation over time
   - Ensures proportional distribution remains accurate

3. **`test_RewardDistributionMath()`** - Mathematical validation:
   - Tests different staking ratios (30%/70%)
   - Validates precise reward calculations
   - Ensures total rewards equal expected amounts

#### Security & Access Control Tests

4. **`test_TrustedRemoteValidation()`** - LayerZero security:

   - Tests endpoint validation (NotEndpoint error)
   - Tests trusted remote validation (UntrustedRemote error)
   - Validates successful calls from trusted sources

5. **`test_PauseUnpauseFunctionality()`** - Emergency controls:

   - Tests pause/unpause for fee collection
   - Tests pause/unpause for bridging
   - Validates admin-only access

6. **`test_AdminFunctions()`** - Administrative controls:
   - Trusted remote management
   - Protocol fee percentage updates
   - Access control validation

#### Edge Cases & Error Handling

7. **`test_SlippageProtection()`** - MEV protection:

   - Tests unrealistic slippage expectations
   - Validates "Insufficient output" protection
   - Ensures swap safety mechanisms

8. **`test_StakingCooldown()`** - Staking mechanics:
   - Tests immediate withdrawal prevention
   - Validates 7-day cooldown period
   - Ensures time-based access control

#### Technical Implementation Tests

9. **`test_LayerZeroOptionsEncoding()`** - LayerZero V2 integration:
   - Validates proper options encoding format
   - Tests TYPE_3 options with gas limits
   - Ensures cross-chain message formatting

### Test Architecture

The integration tests use a realistic multi-chain setup:

- **Base Chain**: Fee collection and bridging initiation
- **Ethereum Chain**: Fee processing, swapping, and reward distribution
- **Cross-chain Communication**: LayerZero V2 message passing simulation

### Key Features Tested

✅ **Fee Collection**: ETH fee routing on Base  
✅ **Cross-chain Bridging**: LayerZero V2 message passing  
✅ **Token Swapping**: WETH → HLG via Uniswap V3  
✅ **Burn Mechanism**: 50% HLG burn to address(0)  
✅ **Reward Distribution**: 50% HLG to stakers pro-rata  
✅ **Staking Mechanics**: Stake, withdraw, claim, cooldown  
✅ **Security Controls**: Trusted remotes, pause/unpause  
✅ **Slippage Protection**: MEV-resistant swapping  
✅ **Admin Functions**: Protocol parameter management

### Running the Tests

```bash
# Run all integration tests
forge test --match-contract FeeRouterTest -v

# Run specific test with verbose output
forge test --match-test test_EndToEndFeeFlow -vv

# Run with trace output for debugging
forge test --match-test test_EndToEndFeeFlow -vvv
```

### Test Constants

- **TEST_FEE_AMOUNT**: 0.001 ETH (realistic protocol fee)
- **EXCHANGE_RATE**: 1:1000 ETH:HLG (for predictable testing)
- **BASE_EID**: 30184 (LayerZero Base chain ID)
- **ETH_EID**: 30101 (LayerZero Ethereum chain ID)

These integration tests provide comprehensive coverage of the fee management system and ensure all components work together correctly in a realistic multi-chain environment.
