# Refactor Deployment Infrastructure & Enable Doppler Integration

## Overview

This PR refactors our deployment infrastructure to implement deterministic CREATE2 deployments with enhanced safety guarantees, resolves critical ownership issues that were blocking configuration, and establishes integration with the Doppler protocol for token launches.

## Changes

### Enhanced HolographDeployer with CREATE2 Safety

Added `safeCreate2` functions that validate predicted addresses before and after deployment to eliminate deployment mismatches that could brick the system:

- Pre-deployment address computation and validation
- Post-deployment address verification  
- Custom `AddressMismatch()` error for diagnostic clarity

```solidity
function safeCreate2(bytes memory creationCode, bytes32 salt, address expectedAddress) 
    public returns (address deployed) {
    address computedAddress = computeAddress(creationCode, salt);
    if (computedAddress != expectedAddress) {
        revert AddressMismatch();
    }
    deployed = deploy(creationCode, salt);
    if (deployed != expectedAddress) {
        revert AddressMismatch();
    }
}
```

### Unified Deployment Infrastructure

Extracted common deployment logic into `DeploymentBase.sol` to eliminate code duplication and ensure consistency across chains:

- Centralized HolographDeployer deployment and verification
- JSON deployment manifests with backward compatibility for existing tooling
- Standardized salt generation using deterministic patterns
- Chain-agnostic configuration management

Refactored all deployment scripts to inherit from the common base, reducing maintenance overhead and deployment inconsistencies across Base, Ethereum, and Unichain.

### Fixed FeeRouter Ownership Issue

The FeeRouter was incorrectly owned by the HolographDeployer contract instead of the deployer EOA, making post-deployment configuration impossible. 

Modified the constructor to accept an explicit owner parameter rather than using `msg.sender`:

```solidity
// Before
constructor(..., address _treasury) Ownable(msg.sender) {

// After  
constructor(..., address _treasury, address _owner) Ownable(_owner) {
```

All deployment scripts now correctly pass the deployer EOA as the owner parameter.

### Doppler Protocol Integration

Configured the HolographFactory to work with Doppler's token launch infrastructure:

- Authorized the Doppler Airlock contract for token creation through our factory
- Added `ConfigureDoppler.s.sol` script for reproducible setup
- Verified `ITokenFactory` interface compliance for seamless integration

The factory is now ready to be whitelisted by the Doppler team for production use.

### Token Creation Script Fixes

Corrected several critical issues in `create-token.ts` that would have caused deployment failures:

- Removed incorrect LayerZero endpoint parameter from HolographERC20 constructor calls
- Fixed CREATE2 address calculations to account for ERC1167 minimal proxy deployment pattern
- Updated deployment addresses to match current Base Sepolia contracts
- Implemented proper ERC1167 bytecode generation for accurate salt mining

## File Changes

### Smart Contracts
- `src/deployment/HolographDeployer.sol` - Added safeCreate2 functions with address validation
- `src/FeeRouter.sol` - Modified constructor to accept explicit owner parameter
- `script/base/DeploymentBase.sol` - New shared deployment infrastructure
- All deployment scripts - Refactored to use common base class

### Tooling & Scripts  
- `script/ConfigureDoppler.s.sol` - New Doppler integration configuration script
- `script/VerifyAddresses.s.sol` - Enhanced JSON reading with graceful fallback
- `create-token.ts` - Fixed for ERC1167 proxy architecture and current deployment addresses

### Test Suite
- Updated FeeRouter tests to include owner parameter
- Resolved compilation issues across all test files

## Testing & Verification

All changes have been tested on Base Sepolia testnet with full contract verification:

- Complete deployment pipeline tested end-to-end
- JSON manifest generation and validation verified
- Address consistency confirmed across all deployment artifacts
- Doppler Airlock authorization successfully configured
- Contract ownership properly established for all deployed contracts
- CREATE2 address predictions validated against actual deployments

## Deployment Results

### Base Sepolia Deployment
```json
{
  "chainId": 84532,
  "deployer": "0x5f5C3548f96C7DA33A18E5F2F2f13519e1c8bD0d",
  "holographDeployer": "0x6566750584BB5e59Be783c9b39C704e3e37Eab51",
  "holographERC20": "0x4679Ba09dcfcC80CF1E6628F9850C54b198b5D6A",
  "holographFactory": "0x08Eb3E7A917bB125613E6Dd2D82ef4D6d6248102",
  "holographFactoryProxy": "0x47ca9bEa164E94C38Ec52aB23377dC2072356D10",
  "feeRouter": "0xc2D248C46f16d0a6F132ACd0E90A64dB78A86fB0"
}
```

## Breaking Changes

### Deployment Pipeline
- FeeRouter deployment now requires explicit owner parameter in constructor
- All deployment scripts must inherit from DeploymentBase
- JSON manifests are now the primary deployment record format

### Token Creation
- create-token.ts updated to work with ERC1167 minimal proxy pattern
- Removed LayerZero endpoint parameter from token constructor calls
- Updated address calculations for current proxy architecture

## Next Steps

1. Doppler team to whitelist HolographFactory at `0x47ca9bEa164E94C38Ec52aB23377dC2072356D10`
2. Deploy updated contracts to Ethereum mainnet using new pipeline
3. Deploy to Unichain network following same pattern
4. Configure cross-chain LayerZero trusted remotes between deployed instances

## Verification Commands

### Deploy to Base Sepolia
```bash
BROADCAST=true make deploy-base
```

### Configure Doppler Integration  
```bash
source .env && BROADCAST=true forge script script/ConfigureDoppler.s.sol \
    --rpc-url https://sepolia.base.org --broadcast --private-key $DEPLOYER_PK
```

### Verify Addresses
```bash
forge script script/VerifyAddresses.s.sol
```

### Test Token Creation
```bash
npm run create-token
```

---

All changes have been thoroughly tested and validated. The deployment infrastructure is now more robust, ownership issues are resolved, and Doppler integration is ready for production use.