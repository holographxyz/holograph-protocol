# CLAUDE.md - Holograph Protocol Development Guide

## 🛠️ Development Environment

- **Smart Contracts**: Solidity (`^0.8.26`)
- **Framework**: Foundry (Forge, Cast, Anvil)
- **TypeScript**: Node.js (`>=18.0.0`) with TypeScript (`^5.3.3`)
- **Package Manager**: `npm` (with `package.json`)
- **Linting**: ESLint with `@typescript-eslint`
- **Formatting**: Prettier (Solidity + TypeScript)
- **Testing**: Forge tests + Jest/TypeScript
- **Networks**: Base Mainnet, Base Sepolia, Ethereum Mainnet

## 📂 Project Structure

```
holograph-2.0/
├── src/                     # Core Solidity contracts
│   ├── HolographFactory.sol # Main token creation factory
│   ├── FeeRouter.sol        # Cross-chain fee routing
│   ├── StakingRewards.sol   # HLG staking rewards
│   └── interfaces/          # Contract interfaces
├── test/                    # Foundry tests
│   ├── unit/               # Unit tests
│   ├── integration/        # Integration tests
│   └── mock/               # Mock contracts
├── script/                  # Deployment & automation scripts
│   ├── DeployBase.s.sol    # Base chain deployment
│   ├── DeployEthereum.s.sol # Ethereum deployment
│   └── FeeOperations.s.sol      # Owner fee operations
├── lib/                     # Git submodules
│   ├── forge-std/          # Foundry standard library
│   ├── openzeppelin-contracts/
│   └── doppler/            # Doppler protocol integration
├── deployments/            # Deployed contract addresses
├── abis/                   # Generated ABI files
├── docs/                   # Documentation
├── create-token.ts         # TypeScript token creation utility
├── foundry.toml           # Foundry configuration
├── Makefile               # Development commands
└── package.json           # TypeScript dependencies
```

## 📦 Installation & Setup

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
git submodule update --init --recursive
npm install

# Set up environment
cp .env.example .env
# Add your private keys and API keys
```

## ⚙️ Development Commands

### Smart Contract Development

- **Build**: `make build` or `forge build`
- **Test**: `make test` or `forge test -vvv`
- **Format**: `make fmt` or `forge fmt`
- **Clean**: `make clean` or `forge clean`

### Deployment Commands

- **Deploy Base**: `make deploy-base` (dry-run) or `BROADCAST=true make deploy-base`
- **Deploy Ethereum**: `make deploy-eth` (dry-run) or `BROADCAST=true make deploy-eth`
- **Configure**: `make configure-base configure-eth`
- **Keeper**: `make keeper`

### TypeScript Utilities

- **Token Creation**: `npm run create-token`
- **Build TS**: `npm run build`
- **Lint**: `npm run lint`
- **Format**: `npm run format`

## 🧠 Claude Code Usage

- Use `claude /init` to create this file
- Run `claude` in the root of the repo
- Prompt with: `think hard`, `ultrathink` for deep analysis
- Use `claude /compact` to optimize code
- Use `claude /permissions` to whitelist safe tools

## 📌 Prompt Examples

```bash
# Smart Contract Development
Claude, add a new fee collection method to FeeRouter.sol
Claude, optimize gas usage in the HolographFactory createToken function
Claude, write integration tests for cross-chain token bridging
Claude, analyze the security of the keeper role permissions

# TypeScript Development
Claude, refactor create-token.ts to support multiple networks
Claude, add better error handling to the salt mining function
Claude, create a CLI interface for the token creation script
Claude, add contract verification retry logic

# Deployment & Operations
Claude, update the deployment script for a new network
Claude, create monitoring scripts for keeper operations
Claude, add emergency pause functionality to all contracts
Claude, optimize the Makefile for better developer experience
```

## 🧪 Testing Practices

### Foundry Tests

- **Unit Tests**: Test individual contract functions in isolation
- **Integration Tests**: Test cross-contract interactions
- **Fork Tests**: Test against live networks with `--fork-url`
- **Invariant Tests**: Property-based testing for complex systems

### Test Organization

```solidity
// test/unit/FeeRouter.t.sol
contract FeeRouterTest is Test {
    function test_collectFees_success() public { ... }
    function test_collectFees_revertUnauthorized() public { ... }
    function testFuzz_bridgeAmount(uint256 amount) public { ... }
}
```

### TypeScript Tests

- **Jest**: For utility functions and business logic
- **Integration**: Test contract interactions via viem
- **Error Handling**: Test all failure scenarios

## 🔧 Contract Development Guidelines

### Security Patterns

- Use OpenZeppelin contracts for standard functionality
- Implement proper access control (roles, ownership)
- Add pausable functionality for emergency stops
- Use reentrancy guards for external calls
- Validate all inputs and handle edge cases

### Gas Optimization

- Use `unchecked` blocks for safe arithmetic
- Cache storage reads in memory
- Batch operations where possible
- Use assembly for low-level optimizations
- Profile gas usage with `forge test --gas-report`

### Code Style

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract ExampleContract is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 private constant MAX_SUPPLY = 1_000_000e18;

    error InvalidAmount();
    error Unauthorized();

    event TokenCreated(address indexed token, uint256 amount);
}
```

## 🌐 Network Configuration

### Supported Networks

- **Base Mainnet**: Chain ID 8453
- **Base Sepolia**: Chain ID 84532 (testnet)
- **Ethereum Mainnet**: Chain ID 1

### Environment Variables

```bash
# Required for deployment
PRIVATE_KEY=0x...
BASESCAN_API_KEY=your_api_key
ETHERSCAN_API_KEY=your_api_key

# Optional RPC endpoints
BASE_RPC_URL=https://mainnet.base.org
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
ETHEREUM_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/...
```

## 🔍 Protocol-Specific Patterns

### Doppler Integration

- Use Doppler Airlock for token launches
- Implement proper salt mining for CREATE2 addresses
- Handle hook validation and flag requirements
- Integrate with Uniswap V4 pools

### Cross-Chain Operations

- LayerZero V2 for cross-chain messaging (not direct asset bridging)
- LayerZero fees calculated using `quote()` function and deducted from bridged amounts
- Trusted remote configuration for security
- Nonce management for message ordering
- Gas estimation for cross-chain calls
- ETH value passed via `msg.value` to destination chain for asset bridging

### Fee Management

- 50% protocol fee (HOLO_FEE_BPS = 5000)
- 50% treasury allocation
- Automated fee collection via keepers
- Cross-chain fee bridging and distribution

## 📝 Documentation Standards

### Contract Documentation

```solidity
/// @title HolographFactory
/// @notice Factory contract for creating omnichain tokens
/// @dev Integrates with Doppler Airlock for token launches
contract HolographFactory {
    /// @notice Creates a new token with cross-chain capabilities
    /// @param params Token creation parameters
    /// @return asset Address of the created token
    function createToken(CreateParams calldata params) external returns (address asset);
}
```

### TypeScript Documentation

```typescript
/**
 * Creates a new token through the Holograph protocol
 * @param config Token configuration parameters
 * @param privateKey Deployer's private key
 * @returns Transaction hash of the creation transaction
 */
async function createToken(config: TokenConfig, privateKey: string): Promise<Hash> {
    // Implementation
}
```

## 🔐 Security Considerations

### Access Control

- Use role-based permissions (AccessControl)
- Implement proper ownership transfers
- Add emergency pause mechanisms
- Validate all external calls

### Cross-Chain Security

- Verify trusted remotes before processing
- Implement replay protection
- Use proper nonce management
- Validate endpoint authenticity

### Economic Security

- Implement slippage protection
- Add minimum value thresholds
- Use cooldown periods for sensitive operations
- Monitor for unusual activity patterns

## 🚀 Deployment Process

### Pre-Deployment Checklist

- [ ] All tests passing (`forge test`)
- [ ] Gas optimization complete
- [ ] Security review conducted
- [ ] Environment variables configured
- [ ] Network configuration verified

### Deployment Steps

1. **Dry Run**: Test deployment with `make deploy-base`
2. **Deploy**: Set `BROADCAST=true` and deploy
3. **Verify**: Contracts automatically verified on Etherscan
4. **Configure**: Set up cross-chain connections
5. **Monitor**: Implement operational monitoring

## 🔧 Operational Tools

### Keeper Automation

- Automated fee collection from Doppler Airlocks
- Cross-chain fee bridging
- HLG token burn and staking distribution
- Emergency response capabilities

### Monitoring & Alerts

- Contract balance monitoring
- Transaction success rates
- Gas price optimization
- Security event detection

## 🧩 Custom Development Patterns

### Salt Mining

```solidity
// Mine valid CREATE2 salt for hook addresses
function mineValidSalt(bytes32 initCodeHash) internal view returns (bytes32) {
    for (uint256 i = 0; i < MAX_ITERATIONS; i++) {
        bytes32 salt = bytes32(i);
        address predicted = Clones.predictDeterministicAddress(initCodeHash, salt);
        if (isValidHookAddress(predicted)) {
            return salt;
        }
    }
    revert("No valid salt found");
}
```

### Error Handling

```typescript
export class TokenCreationError extends Error {
  constructor(
    message: string,
    public code: string,
    public cause?: Error
  ) {
    super(message);
    this.name = 'TokenCreationError';
  }
}
```

## 📊 Performance Optimization

### Gas Optimization

- Use storage packing for related variables
- Implement batch operations
- Cache frequently accessed storage
- Use events for off-chain data

### TypeScript Optimization

- Implement connection pooling for RPC calls
- Use parallel processing for salt mining
- Cache contract bytecode for CREATE2 calculations
- Implement retry logic with exponential backoff

## 🔄 Upgrade Procedures

### Contract Upgrades

Since contracts are not upgradeable:

1. Deploy new contracts with fixes
2. Pause old contracts
3. Migrate state and funds
4. Update integrations
5. Resume operations

### Emergency Response

1. Immediate pause via emergency multisig
2. Assess and determine fix
3. Deploy hotfix if required
4. Communicate with stakeholders
5. Resume with enhanced monitoring

This development guide provides comprehensive coverage of the Holograph Protocol codebase, emphasizing security, gas optimization, and operational excellence in the omnichain token ecosystem.
