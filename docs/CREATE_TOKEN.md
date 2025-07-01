# Token Creation Tool

TypeScript utility for deploying ERC20 tokens via Holograph protocol on Base network.

## Overview

This tool interfaces with the deployed HolographFactory contract to create tokens through the Doppler protocol integration. It handles parameter encoding, transaction management, and provides structured logging for production environments.

## Requirements

- Node.js >= 18.0.0
- TypeScript 5.x
- Private key with ETH on Base mainnet

## Installation

```bash
npm install
```

## Configuration

Set environment variables:

```bash
export PRIVATE_KEY="0x your_private_key_here"
```

## Usage

### CLI Execution

```bash
npm run create-token
```

### Programmatic Usage

```typescript
import { createToken, TokenConfig } from './create-token.js'
import { parseEther } from 'viem'

const config: TokenConfig = {
  name: "Custom Token",
  symbol: "CTK",
  initialSupply: parseEther("1000000"),
  minProceeds: parseEther("100"),
  maxProceeds: parseEther("10000"),
  auctionDurationDays: 3
}

const result = await createToken(config, process.env.PRIVATE_KEY)
```

### Configuration Presets

```typescript
import { STANDARD_TOKEN, GOVERNANCE_TOKEN } from './config.example.js'

const result = await createToken(STANDARD_TOKEN, privateKey)
```

## Contract Addresses

| Contract | Address |
|----------|---------|
| HolographFactory | `0x5290Bee84DC83AC667cF9573eC1edC6FE38eFe50` |
| FeeRouter | `0x9094869232c58B62B85041981cF24aBfcd958977` |

## Token Launch Process

1. **Token Deployment**: ERC20 contract via Doppler TokenFactory
2. **Governance Setup**: DAO creation with configurable parameters
3. **Auction Configuration**: Uniswap V4 bonding curve parameters
4. **Fee Integration**: Automatic FeeRouter integration

## Parameters

### TokenConfig Interface

```typescript
interface TokenConfig {
  name: string                 // Token display name
  symbol: string               // Token symbol (3-5 characters)
  initialSupply: bigint        // Total token supply in wei
  minProceeds: bigint          // Minimum ETH to complete auction
  maxProceeds: bigint          // Maximum ETH auction can raise
  auctionDurationDays: number  // Auction duration in days
}
```

### Default Governance Settings

- Voting delay: 7,200 blocks (~1 day)
- Voting period: 50,400 blocks (~1 week)
- Proposal threshold: 0 tokens

### Default Pool Settings

- Price range: ticks 6,000 - 60,000
- Epoch length: 400 seconds
- Fee tier: 0.3%
- Auction slices: 8

## Development

### Available Scripts

```bash
npm run build          # Compile TypeScript
npm run dev            # Watch mode development
npm run type-check     # Type checking only
npm run lint           # ESLint validation
npm run format         # Prettier formatting
npm run clean          # Remove build artifacts
```

### Error Handling

The tool implements structured error handling with the `TokenCreationError` class:

```typescript
export class TokenCreationError extends Error {
  constructor(message: string, public code: string, public cause?: Error)
}
```

Error codes:
- `TRANSACTION_FAILED`: On-chain transaction reverted
- `CREATION_FAILED`: General creation process failure

### Logging

Structured JSON logging format:

```json
{
  "level": "info",
  "context": "TokenCreator",
  "message": "Token created successfully",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "hash": "0x...",
  "gasUsed": "750000"
}
```

## Network Configuration

- **Chain**: Base Mainnet (8453)
- **RPC**: Default Viem Base RPC endpoint
- **Explorer**: https://basescan.org

## Gas Estimation

Typical gas usage:
- Token creation: 500,000 - 1,000,000 gas
- Gas buffer: 20% above estimate

## Security Considerations

- Private keys must be kept secure
- Transactions are irreversible on mainnet
- Validate all parameters before execution
- Monitor gas prices for cost optimization

## License

MIT
