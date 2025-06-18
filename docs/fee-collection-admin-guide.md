# Holograph × Doppler – Fee-Collection Admin Guide

> **Audience:** DevOps / Treasury / Protocol Ops teams who operate the Holograph deployment on Base (fee origin) and Ethereum (fee destination).
>
> **Last updated:** 2025-06-18

---

## 0. Executive Summary

- **Integration status:** **LIVE** – All onchain contracts responsible for capturing Doppler trading fees are deployed and audited.
- **Economic flow:**

  1.  **Doppler auction** accrues fees during trading (`Doppler.state.feesAccrued`).
  2.  **Pool migration** (triggered once the auction ends) flushes those fees to **Airlock**, where they are split **80-95 %** Integrator / **5-20 %** Doppler protocol.
  3.  **FeeRouter** is set as the Integrator by `HolographFactory`; it _pulls_ the integrator share, performs a **single-slice** split (**1.5 % protocol / 98.5 % treasury**), bridges protocol fees to Ethereum, converts to HLG, then burns 50 % & stakes 50 %.

- **Effective take-rate:**  
  Protocol burn + stake ≈ **1.5 % × (80–95 %) = 1.2–1.4 % of total trading fees**.  
  Treasury revenue ≈ **98.5 % × (80–95 %) = 78.8–93.5 %**.

- **Operations critical path:**
  - Migration events (`Airlock.Migrate`) create _collectable_ integrator balances.
  - A **keeper bot** (or manual operator) must periodically call `FeeRouter.collectAirlockFees()` then optionally `bridge()` / `bridgeToken()` once balances exceed thresholds.

---

## 1. Fee Lifecycle – End-to-End

```
┌──────────┐       ┌──────────────┐       ┌────────────────────────────────┐
│  Trader  │──────▶│  Doppler V4  │──────▶│   Hook feesAccrued (per swap)  │
└──────────┘ swap  └──────────────┘       └────────────────────────────────┘
                                               │   (not withdrawable)
                               migrate()       │
                                               ▼
┌──────────────────────────────┐ 80-95 %  ┌─────────────────────────────┐
│  Airlock._handleFees()       │─────────▶│ getIntegratorFees[FR][tkn] │
│  5-20 % Protocol (Doppler)   │          └─────────────────────────────┘
└──────────────────────────────┘               │ keeper pull
                                               ▼
┌──────────────────────────────┐ 1.5 %  ┌─────────────────────┐   98.5 %
│  FeeRouter._takeAndSlice()   │───────▶│   Protocol bucket   │──────────▶ Treasury
└──────────────────────────────┘        └─────────────────────┘               │
                                           │ keeper bridge                    │
                                           ▼                                  ▼
                                 ETH / ERC-20 on Ethereum        Funds in multisig / ops wallet
```

**Detailed chronology**

| Phase                      | When                                   | Mechanics                                                                                                                                                                                                                                                                                                        |
| -------------------------- | -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **1. Accrual**             | Every swap during an active auction    | Fee deltas recorded in `Doppler.state.feesAccrued` (no transfer yet)                                                                                                                                                                                                                                             |
| **2. Migration**           | Once sale ends or proceeds cap reached | `Airlock.migrate()` empties liquidity, calls `_handleFees()` twice (token0 & token1). Calculation:<br>`protocolLp = fees / 20` (5 %)<br>`protocolProceeds = (balance-fees) / 1000` (0.1 % proceeds)<br>`protocolFees = max(protocolLp, protocolProceeds)` capped at `fees/5` (20 %). Remaining = integratorFees. |
| **3. Integrator balance**  | Instant                                | `getIntegratorFees[feeRouter][token] += integratorFees`. Still held _inside Airlock_.                                                                                                                                                                                                                            |
| **4. Collection**          | Keeper / admin                         | `FeeRouter.collectAirlockFees(airlock, token, amt)` pulls funds to FeeRouter and immediately calls `_takeAndSlice()`.                                                                                                                                                                                            |
| **5. Slice**               | same tx                                | `HOLO_FEE_BPS = 150` → 1.5 % protocol bucket, 98.5 % treasury forwarded.                                                                                                                                                                                                                                         |
| **6. Bridge & Conversion** | Keeper / admin                         | Periodically `bridge()` (native) or `bridgeToken()` (ERC-20). LayerZero sends payload to Ethereum FeeRouter that swaps to HLG then `burn+stake`.                                                                                                                                                                 |

---

## 2. Contract & Role Map

| Contract           | Chain                | Purpose                                                                               | Key Functions                                         |
| ------------------ | -------------------- | ------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `HolographFactory` | Base (and other L2s) | Token launchpad; writes `integrator = FeeRouter` into `CreateParams`.                 | `createToken()`                                       |
| `Doppler`          | Base                 | Uniswap V4 hook implementing the Dutch auction.                                       | swaps, `state.feesAccrued`                            |
| `Airlock`          | Base                 | Migration orchestrator + fee splitter.                                                | `_handleFees()`, `collectIntegratorFees()`            |
| `FeeRouter`        | Base & ETH           | Central fee handler, splitter, bridging, swap-to-HLG. Requires `KEEPER_ROLE` for ops. | `collectAirlockFees()`, `_takeAndSlice()`, `bridge()` |

**Roles**

- `KEEPER_ROLE` – allowed to collect & bridge.
- `DEFAULT_ADMIN_ROLE` – can grant roles & change treasury.

Grant a new keeper:

```bash
cast send $FEEROUTER "grantRole(bytes32,address)" $(cast keccak "KEEPER_ROLE") $KEEPER --private-key $OWNER_PK --rpc-url $BASE_RPC
```

---

## 3. Keeper Operations

### 3.1 Cadence Recommendations

| Task                                 | Suggested Frequency                                         | Rationale                                    |
| ------------------------------------ | ----------------------------------------------------------- | -------------------------------------------- |
| **Pull fees** (`collectAirlockFees`) | **Hourly** cron OR event-driven on `Airlock.Migrate`        | Limits idle capital, minimises gas overhead. |
| **Bridge native** (`bridge`)         | When FeeRouter ETH ≥ `MIN_BRIDGE_VALUE` (0.01 ETH) OR daily | ETH is cheapest to bridge; frequent is fine. |
| **Bridge tokens** (`bridgeToken`)    | When balance ≥ $500 USD equiv OR every 6-12 h               | Avoids high LZ fees for low amounts.         |
| **Burn / stake confirmation**        | Weekly                                                      | Ensure LZ messages delivered & processed.    |

> **Note:** `script/KeeperPullAndBridge.s.sol` already implements balance-aware bridging logic—adjust thresholds to fit production economics.

### 3.2 Deploying the Keeper Bot

1.  Clone repo & configure env (`FEEROUTER`, `AIRLOCKS[]`, RPC URLs, PK).
2.  Review gas limits (`200_000` default) – increase if swap paths are multi-hop.
3.  Schedule with a systemd timer, GitHub Actions, or a serverless cron (e.g. Gelato).
4.  Monitor logs & alert on failures – key events: `SlicePulled`, `TokenBridged`, `RewardsSent`.

### 3.3 Manual Fallback

Commands below assume Foundry `cast`. Replace `$…` env vars accordingly.

```bash
# Pull ETH fees
cast send $FEEROUTER "collectAirlockFees(address,address,uint256)" \
  $AIRLOCK 0x0000000000000000000000000000000000000000 $AMT --private-key $KEEPER_PK --rpc-url $BASE_RPC

# Bridge accumulated ETH
cast send $FEEROUTER "bridge(uint256,uint256)" 250000 0 --private-key $KEEPER_PK --rpc-url $BASE_RPC
```

---

## 4. Monitoring & Alerts

| Metric                         | Source          | Threshold  | Action               |
| ------------------------------ | --------------- | ---------- | -------------------- |
| `getIntegratorFees[FR][token]` | Airlock view    | > $1k      | Trigger pull.        |
| FeeRouter native balance       | `getBalances()` | > 0.02 ETH | Trigger bridge.      |
| LZ message failures            | LZ scan API     | any        | Investigate, replay. |
| `paused()` flag                | FeeRouter       | true       | Assess emergency.    |

Set up dashboards (Dune, etc.) for critical onchain events:

- `Airlock.Collect` (integrator pulls),
- `FeeRouter.TokenBridged`,
- `FeeRouter.Burned`, `FeeRouter.RewardsSent`.

---

## 5. Troubleshooting

| Symptom                                                | Likely Cause                                  | Fix                                                               |
| ------------------------------------------------------ | --------------------------------------------- | ----------------------------------------------------------------- |
| `AccessControl: account … missing role`                | Keeper address not granted                    | Owner grants `KEEPER_ROLE`.                                       |
| `underflow/overflow` revert on `collectIntegratorFees` | Requested amount > available                  | Query `getIntegratorFees` first; pull exact or lower amt.         |
| Bridge tx stuck in LZ                                  | Wrong `remoteEid` or `trustedRemotes` not set | Owner sets `trustedRemotes` on both chains.                       |
| Insufficient HLG output on swap                        | Pool liquidity thin                           | Increase `minHlg` arg in bridge payload or bridge larger batches. |

---

## 6. Security & Emergency Procedures

- **Pause** fee intake & bridging:
  ```bash
  cast send $FEEROUTER "pause()" --private-key $OWNER_PK --rpc-url $BASE_RPC
  ```
- **Unpause** when resolved.
- **Rotate treasury** quickly via `setTreasury()`.
- Maintain off-chain backups of keeper keys; use hardware wallets or managed key services.

---

## 7. Appendix – CLI Cheat-Sheet

```bash
# Check integrator fee balance (ETH)
cast call $AIRLOCK "getIntegratorFees(address,address)" $FEEROUTER 0x00 --rpc-url $BASE_RPC

# Check FeeRouter balances
cast call $FEEROUTER "getBalances()" --rpc-url $BASE_RPC

# Grant role
cast send $FEEROUTER "grantRole(bytes32,address)" $(cast keccak "KEEPER_ROLE") $NEW_KEEPER --private-key $OWNER_PK --rpc-url $BASE_RPC
```

---

> **Note:** onchain logic is only half of the system. Without an observed, fault-tolerant keeper process the protocol cannot convert accrued fees into realised revenue.
