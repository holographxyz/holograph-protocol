# Pull-Based Referral Splits Documentation

This document describes the TypeScript tooling for creating and managing pull-based referral payouts using Splits Protocol V2 and the Warehouse contract.

## Overview

The referral system uses immutable **Pull splits** to distribute trading fees across a fixed allocation:
- **Platform**: 59% (plus any missing tier percentages)
- **Tier 1**: 35%
- **Tier 2**: 3%
- **Tier 3**: 2%
- **Tier 4**: 1%

Each trader gets their own Split contract address, which is passed as `swapFeeRecipient` to 0x Swap API v2. All swap fees land in the Split, then flow through this sequence:

1. Fees accumulate in the **Split contract** (`splitBalance`)
2. **Distribute** moves funds to **Warehouse** accounting (`warehouseBalance`)
3. Recipients **withdraw** from Warehouse to their wallets

No on-chain registry exists; discovery and routing happen off-chain in your application.

## Architecture

```
┌─────────────┐
│   0x Swap   │  swapFeeRecipient = Split Address
└──────┬──────┘
       │ fees
       ▼
┌─────────────┐
│    Split    │  splitBalance > 0
│  (immutable)│
└──────┬──────┘
       │ distribute()
       ▼
┌─────────────┐
│  Warehouse  │  warehouseBalance > 0 (per recipient)
└──────┬──────┘
       │ withdraw()
       ▼
┌─────────────┐
│  Recipient  │  Funds in wallet
│   Wallets   │
└─────────────┘
```

## Setup

### 1. Install Dependencies

```bash
npm install @0xsplits/splits-sdk viem
```

### 2. Environment Configuration

Populate `.env` (or pass flags) with a funded signer and RPC:

```bash
# Base RPCs
BASE_RPC_URL=https://mainnet.base.org          # mainnet
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org  # testnet

# Chain selection (8453 mainnet, 84532 testnet)
BASE_CHAIN_ID=84532

# Signer used for all scripts
DEPLOYER_PRIVATE_KEY=0xYOUR_PRIVATE_KEY

# Optional: enable Splits hosted APIs
SPLITS_API_KEY=your_splits_api_key
```

**Important**
- These scripts interact with Splits contracts using **native ETH** (no wrapping). Ensure the signer funded above has ETH on the target network.
- You may override `--rpc` and `--chainId` per command if preferred.

### 3. Network Support

- **Base Mainnet**: Chain ID `8453`
- **Base Sepolia**: Chain ID `84532`

## Quickstart – Run the full demo

1. Configure `.env` (or export variables) with `BASE_SEPOLIA_RPC_URL`, `BASE_CHAIN_ID=84532`, and `DEPLOYER_PRIVATE_KEY`.
2. Fund the deployer wallet with a small amount of Base Sepolia ETH.
3. Run:

   ```bash
   npx tsx script/ts/splits/demo.ts \
     --platform 0xPlatformAddress \
     --tier1 0xTier1Address \
     --tier2 0xTier2Address \
     --amount 0.05 \
     --chainId 84532 \
     --rpc $BASE_SEPOLIA_RPC_URL
   ```

   Replace the addresses with real recipients. The script will create the split, fund it with ETH, distribute, and withdraw for each tier so you can observe the entire pull flow locally.

## Scripts

All scripts are located in [`script/ts/splits/`](../script/ts/splits/).

### Create Pull Split

Creates an immutable Pull split with platform and tier addresses.

**Usage:**
```bash
npx tsx script/ts/splits/create-pull-split.ts \
  --platform 0xPlatform... \
  --tier1 0xTier1... \
  --tier2 0xTier2... \
  --tier3 0xTier3... \
  --tier4 0xTier4... \
  --chainId 84532 \
  --rpc $BASE_SEPOLIA_RPC_URL
```

Replace the placeholder addresses (and `--chainId/--rpc` if targeting mainnet). Omit tiers you do not have; their percentages roll into the platform share.

**Parameters:**
- `--platform` (required): Platform fee recipient address
- `--tier1`, `--tier2`, `--tier3`, `--tier4` (optional): Tier recipient addresses
- `--salt` (optional): Deterministic salt for CREATE2 address prediction
- `--rpc` (optional): Override RPC URL
- `--chainId` (optional): Override chain ID

**Output:**
- Split address (use as `swapFeeRecipient`)
- Transaction hash
- Gas used
- Deployment confirmation

**Notes:**
- Missing tiers automatically roll their percentages into platform
- Splits require at least two recipients, so supply at least one tier address when creating a split
- Split is immutable (owner = `AddressZero`)
- If a tier is wrong, create a new Split and update off-chain

### Get Balances

Shows the current ETH balances held by the Split and recorded in Warehouse.

**Usage:**
```bash
npx tsx script/ts/splits/get-balances.ts \
  --split 0xSplitAddressHere \
  --chainId 84532 \
  --rpc $BASE_SEPOLIA_RPC_URL
```

**Parameters:**
- `--split` (required): Split contract address
- `--rpc` (optional): Override RPC URL
- `--chainId` (optional): Override chain ID

**Output:**
- Split balance (ETH held by the split contract)
- Warehouse balance (ETH credited to recipients)
- Total balance and human-readable status

### Distribute

Moves accumulated ETH from the Split into Warehouse accounting using the pull model.

**Usage:**
```bash
npx tsx script/ts/splits/distribute.ts \
  --split 0xSplitAddressHere \
  --chainId 84532 \
  --rpc $BASE_SEPOLIA_RPC_URL
```

**Parameters:**
- `--split` (required): Split contract address
- `--rpc` (optional): Override RPC URL
- `--chainId` (optional): Override chain ID

**Output:**
- Pre/post distribution balances
- Transaction hash
- Gas used
- Amount distributed (in ETH)

**Notes:**
- After distribution, `splitBalance` becomes 0
- Recipients' `warehouseBalance` increases proportionally
- Recipients can now withdraw their shares

### Withdraw

Pulls a recipient's ETH balance from Warehouse into their wallet.

**Usage:**
```bash
npx tsx script/ts/splits/withdraw.ts \
  --owner 0xRecipientAddress \
  --chainId 84532 \
  --rpc $BASE_SEPOLIA_RPC_URL
```

**Parameters:**
- `--owner` (required): Recipient address to withdraw for
- `--rpc` (optional): Override RPC URL
- `--chainId` (optional): Override chain ID

**Output:**
- Pre/post Warehouse balance and wallet ETH balance
- Transaction hash
- Gas used
- Amount withdrawn

### Batch Withdraw

Withdraws balances for multiple tokens in one transaction (defaults to ETH only).

**Usage (ETH only):**
```bash
npx tsx script/ts/splits/batch-withdraw.ts \
  --owner 0xRecipientAddress \
  --tokens native \
  --chainId 84532 \
  --rpc $BASE_SEPOLIA_RPC_URL
```

Include additional token addresses in `--tokens` (comma separated) if the recipient has ERC20 balances recorded in Warehouse. Use `--withdrawer 0x...` when the claim should be sent to a different address.

**Parameters:**
- `--owner` (required): Recipient whose balances you are claiming
- `--tokens` (optional): Comma-separated token list (defaults to `native`)
- `--withdrawer` (optional): Address that should receive the withdrawn funds (defaults to owner)
- `--rpc` (optional): Override RPC URL
- `--chainId` (optional): Override chain ID

**Output:**
- Pre/post Warehouse balances for each token
- Transaction hash and gas usage
- Summary of amounts withdrawn

**Notes:**
- Automatically skips tokens with zero balances
- `native` resolves to Splits’ native ETH sentinel (`0xEeeeeE...`); funds remain ETH (no WETH wrapping)
- Useful when recipients accrue multiple fee assets alongside ETH

### Demo (End-to-End)

Runs the entire pull-based flow with native ETH.

**Usage (Base Sepolia example):**
```bash
npx tsx script/ts/splits/demo.ts \
  --platform 0xPlatformAddress \
  --tier1 0xTier1Address \
  --tier2 0xTier2Address \
  --amount 0.10 \
  --chainId 84532 \
  --rpc $BASE_SEPOLIA_RPC_URL
```

Replace the addresses with live values. Provide at least one tier recipient (Splits requires two recipients in total).

**Parameters:**
- `--platform` (required): Platform recipient address
- `--amount` (required): ETH amount to fund the split
- `--tier1`, `--tier2`, `--tier3`, `--tier4` (optional): Tier recipient addresses
- `--rpc` (optional): Override RPC URL
- `--chainId` (optional): Override chain ID

**Flow:**
1. Create pull split
2. Fund split with native ETH
3. Verify balances (expect `splitBalance > 0`, `warehouseBalance == 0`)
4. Distribute to Warehouse (`splitBalance == 0`, `warehouseBalance > 0`)
5. Withdraw ETH for each recipient
6. Report final allocations received

**Output:**
- Step-by-step progress
- All transaction hashes
- Final Split address for use as `swapFeeRecipient`

## Example Workflow

### 1. Create a Split for a New User

```bash
npm run splits:create -- \
  --platform 0xYourPlatform \
  --tier1 0xReferrer \
  --chainId 84532 \
  --rpc $BASE_SEPOLIA_RPC_URL
```

Output:
```
✅ Split created: 0xABC123...
```

### 2. Configure 0x Swap API

In your app, when calling 0x Swap API v2:

```typescript
const quote = await fetch('https://api.0x.org/swap/v2/quote', {
  method: 'POST',
  body: JSON.stringify({
    chainId: 8453,
    sellToken: '0x...',
    buyToken: '0x...',
    sellAmount: '1000000',
    swapFeeRecipient: '0xABC123...', // Split address from step 1
    swapFeeBps: 25, // 0.25%
    swapFeeToken: 'sellToken',
    // ... other params
  })
});
```

### 3. Fees Accumulate in Split

Over time, swap fees accumulate in the Split contract.

Check balances:
```bash
npm run splits:balances -- \
  --split 0xABC123... \
  --chainId 84532 \
  --rpc $BASE_SEPOLIA_RPC_URL
```

Output:
```
Split Balance:     0.125 ETH
Warehouse Balance: 0 ETH
⏳ Funds are in the Split. Run distribute to move to Warehouse.
```

### 4. Distribute to Warehouse

```bash
npm run splits:distribute -- \
  --split 0xABC123... \
  --chainId 84532 \
  --rpc $BASE_SEPOLIA_RPC_URL
```

Output:
```
✅ Distribution complete!
Split Balance:     0 ETH
Warehouse Balance: 0.125 ETH
```

### 5. Recipients Withdraw

Platform withdraws:
```bash
npm run splits:withdraw -- \
  --owner 0xYourPlatform \
  --chainId 84532 \
  --rpc $BASE_SEPOLIA_RPC_URL
```

Tier 1 withdraws:
```bash
npm run splits:withdraw -- \
  --owner 0xReferrer \
  --chainId 84532 \
  --rpc $BASE_SEPOLIA_RPC_URL
```

Output:
```
✅ Funds successfully withdrawn to recipient wallet!
Amount Withdrawn: 0.044 ETH
```

## Integration with 0x Swap API v2

Reference: [0x Docs - Upgrading to Gasless API v2](https://0x.org/docs/upgrading/upgrading_to_gasless_v2)

When calling 0x Swap API v2, pass the Split address as `swapFeeRecipient`:

```typescript
{
  swapFeeRecipient: userSplitAddress, // From create-pull-split
  swapFeeBps: 25,                     // 0.25% fee
  swapFeeToken: 'sellToken',          // or 'buyToken'
}
```

All fees from that swap will be sent to the Split address.

## Splits V2 SDK References

- [Splits V2 SDK](https://docs.splits.org/sdk/splits-v2)
- [Warehouse SDK](https://docs.splits.org/sdk/warehouse)

Key functions used:
- `createSplit`: Create immutable Pull split
- `getSplitBalance`: Check balances in Split and Warehouse
- `distribute`: Move funds from Split to Warehouse
- `withdraw`: Withdraw from Warehouse to wallet
- `batchWithdraw`: Withdraw multiple tokens at once
- `predictDeterministicAddress`: Predict CREATE2 address with salt
- `isDeployed`: Verify split deployment

## Pull Model vs Push Model

### Pull Model (Used Here)
- **Recipients call `withdraw()`** to claim their shares from Warehouse
- Gas paid by recipient
- More flexible; recipients withdraw when they want
- No incentive mechanism needed (no distributor fee)

### Push Model (Not Used)
- Funds pushed directly to recipient wallets during distribution
- Gas paid by distributor
- Can include distributor incentive fee

Our referral system uses Pull for flexibility and to let recipients manage their own gas costs.

## Notes

- **Immutability**: Splits are immutable (owner = `AddressZero`). If you need to change allocations, create a new Split and update off-chain.
- **No On-Chain Registry**: Discovery is off-chain. Your app maps users to Split addresses.
- **Native Token**: The string `native` maps to Splits’ native ETH sentinel (`0xEeeeeE...`); fees remain ETH throughout the flow.
- **Gas Estimation**: All write scripts include gas estimation before execution.
- **Idempotency**: Scripts are safe to re-run; they check balances and skip if nothing to do.

## Troubleshooting

### "No funds to distribute"
The Split balance is 0. Ensure fees are being sent to the Split address via 0x swaps.

### "No funds to withdraw"
The recipient's Warehouse balance is 0. Run `distribute` first to move funds from Split to Warehouse.

### "Invalid address"
Ensure all addresses are checksummed. The scripts auto-validate with `getAddress()`.

### "Unsupported chain ID"
Only Base (8453) and Base Sepolia (84532) are supported. Update `lib/splits-clients.ts` to add more chains.

## Security Considerations

- **Private Keys**: Never commit `.env` files with real private keys
- **Testnet First**: Test on Base Sepolia before mainnet
- **Immutable Splits**: Double-check addresses before creating; splits cannot be modified
- **Off-Chain Mapping**: Secure your user-to-split mapping database
- **Withdrawal Access**: Only the recipient can withdraw their Warehouse balance

## Next Steps

1. Create splits for your users with `create-pull-split`
2. Pass Split addresses to 0x Swap API as `swapFeeRecipient`
3. Periodically run `distribute` to move fees to Warehouse
4. Build a UI for recipients to view balances and withdraw
5. Consider batching withdrawals for gas efficiency

For business context, see O1 Exchange's referral system which uses a similar pull-based claiming model.
