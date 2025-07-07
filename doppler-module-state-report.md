# Doppler Module State Issue Report - Base Sepolia

## Summary

The latest Doppler contracts deployed on Base Sepolia (July 4, 2025) are not whitelisted in the current Airlock contract, preventing token creation due to `WrongModuleState` errors. This creates a compatibility issue where we must choose between correct bytecode (latest contracts) or proper authorization (whitelisted contracts).

## Technical Details

### Current State

- **Airlock Contract**: `0x3411306Ce66c9469BFF1535BA955503c4Bde1C6e`
- **Issue**: Latest deployed contracts are not whitelisted in this Airlock

### Latest Deployment (July 4, 2025 14:00:06 GMT)

From `lib/doppler/deployments/84532.md` (Base Sepolia deployment log):

```
DopplerDeployer: 0x60a039e4add40ca95e0475c11e8a4182d06c9aa0
UniswapV4Initializer: 0x8e891d249f1ecbffa6143c03eb1b12843aef09d3
```

### Module State Verification

**Current whitelisted contracts (working):**

- `UniswapV4Initializer`: `0xca2079706A4c2a4a1aA637dFB47d7f27Fe58653F` → State: `3` ✅
- `DopplerDeployer`: `0x4Bf819DfA4066Bd7c9f21eA3dB911Bd8C10Cb3ca` → State: `1` ✅

**Latest contracts (not whitelisted):**

- `UniswapV4Initializer`: `0x8e891d249f1ecbffa6143c03eb1b12843aef09d3` → State: `0` ❌
- `DopplerDeployer`: `0x60a039e4add40ca95e0475c11e8a4182d06c9aa0` → State: `0` ❌

### Error Details

When using latest contracts, we get:

```
Error: WrongModuleState(address,uint8,uint8)
- Contract: 0x8e891d249f1ecbffa6143c03eb1b12843aef09d3 (UniswapV4Initializer)
- Expected State: 3 (POOL_INITIALIZER)
- Actual State: 0 (NOT_WHITELISTED)
```

### CREATE2 Dependency Issue

The core problem is that CREATE2 address calculation depends on exact bytecode matching:

- **Hook addresses** are calculated using `DopplerDeployer` contract bytecode
- **Token addresses** are calculated using contract creation code
- Any version mismatch results in different addresses and failed validations

### Required Actions

1. **Whitelist latest contracts** in Airlock `0x3411306Ce66c9469BFF1535BA955503c4Bde1C6e`:
   - Set `UniswapV4Initializer` (`0x8e891d249f1ecbffa6143c03eb1b12843aef09d3`) to state `3`
   - Set `DopplerDeployer` (`0x60a039e4add40ca95e0475c11e8a4182d06c9aa0`) to state `1`

2. **Alternative**: Deploy new Airlock with latest contracts pre-whitelisted

### Impact

- **Immediate**: Cannot create tokens using latest Doppler contracts
- **Development**: Must use outdated contracts for compatibility
- **Production**: Risk of bytecode mismatches in production deployments

### Verification Commands

```bash
# Check current states
cast call 0x3411306Ce66c9469BFF1535BA955503c4Bde1C6e "getModuleState(address)" 0x8e891d249f1ecbffa6143c03eb1b12843aef09d3 --rpc-url https://sepolia.base.org
cast call 0x3411306Ce66c9469BFF1535BA955503c4Bde1C6e "getModuleState(address)" 0x60a039e4add40ca95e0475c11e8a4182d06c9aa0 --rpc-url https://sepolia.base.org
```

### Recommendation

Prioritize whitelisting the latest contracts to ensure bytecode compatibility and prevent future deployment issues. This will allow developers to use the most recent Doppler contracts without workaround solutions.
