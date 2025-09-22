# Uniswap V3 HLG/WETH Pool Setup (Sepolia)

This guide provides a comprehensive understanding of Uniswap V3 concepts in the context of our HLG/WETH pool operations, along with practical setup instructions and troubleshooting based on real implementation experience.

## 📚 Understanding Uniswap V3 Concepts

### Fee Tiers and Tick Spacing

Uniswap V3 introduces concentrated liquidity through discrete price ranges defined by "ticks". Different fee tiers have different tick spacings, affecting the precision of liquidity positioning:

| Fee Tier | Percentage | Tick Spacing | Best For | Example Use Case |
|----------|------------|--------------|----------|------------------|
| 500 | 0.05% | 10 | Stable pairs | USDC/USDT, stablecoins |
| 3000 | 0.3% | 60 | Standard pairs | ETH/USDC, most tokens |
| 10000 | 1% | 200 | Volatile pairs | New tokens, high volatility |

**For HLG/WETH Operations:**
- **500 basis points**: Use when HLG price is stable relative to ETH
- **3000 basis points**: Default choice for normal volatility (recommended)
- **10000 basis points**: Use during high volatility periods

```bash
# Force specific fee tier in our scripts
export REQUIRED_FEE_TIER=500    # Force 0.05% pool
export PREFER_FEE_TIER=3000     # Prefer 0.3% with fallback
```

### Tick Math and Price Ranges

**Key Concepts:**
- **Ticks** represent discrete price points: `price = 1.0001^tick`
- **Tick Spacing** determines valid tick positions (must be multiples)
- **Current Tick** represents the current pool price
- **Price Ranges** are defined by `tickLower` and `tickUpper`

**Practical Examples:**
```solidity
// Current pool at tick 0 means price = 1.0001^0 = 1.0
// Tick 6931 ≈ 2.0 price ratio
// Tick -6931 ≈ 0.5 price ratio

// For 3000 fee tier (spacing = 60):
// Valid ticks: -6900, -6840, -6780, ..., 0, 60, 120, ...
// Invalid tick: -6850 (not divisible by 60)
```

### Single-Sided vs Balanced Liquidity

**Balanced Liquidity (Traditional):**
- Range straddles current price
- Requires both tokens at mint
- Provides active liquidity immediately
- Example: Range [-3000, +3000] around current tick

**Single-Sided Liquidity (Advanced):**
- Range entirely above OR below current price
- Requires only one token at mint
- Becomes active when price moves into range

**Token0-Only Strategy:**
```bash
# Place liquidity ABOVE current price
# Only HLG required, activated when price rises
MINT_HLG=50000000000000000000000000 MINT_WETH=0 forge script CreateHLGWETHPool --broadcast
```

**Token1-Only Strategy:**
```bash
# Place liquidity BELOW current price  
# Only WETH required, activated when price falls
MINT_HLG=0 MINT_WETH=50000000000000000 forge script CreateHLGWETHPool --broadcast
```

### Price Encoding (sqrtPriceX96)

Uniswap V3 encodes prices as `sqrtPriceX96 = sqrt(price) * 2^96`:

```javascript
// Convert real-world price to sqrtPriceX96
// Example: 2.81e-8 WETH per HLG
const price = 0.0000000281;
const sqrtPrice = Math.sqrt(price);
const sqrtPriceX96 = sqrtPrice * (2 ** 96);

// In Solidity (our implementation):
function _encodeSqrtPriceX96FromPriceE18(uint256 priceE18) internal pure returns (uint160) {
    uint256 sqrtValue = _sqrt(priceE18);
    uint256 Q96 = 0x1000000000000000000000000;  // 2**96
    uint256 result = (sqrtValue * Q96) / 1e9;
    return uint160(result);
}
```

### Liquidity Mining and Rewards

**Understanding Liquidity Positions:**
- Each position is an NFT with unique ID
- Contains specific price range and liquidity amount
- Earns fees only when price is within range
- Can be increased, decreased, or collected from

**Fee Accumulation:**
- Fees accrue continuously when price is in range
- Collected via `collect()` function on PositionManager
- Split between token0 and token1 based on trading activity

## ✅ Deployed Pool Details
- **Pool Address**: [`0x333A14e3e32D8905432b9A70903c473A57dD5E2b`](https://sepolia.etherscan.io/address/0x333A14e3e32D8905432b9A70903c473A57dD5E2b)
- **Status**: Live with liquidity
- **Initial Price**: 1 HLG = 0.0000000281 ETH (based on market rates)
- **LP NFT**: Token ID 202,773

## Addresses (Sepolia)
- **Uniswap v3 Factory**: `0x0227628f3F023bb0B980b67D528571c95c6DaC1c`
- **NonfungiblePositionManager (NPM)**: `0x1238536071E1c677A632429e3655c799b22cDA52`
- **WETH**: `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14`
- **HLG**: `0x5Ff07042d14E60EC1de7a860BBE968344431BaA1`
- **Fee tier**: `3000` (0.3%)

Script: `script/CreateHLGWETHPool.s.sol`

## Prerequisites
- Foundry installed and up to date (`foundryup`)
- Repo builds clean: `forge build`
- `.env` configured (you likely already have these):
  - `DEPLOYER_PK=0x...`
  - `ETHEREUM_SEPOLIA_RPC_URL=...`
- Deployer wallet funded with:
  - Sepolia ETH (gas + optional WETH wrap)
  - HLG (you already have Sepolia HLG)
  - WETH (only if you plan to add WETH-side liquidity)

### Getting Sepolia WETH
1) Get Sepolia ETH from a faucet (any reputable Sepolia ETH faucet works).

2) Wrap ETH into WETH by calling `deposit()` on the Sepolia WETH contract:
```bash
# Wrap 0.3 ETH to have enough for liquidity provision
cast send 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 'deposit()' \
  --value 300000000000000000 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $DEPLOYER_PK
```

3) Verify balances (optional):
```bash
cast call 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 'balanceOf(address)(uint256)' $YOUR_ADDRESS \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```

4) To unwrap back to ETH (optional):
```bash
cast send 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 'withdraw(uint256)' 100000000000000000 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $DEPLOYER_PK
```

## Environment Variables
Use your existing `.env` values to avoid drift with the rest of the repo:

- **Required**
  - `DEPLOYER_PK` (already present in your `.env`)
  - `ETHEREUM_SEPOLIA_RPC_URL` (already present in your `.env`)

- **Optional**
  - `INIT_PRICE_E18` — token1-per-token0 price scaled by 1e18 (default: `1e15` = 0.001 WETH per 1 HLG)
  - `MINT_HLG` — amount of HLG (wei) to deposit as token0 liquidity (default: 0, skip mint)
  - `MINT_WETH` — amount of WETH (wei) to deposit as token1 liquidity (default: 0, skip mint)
  - `SLIPPAGE_BPS` — slippage protection in basis points (default: `500` = 5%)
  - `RECIPIENT` — LP NFT recipient (default: `tx.origin`)

## 🎯 Successful Deployment Example

Based on market rates ($0.0001275/HLG, $4,535.84/ETH):

```bash
# Step 1: Load environment and set recipient
source .env
export RECIPIENT=$(cast wallet address --private-key $DEPLOYER_PK)

# Step 2: Create pool with realistic pricing (if doesn't exist)
export INIT_PRICE_E18=28100000000              # 0.0000000281 ETH per HLG
unset MINT_HLG MINT_WETH SLIPPAGE_BPS           # Pool creation only
forge script script/CreateHLGWETHPool.s.sol:CreateHLGWETHPool \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --broadcast

# Step 3: Add balanced liquidity with zero slippage protection
export MINT_WETH=50000000000000000              # 0.05 WETH
export MINT_HLG=1779370000000000000000000       # ~1.78M HLG (balanced ratio)
export SLIPPAGE_BPS=10000                       # 100% = mins set to 0
forge script script/CreateHLGWETHPool.s.sol:CreateHLGWETHPool \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --broadcast
```

## Running the Script
- Dry run:
```bash
forge script script/CreateHLGWETHPool.s.sol:CreateHLGWETHPool --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```

- Broadcast transactions:
```bash
forge script script/CreateHLGWETHPool.s.sol:CreateHLGWETHPool --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --broadcast
```

The script will:
1. Sort tokens by address (`token0`, `token1`).
2. Compute `sqrtPriceX96` from `INIT_PRICE_E18` (assumes both tokens use 18 decimals).
3. Call `createAndInitializePoolIfNecessary(token0, token1, 3000, sqrtPriceX96)` if the pool does not exist.
4. If `MINT_HLG` or `MINT_WETH` > 0, approve NPM and mint a full-range position `[MIN_TICK, MAX_TICK]` with simple slippage checks.

## Verifying
- Check if the pool exists:
```bash
cast call 0x0227628f3F023bb0B980b67D528571c95c6DaC1c \
  'getPool(address,address,uint24)(address)' \
  0x5Ff07042d14E60EC1de7a860BBE968344431BaA1 \
  0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 \
  3000 --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```

- LP NFT will be emitted by the NonfungiblePositionManager `mint` transaction logs.

## 🚨 Critical Success Tips

### Liquidity Addition
- **Always use balanced amounts**: Calculate `MINT_HLG = MINT_WETH / price_ratio` 
- **Set SLIPPAGE_BPS=10000**: This sets `amount0Min` and `amount1Min` to zero, preventing "Price slippage check" reverts
- **Use realistic pricing**: Base prices on current market data (see CoinMarketCap)
- **Ensure sufficient WETH**: Wrap enough ETH beforehand (recommended: 0.3+ ETH)

### Troubleshooting

#### Common Errors and Solutions

**SwapRouter Interface Errors:**
- **Problem**: `exactInputSingle()` reverts with wrong parameters
- **Root Cause**: SwapRouter V1 vs V2 interface differences  
- **Solution**: SwapRouter02 does NOT have `deadline` parameter
```solidity
// ❌ Wrong (SwapRouter V1)
exactInputSingle((tokenIn, tokenOut, fee, recipient, deadline, amountIn, amountOutMinimum, sqrtPriceLimitX96))

// ✅ Correct (SwapRouter02) 
exactInputSingle((tokenIn, tokenOut, fee, recipient, amountIn, amountOutMinimum, sqrtPriceLimitX96))
```

**Pool Pricing Issues:**
- **Problem**: Pool price is 387x higher than mainnet
- **Root Cause**: Wrong initialization price or insufficient liquidity  
- **Solution**: Use realistic mainnet-based pricing
```bash
# Calculate from real market data
HLG_PRICE_USD=0.0001275
ETH_PRICE_USD=4535.84
WETH_PER_HLG=$(echo "$HLG_PRICE_USD / $ETH_PRICE_USD" | bc -l)
# Result: 0.0000000281 WETH per HLG
export INIT_PRICE_E18=28100000000
```

**RewardTooSmall Errors (in multisig-cli):**
- **Problem**: `(rewardAmount * 1e12) / activeStaked < 1`
- **Root Cause**: Not enough HLG being swapped relative to total staked
- **Solution**: Auto-scaling is built into multisig-cli, or increase ETH amount

**Single-Sided Liquidity Failures:**
- **Problem**: Position requires both tokens even with single-sided intent
- **Root Cause**: Range includes current price
- **Solution**: Position ranges entirely above/below current tick
```bash
# Token0-only: Place ABOVE current price (only HLG needed)
MINT_HLG=50000000000000000000000000 MINT_WETH=0 forge script CreateHLGWETHPool --broadcast

# Token1-only: Place BELOW current price (only WETH needed)  
MINT_HLG=0 MINT_WETH=50000000000000000 forge script CreateHLGWETHPool --broadcast
```

**Classic Errors:**
- **"STF" error**: Not enough WETH balance - wrap more ETH
- **"Price slippage check"**: Use `SLIPPAGE_BPS=10000` to disable minimum amount checks
- **Pool creation fails**: Check if pool already exists first
- **Invalid amounts**: Ensure amounts are balanced according to the initialized price

### Price Calculation Example
For current market rates:
```
HLG Price: $0.0001275
ETH Price: $4,535.84
Price Ratio: 0.0001275 / 4535.84 = 0.0000000281 ETH per HLG
INIT_PRICE_E18: 28100000000 (0.0000000281 * 1e18)
```

### Verification Commands
```bash
# Check if pool exists
cast call 0x0227628f3F023bb0B980b67D528571c95c6DaC1c \
  'getPool(address,address,uint24)(address)' \
  0x5Ff07042d14E60EC1de7a860BBE968344431BaA1 \
  0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 \
  3000 --rpc-url $ETHEREUM_SEPOLIA_RPC_URL

# Check pool liquidity
cast call 0x5Ff07042d14E60EC1de7a860BBE968344431BaA1 \
  "balanceOf(address)(uint256)" \
  0x333A14e3e32D8905432b9A70903c473A57dD5E2b \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL

# Confirm HLG decimals (expected 18)
cast call 0x5Ff07042d14E60EC1de7a860BBE968344431BaA1 'decimals()(uint8)' \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```

## 🔄 Token Swapping Guide

Now that the HLG/WETH pool is live with liquidity, you can perform token swaps on Ethereum Sepolia testnet.

### Swap Addresses (Sepolia)
- **Uniswap V3 SwapRouter**: `0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E`
- **Pool Address**: `0x333A14e3e32D8905432b9A70903c473A57dD5E2b`
- **HLG Token**: `0x5Ff07042d14E60EC1de7a860BBE968344431BaA1`
- **WETH Token**: `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14`

### Web Interface Trading
The easiest way to test swapping is through the Uniswap web interface:

#### Important: Enable Testnet Mode First!

1. **Enable Testnet Mode:**
   - Go to https://app.uniswap.org
   - Click the **Settings gear icon** (⚙️) in the top right
   - Toggle **"Testnet mode"** to ON
   - The interface will reload with testnet support

2. **Switch to Sepolia:**
   - Connect your wallet (make sure MetaMask is on Sepolia)
   - Click the network selector near your address
   - Select **Sepolia** from the dropdown

3. **Wrap ETH to WETH First:**
   - The pool uses WETH, not ETH directly
   - In Uniswap, select ETH as the top token
   - Select WETH (`0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14`) as the bottom token
   - Enter amount to wrap and click "Wrap"
   - Confirm the transaction

4. **Import HLG Token:**
   - Click "Select token"
   - Paste HLG address: `0x5Ff07042d14E60EC1de7a860BBE968344431BaA1`
   - Click "Import" and acknowledge

5. **Swap Between HLG and WETH:**
   - Select WETH and HLG as your pair
   - Enter swap amount
   - Review and confirm transaction

**Note**: You need WETH to trade in this pool, not ETH. Always wrap ETH → WETH first!

### Command Line Swapping

#### Swap HLG for WETH
```bash
# Set up environment
source .env
SWAPPER_ADDRESS=$(cast wallet address --private-key $DEPLOYER_PK)
SWAP_ROUTER=0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E

# Example: Swap 1000 HLG for WETH
HLG_AMOUNT=1000000000000000000000  # 1000 HLG (18 decimals)

# 1. Approve SwapRouter to spend HLG
cast send 0x5Ff07042d14E60EC1de7a860BBE968344431BaA1 \
  'approve(address,uint256)' \
  $SWAP_ROUTER $HLG_AMOUNT \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $DEPLOYER_PK

# 2. Execute swap using exactInputSingle
# Parameters: (tokenIn, tokenOut, fee, recipient, deadline, amountIn, amountOutMinimum, sqrtPriceLimitX96)
cast send $SWAP_ROUTER \
  'exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))' \
  "(0x5Ff07042d14E60EC1de7a860BBE968344431BaA1,0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,3000,$SWAPPER_ADDRESS,$(($(date +%s) + 1800)),$HLG_AMOUNT,0,0)" \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $DEPLOYER_PK
```

#### Swap WETH for HLG
```bash
# Example: Swap 0.001 WETH for HLG
WETH_AMOUNT=1000000000000000  # 0.001 WETH (18 decimals)

# 1. Approve SwapRouter to spend WETH
cast send 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 \
  'approve(address,uint256)' \
  $SWAP_ROUTER $WETH_AMOUNT \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $DEPLOYER_PK

# 2. Execute swap
cast send $SWAP_ROUTER \
  'exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))' \
  "(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,0x5Ff07042d14E60EC1de7a860BBE968344431BaA1,3000,$SWAPPER_ADDRESS,$(($(date +%s) + 1800)),$WETH_AMOUNT,0,0)" \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $DEPLOYER_PK
```

### Get Swap Quotes

Before executing swaps, you can get quotes to see expected output amounts:

```bash
# Get quote for HLG → WETH swap (1000 HLG)
cast call 0x61fFE014bA17989E743c5F6cB21bF9697530B21e \
  'quoteExactInputSingle((address,address,uint24,uint256,uint160))' \
  "(0x5Ff07042d14E60EC1de7a860BBE968344431BaA1,0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,3000,1000000000000000000000,0)" \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL

# Get quote for WETH → HLG swap (0.001 WETH)
cast call 0x61fFE014bA17989E743c5F6cB21bF9697530B21e \
  'quoteExactInputSingle((address,address,uint24,uint256,uint160))' \
  "(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,0x5Ff07042d14E60EC1de7a860BBE968344431BaA1,3000,1000000000000000,0)" \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```

### Check Token Balances
```bash
# Check your HLG balance
cast call 0x5Ff07042d14E60EC1de7a860BBE968344431BaA1 \
  'balanceOf(address)(uint256)' $YOUR_ADDRESS \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL

# Check your WETH balance
cast call 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 \
  'balanceOf(address)(uint256)' $YOUR_ADDRESS \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```

### Important Notes
- **Pool Fee**: 0.3% fee tier (3000)
- **Slippage**: Set to 0 in examples above - adjust based on trade size
- **Deadline**: Set to 30 minutes (1800 seconds) from current time
- **Minimum Output**: Set to 0 for simplicity - use proper slippage protection for real trades
- **Quote Contract**: `0x61fFE014bA17989E743c5F6cB21bF9697530B21e` (Quoter V2 on Sepolia)
