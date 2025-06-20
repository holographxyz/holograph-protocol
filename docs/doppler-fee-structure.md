# Analyze repository architecture and data flow
_Exported on 6/10/2025 at 14:10:28 EDT from Cursor (1.0.0)_

---

**User**

Analyze the repository end-to-end, summarizing its overall architecture, key modules, data flow, and any complex or non-obvious implementation patterns. Present your findings clearly so I can later ask precise questions about specific details.@/src @/docs 

---

**Cursor**

I'll analyze the Doppler repository end-to-end by examining the codebase structure, key contracts, and documentation to provide you with a comprehensive overview.

Now let me read the key documentation files and main contracts to understand the architecture:

Now let me examine the main contracts to understand their implementation:

Now let me examine some key factory and migration contracts:

Now let me examine some test files to better understand the system's behavior:

Based on my comprehensive analysis of the Doppler repository, here's a detailed summary of the overall architecture, key modules, data flow, and implementation patterns:

## **Overall Architecture**

The Doppler Protocol is a **liquidity bootstrapping platform** built on Uniswap v4 that enables fair token launches through Dutch auction mechanisms. The system consists of two main components:

1. **Doppler Protocol** - A Uniswap v4 hook that implements dynamic bonding curves for token sales
2. **Airlock** - A modular factory system for deploying tokens with associated governance and liquidity infrastructure

## **Key Modules & Components**

### **Core Contracts**

**1. Doppler.sol (1,477 lines)**
- **Purpose**: Main Uniswap v4 hook implementing the liquidity bootstrapping auction
- **Key Features**:
  - Dynamic bonding curve that adjusts based on sales performance
  - Epoch-based rebalancing (Dutch auction mechanism)
  - Three types of liquidity positions ("slugs"): Lower, Upper, and Price Discovery
  - Early exit and insufficient proceeds handling
  - Migration capabilities to standard AMM pools

**2. Airlock.sol (318 lines)**
- **Purpose**: Modular factory orchestrating token deployment lifecycle
- **Architecture**: Plugin-based system with whitelisted modules
- **Module Types**:
  - `TokenFactory` - Deploys ERC20 tokens
  - `GovernanceFactory` - Deploys governance contracts
  - `PoolInitializer` - Initializes liquidity pools (V3/V4)
  - `LiquidityMigrator` - Handles liquidity migration

**3. DERC20.sol (306 lines)**
- **Purpose**: Enhanced ERC20 with governance, vesting, and pool locking
- **Features**:
  - ERC20Votes for governance participation
  - Vesting mechanism for team/investor allocations
  - Pool locking to prevent transfers during bootstrap phase
  - Inflation controls with yearly mint caps

### **Initializers & Migration**

**4. UniswapV4Initializer.sol**
- Deploys Doppler hooks and initializes V4 pools
- Handles token transfers and pool setup

**5. UniswapV3Initializer.sol (417 lines)**
- Creates V3 pools for post-migration liquidity
- Implements log-normal distribution for initial liquidity placement
- Complex position management for bonding curve simulation

**6. UniswapV2Migrator.sol & Extensions**
- Handles migration from V2 to V3/V4 pools
- Custom LP token support

### **Utilities & Lens**

**7. DopplerLens.sol (183 lines)**
- View functions for querying pool state
- Price and liquidity calculations
- Integration with V4 quoter system

**8. Bundler.sol**
- Batch operations for improved UX
- Gas optimization for multiple calls

## **Data Flow & Lifecycle**

### **1. Token Creation Flow**
```
Airlock.create() → TokenFactory → DERC20 deployment
                → GovernanceFactory → Governance contracts
                → PoolInitializer → Doppler hook + V4 pool
                → LiquidityMigrator → V3 migration pool setup
```

### **2. Doppler Auction Lifecycle**

**Phase 1: Initialization**
- Hook deployed with auction parameters (start/end time, price range, epochs)
- Initial liquidity placed in three "slug" types
- Pool locked to prevent external LP additions

**Phase 2: Active Auction (Epoch-based)**
- Each epoch triggers rebalancing based on sales performance
- **Undersold**: Dutch auction (price reduction)
- **Oversold**: Price increase
- **On-target**: Maintain current curve

**Phase 3: Completion**
- **Success**: Migration to standard V3 pool
- **Insufficient proceeds**: Refund mechanism
- **Early exit**: Triggered if maximum proceeds reached

### **3. Liquidity Slug System**

The Doppler hook manages three types of liquidity positions:

**Lower Slug**
- Positioned below current price
- Contains proceeds from token sales
- Allows token holders to sell back

**Upper Slug**
- Positioned above current price
- Contains tokens available for purchase
- Sized based on expected sales for current epoch

**Price Discovery Slugs (1-15)**
- Positioned above upper slug
- Provides liquidity for future epochs
- Number configurable at deployment

## **Complex Implementation Patterns**

### **1. Epoch-Based Rebalancing Algorithm**
```solidity
// Sophisticated curve adjustment based on sales performance
tickAccumulator += calculateTickDelta(
    expectedSales,
    actualSales,
    maxDutchAuctionAmount
);
```

### **2. Slug Liquidity Management**
- Dynamic position sizing based on sales velocity
- Complex tick math for price range calculations
- Liquidity concentration optimization

### **3. Migration Architecture**
- Seamless transition from V4 hook to V3 standard pool
- Liquidity preservation during migration
- Fee collection and distribution

### **4. Modular Factory Pattern**
- Plugin-based architecture with module whitelisting
- Standardized interfaces for different components
- CREATE2 deterministic deployments

### **5. Hook Integration Patterns**
- Four hook functions utilized: `afterInitialize`, `beforeSwap`, `afterSwap`, `beforeAddLiquidity`
- State management across hook calls
- Integration with Uniswap v4's transient storage

## **Security & Access Control**

- **Ownable** patterns for administrative functions
- **Module whitelisting** in Airlock
- **Pool locking** mechanisms in DERC20
- **Migration controls** to prevent premature exits
- **Fee collection** and protocol revenue sharing

## **Testing & Deployment**

- Comprehensive test suite with unit, integration, and invariant tests
- Multi-chain deployment support (Base, Unichain, Ink, etc.)
- Foundry-based development environment
- Gas optimization with via-ir compilation

This architecture represents a sophisticated DeFi protocol that combines Dutch auction mechanics, modular deployment systems, and advanced AMM integration to create a comprehensive token launch platform.

```plaintext
Airlock.create() → TokenFactory → DERC20 deployment
                → GovernanceFactory → Governance contracts
                → PoolInitializer → Doppler hook + V4 pool
                → LiquidityMigrator → V3 migration pool setup
```

```solidity
// Sophisticated curve adjustment based on sales performance
tickAccumulator += calculateTickDelta(
    expectedSales,
    actualSales,
    maxDutchAuctionAmount
);
```

---

**User**

Explain in depth how the Doppler protocol’s fee lifecycle works. Detail exactly when fees are assessed and moved to Doppler versus to the integrator—especially during token creation. Point me to the specific contract files and line numbers that implement this logic. Finally, recommend best-practice patterns for structuring and managing integrator-fee logic at the contract level.@/src 

---

**Cursor**

I'll analyze the Doppler protocol's fee lifecycle in depth, examining when fees are assessed, how they're distributed between the protocol and integrators, and the specific implementation details.

Now I have a comprehensive understanding of the Doppler protocol's fee lifecycle. Let me provide a detailed analysis.

# **Doppler Protocol Fee Lifecycle: In-Depth Analysis**

## **Overview of Fee Architecture**

The Doppler protocol implements a **two-tier fee system** that distinguishes between **protocol fees** and **integrator fees**. Fees are assessed during trading activities and distributed at the time of migration from the Doppler auction to the final liquidity pool.

## **Fee Assessment Timeline**

### **1. During Token Creation (No Fees Assessed)**
**Location**: `src/Airlock.sol`, lines 134-175

During the `create()` function, **no fees are assessed**. The integrator address is simply stored for future fee distribution:

```solidity
// Line 172-174 in Airlock.sol
integrator: createData.integrator == address(0) ? owner() : createData.integrator
```

The integrator is set during token creation and stored in the `AssetData` struct, but no fees are collected at this stage.

### **2. During Swap Operations (Fee Tracking)**
**Location**: `src/Doppler.sol`, lines 1176 and 490-559

Fees are **tracked but not distributed** during swap operations:

```solidity
// Line 1176 in Doppler.sol - Fee accumulation during position management
state.feesAccrued = add(state.feesAccrued, feeDeltas);
```

In the `_afterSwap` hook (lines 490-559), the protocol tracks proceeds **excluding fees**:

```solidity
// Lines 520-525 - Fee-adjusted proceeds calculation
uint256 proceedsLessFee = FullMath.mulDiv(uint128(-amount1), MAX_SWAP_FEE - swapFee, MAX_SWAP_FEE);
state.totalProceeds += proceedsLessFee;
```

### **3. During Migration (Fee Distribution)**
**Location**: `src/Airlock.sol`, lines 210-211 and 237-250

This is where the **actual fee assessment and distribution** occurs:

```solidity
// Lines 210-211 in Airlock.sol
_handleFees(token0, assetData.integrator, balance0, fees0);
_handleFees(token1, assetData.integrator, balance1, fees1);
```

## **Fee Calculation Logic**

**Location**: `src/Airlock.sol`, lines 237-250

The `_handleFees()` function implements a sophisticated fee distribution algorithm:

```solidity
function _handleFees(address token, address integrator, uint256 balance, uint256 fees) internal {
    if (fees > 0) {
        uint256 protocolLpFees = fees / 20;           // 5% of trading fees
        uint256 protocolProceedsFees = (balance - fees) / 1000;  // 0.1% of proceeds
        uint256 protocolFees = Math.max(protocolLpFees, protocolProceedsFees);
        uint256 maxProtocolFees = fees / 5;           // 20% cap on trading fees
        uint256 integratorFees;

        (integratorFees, protocolFees) = protocolFees > maxProtocolFees
            ? (fees - maxProtocolFees, maxProtocolFees)
            : (fees - protocolFees, protocolFees);

        getProtocolFees[token] += protocolFees;
        getIntegratorFees[integrator][token] += integratorFees;
    }
}
```

### **Fee Distribution Formula**:

1. **Protocol Fee Calculation**:
   - `protocolLpFees = fees / 20` (5% of trading fees)
   - `protocolProceedsFees = (balance - fees) / 1000` (0.1% of proceeds)
   - `protocolFees = max(protocolLpFees, protocolProceedsFees)`
   - **Capped at 20% of total trading fees** (`fees / 5`)

2. **Integrator Fee Calculation**:
   - `integratorFees = totalFees - protocolFees`
   - Integrators receive the **remainder** after protocol fees are deducted

## **Fee Collection Mechanisms**

### **Protocol Fee Collection**
**Location**: `src/Airlock.sol`, lines 278-289

```solidity
function collectProtocolFees(address to, address token, uint256 amount) external onlyOwner {
    getProtocolFees[token] -= amount;
    // Transfer logic for ETH vs ERC20
    emit Collect(to, token, amount);
}
```

- **Access Control**: Only contract owner can collect protocol fees
- **Flexibility**: Can specify recipient address and amount

### **Integrator Fee Collection**
**Location**: `src/Airlock.sol`, lines 296-307

```solidity
function collectIntegratorFees(address to, address token, uint256 amount) external {
    getIntegratorFees[msg.sender][token] -= amount;
    // Transfer logic
    emit Collect(to, token, amount);
}
```

- **Access Control**: Only the integrator themselves can collect their fees
- **Self-Service**: Integrators manage their own fee collection

## **Data Flow During Migration**

**Location**: `src/Doppler.sol`, lines 1450-1467

1. **Fee Accumulation**: Fees are accumulated in `state.feesAccrued` during the auction
2. **Migration Trigger**: When `migrate()` is called, liquidity is removed and fees are calculated
3. **Fee Transfer**: Total fees (including accrued fees) are transferred to Airlock
4. **Fee Distribution**: Airlock splits fees between protocol and integrator

```solidity
// Lines 1453-1467 in Doppler.sol
BalanceDelta totalFeesAccrued = state.feesAccrued + slugsFeesAccrued;
// ...
fees0 = uint128(totalFeesAccrued.amount0());
fees1 = uint128(totalFeesAccrued.amount1());
```

## **Best Practice Patterns for Integrator Fee Management**

Based on the Doppler implementation, here are recommended patterns:

### **1. Separation of Concerns Pattern**
```solidity
// Store integrator info during creation, handle fees during settlement
struct AssetData {
    address integrator;  // Set once during creation
    // ... other fields
}

// Separate fee handling logic
function _handleFees(address token, address integrator, uint256 balance, uint256 fees) internal {
    // Complex fee calculation logic isolated
}
```

### **2. Deferred Fee Distribution Pattern**
```solidity
// Don't distribute fees immediately - accumulate and distribute at settlement
mapping(address integrator => mapping(address token => uint256 amount)) public getIntegratorFees;

// Allow integrators to pull their fees when ready
function collectIntegratorFees(address to, address token, uint256 amount) external {
    require(msg.sender == integratorAddress, "Only integrator can collect");
    // Transfer logic
}
```

### **3. Flexible Fee Calculation Pattern**
```solidity
// Use max() and capping to ensure fair distribution
uint256 protocolFees = Math.max(lpFeeShare, proceedsFeeShare);
uint256 maxProtocolFees = totalFees / maxProtocolRatio;
protocolFees = protocolFees > maxProtocolFees ? maxProtocolFees : protocolFees;
```

### **4. Event-Driven Transparency Pattern**
```solidity
event Collect(address indexed to, address indexed token, uint256 amount);

// Emit events for all fee-related actions for transparency
function collectFees(...) external {
    // Transfer logic
    emit Collect(to, token, amount);
}
```

### **5. Access Control Patterns**
```solidity
// Protocol fees: Only owner can collect
function collectProtocolFees(...) external onlyOwner { }

// Integrator fees: Only integrator can collect their own fees
function collectIntegratorFees(...) external {
    require(msg.sender == integrator, "Unauthorized");
}
```

### **6. Fallback Integrator Pattern**
```solidity
// Default to protocol owner if no integrator specified
integrator: createData.integrator == address(0) ? owner() : createData.integrator
```

## **Key Implementation Files & Line Numbers**

1. **Fee Storage**: `src/Airlock.sol:120-121`
2. **Fee Calculation**: `src/Airlock.sol:237-250`
3. **Fee Distribution Trigger**: `src/Airlock.sol:210-211`
4. **Fee Accumulation**: `src/Doppler.sol:1176`
5. **Fee Tracking During Swaps**: `src/Doppler.sol:520-525`
6. **Protocol Fee Collection**: `src/Airlock.sol:278-289`
7. **Integrator Fee Collection**: `src/Airlock.sol:296-307`
8. **Integrator Assignment**: `src/Airlock.sol:172-174`

The Doppler protocol's fee system is sophisticated, ensuring fair distribution between protocol development and frontend integrators while maintaining transparency and flexibility in fee collection.

```solidity
// Line 172-174 in Airlock.sol
integrator: createData.integrator == address(0) ? owner() : createData.integrator
```

```solidity
// Line 1176 in Doppler.sol - Fee accumulation during position management
state.feesAccrued = add(state.feesAccrued, feeDeltas);
```

```solidity
// Lines 520-525 - Fee-adjusted proceeds calculation
uint256 proceedsLessFee = FullMath.mulDiv(uint128(-amount1), MAX_SWAP_FEE - swapFee, MAX_SWAP_FEE);
state.totalProceeds += proceedsLessFee;
```

```solidity
// Lines 210-211 in Airlock.sol
_handleFees(token0, assetData.integrator, balance0, fees0);
_handleFees(token1, assetData.integrator, balance1, fees1);
```

```solidity
function _handleFees(address token, address integrator, uint256 balance, uint256 fees) internal {
    if (fees > 0) {
        uint256 protocolLpFees = fees / 20;           // 5% of trading fees
        uint256 protocolProceedsFees = (balance - fees) / 1000;  // 0.1% of proceeds
        uint256 protocolFees = Math.max(protocolLpFees, protocolProceedsFees);
        uint256 maxProtocolFees = fees / 5;           // 20% cap on trading fees
        uint256 integratorFees;

        (integratorFees, protocolFees) = protocolFees > maxProtocolFees
            ? (fees - maxProtocolFees, maxProtocolFees)
            : (fees - protocolFees, protocolFees);

        getProtocolFees[token] += protocolFees;
        getIntegratorFees[integrator][token] += integratorFees;
    }
}
```

```solidity
function collectProtocolFees(address to, address token, uint256 amount) external onlyOwner {
    getProtocolFees[token] -= amount;
    // Transfer logic for ETH vs ERC20
    emit Collect(to, token, amount);
}
```

```solidity
function collectIntegratorFees(address to, address token, uint256 amount) external {
    getIntegratorFees[msg.sender][token] -= amount;
    // Transfer logic
    emit Collect(to, token, amount);
}
```

```solidity
// Lines 1453-1467 in Doppler.sol
BalanceDelta totalFeesAccrued = state.feesAccrued + slugsFeesAccrued;
// ...
fees0 = uint128(totalFeesAccrued.amount0());
fees1 = uint128(totalFeesAccrued.amount1());
```

```solidity
// Store integrator info during creation, handle fees during settlement
struct AssetData {
    address integrator;  // Set once during creation
    // ... other fields
}

// Separate fee handling logic
function _handleFees(address token, address integrator, uint256 balance, uint256 fees) internal {
    // Complex fee calculation logic isolated
}
```

```solidity
// Don't distribute fees immediately - accumulate and distribute at settlement
mapping(address integrator => mapping(address token => uint256 amount)) public getIntegratorFees;

// Allow integrators to pull their fees when ready
function collectIntegratorFees(address to, address token, uint256 amount) external {
    require(msg.sender == integratorAddress, "Only integrator can collect");
    // Transfer logic
}
```

```solidity
// Use max() and capping to ensure fair distribution
uint256 protocolFees = Math.max(lpFeeShare, proceedsFeeShare);
uint256 maxProtocolFees = totalFees / maxProtocolRatio;
protocolFees = protocolFees > maxProtocolFees ? maxProtocolFees : protocolFees;
```

```solidity
event Collect(address indexed to, address indexed token, uint256 amount);

// Emit events for all fee-related actions for transparency
function collectFees(...) external {
    // Transfer logic
    emit Collect(to, token, amount);
}
```

```solidity
// Protocol fees: Only owner can collect
function collectProtocolFees(...) external onlyOwner { }

// Integrator fees: Only integrator can collect their own fees
function collectIntegratorFees(...) external {
    require(msg.sender == integrator, "Unauthorized");
}
```

```solidity
// Default to protocol owner if no integrator specified
integrator: createData.integrator == address(0) ? owner() : createData.integrator
```

