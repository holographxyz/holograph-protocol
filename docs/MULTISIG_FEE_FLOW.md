# Multisig Fee Distribution Flow

This document outlines the complete fee distribution process from 0x Protocol trading fees to HLG staking rewards, using Gnosis Safe multisigs for security.

## 📊 Complete Flow Diagram

```
┌─────────────────────┐
│  0x Protocol Trading │
└──────────┬──────────┘
           │
      Weekly Fees
           │
           ▼
┌─────────────────────┐
│  Multisig on Base   │ ◄── Gnosis Safe (Base)
└──────┬──────────────┘
       │
   50/50 Split
       │
       ├─── 50% ──► ┌──────────┐
       │            │ Treasury │
       │            └──────────┘
       │
       └─── 50% ──► ┌─────────────────────┐
                    │ Bridge to Ethereum  │
                    └──────────┬──────────┘
                               │
                         Superbridge
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Multisig on Ethereum │ ◄── Gnosis Safe (Ethereum)
                    └──────────┬───────────┘
                               │
                      Batch Transaction
                               │
                    ┌──────────▼───────────┐
                    │  1. Swap ETH → WETH  │
                    │  2. Swap WETH → HLG  │
                    │  3. depositAndDistribute │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │   StakingRewards     │
                    └──────────┬───────────┘
                               │
                        50/50 Split
                               │
                 ┌─────────────┴─────────────┐
                 │                           │
                 ▼                           ▼
         ┌──────────────┐           ┌──────────────────┐
         │ Burn (50%)   │           │ Auto-Compound    │
         │ ERC20Burnable│           │ to Stakers (50%) │
         └──────────────┘           └──────────────────┘
```

## 🌉 Step 1: Bridge ETH from Base to Ethereum

### Recommended: Superbridge

#### Mainnet

**Web Interface**: https://superbridge.app

1. **Connect Multisig**:
   - Go to https://superbridge.app
   - Click "Connect Wallet"
   - Choose "WalletConnect"
   - Connect your Gnosis Safe multisig

2. **Bridge Setup**:
   - Select "Base" as source network
   - Select "Ethereum" as destination
   - Enter ETH amount to bridge
   - Destination address: Your Ethereum multisig

3. **Execute Bridge**:
   - Review fees (~$2-5)
   - Click "Bridge"
   - Approve in Gnosis Safe
   - Wait ~10-20 minutes for arrival

#### Testnet (Sepolia)

**Web Interface**: https://testnets.superbridge.app/base-sepolia

- Same process as mainnet
- Bridge Sepolia ETH between Base Sepolia ↔ Ethereum Sepolia
- Perfect for testing the full flow

### Alternative Bridges

| Bridge                   | URL                     | Speed   | Notes                              |
| ------------------------ | ----------------------- | ------- | ---------------------------------- |
| **Official Base Bridge** | https://bridge.base.org | 7 days  | Most secure, slow withdrawal       |
| **Relay Bridge**         | https://www.relay.link  | 2-3 min | Fastest, higher fees, mainnet only |
| **Brid.gg**              | https://brid.gg         | ~15 min | Good alternative, supports testnet |

## 💱 Step 2: Convert ETH to HLG on Ethereum

### Option A: Using Gnosis Safe Transaction Builder (Recommended)

1. **Access Transaction Builder**:
   - Go to https://app.safe.global
   - Connect to your Ethereum multisig
   - Navigate to "Apps" → "Transaction Builder"

2. **Import Batch Transaction**:
   - Click "Upload Batch"
   - Use the JSON generated from our script (see below)
   - Review all 5 transactions
   - Confirm and sign

### Option B: Manual Execution via Web Apps

#### Step 2.1: Wrap ETH to WETH

1. Go to https://app.uniswap.org
2. Connect multisig via WalletConnect
3. Select ETH → WETH
4. Enter amount and click "Wrap"
5. Sign with multisig

#### Step 2.2: Swap WETH to HLG

1. Stay on Uniswap
2. Select WETH → HLG (import HLG token if needed)
3. Enter amount
4. Review price impact (should be <5%)
5. Click "Swap" and sign

#### Step 2.3: Deposit to StakingRewards

1. Go to Etherscan → StakingRewards contract
2. Click "Write Contract" → Connect wallet
3. First approve HLG:
   - Go to HLG token contract
   - Call `approve(spender, amount)`
   - Spender = StakingRewards address
4. Call `depositAndDistribute(amount)`
5. Sign with multisig

### Option C: CoW Swap (MEV Protected)

- Go to https://swap.cow.fi
- Swap ETH → HLG directly with MEV protection
- Then manually deposit to StakingRewards

## 🛠️ Foundry Scripts for Automation

### Complete Fee Processing Script

Create `script/ProcessFees.s.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETH {
    function deposit() external payable;
    function approve(address, uint256) external returns (bool);
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}

interface IQuoterV2 {
    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        external
        returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate);
}

interface IStakingRewards {
    function depositAndDistribute(uint256 amount) external;
}

contract ProcessFees is Script {
    // Ethereum Mainnet addresses
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant QUOTER_V2 = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
    address constant HLG = 0x5Ff07042d14E60EC1de7a860BBE968344431BaA1; // HLG on Sepolia
    address constant STAKING_REWARDS = 0x50D5972b1ACc89F8433E70C7c8C044100E211081; // StakingRewards on Sepolia

    uint24 constant POOL_FEE = 3000; // 0.3%
    uint256 constant SLIPPAGE_BPS = 200; // 2% slippage

    function run() external {
        uint256 ethAmount = vm.envUint("ETH_AMOUNT");

        // Get quote first
        uint256 expectedHlg = getQuote(ethAmount);
        uint256 minHlgOut = (expectedHlg * (10000 - SLIPPAGE_BPS)) / 10000;

        console.log("Processing %s ETH", ethAmount);
        console.log("Expected HLG: %s", expectedHlg);
        console.log("Min HLG (with slippage): %s", minHlgOut);

        vm.startBroadcast();

        // 1. Wrap ETH to WETH
        IWETH(WETH).deposit{value: ethAmount}();
        console.log("✓ Wrapped ETH to WETH");

        // 2. Approve WETH for Swap Router
        IWETH(WETH).approve(SWAP_ROUTER, ethAmount);
        console.log("✓ Approved WETH");

        // 3. Swap WETH to HLG
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: HLG,
                fee: POOL_FEE,
                recipient: address(this),
                deadline: block.timestamp + 1800,
                amountIn: ethAmount,
                amountOutMinimum: minHlgOut,
                sqrtPriceLimitX96: 0
            });

        uint256 hlgReceived = ISwapRouter(SWAP_ROUTER).exactInputSingle(params);
        console.log("✓ Swapped for %s HLG", hlgReceived);

        // 4. Approve HLG for StakingRewards
        IERC20(HLG).approve(STAKING_REWARDS, hlgReceived);
        console.log("✓ Approved HLG");

        // 5. Deposit to StakingRewards
        IStakingRewards(STAKING_REWARDS).depositAndDistribute(hlgReceived);
        console.log("✓ Deposited to StakingRewards");
        console.log("Distribution complete: 50% burned, 50% to stakers");

        vm.stopBroadcast();
    }

    function getQuote(uint256 ethAmount) public returns (uint256) {
        IQuoterV2.QuoteExactInputSingleParams memory params = IQuoterV2
            .QuoteExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: HLG,
                fee: POOL_FEE,
                amountIn: ethAmount,
                sqrtPriceLimitX96: 0
            });

        (uint256 amountOut,,,) = IQuoterV2(QUOTER_V2).quoteExactInputSingle(params);
        return amountOut;
    }

    // Generate batch transaction for Gnosis Safe
    function generateBatch() external view {
        uint256 ethAmount = vm.envUint("ETH_AMOUNT");
        console.log("Generating batch for %s ETH", ethAmount);

        // Output JSON format for Gnosis Safe Transaction Builder
        console.log('[');
        console.log('  {');
        console.log('    "to": "%s",', WETH);
        console.log('    "value": "%s",', ethAmount);
        console.log('    "data": "0xd0e30db0"');
        console.log('  },');
        // ... continue for all 5 transactions
        console.log(']');
    }
}
```

### Running the Scripts

```bash
# 1. Test on Sepolia first
ETH_AMOUNT=100000000000000000 \
forge script script/ProcessFees.s.sol:ProcessFees \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  -vvv

# 2. Generate batch for Gnosis Safe
ETH_AMOUNT=1000000000000000000 \
forge script script/ProcessFees.s.sol:ProcessFees \
  --sig "generateBatch()" \
  --rpc-url $ETHEREUM_RPC_URL

# 3. Execute on mainnet (if not using multisig)
ETH_AMOUNT=1000000000000000000 \
forge script script/ProcessFees.s.sol:ProcessFees \
  --rpc-url $ETHEREUM_RPC_URL \
  --broadcast \
  --verify
```

### TypeScript Helper for Gnosis Safe Batch

Create `scripts/generateBatch.ts`:

```typescript
import {
  createPublicClient,
  http,
  parseAbi,
  encodeFunctionData,
  parseEther,
  formatEther
} from 'viem';
import { mainnet } from 'viem/chains';

const ADDRESSES = {
  WETH: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
  SWAP_ROUTER: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  QUOTER_V2: '0x61fFE014bA17989E743c5F6cB21bF9697530B21e',
  HLG: '0x5Ff07042d14E60EC1de7a860BBE968344431BaA1',
  STAKING_REWARDS: '0x50D5972b1ACc89F8433E70C7c8C044100E211081'
};

async function getQuote(ethAmount: bigint) {
  const client = createPublicClient({
    chain: mainnet,
    transport: http()
  });

  const result = await client.readContract({
    address: ADDRESSES.QUOTER_V2,
    abi: parseAbi([
      'function quoteExactInputSingle((address,address,uint256,uint24,uint160)) returns (uint256,uint160,uint32,uint256)'
    ]),
    functionName: 'quoteExactInputSingle',
    args: [{
      tokenIn: ADDRESSES.WETH,
      tokenOut: ADDRESSES.HLG,
      amountIn: ethAmount,
      fee: 3000,
      sqrtPriceLimitX96: 0n
    }]
  });

  return result[0]; // amountOut
}

export async function generateBatchTransaction(ethAmount: string) {
  const amount = parseEther(ethAmount);
  const expectedHlg = await getQuote(amount);
  const minHlgOut = (expectedHlg * 98n) / 100n; // 2% slippage

  console.log(`Processing ${ethAmount} ETH`);
  console.log(`Expected HLG: ${formatEther(expectedHlg)}`);
  console.log(`Min HLG (2% slippage): ${formatEther(minHlgOut)}`);

  const deadline = Math.floor(Date.now() / 1000) + 1800;

  const transactions = [
    // 1. Wrap ETH
    {
      to: ADDRESSES.WETH,
      value: amount.toString(),
      data: '0xd0e30db0', // deposit()
      operation: '0'
    },

    // 2. Approve WETH
    {
      to: ADDRESSES.WETH,
      value: '0',
      data: encodeFunctionData({
        abi: parseAbi(['function approve(address,uint256)']),
        functionName: 'approve',
        args: [ADDRESSES.SWAP_ROUTER, amount]
      }),
      operation: '0'
    },

    // 3. Swap WETH to HLG
    {
      to: ADDRESSES.SWAP_ROUTER,
      value: '0',
      data: encodeFunctionData({
        abi: parseAbi([
          'function exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))'
        ]),
        functionName: 'exactInputSingle',
        args: [{
          tokenIn: ADDRESSES.WETH,
          tokenOut: ADDRESSES.HLG,
          fee: 3000,
          recipient: process.env.MULTISIG_ADDRESS!,
          deadline: BigInt(deadline),
          amountIn: amount,
          amountOutMinimum: minHlgOut,
          sqrtPriceLimitX96: 0n
        }]
      }),
      operation: '0'
    },

    // 4. Approve HLG
    {
      to: ADDRESSES.HLG,
      value: '0',
      data: encodeFunctionData({
        abi: parseAbi(['function approve(address,uint256)']),
        functionName: 'approve',
        args: [ADDRESSES.STAKING_REWARDS, expectedHlg * 2n] // Approve 2x for safety
      }),
      operation: '0'
    },

    // 5. Deposit to StakingRewards
    {
      to: ADDRESSES.STAKING_REWARDS,
      value: '0',
      data: encodeFunctionData({
        abi: parseAbi(['function depositAndDistribute(uint256)']),
        functionName: 'depositAndDistribute',
        args: [minHlgOut] // Use minimum as a safety measure
      }),
      operation: '0'
    }
  ];

  // Output for Gnosis Safe Transaction Builder
  console.log('\n=== Copy this JSON to Gnosis Safe Transaction Builder ===\n');
  console.log(JSON.stringify(transactions, null, 2));

  return transactions;
}

// Run if called directly
if (require.main === module) {
  const ethAmount = process.argv[2] || '1';
  generateBatchTransaction(ethAmount).catch(console.error);
}
```

Run with:

```bash
# Using the new CLI
npm run multisig-cli batch --eth 1.5

# Or legacy TypeScript approach
npx ts-node scripts/generateBatch.ts 1.5
```

## 📋 Weekly Execution Checklist

### Pre-Flight Checks

- [ ] Check 0x Protocol fees accumulated on Base multisig
- [ ] Verify gas prices on both Base and Ethereum
- [ ] Check HLG/ETH liquidity on Uniswap V3
- [ ] Get current HLG price for slippage calculation

### Execution Flow

#### Week 1 Example (Mainnet)

```
Monday: Fees accumulate from 0x Protocol
Tuesday: Base multisig receives ~10 ETH in fees
Wednesday: Execute distribution
  1. Base Multisig:
     - Send 5 ETH to Treasury
     - Bridge 5 ETH to Ethereum via Superbridge
  2. Wait 15 minutes for bridge
  3. Ethereum Multisig:
     - Execute batch transaction (5 transactions)
     - Converts 5 ETH → ~175,000 HLG
  4. StakingRewards:
     - Burns 87,500 HLG (50%)
     - Distributes 87,500 HLG to stakers (50%)
```

### Step-by-Step Execution

#### 1️⃣ Base Multisig Operations

1. **Access Base Multisig**:

   ```
   https://app.safe.global
   Network: Base
   ```

2. **Send to Treasury** (50%):
   - New Transaction → Send tokens
   - Asset: ETH
   - Amount: 50% of balance
   - Recipient: Treasury address
   - Sign and execute

3. **Bridge to Ethereum** (50%):
   - Go to https://superbridge.app
   - Connect multisig via WalletConnect
   - Select Base → Ethereum
   - Enter amount
   - Bridge to Ethereum multisig address
   - Sign and execute

#### 2️⃣ Wait for Bridge

- Monitor: https://superbridge.app/account
- Expected time: ~10-20 minutes
- Verify receipt on Ethereum multisig

#### 3️⃣ Ethereum Multisig Operations

1. **Generate Batch Transaction**:

   ```bash
   # Run locally to get batch JSON (recommended)
   npm run multisig-cli batch --eth 5
   
   # Or using legacy approach
   npx ts-node scripts/generateBatch.ts 5
   ```

2. **Execute via Transaction Builder**:
   - https://app.safe.global
   - Apps → Transaction Builder
   - Upload batch JSON
   - Review all 5 transactions
   - Collect signatures
   - Execute

3. **Verify Completion**:
   - Check StakingRewards contract for events
   - Verify HLG burn event
   - Confirm staker balances increased

### Post-Execution Verification

```bash
# Check StakingRewards events
cast logs --address $STAKING_REWARDS \
  --from-block latest \
  --rpc-url $ETHEREUM_RPC_URL

# Verify HLG total supply decreased (burn)
cast call $HLG "totalSupply()" --rpc-url $ETHEREUM_RPC_URL

# Check staking pool total
cast call $STAKING_REWARDS "totalStaked()" --rpc-url $ETHEREUM_RPC_URL
```

## 🔐 Security Guidelines

### Multisig Best Practices

1. **Never rush**: Take time to verify amounts and addresses
2. **Double-check**: Have another signer verify independently
3. **Test first**: Always run on Sepolia before mainnet
4. **Document**: Keep records of all transactions

### Transaction Safety

- Set slippage to 2-5% maximum
- For amounts >10 ETH, consider splitting
- Monitor for sandwich attacks
- Use CoW Swap for MEV protection on large swaps

### Emergency Procedures

If something goes wrong:

1. **Bridge delays**: Check explorer, may take up to 2 hours
2. **Failed swap**: Increase slippage or wait for better liquidity
3. **Contract paused**: Contact team to unpause StakingRewards
4. **Wrong address**: For bridges, contact support immediately

## 📊 Reporting Template

After each weekly distribution:

```markdown
## Weekly Fee Distribution Report - [DATE]

### Received
- 0x Protocol Fees: X ETH
- Network: Base

### Distribution
- Treasury (50%): X ETH
- Bridge to Ethereum (50%): X ETH

### Ethereum Operations
- ETH Swapped: X ETH
- HLG Received: X HLG
- Average Price: X ETH/HLG
- Slippage: X%

### StakingRewards Distribution
- HLG Burned: X HLG (50%)
- HLG to Stakers: X HLG (50%)
- New Total Staked: X HLG
- APR Impact: +X%

### Transaction Hashes
- Base Treasury Transfer: 0x...
- Bridge Transaction: 0x...
- Ethereum Batch: 0x...

### Notes
[Any issues or observations]
```

## 🚀 Future Optimizations

### Potential Improvements

1. **Automated Keeper**: Deploy contract to automate swaps
2. **Direct Integration**: 0x Protocol → StakingRewards directly
3. **Multi-path Routing**: Use 1inch or 0x API for best rates
4. **Yield Generation**: Stake ETH while waiting for distribution

### Proposed Automation Contract

Deploy a contract that handles the entire flow:

- Receives ETH from bridge
- Automatically swaps to HLG
- Deposits to StakingRewards
- Single multisig transaction to trigger

This would reduce operational overhead and minimize human error.

## 📚 Additional Resources

- [Gnosis Safe Docs](https://help.safe.global)
- [Superbridge Support](https://superbridge.app/support)
- [Uniswap V3 Docs](https://docs.uniswap.org)
- [Base Bridge Guide](https://docs.base.org/base-chain/bridges)
- [Viem Documentation](https://viem.sh)

## ❓ Troubleshooting FAQ

**Q: Bridge is taking too long?**
A: Superbridge usually takes 10-20 min. Check https://superbridge.app/account for status.

**Q: Swap failing with "STF"?**
A: Increase slippage or reduce amount. Check pool liquidity.

**Q: Can't connect multisig to dApp?**
A: Use WalletConnect, not direct connection. Enable in Safe settings.

**Q: How to verify burn happened?**
A: Check HLG totalSupply() before and after - should decrease by burn amount.

**Q: Testnet faucets?**
A: https://www.alchemy.com/faucets/ethereum-sepolia for Sepolia ETH
