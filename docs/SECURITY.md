# Security Architecture

Comprehensive security documentation for the Holograph Protocol.

## Access Control

### Role-Based Permissions

- **Owner**: Contract administration, trusted remote management, treasury updates
- **Owner-Only Operations**: All fee operations require owner permissions (no keeper role)
- **FeeRouter Authorization**: Only designated FeeRouter can add rewards to StakingRewards
- **Airlock Authorization**: Only whitelisted Doppler Airlock contracts can create tokens
- **Distributor Authorization**: Whitelisted contracts can stake on behalf of users for campaigns

### Multisig Security

All owner operations should be executed through a Gnosis Safe multisig wallet:
- Deployment via multisig
- Fee operations via multisig
- Emergency controls via multisig
- Configuration updates via multisig

## Deployment Security

### Salt Validation
HolographDeployer requires first 20 bytes of salt to match sender address:
- Prevents griefing attacks
- Ensures deployer control over addresses
- Enables deterministic cross-chain deployment

### Deterministic Addresses
CREATE2 deployment ensures consistent addresses:
- Same address on all chains
- Prevents address confusion
- Simplifies cross-chain operations

### Additional Features
- **Griefing Protection**: Salt validation prevents malicious actors from front-running deployments
- **Signed Deployments**: Support for gasless deployment with signature verification

## Cross-Chain Security

### Trusted Remotes
Per-endpoint whitelist of authorized cross-chain message senders:
- Each chain maintains its own trusted remote list
- Only accept messages from known FeeRouter addresses
- Configurable by owner only

### Endpoint Validation
LayerZero V2 endpoint verification for all cross-chain messages:
- Verify message authenticity
- Check source chain and sender
- Validate message format and data

### Additional Protections
- **Trusted Airlocks**: Whitelist preventing unauthorized ETH transfers to FeeRouter
- **Replay Protection**: Nonce-based system preventing message replay attacks
- **Gas Limits**: Controlled gas limits for cross-chain execution

## Economic Security

### Value Protection
- **Dust Protection**: MIN_BRIDGE_VALUE (0.01 ETH) prevents uneconomical bridging
- **Slippage Protection**: Configurable minimum HLG output for swaps
- **Fee Limits**: Maximum fee percentages to prevent excessive charges

### Staking Security
- **Cooldown Period**: 7-day default withdrawal cooldown prevents staking manipulation
- **Emergency Exit**: Users can always exit, even when paused
- **Auto-Compounding**: Rewards automatically compound, preventing loss

### Emergency Controls
- **Pause Functionality**: Owner can pause all major contract functions
- **Unpause Control**: Only owner can unpause
- **Emergency Recovery**: Multiple recovery mechanisms for different scenarios

## Smart Contract Security Features

### StakingRewards Security

**Reentrancy Protection**:
```solidity
function stake(uint256 amount) external nonReentrant whenNotPaused
```

**Fee-on-Transfer Protection**:
```solidity
uint256 before = HLG.balanceOf(address(this));
HLG.safeTransferFrom(msg.sender, address(this), amount);
uint256 after = HLG.balanceOf(address(this));
if (after - before != amount) revert FeeOnTransferNotSupported();
```

**Pausable Design**:
- Contract starts paused
- When paused, users can withdraw but cannot stake
- Reward distribution blocked while paused

**Emergency Recovery**:
- `recoverExtraHLG()` - recover HLG accidentally sent to contract
- `reclaimUnallocatedRewards()` - reclaim rewards when no active stakers
- `sweepETH()` - recover accidentally sent ETH
- `recoverToken()` - recover any non-HLG tokens

### FeeRouter Security

**Trusted Airlock Whitelist**:
- Only whitelisted Airlocks can trigger fee collection
- Prevents unauthorized ETH transfers
- Owner-controlled whitelist management

**Bridge Security**:
- Minimum bridge amounts to prevent dust attacks
- Slippage protection on swaps
- Gas limit controls for cross-chain messages

### HolographFactory Security

**Airlock Authorization**:
- Only authorized Doppler Airlocks can create tokens
- Authorization managed by owner
- Token creator tracking for accountability

**Deterministic Deployment**:
- CREATE2 ensures predictable addresses
- Salt validation prevents front-running
- Initialization data validation

## Operational Security

### Transaction Safety

**Best Practices**:
- Always simulate transactions before execution
- Use Tenderly for transaction preview
- Set appropriate slippage limits (2-5% maximum)
- Monitor for sandwich attacks
- Use CoW Swap for MEV protection on large swaps

**Emergency Procedures**:
1. **Contract Compromise**: Immediately pause affected contracts
2. **Bridge Issues**: Contact LayerZero support, pause bridging
3. **Liquidity Crisis**: Adjust slippage, wait for better conditions
4. **Failed Operations**: Check logs, retry with adjusted parameters

### Key Management

**Private Key Security**:
- Never store private keys in code
- Use hardware wallets for production
- Rotate keys regularly
- Use separate keys for different roles

**Multisig Configuration**:
- Minimum 3/5 signers recommended
- Geographic distribution of signers
- Regular signer availability checks
- Clear signing procedures

## Audit Recommendations

### High Priority
1. Full audit of StakingRewards contract
2. Review of cross-chain message handling
3. Validation of economic model parameters
4. Access control verification

### Medium Priority
1. Gas optimization review
2. Integration testing with Doppler
3. LayerZero configuration validation
4. Emergency procedure testing

### Completed Audits
- OpenZeppelin contracts (external audit)
- LayerZero V2 protocol (external audit)
- Uniswap V3 contracts (external audit)

## Security Monitoring

### Real-Time Monitoring
- Contract balance tracking
- Transaction success rates
- Gas price monitoring
- Cross-chain message delivery

### Alert Thresholds
- Unusual transaction volumes
- Failed transactions
- Large value transfers
- Unauthorized access attempts

### Incident Response
1. **Detection**: Automated alerts or manual discovery
2. **Assessment**: Determine severity and scope
3. **Containment**: Pause affected systems if necessary
4. **Resolution**: Fix issue and restore normal operations
5. **Post-Mortem**: Document and improve procedures

## Security Checklist

### Deployment
- [ ] Contracts deployed via multisig
- [ ] Ownership transferred to multisig
- [ ] Trusted remotes configured
- [ ] Airlocks whitelisted
- [ ] Emergency contacts documented

### Operations
- [ ] Regular security reviews
- [ ] Key rotation schedule
- [ ] Incident response drills
- [ ] Monitoring systems active
- [ ] Backup procedures tested

### Upgrades
- [ ] Security review of changes
- [ ] Testnet deployment first
- [ ] Gradual rollout plan
- [ ] Rollback procedures ready
- [ ] Communication plan prepared