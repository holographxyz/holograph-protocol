# Multisig CLI Documentation

The Holograph Multisig CLI is a TypeScript tool that generates Gnosis Safe Transaction Builder compatible JSON for common protocol operations. It provides automatic optimization, Tenderly simulation, and comprehensive error handling.

## Overview

The CLI handles five main operation types:
1. **ETH → HLG → StakingRewards** batch transactions (primary use case)
2. **Direct HLG deposits** to StakingRewards (when Safe already holds HLG)
3. **StakingRewards ownership management** (transfer and acceptance)
4. **Emergency pause operations** (pause/unpause StakingRewards)
5. **Contract administration** (pausing for maintenance or emergencies)

## Installation and Setup

### Prerequisites

```bash
# Required: Node.js 18+ and npm
npm install

# Required: Environment configuration
cp .env.example .env
# Edit .env with your configuration
```

### Environment Variables

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `MULTISIG_ADDRESS` | Yes | Gnosis Safe contract address | |
| `SAFE_OWNER_ADDRESS` | Yes | Primary Safe owner for simulation | |
| `SAFE_OWNER_ADDRESS_2` | No | Secondary Safe owner | |
| `SLIPPAGE_BPS` | No | Slippage tolerance in basis points | 5000 (50%) |
| `TENDERLY_ACCOUNT` | No | Tenderly account name | |
| `TENDERLY_PROJECT` | No | Tenderly project name | |
| `TENDERLY_ACCESS_KEY` | No | Tenderly API access key | |
| `REQUIRED_FEE_TIER` | No | Force specific Uniswap fee tier | |
| `PREFER_FEE_TIER` | No | Prefer fee tier with fallback | |

### Example .env Configuration

```bash
# Safe Configuration
MULTISIG_ADDRESS=0x8FE61F653450051cEcbae12475BA2b8fbA628c7A
SAFE_OWNER_ADDRESS=0x1ef43b825f6d1c3bfa93b3951e711f5d64550bda
SAFE_OWNER_ADDRESS_2=0x2ef43b825f6d1c3bfa93b3951e711f5d64550bdb

# Trading Configuration  
SLIPPAGE_BPS=2000  # 20% slippage tolerance

# Tenderly Integration (optional but recommended)
TENDERLY_ACCOUNT=attar
TENDERLY_PROJECT=holograph
TENDERLY_ACCESS_KEY=your_access_key_here

# Uniswap Configuration (optional)
PREFER_FEE_TIER=3000  # Prefer 0.3% pools
```

## Usage

### Two Ways to Run Commands

**Method 1: Direct Script Execution (Recommended - Cleanest)**

```bash
# ✨ Clean syntax - no -- separator needed!
# Convert ETH to HLG and stake
npx tsx script/ts/multisig-cli.ts batch --eth 0.5
npx tsx script/ts/multisig-cli.ts batch --amount 1.0 --simulate-only

# Direct HLG deposit (no swapping)  
npx tsx script/ts/multisig-cli.ts deposit --hlg 1000
npx tsx script/ts/multisig-cli.ts deposit --hlg 500 --simulate-only

# Ownership management
npx tsx script/ts/multisig-cli.ts transfer-ownership
npx tsx script/ts/multisig-cli.ts accept-ownership --simulate-only

# Emergency pause operations
npx tsx script/ts/multisig-cli.ts pause --simulate-only
npx tsx script/ts/multisig-cli.ts unpause

# Help and documentation
npx tsx script/ts/multisig-cli.ts help
npx tsx script/ts/multisig-cli.ts batch --help
```

**Method 2: npm Scripts (Alternative)**

```bash
# Convert ETH to HLG and stake
npm run multisig-cli:batch -- --eth 0.5
npm run multisig-cli:batch -- --amount 1.0 --simulate-only

# Direct HLG deposit (no swapping)  
npm run multisig-cli:deposit -- --hlg 1000
npm run multisig-cli:deposit -- --hlg 500 --simulate-only

# Ownership management
npm run multisig-cli:transfer-ownership
npm run multisig-cli:accept-ownership -- --simulate-only

# Emergency pause operations
npm run multisig-cli:pause -- --simulate-only
npm run multisig-cli:unpause

# Help and documentation
npm run multisig-cli                    # Show global help (no args)
npm run multisig-cli:help               # Show global help
npm run multisig-cli:batch -- --help    # Show batch command help (note: -- separator needed)
npm run multisig-cli:deposit -- --help  # Show deposit command help (note: -- separator needed)
```

### Core Commands

The CLI uses a subcommand structure for clarity and explicit operation specification. Choose either method above based on your preference.

### Command Reference

**Direct Script Execution (Recommended):**

```bash
# Available commands - clean syntax
npx tsx script/ts/multisig-cli.ts batch --eth 0.5
npx tsx script/ts/multisig-cli.ts deposit --hlg 1000
npx tsx script/ts/multisig-cli.ts transfer-ownership
npx tsx script/ts/multisig-cli.ts accept-ownership
npx tsx script/ts/multisig-cli.ts pause --simulate-only
npx tsx script/ts/multisig-cli.ts unpause

# Help commands
npx tsx script/ts/multisig-cli.ts help             # Global help
npx tsx script/ts/multisig-cli.ts batch --help     # Batch command help
npx tsx script/ts/multisig-cli.ts deposit --help   # Deposit command help
```

**npm Scripts (Alternative):**

```bash
# Available commands - require -- separator for flags
npm run multisig-cli:batch -- --eth 0.5
npm run multisig-cli:deposit -- --hlg 1000
npm run multisig-cli:transfer-ownership
npm run multisig-cli:accept-ownership
npm run multisig-cli:pause -- --simulate-only
npm run multisig-cli:unpause

# Help commands
npm run multisig-cli                               # Global help (no args)
npm run multisig-cli:help                          # Global help
npm run multisig-cli:batch -- --help               # Batch command help (need -- separator)
npm run multisig-cli:deposit -- --help             # Deposit command help (need -- separator)
```

## Getting Help

### Direct Script Execution (Recommended)

```bash
# Global help
npx tsx script/ts/multisig-cli.ts help
npx tsx script/ts/multisig-cli.ts

# Command-specific help
npx tsx script/ts/multisig-cli.ts batch --help
npx tsx script/ts/multisig-cli.ts deposit --help
npx tsx script/ts/multisig-cli.ts transfer-ownership --help
npx tsx script/ts/multisig-cli.ts accept-ownership --help
npx tsx script/ts/multisig-cli.ts pause --help
npx tsx script/ts/multisig-cli.ts unpause --help
```

### npm Scripts (Alternative)

```bash
# Global help
npm run multisig-cli                    # Show all commands (no args)
npm run multisig-cli:help               # Show all commands

# Command-specific help (requires -- separator)
npm run multisig-cli:batch -- --help              # Batch command details
npm run multisig-cli:deposit -- --help             # Deposit command details
npm run multisig-cli:transfer-ownership -- --help  # Transfer ownership help
npm run multisig-cli:accept-ownership -- --help    # Accept ownership help
npm run multisig-cli:pause -- --help               # Pause operations help
npm run multisig-cli:unpause -- --help             # Unpause operations help
```

### Important Note about `--` Separator

**When using npm scripts**, you must use the `--` separator for flags because npm intercepts them:

```bash
# ❌ This won't work with npm scripts - npm shows its own help
npm run multisig-cli:batch --help

# ✅ This works with npm scripts - passes --help to the CLI
npm run multisig-cli:batch -- --help

# ✨ But this always works cleanly with direct execution
npx tsx script/ts/multisig-cli.ts batch --help
```

**Comparison:**
- **Direct script**: Clean syntax, no separators needed
- **npm scripts**: Require `--` separator for all flags
- **Both methods**: Support the same functionality

## Operation Details

### 1. ETH → HLG → StakingRewards Batch (`batch`)

**What it does:**
1. Wraps ETH to WETH (`deposit()` function)
2. Approves WETH for Uniswap SwapRouter
3. Swaps WETH → HLG via Uniswap V3 (`exactInputSingle`)
4. Approves HLG for StakingRewards
5. Deposits HLG to StakingRewards (`depositAndDistribute`)

**Auto-scaling Logic:**
- Calculates minimum HLG needed to avoid RewardTooSmall error
- Automatically scales ETH amount if needed to meet threshold
- Uses exponential scaling with binary search refinement

**Usage (Direct Script - Recommended):**
```bash
npx tsx script/ts/multisig-cli.ts batch --eth <amount> [--simulate-only]
npx tsx script/ts/multisig-cli.ts batch --amount <amount> [--simulate-only]
```

**Usage (npm Scripts - Alternative):**
```bash
npm run multisig-cli:batch -- --eth <amount> [--simulate-only]
npm run multisig-cli:batch -- --amount <amount> [--simulate-only]
```

**Examples:**
```bash
# Direct script execution (cleanest)
npx tsx script/ts/multisig-cli.ts batch --eth 0.5
npx tsx script/ts/multisig-cli.ts batch --amount 1.0
npx tsx script/ts/multisig-cli.ts batch --eth 0.2 --simulate-only
PREFER_FEE_TIER=500 npx tsx script/ts/multisig-cli.ts batch --eth 0.2
REQUIRED_FEE_TIER=10000 npx tsx script/ts/multisig-cli.ts batch --eth 1.0

# npm scripts (alternative)
npm run multisig-cli:batch -- --eth 0.5
npm run multisig-cli:batch -- --amount 1.0
npm run multisig-cli:batch -- --eth 0.2 --simulate-only
PREFER_FEE_TIER=500 npm run multisig-cli:batch -- --eth 0.2
REQUIRED_FEE_TIER=10000 npm run multisig-cli:batch -- --eth 1.0
```

### 2. Direct HLG Deposit (`deposit`)

**What it does:**
1. Approves HLG for StakingRewards
2. Deposits HLG directly (`depositAndDistribute`)

**Use cases:**
- Safe already holds HLG tokens
- Bypass ETH → WETH → HLG conversion
- Lower gas costs for existing HLG holdings

**Usage (Direct Script - Recommended):**
```bash
npx tsx script/ts/multisig-cli.ts deposit --hlg <amount> [--simulate-only]
```

**Usage (npm Scripts - Alternative):**
```bash
npm run multisig-cli:deposit -- --hlg <amount> [--simulate-only]
```

**Examples:**
```bash
# Direct script execution (cleanest)
npx tsx script/ts/multisig-cli.ts deposit --hlg 1000
npx tsx script/ts/multisig-cli.ts deposit --hlg 2000
npx tsx script/ts/multisig-cli.ts deposit --hlg 100 --simulate-only

# npm scripts (alternative)
npm run multisig-cli:deposit -- --hlg 1000
npm run multisig-cli:deposit -- --hlg 2000
npm run multisig-cli:deposit -- --hlg 100 --simulate-only
```

### 3. Ownership Management

**Transfer Ownership (`transfer-ownership`):**
- Provides instructions for current owner to initiate transfer
- Generates transaction data for `transferOwnership(address)`

**Accept Ownership (`accept-ownership`):**
- Generates Safe transaction to accept ownership
- Creates JSON for `acceptOwnership()` function

**Usage (Direct Script - Recommended):**
```bash
npx tsx script/ts/multisig-cli.ts transfer-ownership [--simulate-only]
npx tsx script/ts/multisig-cli.ts accept-ownership [--simulate-only]
```

**Usage (npm Scripts - Alternative):**
```bash
npm run multisig-cli:transfer-ownership
npm run multisig-cli:accept-ownership [-- --simulate-only]
```

**Example workflow:**
```bash
# Direct script execution (cleanest)
# Step 1: Get transfer instructions
npx tsx script/ts/multisig-cli.ts transfer-ownership

# Step 2: Generate acceptance transaction
npx tsx script/ts/multisig-cli.ts accept-ownership
npx tsx script/ts/multisig-cli.ts accept-ownership --simulate-only

# npm scripts (alternative)
# Step 1: Get transfer instructions
npm run multisig-cli:transfer-ownership

# Step 2: Generate acceptance transaction
npm run multisig-cli:accept-ownership
npm run multisig-cli:accept-ownership -- --simulate-only
```

## Advanced Features

### Uniswap V3 Integration

**Fee Tier Selection:**
- Automatically finds best price across fee tiers (500, 3000, 10000)
- Supports forced fee tier selection
- Provides educational information about each tier

**Price Impact Analysis:**
- Calculates expected vs minimum output amounts
- Applies configurable slippage protection
- Warns about large price impacts

### Tenderly Simulation

**Automatic Simulation:**
- Simulates complete Safe execution workflow
- Tests with realistic token balances
- Provides detailed error information

**Bundle Simulation:**
- Tests complete multi-signature workflow
- Simulates: `approveHash` → `approveHash` → `execTransaction`
- Provides links to detailed trace analysis

**Fallback Options:**
- Manual simulation links when API unavailable
- Graceful degradation without blocking execution

### Error Handling and Validation

**Input Validation:**
- Validates all addresses with checksumming
- Ensures positive amounts and valid parameters
- Provides clear error messages with suggested fixes

**Real-time Monitoring:**
- Checks current staking state before operations
- Validates minimum threshold requirements
- Provides warnings for suboptimal conditions

## Output Format

### Safe Transaction Builder JSON

The CLI outputs JSON compatible with the Gnosis Safe Transaction Builder:

```json
{
  "version": "1.0",
  "chainId": "11155111",
  "createdAt": 1699123456789,
  "meta": {
    "name": "HLG Fee Distribution Batch",
    "description": "Convert 0.5 ETH to HLG and stake in StakingRewards contract",
    "txBuilderVersion": "1.17.1",
    "createdFromSafeAddress": "0x8FE61F653450051cEcbae12475BA2b8fbA628c7A",
    "createdFromOwnerAddress": "",
    "checksum": "0x..."
  },
  "transactions": [
    {
      "to": "0xfff9976782d46cc05630d1f6ebab18b2324d6b14",
      "value": "500000000000000000",
      "data": null,
      "contractMethod": {
        "inputs": [],
        "name": "deposit",
        "payable": true
      }
    }
    // ... additional transactions
  ]
}
```

### Usage in Safe Web App

1. Copy the generated JSON
2. Navigate to Safe Transaction Builder
3. Click "Import JSON" or drag & drop
4. Review transactions in readable format
5. Execute when ready

## Troubleshooting

### Common Issues

**Missing Environment Variables:**
```bash
Error: Missing required Tenderly environment variables: TENDERLY_ACCOUNT
```
- Solution: Add required variables to `.env` or disable Tenderly

**Network Connection Issues:**
```bash
Error: Failed to fetch staking info
```
- Solution: Check RPC endpoint and network connectivity

**Insufficient Balance Warnings:**
```bash
Warning: Safe must hold at least 1000 HLG balance
```
- Solution: Verify Safe token balances before execution

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Add debug environment variable (direct script)
DEBUG=multisig-cli npx tsx script/ts/multisig-cli.ts batch --eth 0.1

# Add debug environment variable (npm script)
DEBUG=multisig-cli npm run multisig-cli:batch -- --eth 0.1

# Check network connectivity
npx tsx script/ts/multisig-cli.ts help  # Should load without RPC calls
npm run multisig-cli:help              # Alternative
```

### Simulation Failures

**Tenderly API Errors:**
- Check API credentials and rate limits
- Use manual simulation links provided in output
- Verify Safe configuration and balances

**Transaction Simulation Failures:**
- Review error messages in Tenderly dashboard
- Check token approvals and balances
- Verify contract interactions and parameters

## Integration Examples

### Programmatic Usage

```typescript
import { MultisigCLI } from './script/ts/multisig-cli.js';

const cli = new MultisigCLI();

// Generate batch transaction
await cli.generateBatchTransaction('0.5');

// Generate direct deposit
await cli.generateDirectHLGDeposit('1000');

// Ownership management
await cli.transferStakingRewardsOwnership();
await cli.generateAcceptOwnershipTransaction();
```

### Automation Scripts

```bash
#!/bin/bash
# Automated fee distribution script

# Check if Safe has sufficient ETH
ETH_BALANCE=$(cast balance $MULTISIG_ADDRESS --rpc-url $ETHEREUM_SEPOLIA_RPC_URL)
MIN_BALANCE="100000000000000000"  # 0.1 ETH

if [ "$ETH_BALANCE" -lt "$MIN_BALANCE" ]; then
    echo "Insufficient ETH balance"
    exit 1
fi

# Generate and save batch transaction (direct script)
npx tsx script/ts/multisig-cli.ts batch --eth 0.05 > batch_transaction.json

# Generate and save batch transaction (npm script)
npm run multisig-cli:batch -- --eth 0.05 > batch_transaction.json

# Validate JSON format
if jq empty batch_transaction.json 2>/dev/null; then
    echo "Valid JSON generated"
else
    echo "Invalid JSON generated"
    exit 1
fi
```

## Best Practices

### Security

1. **Always simulate first**: Use `--simulate-only` for testing
2. **Verify addresses**: Double-check all contract addresses
3. **Review JSON carefully**: Understand each transaction before execution
4. **Use realistic amounts**: Start with small amounts for testing

### Performance

1. **Set appropriate slippage**: Higher slippage for volatile markets
2. **Monitor gas prices**: Execute during low gas periods
3. **Use preferred fee tiers**: Set `PREFER_FEE_TIER` for consistent execution
4. **Batch operations**: Combine multiple operations when possible

### Maintenance

1. **Update regularly**: Keep dependencies and addresses current
2. **Monitor performance**: Track success rates and gas costs
3. **Document changes**: Record any customizations or modifications
4. **Test thoroughly**: Verify operations on testnet before mainnet

## Features and Improvements

### Recent Enhancements

- **Human-readable output**: All values displayed in compact format (e.g., "333.5K HLG" instead of wei)
- **Clear fee tier labels**: "Volatile pairs" for 1% tier, "Most pairs" for 0.3% tier
- **Smart number formatting**: Very small values show as "< 0.000001" instead of scientific notation
- **Improved simulation**: Full Safe transaction simulation with storage overrides
- **Better error handling**: Clear messages with helpful context

### Output Formatting

The CLI now provides clean, readable output:
```
🔍 Checking 3 fee tier(s) for optimal quote...
   0.05% - Stable pairs: 689.56K HLG
   0.3% - Most pairs: 394.85K HLG
   1% - Volatile pairs: 333.5M HLG
✅ Best quote: 1% - Volatile pairs (333.5M HLG)
```

## Support and Resources

- **CLI Help**: `npx tsx script/ts/multisig-cli.ts help` or `npm run multisig-cli:help`
- **Documentation**: See `docs/` directory for additional guides
- **Troubleshooting**: Check `docs/UNISWAP_V3_POOL_SETUP.md` for common issues
- **Examples**: Review `script/ts/multisig-cli.ts` for implementation details