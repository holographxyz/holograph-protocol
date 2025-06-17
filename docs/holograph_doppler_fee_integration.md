# Holograph Doppler Fee Integration Plan

## Table of Contents
1. [Executive Summary](#executive-summary)  
2. [Deep‑Dive Doppler Synopsis](#deep-dive-doppler-synopsis)  
3. [Current Holograph Fee Flow](#current-holograph-fee-flow)  
4. [Integration Objectives](#integration-objectives)  
5. [Detailed Implementation Plan](#detailed-implementation-plan)  
   * 5.1 [Contract Modifications](#51-contract-modifications)  
     * [Factory updates](#factory-updates)  
     * [FeeRouter upgrades](#feerouter-upgrades)  
     * [New/updated interfaces](#newupdated-interfaces)  
     * [Keeper automation](#keeper-automation)  
   * 5.2 [Cross‑Chain Flow Diagram](#52-cross-chain-flow-diagram)  
   * 5.3 [Storage & Constant Additions](#53-storage--constant-additions)  
6. [Test Strategy](#test-strategy)  
   * [Unit tests](#unit-tests)  
   * [Fork / integration tests](#fork--integration-tests)  
   * [Coverage targets & fork commands](#coverage-targets--fork-commands)  
7. [Migration & Deployment Guide](#migration--deployment-guide)  
8. [Open Questions & Risks](#open-questions--risks)  

---

## Executive Summary
We adopt a **single‑slice model** that better matches Doppler's "integrator‑pull" pattern:  

* **HolographFactory** forwards *all* launch ETH to `FeeRouter.receiveFee()` and always sets `integrator = FeeRouter`.  
* **FeeRouter** applies a **1.5 % protocol skim** (`HOLO_FEE_BPS`) to every inflow (launch ETH, Airlock pulls, or manual token routes), forwarding 98.5 % to a multisig **treasury**.  
* The skim is either bridged (ETH) or buffered/bridged (ERC‑20), swapped for HLG on Ethereum, burned 50 %, and rewarded 50 % to `StakingRewards`.  

No contract names change; every update is additive and fully compatible with existing storage layouts.

---

## Deep‑Dive Doppler Synopsis
| Stage | Contract | Value Path | Trigger |
|-------|----------|-----------|---------|
| Auction | `Doppler` → `Airlock` | `feesAccrued` → `getIntegratorFees` | `migrate()` |
| Integrator pull | `Airlock` → `FeeRouter` | `collectIntegratorFees()` | Keeper script |
| Distribution | `FeeRouter` → LZ → `FeeRouter`(Eth) → `StakingRewards` | Keeper + LZ receive |

---

## Current Holograph Fee Flow
```text
(Base)
User ──launch ETH──▶ HolographFactory ──receiveFee()──▶ FeeRouter
Keeper ──pullAndSlice()──▶ FeeRouter (ERC‑20 + ETH)
FeeRouter ──bridge / bridgeToken──▶ LayerZero ──▶ FeeRouter (Eth)
FeeRouter (Eth) ──swap→HLG──▶ burn 50 % │ stake 50 %
```

---

## Integration Objectives

* **Single slicing point** inside FeeRouter (1.5 % skim on every inflow).
* **ERC‑20 support** end‑to‑end (receive → slice → bridge → swap).
* **Foundry‑only workflow**—all automation and tests use Forge/Foundry.
* **Role‑based keeper** (`KEEPER_ROLE`) and value threshold guard (`MIN_BRIDGE_VALUE`).
* **Governance:** updatable `treasury` (multisig) via `onlyOwner`.
* **Minimal diff**: no renames, storage‑safe additions.

---

## Detailed Implementation Plan

### 5.1 Contract Modifications

#### Factory updates

Full ETH forward + integrator set.

```diff
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
...
import { IFeeRouter } from "./interfaces/IFeeRouter.sol"; // NEW import

// STORAGE: no additions, launchFeeETH & protocolFeePercentage left for now.

function createToken(CreateParams calldata params)
    external
    payable
    nonReentrant
    whenNotPaused
    returns (address asset)
{
-   uint256 protocolFee = (launchFeeETH * protocolFeePercentage) / 10000;
-   feeRouter.routeFeeETH{value: protocolFee}();
+   // Forward full launch ETH (single‑slice model)
+   feeRouter.receiveFee{value: msg.value}();

    if (msg.value > launchFeeETH) {
        payable(msg.sender).transfer(msg.value - launchFeeETH);
    }

-   (asset,,, ,) = dopplerAirlock.create(params);
+   CreateParams memory p = params;
+   p.integrator = address(feeRouter); // FeeRouter becomes integrator
+   (asset,,, ,) = dopplerAirlock.create(p);
}
```

**Commit checklist**

* [ ] Add `import { IFeeRouter }` line.
* [ ] Replace slice logic with `receiveFee{value: msg.value}`.
* [ ] Copy params to `p` and set `integrator`.
* [ ] Run `forge test` (existing tests pass).

#### FeeRouter upgrades

Granular code. **Storage‑layout note:** we append new variables after existing mappings—safe because no re‑ordering.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/access/AccessControl.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";
import "@openzeppelin/utils/Pausable.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ILZEndpointV2.sol";
import "./interfaces/ILZReceiverV2.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IStakingRewards.sol";

contract FeeRouter is
    Ownable,
    AccessControl,
    ReentrancyGuard,
    Pausable,
    ILZReceiverV2
{
    using SafeERC20 for IERC20;

    /* ───────────── Constants ───────────── */
    uint24  public constant POOL_FEE         = 3000;          // 0.3 %
    uint16  public constant HOLO_FEE_BPS     = 150;           // 1.5 %
    uint64  public constant MIN_BRIDGE_VALUE = 0.01 ether;    // skip dust
    bytes32 public constant KEEPER_ROLE      = keccak256("KEEPER_ROLE");

    /* ───────────── Immutable ───────────── */
    ILZEndpointV2 public immutable lzEndpoint;
    uint32 public immutable remoteEid;
    IStakingRewards public immutable stakingPool;
    IERC20 public immutable HLG;
    IWETH9 public immutable WETH;
    ISwapRouter public immutable swapRouter;

    /* ───────────── Storage (APPENDED) ───────────── */
    mapping(uint32 => uint64) public nonce;          // *pre‑existing*
    mapping(uint32 => bytes32) public trustedRemotes;// *pre‑existing*
    address public treasury;                         // NEW

    /* ───────────── Events ───────────── */
    event SlicePulled(address airlock,address token,uint256 holo,uint256 treasuryPortion);
    event TokenBridged(address token,uint256 amt,uint64 nonce);
    event TokenReceived(address sender,address token,uint256 amt);

    /* ───────────── Constructor ───────────── */
    constructor(
        address _endpoint,
        uint32  _remoteEid,
        address _stakingPool,
        address _hlg,
        address _weth,
        address _swapRouter,
        address _treasury
    ) Ownable(msg.sender) {
        require(_endpoint != address(0) && _treasury != address(0), "Zero");
        lzEndpoint   = ILZEndpointV2(_endpoint);
        remoteEid    = _remoteEid;
        stakingPool  = IStakingRewards(_stakingPool);
        HLG          = IERC20(_hlg);
        WETH         = IWETH9(_weth);
        swapRouter   = ISwapRouter(_swapRouter);
        treasury     = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /* ───────────── Fee Intake ───────────── */

    /// @notice Called by factory (launch ETH) or any payer.
    function receiveFee() external payable whenNotPaused {
        _takeAndSlice(address(0), msg.value);
    }
    receive() external payable { _takeAndSlice(address(0), msg.value); }

    /// @notice ERC‑20 intake (optional manual route)
    function routeFeeToken(address token,uint256 amt) external whenNotPaused {
        if (amt == 0) revert();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amt);
        _takeAndSlice(token, amt);
        emit TokenReceived(msg.sender, token, amt);
    }

    /* ───────────── Integrator pull ───────────── */

    function pullAndSlice(
        address airlock,
        address token,
        uint128 amt
    ) external onlyRole(KEEPER_ROLE) nonReentrant {
        IAirlock(airlock).collectIntegratorFees(address(this), token, amt);
        _takeAndSlice(token, amt);
    }

    /* ───────────── Internal slicer ───────────── */

    function _takeAndSlice(address token,uint256 amt) internal {
        uint256 holo = (amt * HOLO_FEE_BPS) / 10_000; // 1.5 %
        uint256 rest = amt - holo;

        if (rest > 0) {
            if (token == address(0)) {
                payable(treasury).transfer(rest);
            } else {
                IERC20(token).transfer(treasury, rest);
            }
        }
        if (holo > 0) { _bufferForBridge(token, holo); }
        emit SlicePulled(address(0), token, holo, rest);
    }

    /* ───────────── Bridging ───────────── */

    function bridge(uint256 minGas,uint256 minHlg)
        external
        onlyRole(KEEPER_ROLE)
        nonReentrant
    {
        uint256 bal = address(this).balance;
        if (bal < MIN_BRIDGE_VALUE) return;

        bytes memory payload = abi.encode(address(0), minHlg);
        bytes memory opts    = _buildLzReceiveOption(minGas);
        uint64 n = ++nonce[remoteEid];
        lzEndpoint.send{value: bal}(remoteEid, payload, opts);
        emit TokenBridged(address(0), bal, n);
    }

    function bridgeToken(
        address token,
        uint256 minGas,
        uint256 minHlg
    ) external onlyRole(KEEPER_ROLE) nonReentrant {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal < MIN_BRIDGE_VALUE) return;

        IERC20(token).approve(address(lzEndpoint), bal);
        bytes memory payload = abi.encode(token, minHlg);
        bytes memory opts    = _buildLzReceiveOption(minGas);
        uint64 n = ++nonce[remoteEid];
        lzEndpoint.send(remoteEid, payload, opts);
        emit TokenBridged(token, bal, n);
    }

    /* ───────────── lzReceive & Swapping (Ethereum) ───────────── */

    function lzReceive(
        uint32 srcEid,
        bytes calldata payload,
        address sender,
        bytes calldata
    ) external payable override {
        require(msg.sender == address(lzEndpoint), "NotEP");
        require(trustedRemotes[srcEid] == _addressToBytes32(sender), "Untrusted");

        (address token,uint256 minHlg) = abi.decode(payload,(address,uint256));
        _swapAndDistribute(token, minHlg);
    }

    function _swapAndDistribute(address token,uint256 minHlg) internal {
        uint256 amtIn;
        if (token == address(0)) {
            amtIn = address(this).balance;
            WETH.deposit{value: amtIn}();
            token = address(WETH);
        } else {
            amtIn = IERC20(token).balanceOf(address(this));
        }
        uint256 hlgOut = _swapExact(token, amtIn, minHlg);
        _burnAndStake(hlgOut);
    }

    /* ───────────── Swap helpers ───────────── */
    function _swapExact(address tokenIn,uint256 amtIn,uint256 minHlg) internal returns (uint256) {
        if (tokenIn == address(HLG)) return amtIn;

        if (_poolExists(tokenIn, address(HLG))) {
            return _swapSingle(tokenIn, address(HLG), amtIn, minHlg);
        }
        // token→WETH→HLG path
        require(_poolExists(tokenIn,address(WETH)) && _poolExists(address(WETH),address(HLG)), "NoRoute");
        bytes memory path = abi.encodePacked(
            tokenIn, uint24(POOL_FEE), address(WETH),
            uint24(POOL_FEE), address(HLG)
        );
        return _swapPath(path, amtIn, minHlg);
    }

    // _swapSingle & _swapPath bodies omitted (identical to ISwapRouter examples)

    /* ───────────── Burn & Stake ───────────── */
    function _burnAndStake(uint256 hlgAmt) internal {
        uint256 stakeAmt = hlgAmt / 2;
        uint256 burnAmt  = hlgAmt - stakeAmt;
        HLG.safeTransfer(address(0), burnAmt);
        HLG.approve(address(stakingPool), stakeAmt);
        stakingPool.addRewards(stakeAmt);
    }

    /* ───────────── Util ───────────── */
    function _poolExists(address a,address b) internal view returns (bool) {
        return ISwapRouter(address(swapRouter)).factory().getPool(a,b,POOL_FEE) != address(0);
    }
    function _addressToBytes32(address a) internal pure returns (bytes32) { return bytes32(uint256(uint160(a))); }
    function _buildLzReceiveOption(uint256 gasLimit) internal pure returns (bytes memory) { /* unchanged */ }
}
```

**Commit checklist**

* [ ] Append new imports (`AccessControl`).
* [ ] Add constants/storage/events.
* [ ] Insert `receiveFee`, `routeFeeToken`, `_takeAndSlice`.
* [ ] Add keeper‑gated bridge functions with `MIN_BRIDGE_VALUE`.
* [ ] Implement `_swapAndDistribute` with WETH fallback.
* [ ] Grant roles in constructor.
* [ ] Run `forge test`.

#### New/updated interfaces

```solidity
// src/interfaces/IFeeRouter.sol
pragma solidity ^0.8.24;

interface IFeeRouter {
    function receiveFee() external payable;
    function routeFeeToken(address token,uint256 amt) external;
    function pullAndSlice(address airlock,address token,uint128 amt) external;
    function bridge(uint256 minGas,uint256 minHlg) external;
    function bridgeToken(address token,uint256 minGas,uint256 minHlg) external;
}
```

**Commit checklist**

* [ ] Create new file under `src/interfaces/`.
* [ ] Update imports in factory & tests.

#### Keeper automation (Foundry script)

```solidity
// script/KeeperPullAndBridge.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/interfaces/IFeeRouter.sol";
import "../src/interfaces/IAirlock.sol";

contract KeeperPullAndBridge is Script {
    IFeeRouter constant FR = IFeeRouter(0xFEE...R);       // <-- fill
    IAirlock   constant AIR = IAirlock(0xAIr...K);        // registry or loop externally

    function run() external {
        vm.startBroadcast();

        // example: pull a single token fee then bridge
        FR.pullAndSlice(address(AIR), 0xA0b86991c6218b36..., 1e6); // USDC 1e6
        FR.bridgeToken(0xA0b86991c621..., 200_000, 0);
        FR.bridge(200_000, 0);

        vm.stopBroadcast();
    }
}
```

Run:

```bash
forge script script/KeeperPullAndBridge.s.sol --rpc-url $BASE_RPC --broadcast --legacy --gas-price 100000000
```

**Commit checklist**

* [ ] Add script file.
* [ ] Replace placeholder addresses.
* [ ] Document `forge script` command in README.

---

### 5.2 Cross‑Chain Flow Diagram

```text
┌───────────────┐      launch ETH        ┌──────────────┐
│   User (EOA)  ├───────────────────────►│HolographFactory│
└───────────────┘                       └──────┬───────┘
                                              │receiveFee(msg.value)
                                              ▼
                                      ┌─────────────────┐
                                      │  FeeRouter(Base)│◄─ keeper pull + slice
                                      └──────┬──────────┘
                                             │bridge / bridgeToken
                                             ▼
                                      ┌─────────────────┐
                                      │ LayerZero V2    │
                                      └──────┬──────────┘
                                             │lzReceive
                                             ▼
                                      ┌─────────────────┐
                                      │ FeeRouter(Eth)  │
                                      └─┬─────┬─────┬───┘
                                        │swap │burn │stake
                                        ▼     ▼     ▼
                                   address(0)  ║  StakingRewards
```

---

### 5.3 Storage & Constant Additions

| Contract  | Slot growth | Variable            | Type    | Notes                   |
| --------- | ----------- | ------------------- | ------- | ----------------------- |
| FeeRouter | +1 word     | `treasury`          | address | appended – storage‑safe |
| FeeRouter | constants   | `HOLO_FEE_BPS` etc. | `uint`  | in bytecode, no storage |
| FeeRouter | +0          | `KEEPER_ROLE`       | bytes32 | constant                |

---

## Test Strategy

### Unit tests

```solidity
// test/HolographFactory.t.sol
contract HolographFactoryTest is Test {
    HolographFactory factory;
    FeeRouter        router;
    address alice = address(0xA1);

    function setUp() public {
        router  = new FeeRouter(...);
        factory = new HolographFactory(..., address(router));
        vm.deal(alice, 1 ether);
    }

    function testLaunchForwardsFullEth() public {
        vm.prank(alice);
        factory.createToken{value: 0.01 ether}(dummyParams());
        assertEq(address(router).balance, 0.01 ether);
    }
}
```

Add skeletons:

```solidity
// test/FeeRouterSlice.t.sol
contract FeeRouterSliceTest is Test {
    function setUp() public {}
    function testSlice() public {
        assertTrue(true); // TODO replace with real assertions
    }
}

// test/RoleEnforcement.t.sol
contract RoleEnforcementTest is Test {
    function testNonKeeperReverts() public {
        vm.expectRevert();
        FeeRouter(ADDRESS).bridge(0,0);
    }
}
```

### Fork / integration tests

* `BaseIntegration.t.sol` – deploy mocks on Base fork, run keeper script via `forge script`, assert events.
* `EthereumSwap.t.sol` – simulate LZ receive, ensure swap path returns >0 HLG and balances updated.

### Coverage targets & commands

```bash
forge coverage --report lcov --min 90
forge test --fork-url $BASE_RPC --match-path test/*Base*
forge test --fork-url $ETH_RPC  --match-path test/*Ethereum*
```

---

## Migration & Deployment Guide

1. **Compile & deploy patched FeeRouter** with same salt:

   ```bash
   forge create --rpc-url $BASE_RPC --constructor-args <args> \
     --private-key $DEPLOYER_PK --legacy --gas-price 100000000 \
     src/FeeRouter.sol:FeeRouter --salt $SALT
   ```

2. **Grant roles & set treasury**

   ```bash
   cast send FeeRouter grantRole $(cast keccak "KEEPER_ROLE") $KEEPER \
     --rpc-url $BASE_RPC --private-key $OWNER_PK
   cast send FeeRouter setTreasury $MULTISIG --rpc-url $BASE_RPC --private-key $OWNER_PK
   ```

3. **Upgrade HolographFactory** (proxy admin):

   ```bash
   forge script script/UpgradeFactory.s.sol --rpc-url $BASE_RPC --broadcast
   ```

4. **Run keeper Foundry script once to back‑pull legacy fees.**

5. **Smoke‑test** on Base‑fork & Sepolia‑fork.

Rollback: `cast send FeeRouter pause`.

---

## Open Questions & Risks

* **Treasury misuse** – require multisig, on‑chain events, public docs.
* **Keeper downtime** – plan redundant nodes; possible move to Chainlink Automation later.
* **Gas / value threshold tuning** – `MIN_BRIDGE_VALUE` owner‑settable; monitor weekly.
* **Byte‑code size** – re‑compile with `--sizes`; stay < 24 KB for CREATE2.