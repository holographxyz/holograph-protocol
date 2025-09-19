# Safe SDK Integration - Future Work Plan

This document outlines the roadmap for completing the Safe SDK integration to enable direct transaction execution and proposal submission from the multisig CLI, built on our existing viem-based architecture.

## 🎯 Current Status

The foundation for Safe SDK integration has been established with:
- ✅ Infrastructure and type definitions (`ExecutionMode`, `SafeConfig`)
- ✅ CLI argument parsing for execution modes (`--execute`, `--propose`, `--json`)
- ✅ SafeExecutionService framework with placeholder implementation
- ✅ Viem-based architecture with Sepolia testnet configuration
- ✅ Backwards compatibility maintained with existing JSON workflow
- ✅ Graceful fallback to JSON mode

## 📋 Implementation Roadmap

### Phase 1: Core Safe SDK Integration

#### 1.1 Fix Safe SDK Dependencies and Configuration
**Priority: High**
**Estimated Effort: 1-2 days**

The current Safe SDK packages have TypeScript compilation issues. Key fixes needed:

```typescript
// Current dependencies that need verification/updates:
"@safe-global/api-kit": "^4.0.0",
"@safe-global/protocol-kit": "^6.1.0", 
"@safe-global/safe-core-sdk": "^3.3.5"
```

**Tasks:**
- [ ] Resolve TypeScript compilation errors with Safe SDK packages
- [ ] Update tsconfig.json to support ES2020+ (for BigInt literals)
- [ ] Verify Safe SDK version compatibility
- [ ] Fix import statements to match actual Safe SDK exports

**Files to modify:**
- `tsconfig.json` - Update target to ES2020+ to support BigInt literals
- `script/ts/services/SafeExecutionService.ts` - Fix imports and type definitions
- Potentially downgrade or upgrade Safe SDK versions for compatibility

#### 1.2 Integrate Safe SDK with Existing Viem Architecture
**Priority: High**
**Estimated Effort: 2-3 days**

Our codebase is already built on viem (not ethers), so we need to bridge Safe SDK with viem:

```typescript
// Current viem setup in our services:
import { createPublicClient, http } from "viem";
import { sepolia } from "viem/chains";

// Need to integrate with Safe SDK's ethers-based approach
```

**Tasks:**
- [ ] Create viem-to-ethers adapter for Safe SDK compatibility
- [ ] Implement proper signer initialization from SAFE_PRIVATE_KEY
- [ ] Configure Safe SDK to work with existing viem clients
- [ ] Maintain consistency with existing service patterns

**New files:**
```typescript
// script/ts/lib/safe-adapter.ts
export class ViemSafeAdapter {
  // Bridge viem and Safe SDK functionality
}
```

#### 1.3 Complete SafeExecutionService Implementation
**Priority: High**
**Estimated Effort: 3-4 days**

Replace the current placeholder implementation:

```typescript
// Current placeholder:
throw new Error("Safe SDK direct execution not yet implemented. Use JSON mode (default).");

// Replace with actual implementation:
```

**Key methods to implement:**
- [ ] `initializeProtocolKit()` - Remove placeholder, add real Safe initialization
- [ ] `executeTransaction()` - Complete direct execution for single-signer Safes
- [ ] `proposeTransaction()` - Complete proposal workflow for multi-sig Safes
- [ ] Error handling consistent with existing service patterns

**Integration with existing patterns:**
- Use same error handling as other services (`MultisigCliError` subclasses)
- Follow same logging patterns as `TenderlyService` and `UniswapService`
- Maintain consistency with viem-based client initialization

### Phase 2: Enhanced User Experience

#### 2.1 Safe Configuration Auto-Detection
**Priority: Medium**
**Estimated Effort: 1-2 days**

Leverage existing configuration patterns:

```typescript
// Extend existing getEnvironmentConfig() pattern
// script/ts/lib/config.ts already has parseSafeConfig()
```

**Tasks:**
- [ ] Auto-detect Safe threshold and owners using viem
- [ ] Extend existing config validation to include Safe validation
- [ ] Add Safe access validation to existing environment checks

**Files to extend:**
- `script/ts/lib/config.ts` - Add Safe validation functions
- `script/ts/services/SafeExecutionService.ts` - Add auto-detection methods

#### 2.2 Transaction Status Monitoring
**Priority: Medium**
**Estimated Effort: 2-3 days**

Build on existing CLI command patterns:

**New CLI commands following existing patterns:**
```bash
# Following existing multisig-cli:* pattern
npm run multisig-cli:status -- --tx-hash 0x...
npm run multisig-cli:pending
```

**Tasks:**
- [ ] Add new commands to package.json scripts
- [ ] Implement status checking with Safe Transaction Service
- [ ] Display signature collection progress
- [ ] Integrate with existing CLI argument parsing

#### 2.3 Enhance Existing Commands
**Priority: Medium**
**Estimated Effort: 1-2 days**

All existing commands already support execution modes, but need better feedback:

```typescript
// Current implementation shows generic messages:
"Execute mode is not yet implemented."

// Enhance with specific guidance:
"Execute mode requires SAFE_PRIVATE_KEY and single-signer Safe"
"Propose mode requires SAFE_TRANSACTION_SERVICE_URL and multi-sig Safe"
```

### Phase 3: Advanced Features

#### 3.1 Multi-Network Support
**Priority: Medium**  
**Estimated Effort: 2-3 days**

Extend existing network configuration:

```typescript
// Current: script/ts/lib/config.ts has SEPOLIA_ADDRESSES
// Add: BASE_ADDRESSES, ETHEREUM_ADDRESSES
```

**Tasks:**
- [ ] Add network-specific Safe Transaction Service URLs
- [ ] Extend existing chainId configuration
- [ ] Support network switching within same session
- [ ] Update existing services to handle multiple networks

#### 3.2 Advanced Transaction Features
**Priority: Low**
**Estimated Effort: 3-4 days**

Build on existing SafeTransactionBuilder patterns:

**Tasks:**
- [ ] Enhanced gas estimation using existing viem patterns
- [ ] Transaction simulation before execution (extend TenderlyService)
- [ ] Batch optimization for multiple sequential operations
- [ ] Integration with existing Tenderly simulation workflow

## 🔧 Technical Implementation Details

### Viem Integration Strategy

Our codebase is built on viem, not ethers. The Safe SDK uses ethers, so we need a bridge:

```typescript
// script/ts/lib/safe-adapter.ts
import { createWalletClient, http, privateKeyToAccount } from "viem";
import { sepolia } from "viem/chains";

export class ViemSafeAdapter {
  constructor(privateKey: string, chainId: number) {
    this.account = privateKeyToAccount(privateKey as `0x${string}`);
    this.walletClient = createWalletClient({
      account: this.account,
      chain: sepolia, // or other chain based on chainId
      transport: http()
    });
  }

  // Convert viem client to ethers-compatible format for Safe SDK
  getEthersAdapter() {
    // Implementation needed
  }
}
```

### Safe Configuration Enhancement

```typescript
// Extend existing script/ts/types/index.ts SafeConfig
export interface SafeConfig {
  privateKey?: string;
  signerAddress?: string;
  transactionServiceUrl?: string;
  defaultExecutionMode?: ExecutionMode;
  chainId?: number; // Add chainId support
  rpcUrl?: string;  // Add custom RPC support
}
```

### Environment Variables Integration

Build on existing environment variable patterns in `config.ts`:

```bash
# Existing Safe variables (already implemented):
SAFE_PRIVATE_KEY=0x...
SAFE_SIGNER_ADDRESS=0x...
SAFE_TRANSACTION_SERVICE_URL=https://safe-transaction-sepolia.safe.global

# New variables to add:
SAFE_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/...
DEFAULT_EXECUTION_MODE=json|execute|propose
```

### Error Handling Strategy

Follow existing error patterns in `types/index.ts`:

```typescript
export class SafeExecutionError extends MultisigCliError {
  constructor(message: string, cause?: Error) {
    super(message, 'SAFE_EXECUTION_ERROR', cause);
  }
}

export class SafeConfigurationError extends MultisigCliError {
  constructor(message: string, cause?: Error) {
    super(message, 'SAFE_CONFIGURATION_ERROR', cause);
  }
}
```

## 🚨 Risk Assessment & Mitigation

### High-Risk Items

1. **Viem-Ethers Compatibility**
   - Risk: Safe SDK requires ethers, our stack uses viem
   - Mitigation: Create adapter layer, test thoroughly

2. **Safe SDK Version Compatibility**
   - Risk: Current versions have TypeScript compilation issues
   - Mitigation: Test multiple Safe SDK versions, potentially downgrade

3. **Private Key Security**
   - Risk: Private keys in environment variables
   - Mitigation: Add warnings, support hardware wallets in future

### Medium-Risk Items

1. **Network Configuration Errors**
   - Risk: Wrong network execution with real funds
   - Mitigation: Extend existing network validation, clear warnings

2. **Transaction Execution Failures**
   - Risk: Failed transactions with lost gas fees
   - Mitigation: Extend existing Tenderly simulation to validate before execution

## 📚 Integration with Existing Architecture

### Service Patterns

All existing services follow this pattern:

```typescript
export class NewService {
  private config: EnvironmentConfig;
  private client = createPublicClient({ chain: sepolia, transport: http() });

  constructor() {
    this.config = getEnvironmentConfig();
  }

  // Methods follow async/await with try/catch
  // Errors thrown as MultisigCliError subclasses
  // Logging follows existing patterns
}
```

SafeExecutionService should follow the same pattern.

### CLI Command Integration

All commands follow this pattern in `multisig-cli.ts`:

```typescript
// 1. Method signature includes executionMode parameter
async methodName(params: string, executionMode?: ExecutionMode): Promise<void>

// 2. All methods call executeTransaction helper
await this.executeTransaction(batch, executionMode);

// 3. Package.json includes npm script
"multisig-cli:command": "tsx script/ts/multisig-cli.ts command"
```

## 📋 Implementation Priority

### Phase 1 (Essential - 1-2 weeks)
1. Fix Safe SDK TypeScript compilation issues
2. Create viem-ethers adapter for Safe SDK
3. Implement basic executeTransaction and proposeTransaction

### Phase 2 (Enhancement - 1 week)  
1. Add transaction status monitoring
2. Enhance error messages and user guidance
3. Improve Safe configuration validation

### Phase 3 (Advanced - 2 weeks)
1. Multi-network support
2. Advanced transaction features
3. Performance optimizations

## 🎯 Success Criteria

### Phase 1 Complete
- [ ] TypeScript compilation errors resolved
- [ ] Basic `--execute` mode works for single-signer Safes
- [ ] Basic `--propose` mode works for multi-sig Safes  
- [ ] Perfect backwards compatibility maintained

### Phase 2 Complete
- [ ] Transaction status monitoring available
- [ ] User experience matches existing CLI quality
- [ ] Comprehensive error handling and recovery

### Phase 3 Complete
- [ ] Multi-network operation seamless
- [ ] Advanced features enable power-user workflows
- [ ] Performance matches or exceeds JSON workflow

## 🔄 Migration Strategy

### Development Approach
1. **Branch-based development** with comprehensive testing
2. **Feature flags** for gradual rollout
3. **Backwards compatibility** maintained throughout
4. **Documentation updates** alongside implementation

### Testing Strategy
- Unit tests for Safe adapter layer
- Integration tests with Sepolia testnet
- End-to-end testing of complete workflows
- Performance comparison with JSON workflow

This roadmap leverages our existing viem-based architecture while adding Safe SDK direct execution capabilities, maintaining the high code quality and patterns established in the current implementation.