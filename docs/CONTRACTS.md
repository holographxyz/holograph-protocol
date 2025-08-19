# Contract Architecture

Technical documentation for all Holograph Protocol smart contracts.

## Core Contracts

### HolographDeployer

Deterministic contract deployment system using CREATE2 for cross-chain address consistency.

**Key Functions:**
```solidity
function deploy(bytes memory creationCode, bytes32 salt) external returns (address deployed);
function deployAndInitialize(bytes memory creationCode, bytes32 salt, bytes memory initData) external returns (address deployed);
function computeAddress(bytes memory creationCode, bytes32 salt) external view returns (address);
```

**Features:**
- CREATE2 deployment for deterministic addresses
- Salt validation (first 20 bytes must match sender)
- Batch deploy and initialize support
- Signed deployment for gasless operations

### HolographFactory

Doppler-authorized token factory implementing ITokenFactory for omnichain token creation.

**Key Functions:**
```solidity
// Called by Doppler Airlock contracts only
function create(
    uint256 initialSupply,
    address recipient,
    address owner,
    bytes32 salt,
    bytes calldata tokenData
) external returns (address token);

function setAirlockAuthorization(address airlock, bool authorized) external; // Owner only
function isTokenCreator(address token, address user) external view returns (bool);
```

**Features:**
- Doppler Airlock integration
- Deterministic token addresses via CREATE2
- Access control for authorized Airlocks
- Token creator tracking

### FeeRouter

Handles fee collection from Doppler Airlock contracts and cross-chain fee distribution.

**Key Functions:**
```solidity
function collectAirlockFees(address airlock, address token, uint256 amt) external; // Owner only
function bridge(uint256 minGas, uint256 minHlg) external; // Owner only
function setTrustedAirlock(address airlock, bool trusted) external; // Owner only
```

**Features:**
- Automated fee collection from Airlocks
- LayerZero V2 cross-chain bridging
- WETH to HLG swapping on Ethereum
- Treasury and protocol fee splitting (50/50)

### StakingRewards

Single-token HLG staking with configurable burn/reward distribution and auto-compounding.

**Key Functions:**
```solidity
// User functions
function stake(uint256 amount) external;
function unstake() external;
function emergencyExit() external;

// Admin functions
function depositAndDistribute(uint256 hlgAmount) external; // Owner only
function addRewards(uint256 amount) external; // FeeRouter only
function setBurnPercentage(uint256 _burnPercentage) external; // Owner only

// Referral system
function batchStakeFor(address[] calldata users, uint256[] calldata amounts, 
                       uint256 startIndex, uint256 endIndex) external; // Owner only

// Distributor system
function setDistributor(address distributor, bool status) external; // Owner only
function stakeFromDistributor(address user, uint256 amount) external; // Distributor only

// Recovery functions
function getExtraTokens() external view returns (uint256);
function recoverExtraHLG(address to, uint256 amount) external; // Owner only
```

**Features:**
- Auto-compounding rewards (no manual claiming)
- Configurable burn/reward split (default 50/50)
- O(1) gas efficiency using MasterChef V2 algorithm
- Emergency exit and pause functionality
- Extra token recovery system
- Future campaign distributor support

### HolographERC20

Standard ERC20 implementation with additional features for omnichain deployment.

**Features:**
- CREATE2 deterministic deployment
- Doppler Airlock compatibility
- Fee-on-transfer protection
- Standard ERC20 functionality

## Contract Interactions

### Token Creation Flow

```
User → Doppler Airlock → HolographFactory.create() → HolographERC20
                     ↓
                FeeRouter (set as integrator)
```

### Fee Distribution Flow

```
Trading Fees → Airlock → FeeRouter.collectAirlockFees()
                            ↓
                    50% to Treasury
                    50% bridged via LayerZero
                            ↓
                    Ethereum FeeRouter
                            ↓
                    WETH → HLG swap
                            ↓
                    StakingRewards.addRewards()
                            ↓
                    X% burned / (100-X)% staked
```

## Integration Patterns

### Direct Factory Authorization

For authorized Airlock contracts to create tokens:

```solidity
// Only callable by authorized Doppler Airlock contracts
bytes memory tokenData = abi.encode(
    name,
    symbol,
    yearlyMintCap,
    vestingDuration,
    recipients,
    amounts,
    tokenURI
);

address token = holographFactory.create(
    initialSupply,
    recipient,
    owner,
    salt,
    tokenData
);
```

### Owner Operations

```solidity
// Collect fees from Doppler Airlock (Owner only)
feeRouter.collectAirlockFees(airlockAddress, tokenAddress, amount);

// Bridge accumulated fees (Owner only)
feeRouter.bridge(minGas, minHlgOut);

// Set trusted Airlock (Owner only)
feeRouter.setTrustedAirlock(airlockAddress, true);
```

### Future Campaign System

The StakingRewards contract includes a distributor system for future campaigns:

```solidity
// 1. Deploy campaign distributor (e.g., MerkleDistributor)
MerkleDistributor distributor = new MerkleDistributor(
    hlg, stakingRewards, merkleRoot, allocation, duration, owner
);

// 2. Whitelist distributor in StakingRewards
stakingRewards.setDistributor(address(distributor), true);

// 3. Fund distributor with HLG budget
hlg.transfer(address(distributor), totalAllocation);

// 4. Users claim via distributor (gas paid by user)
distributor.claim(amount, merkleProof); // Automatically stakes in StakingRewards
```

**Example Use Cases:**
- Merkle Airdrops with auto-staking
- Trading quest rewards
- Bug bounty distributions
- Liquidity mining campaigns

## Gas Optimization

- **Batch Operations**: Process multiple users efficiently
- **CREATE2**: Avoid initialization gas on each chain
- **MasterChef V2**: O(1) reward distribution
- **Storage Packing**: Optimized variable layout

## Upgrade Patterns

Contracts are not upgradeable by design. Future upgrades require:

1. Deploy new contract versions
2. Migrate state if necessary
3. Update integration points
4. Transfer ownership/roles

See [UPGRADE_GUIDE.md](UPGRADE_GUIDE.md) for detailed procedures.