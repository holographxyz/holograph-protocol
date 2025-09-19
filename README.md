# Holograph Protocol

Omnichain token protocol enabling deterministic addresses across multiple blockchains. Built on Doppler with LayerZero V2 for cross-chain messaging.

## Overview

Holograph Protocol creates ERC-20 tokens with identical addresses on all supported chains. The protocol integrates with Doppler's token factory for secure launches and automates fee collection with configurable burn/reward distribution to HLG stakers.

### Key Features

- **Deterministic Addresses**: CREATE2-based deployment ensures consistent addresses across chains
- **Doppler Integration**: Authorized token factory for Doppler Airlock launches
- **Auto-Compounding Staking**: HLG staking rewards with automatic compounding
- **Cross-Chain Fee Collection**: Automated fee bridging and distribution via LayerZero V2
- **Configurable Tokenomics**: Adjustable burn/reward split for protocol sustainability

### Architecture

```
Base Chain                   LayerZero V2              Ethereum Chain
┌─────────────────┐         ┌─────────────┐          ┌─────────────────┐
│ Doppler Airlock │────────▶│             │          │                 │
│       ↓         │         │   Message   │          │                 │
│ HolographFactory│         │   Passing   │          │                 │
│                 │         │             │          │                 │
│ FeeRouter       │────────▶│   (Fees)    │─────────▶│ Fee Processing  │
│                 │         │             │          │                 │
│ HolographERC20  │         │             │          │ StakingRewards  │
└─────────────────┘         └─────────────┘          └─────────────────┘
```

**Primary Chains**: Base (token creation) and Ethereum (fee processing/staking)  
**Additional Support**: Unichain deployment available for expanded reach

## Quick Start

```bash
# Install dependencies
git submodule update --init --recursive
npm install

# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Install git hooks
make install-hooks

# Run tests
make test

# Deploy (dry-run by default)
make deploy-base deploy-eth

# Deploy to mainnet
BROADCAST=true DEPLOYER_PK=0x... make deploy-base deploy-eth
```

## Development

### Essential Commands

```bash
make build          # Compile contracts
make test           # Run test suite
make fmt            # Format code
make clean          # Clean artifacts
make gas-analysis   # Analyze gas costs
make help           # Show all commands
```

### Token Creation

```bash
# Interactive token creation via Doppler
npm run create-token
```

### Multisig Operations

```bash
# Convert ETH to HLG and stake
npx tsx script/ts/multisig-cli.ts batch --eth 0.5

# Direct HLG deposit
npx tsx script/ts/multisig-cli.ts deposit --hlg 1000

# View all commands
npx tsx script/ts/multisig-cli.ts help
```

## Core Contracts

- **HolographFactory**: Doppler-authorized token factory with deterministic deployment
- **FeeRouter**: Cross-chain fee collection and distribution system
- **StakingRewards**: HLG staking with auto-compounding and configurable burn/reward split
- **HolographDeployer**: CREATE2 deployment system for cross-chain address consistency

## Documentation

Comprehensive documentation available in the [`docs/`](docs/) directory:

| Document                                       | Description                           |
| ---------------------------------------------- | ------------------------------------- |
| [Deployment Guide](docs/DEPLOYMENT.md)         | Step-by-step deployment instructions  |
| [Contract Architecture](docs/CONTRACTS.md)     | Detailed contract documentation       |
| [Security](docs/SECURITY.md)                   | Security features and best practices  |
| [Staking Rewards](docs/STAKING_REWARDS.md)     | StakingRewards contract guide     |
| [Protocol Flow](docs/PROTOCOL_FLOW.md)         | System architecture and flow diagrams |
| [Operations Guide](docs/OPERATIONS.md)         | Fee operations, bootstrap flow, and referral batching         |
| [Scripts Overview](docs/SCRIPTS_OVERVIEW.md)   | Deployment and operational scripts    |
| [Token Creation](docs/CREATE_TOKEN.md)         | Token creation utility guide          |
| [Multisig CLI](docs/MULTISIG_CLI.md)           | Safe transaction generator docs       |
| [DVN Configuration](docs/DVN_CONFIGURATION.md) | LayerZero V2 security setup           |
| [Upgrade Guide](docs/UPGRADE_GUIDE.md)         | Contract upgrade procedures           |
| [Audit Reports](docs/audits/)                  | Security audit documentation         |
| [Archive](docs/archive/)                       | Outdated/future work documentation   |

## Testing

```bash
# Run all tests
forge test

# Run with gas report
forge test --gas-report

# Run specific test file
forge test --match-path test/StakingRewards.t.sol

# Run invariant tests
forge test --match-contract StakingRewardsInvariants
```

## Environment Setup

Essential environment variables:

```bash
# Network RPCs
BASE_RPC_URL=https://mainnet.base.org
ETHEREUM_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY

# Deployment
DEPLOYER_PK=0x...      # For deployment
OWNER_PK=0x...         # For administration

# API Keys
BASESCAN_API_KEY=your_key
ETHERSCAN_API_KEY=your_key
```

See [DEPLOYMENT.md](docs/DEPLOYMENT.md) for complete configuration.

## Security

- **Access Control**: Owner-only operations via multisig
- **Cross-Chain Security**: LayerZero V2 with DVN consensus
- **Economic Security**: Configurable burn/reward distribution
- **Emergency Controls**: Pause functionality and recovery mechanisms

See [SECURITY.md](docs/SECURITY.md) for detailed security documentation.

## Dependencies

- [Foundry](https://book.getfoundry.sh/) - Smart contract development framework
- [LayerZero V2](https://layerzero.network/) - Cross-chain messaging protocol
- [Doppler Airlock](https://doppler.lol/) - Token launch mechanism
- [OpenZeppelin](https://openzeppelin.com/) - Security utilities
- [Uniswap V3](https://uniswap.org/) - DEX integration

## License

MIT
