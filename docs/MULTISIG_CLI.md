# MULTISIG CLI

TypeScript tool that generates Gnosis Safe Transaction Builder JSON for protocol operations. Provides automatic optimization, Tenderly simulation, and error handling.

## Operations
1. **ETH → HLG → StakingRewards** batch transactions (primary use case)
2. **Direct HLG deposits** to StakingRewards (when Safe already holds HLG)
3. **StakingRewards ownership management** (transfer and acceptance)
4. **Emergency pause operations** (pause/unpause StakingRewards)

## Setup

```bash
npm install
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

```bash
# Convert ETH to HLG and stake
npx tsx script/ts/multisig-cli.ts batch --eth 0.5

# Direct HLG deposit
npx tsx script/ts/multisig-cli.ts deposit --hlg 1000

# Ownership management
npx tsx script/ts/multisig-cli.ts transfer-ownership
npx tsx script/ts/multisig-cli.ts accept-ownership

# Emergency controls
npx tsx script/ts/multisig-cli.ts pause
npx tsx script/ts/multisig-cli.ts unpause

# Add --simulate-only for dry runs
# Add --help for command details
```

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

**Examples:**
```bash
npx tsx script/ts/multisig-cli.ts batch --eth 0.5
npx tsx script/ts/multisig-cli.ts batch --amount 1.0 --simulate-only
PREFER_FEE_TIER=500 npx tsx script/ts/multisig-cli.ts batch --eth 0.2
```

### 2. Direct HLG Deposit (`deposit`)

**What it does:**
1. Approves HLG for StakingRewards
2. Deposits HLG directly (`depositAndDistribute`)

**Use cases:**
- Safe already holds HLG tokens
- Bypass ETH → WETH → HLG conversion
- Lower gas costs for existing HLG holdings

**Examples:**
```bash
npx tsx script/ts/multisig-cli.ts deposit --hlg 1000
npx tsx script/ts/multisig-cli.ts deposit --hlg 500 --simulate-only
```

### 3. Ownership Management

**Transfer Ownership (`transfer-ownership`):**
- Provides instructions for current owner to initiate transfer
- Generates transaction data for `transferOwnership(address)`

**Accept Ownership (`accept-ownership`):**
- Generates Safe transaction to accept ownership
- Creates JSON for `acceptOwnership()` function

**Example workflow:**
```bash
# Step 1: Get transfer instructions
npx tsx script/ts/multisig-cli.ts transfer-ownership

# Step 2: Generate acceptance transaction
npx tsx script/ts/multisig-cli.ts accept-ownership
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
```
Error: Missing required Tenderly environment variables: TENDERLY_ACCOUNT
```
- Solution: Add required variables to `.env` or disable Tenderly

**Network Connection Issues:**
```
Error: Failed to fetch staking info
```
- Solution: Check RPC endpoint and network connectivity

**Insufficient Balance Warnings:**
```
Warning: Safe must hold at least 1000 HLG balance
```
- Solution: Verify Safe token balances before execution

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
DEBUG=multisig-cli npx tsx script/ts/multisig-cli.ts batch --eth 0.1
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

## Missing Functionality

The following StakingRewards administrative functions are **NOT YET** available via multisig-cli and currently require cast commands after multisig ownership transfer:

### Administrative Functions
- `setBurnPercentage(uint256)` - Configure burn/reward split percentage
- `setStakingCooldown(uint256)` - Adjust cooldown period (default 7 days)
- `setFeeRouter(address)` - Update fee router address

### Recovery Functions
- `recoverExtraHLG(address,uint256)` - Recover surplus HLG tokens
- `recoverToken(address,address,uint256)` - Recover non-HLG tokens
- `reclaimUnallocatedRewards(address)` - Reclaim unallocated rewards

### Upgrade Functions
- `upgradeToAndCall(address,bytes)` - Upgrade contract implementation

**Current Workaround**: Use cast commands with multisig for these functions. See OPERATIONS.md for specific command examples.

**Future Enhancement**: These functions should be added to multisig-cli to provide complete Safe Transaction Builder JSON generation for all post-handoff operations.