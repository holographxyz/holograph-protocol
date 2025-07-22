# Holograph Protocol Upgrade Guide

This document outlines the upgrade procedures for the Holograph protocol contracts.

## Overview

The protocol uses two different patterns for upgradeability:
- **HolographFactory**: UUPS proxy pattern (upgradeable)
- **HolographERC20**: Clone pattern (new versions, not upgrades)

## Upgrading HolographFactory

The factory uses UUPS (Universal Upgradeable Proxy Standard), allowing the implementation to be upgraded while keeping the same proxy address.

### Prerequisites
- Must have owner role on the factory proxy
- New implementation must inherit from `UUPSUpgradeable`
- New implementation must maintain storage layout compatibility

### Upgrade Steps

1. **Deploy new implementation**
   ```solidity
   // Deploy new factory implementation
   HolographFactory newImpl = new HolographFactory(erc20ImplementationAddress);
   ```

2. **Upgrade the proxy**
   ```solidity
   // Call through the proxy (as owner)
   HolographFactory(proxyAddress).upgradeToAndCall(
       address(newImpl),
       "" // or initialization data if needed
   );
   ```

3. **Verify the upgrade**
   ```bash
   # Check implementation address
   cast implementation $PROXY_ADDRESS
   
   # Verify new functionality
   cast call $PROXY_ADDRESS "version()"
   ```

### Storage Layout Rules
- Never delete or reorder existing storage variables
- Only add new variables at the end
- Use gaps for future storage: `uint256[50] private __gap;`

### Example: Adding new functionality
```solidity
contract HolographFactoryV2 is HolographFactory {
    // Existing storage preserved...
    
    // New storage at the end
    mapping(address => uint256) public tokenVersions;
    uint256[49] private __gap; // Reduced gap
    
    // New function
    function setTokenVersion(address token, uint256 version) external onlyOwner {
        tokenVersions[token] = version;
    }
    
    // Override version
    function version() external pure override returns (string memory) {
        return "2.0.0";
    }
}
```

## Releasing New HolographERC20 Versions

Tokens use the clone pattern - you can't upgrade existing tokens, but you can deploy new versions for future tokens.

### Steps for New Token Version

1. **Deploy new ERC20 implementation**
   ```solidity
   // e.g., HolographERC20V2 with LayerZero support
   HolographERC20V2 newTokenImpl = new HolographERC20V2();
   ```

2. **Option A: Update existing factory**
   ```solidity
   // Deploy new factory implementation pointing to new token
   HolographFactory newFactoryImpl = new HolographFactory(address(newTokenImpl));
   
   // Upgrade factory proxy
   factory.upgradeToAndCall(address(newFactoryImpl), "");
   ```

3. **Option B: Support multiple versions**
   ```solidity
   contract HolographFactoryMultiVersion is HolographFactory {
       mapping(uint256 => address) public tokenImplementations;
       
       function addTokenImplementation(uint256 version, address impl) external onlyOwner {
           tokenImplementations[version] = impl;
       }
       
       function createTokenWithVersion(
           uint256 version,
           uint256 initialSupply,
           address recipient,
           address owner,
           bytes32 salt,
           bytes calldata tokenData
       ) external returns (address) {
           address impl = tokenImplementations[version];
           require(impl != address(0), "Version not supported");
           
           // Deploy clone of specific version
           address token = Clones.cloneDeterministic(impl, salt);
           // ... rest of creation logic
       }
   }
   ```

### Example: HolographERC20V2 with LayerZero

```solidity
contract HolographERC20V2 is HolographERC20, OFT {
    address public endpoint;
    
    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address recipient,
        address owner,
        address _endpoint, // New parameter
        uint256 yearlyMintRate,
        uint256 vestingDuration,
        address[] memory recipients,
        uint256[] memory amounts,
        string memory tokenURI
    ) external override initializer {
        endpoint = _endpoint;
        // ... rest of initialization
    }
    
    // LayerZero functions
    function setPeer(uint32 eid, bytes32 peer) external onlyOwner {
        _setPeer(eid, peer);
    }
}
```

## Upgrade Checklist

### Before Upgrading
- [ ] Test upgrade on testnet
- [ ] Verify storage layout compatibility
- [ ] Audit new implementation
- [ ] Check all integration points
- [ ] Prepare rollback plan

### During Upgrade
- [ ] Deploy new implementation
- [ ] Verify implementation before upgrade
- [ ] Execute upgrade transaction
- [ ] Verify upgrade succeeded
- [ ] Test critical functions

### After Upgrade
- [ ] Update documentation
- [ ] Notify integrators
- [ ] Monitor for issues
- [ ] Update off-chain systems

## Emergency Procedures

### Factory Upgrade Rollback
```solidity
// If issues found, upgrade back to previous implementation
factory.upgradeToAndCall(previousImplAddress, "");
```

### Pausing Operations
Both factory and bridge have pause functionality:
```solidity
factory.pause();  // Stop new token creation
bridge.pause();   // Stop cross-chain operations
```

## Version Management

Maintain clear version tracking:
```
v1.0.0 - Initial deployment (no LayerZero)
v1.1.0 - Bug fixes only
v2.0.0 - LayerZero support added
v2.1.0 - Multiple token versions support
```

## Security Considerations

1. **Time locks**: Consider adding time delays for upgrades
2. **Multi-sig**: Use multi-signature wallet for owner role
3. **Upgrade limits**: Implement upgrade frequency limits
4. **Testing**: Always test on testnet first
5. **Audits**: Get new implementations audited

## Contact

For upgrade support or questions:
- Technical issues: [create GitHub issue]
- Security concerns: [security contact]