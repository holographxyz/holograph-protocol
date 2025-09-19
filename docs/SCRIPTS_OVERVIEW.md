# Scripts Overview

This document provides a comprehensive overview of the Holograph Protocol deployment and operational scripts.

## Script Structure

```
script/
├── Configure.s.sol           # Post-deployment configuration
├── ConfigureDVN.s.sol         # LayerZero V2 DVN security setup
├── DeployBase.s.sol           # Deploy to Base chain
├── DeployEthereum.s.sol       # Deploy to Ethereum chain
├── DeployUnichain.s.sol       # Deploy to Unichain chain
├── DeploymentBase.sol         # Common deployment functionality
├── DeploymentConfig.sol       # Consolidated chain and protocol configuration
├── FeeOperations.s.sol        # Fee collection and bridging operations
├── VerifyAddresses.s.sol      # Cross-chain address consistency check
├── create-token.ts            # TypeScript token creation utility
└── _generate_abis.sh          # Extract contract ABIs
```

## Core Scripts

### Deployment Scripts

#### DeployBase.s.sol
Deploys contracts to Base mainnet or Base Sepolia:
- HolographDeployer (deterministic deployer)
- HolographERC20 (token implementation)
- HolographFactory (token factory)
- HolographFactoryProxy (upgradeable proxy)
- FeeRouter (fee collection and bridging)

**Environment Variables:**
- `LZ_ENDPOINT` - LayerZero V2 endpoint address
- `DOPPLER_AIRLOCK` - Doppler Airlock contract address
- `TREASURY` - Treasury wallet address
- `ETH_EID` - Ethereum LayerZero endpoint ID

#### DeployEthereum.s.sol
Deploys contracts to Ethereum mainnet or Sepolia:
- HolographDeployer (deterministic deployer)
- StakingRewards (HLG staking contract)
- FeeRouter (fee processing and token swapping)

**Environment Variables:**
- `LZ_ENDPOINT` - LayerZero V2 endpoint address
- `BASE_EID` - Base LayerZero endpoint ID
- `HLG` - HLG token address
- `WETH` - WETH contract address
- `SWAP_ROUTER` - Uniswap V3 SwapRouter address
- `TREASURY` - Treasury wallet address

#### DeployUnichain.s.sol
Deploys contracts to Unichain for expanded network support.

### Configuration Scripts

#### Configure.s.sol
Sets up cross-chain configuration after deployment:
- Configures trusted remotes for LayerZero messaging
- Authorizes Doppler Airlock contracts
- Sets up treasury and fee router relationships

**Key Functions:**
- Sets `trustedRemotes` mapping for cross-chain security
- Authorizes Airlock contracts for token creation
- Configures LayerZero gas settings

#### ConfigureDVN.s.sol
Configures LayerZero V2 DVN (Decentralized Verifier Network) security:
- Uses single required DVN (LayerZero Labs)
- Configures block confirmations (15 blocks)
- Sets up ULN (Ultra Light Node) parameters

**Simplified Security Model:**
- **Single DVN**: LayerZero Labs DVN only
- **No Optional DVNs**: Removed Polyhedra for simplicity
- **Base Mainnet**: Uses Dead DVN as temporary fallback

### Operational Scripts

#### FeeOperations.s.sol
Handles fee collection and cross-chain bridging:
- Collects fees from Doppler Airlock contracts
- Bridges protocol fees to Ethereum
- Manages treasury payments

**Owner-Only Operations:**
- `collectAirlockFees()` - Extract fees from Airlocks
- `bridge()` - Bridge ETH to Ethereum for HLG conversion
- `bridgeToken()` - Bridge specific ERC20 tokens

#### VerifyAddresses.s.sol
Verifies deterministic address consistency across chains:
- Reads deployment artifacts from all chains
- Compares addresses for consistency
- Identifies any deployment discrepancies

### Utility Scripts

#### _generate_abis.sh
Bash script that extracts contract ABIs:
- Processes Foundry build artifacts in `out/`
- Generates clean ABI files in `abis/`
- Filters to only include `src/` contracts

#### create-token.ts
TypeScript utility for creating tokens through Doppler Airlock:
- Interactive token creation with salt mining
- Integrates with HolographFactory for deterministic addresses
- Supports Base Sepolia testnet deployments
- Includes contract verification and deployment tracking

**Usage:**
```bash
npm run create-token  # Interactive token creation
npm run build        # Compile to JavaScript
npm run type-check   # Validate TypeScript
```

## Configuration Library

### DeploymentConfig.sol
Consolidated configuration library located in the `script/` directory containing:

**Chain Constants:**
- Chain IDs for all supported networks
- LayerZero endpoint IDs and addresses
- DVN addresses for each chain

**Protocol Configuration:**
- Fee percentages (50% protocol/treasury split)
- Minimum bridge amounts
- Gas limits for cross-chain operations

**Helper Functions:**
- `isMainnet()` / `isTestnet()` - Chain type detection
- `getChainName()` - Human-readable chain names
- `getLzEndpoint()` - LayerZero endpoint addresses
- `getLayerZeroLabsDVN()` - DVN addresses
- `generateSalt()` - Deterministic salt generation

## Base Contracts

### DeploymentBase.sol
Abstract base contract located in the `script/` directory providing:
- Common deployment initialization
- HolographDeployer deployment via CREATE2
- JSON artifact generation
- Gas tracking and reporting

**Salt Generation:**
- First 20 bytes: deployer address (required by HolographDeployer)
- Last 12 bytes: contract-specific identifier
- Ensures consistent addresses across chains

## Usage Patterns

### Typical Deployment Flow

1. **Deploy Contracts:**
   ```bash
   make deploy-base deploy-eth BROADCAST=true
   ```

2. **Configure Cross-Chain:**
   ```bash
   make configure-base configure-eth BROADCAST=true
   ```

3. **Setup DVN Security:**
   ```bash
   make configure-dvn-base configure-dvn-eth BROADCAST=true
   ```

4. **Verify Consistency:**
   ```bash
   make verify-addresses
   ```

### Environment Variables

All scripts support:
- `BROADCAST=true` - Execute real transactions (default: dry-run)
- `DEPLOYER_PK` - Private key for deployments
- `PRIVATE_KEY` - Private key for configuration (bootstrap phase)
- `MAINNET=true` - Required for mainnet deployments

### Safety Features

- **Dry-run by default** - No transactions without explicit broadcast
- **Chain validation** - Warns about unexpected networks
- **Mainnet protection** - Requires explicit confirmation
- **Gas validation** - Ensures sufficient gas for deployment
- **Address validation** - Prevents zero address deployments

## Recent Changes

### Script Consolidation
- Removed redundant `ConfigureDoppler.s.sol` (functionality in `Configure.s.sol`)
- Removed test script `TestTokenCreation.s.sol`

### Configuration Consolidation
- Merged `ChainConfigs.sol` and `DeploymentConstants.sol` into `DeploymentConfig.sol`
- Eliminated duplicate chain ID definitions
- Simplified salt generation functions
- Completely flattened directory structure - all files now in script root

### DVN Simplification
- Removed Polyhedra DVN complexity
- Uses single required DVN (LayerZero Labs)
- Base mainnet uses Dead DVN as temporary fallback
- Cleaner, more maintainable configuration

This simplified structure makes the deployment process more reliable and easier to maintain while preserving all necessary functionality.