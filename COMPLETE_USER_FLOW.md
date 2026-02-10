# GBP Yield Vault - Complete User Flow
**Date:** February 1, 2026
**Version:** V2 Secure

---

## 🎯 Product Overview

**What it does:** Provides GBP-denominated yield on USDC deposits through hybrid lending + perp strategy

**Core mechanism:**
- 90% USDC → Lending (Morpho/Euler) for USD yield
- 10% USDC → GBP/USD long perp for currency hedge
- Result: Users get yield that tracks GBP value, not USD

---

## 👤 USER JOURNEY: STEP-BY-STEP

### Phase 1: User Deposits USDC

```
USER WALLET                                    GBP YIELD VAULT
    │                                                │
    │  1. Approve USDC                               │
    │──────────────────────────────────────────────>│
    │                                                │
    │  2. Call deposit(1000 USDC, userAddress)      │
    │──────────────────────────────────────────────>│
    │                                                │
    │                              ┌─────────────────┤
    │                              │ SAFETY CHECKS:  │
    │                              │ ✅ Not paused   │
    │                              │ ✅ Below TVL cap│
    │                              │ ✅ Rate limit OK│
    │                              │ ✅ Price stable │
    │                              └─────────────────┤
    │                                                │
    │  3. Transfer 1000 USDC                         │
    │════════════════════════════════════════════════│
    │                                                │
    │  4. Mint shares (e.g., 1000 shares @ 1:1)     │
    │<───────────────────────────────────────────────│
    │                                                │
```

**What happens:**
1. User approves vault to spend USDC
2. User calls `deposit(1000 USDC, userAddress)`
3. Vault runs safety checks (pause, TVL cap, rate limit, price sanity)
4. Vault calculates shares: `shares = 1000 * totalSupply / totalAssets`
5. Vault mints shares to user
6. Vault receives 1000 USDC

**User now has:** 1000 vault shares representing their position

---

### Phase 2: Vault Allocates Funds (90/10 Split)

```
GBP YIELD VAULT (1000 USDC)
    │
    ├──────────────────────────────────────┐
    │                                      │
    │  90% (900 USDC)                      │  10% (100 USDC)
    │  TO LENDING                          │  TO PERP HEDGE
    │                                      │
    ▼                                      ▼
┌─────────────────────────┐      ┌──────────────────────────┐
│  ACTIVE YIELD STRATEGY  │      │   PERP POSITION MANAGER  │
│  (Morpho or Euler)      │      │                          │
├─────────────────────────┤      ├──────────────────────────┤
│                         │      │                          │
│ 1. Receive 900 USDC     │      │ 1. Receive 100 USDC      │
│ 2. Approve ERC4626 vault│      │ 2. Approve Ostium        │
│ 3. Deposit to Morpho    │      │ 3. Open GBP/USD long     │
│ 4. Get vault shares     │      │    - Pair: GBP/USD       │
│                         │      │    - Size: 100 USDC      │
│ Earning: 8% APY (USD)   │      │    - Leverage: 10x       │
│                         │      │    - Notional: 1000 USD  │
└─────────────────────────┘      └──────────────────────────┘

RESULT:
✅ 900 USDC earning 8% APY in Morpho (72 USDC/year)
✅ 100 USDC in GBP/USD perp position (tracks GBP price)
```

**What happens:**
1. Vault calls `activeStrategy.deposit(900 USDC)`
   - Strategy approves Morpho vault
   - Strategy deposits to Morpho ERC4626 vault
   - Strategy receives Morpho shares

2. Vault calls `perpManager.depositCollateralAndOpen(100 USDC, GBP/USD)`
   - PerpManager approves Ostium
   - Opens 10x leveraged GBP/USD long position
   - Position tracks GBP price movements

**Assets now:**
- 900 USDC in Morpho (earning yield)
- 100 USDC in Ostium (hedging currency risk)

---

### Phase 3: Yield Accrues Over Time

```
TIME: Day 1 → Day 30 (1 month later)

┌─────────────────────────────────────────────────────────────┐
│  LENDING SIDE (900 USDC @ 8% APY)                          │
├─────────────────────────────────────────────────────────────┤
│  Day 1:  900.00 USDC                                        │
│  Day 15: 902.00 USDC (+2.00 interest)                      │
│  Day 30: 906.00 USDC (+6.00 interest)                      │
│                                                              │
│  Monthly yield: 6 USDC (0.67% monthly)                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  PERP SIDE (100 USDC, 10x leverage, GBP/USD long)          │
├─────────────────────────────────────────────────────────────┤
│  Open price:   1.27 USD per GBP                             │
│  Current price: 1.30 USD per GBP                            │
│  Price change: +2.36% (GBP appreciated)                     │
│                                                              │
│  PnL Calculation:                                           │
│  - Position size: 1000 USD notional (10x leverage)          │
│  - Price gain: 2.36%                                        │
│  - Gross PnL: 1000 * 2.36% = 23.60 USD                     │
│  - Trading fees: -1.00 USD (conservative estimate)          │
│  - Funding fees: -0.50 USD (net funding rate)              │
│  - Net PnL: +22.10 USD                                      │
│                                                              │
│  Position value: 122.10 USDC (100 collateral + 22.10 PnL)  │
└─────────────────────────────────────────────────────────────┘

TOTAL VAULT VALUE AFTER 1 MONTH:
- Lending: 906.00 USDC
- Perp: 122.10 USDC
- Total: 1,028.10 USDC
- Gain: 28.10 USDC (2.81% monthly return)
```

**What's happening:**
- Morpho vault compounds interest automatically
- Perp position PnL updates based on GBP/USD price
- Vault's `totalAssets()` reflects both:
  - Lending value: `strategy.totalAssets()`
  - Perp value: `perpManager.getCollateral() + perpManager.getPositionPnL()`

**User's shares:** Still 1000 shares, but now worth 1,028.10 USDC

---

### Phase 4: Fee Harvesting (Weekly/Monthly)

```
OWNER CALLS: vault.harvest()

┌─────────────────────────────────────────────────────────────┐
│  HIGH WATER MARK CALCULATION                                │
├─────────────────────────────────────────────────────────────┤
│  Last high water mark: 1.000000 USDC per share              │
│  Current price:        1.028100 USDC per share              │
│  Profit per share:     0.028100 USDC                        │
│                                                              │
│  Total shares: 1000                                          │
│  Total profit: 28.10 USDC                                   │
│                                                              │
│  Performance fee (20%): 5.62 USDC                           │
│  User keeps (80%):      22.48 USDC                          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  FEE DISTRIBUTION                                           │
├─────────────────────────────────────────────────────────────┤
│  Vault mints fee shares:                                    │
│  - Fee in USDC: 5.62 USDC                                   │
│  - Current price: 1.028100 USDC/share                       │
│  - Shares minted: 5.62 / 1.028100 = 5.47 shares            │
│  - Recipient: FeeDistributor contract                       │
│                                                              │
│  Update high water mark:                                    │
│  - New HWM: 1.028100 USDC/share                            │
│  - (prevents charging fees on same profits twice)           │
└─────────────────────────────────────────────────────────────┘

FEE DISTRIBUTOR HOLDS:
┌─────────────────────────────────────────────────────────────┐
│  5.47 vault shares (worth 5.62 USDC)                        │
│                                                              │
│  Ready to release:                                          │
│  - 90% to Treasury: 4.92 shares → 5.06 USDC                │
│  - 10% to Reserve:  0.55 shares → 0.56 USDC                │
└─────────────────────────────────────────────────────────────┘

USER POSITION AFTER HARVEST:
- Still owns: 1000 shares
- Now worth: 1,022.48 USDC (28.10 profit - 5.62 fees)
- Gain: 2.25% (net of fees)
```

**What happens:**
1. Owner calls `vault.harvest()`
2. Vault calculates profit above high water mark
3. Takes 20% performance fee (5.62 USDC)
4. Mints fee shares to FeeDistributor (5.47 shares)
5. Updates high water mark to prevent double-charging
6. User keeps 80% of profits (22.48 USDC)

**Fee claiming:**
- Treasury calls `feeDistributor.releaseTreasury()` → receives 90%
- Reserve calls `feeDistributor.releaseReserve()` → receives 10%

---

### Phase 5: User Withdraws Funds

```
USER WALLET                                    GBP YIELD VAULT
    │                                                │
    │  1. Call withdraw(500 USDC, userAddress)      │
    │──────────────────────────────────────────────>│
    │                                                │
    │                              ┌─────────────────┤
    │                              │ CALCULATIONS:   │
    │                              │ Current price:  │
    │                              │ 1.02248/share   │
    │                              │                 │
    │                              │ Shares to burn: │
    │                              │ 500/1.02248     │
    │                              │ = 489 shares    │
    │                              └─────────────────┤
    │                                                │
```

**Vault needs to get USDC from strategies:**

```
STEP 1: Calculate how much from each
┌─────────────────────────────────────────────────────────────┐
│  Need: 500 USDC                                             │
│  Current allocation: 90% lending, 10% perp                  │
│                                                              │
│  Withdraw from lending: 450 USDC (90%)                      │
│  Withdraw from perp: 50 USDC (10%)                          │
└─────────────────────────────────────────────────────────────┘

STEP 2: Withdraw from lending strategy
┌─────────────────────────────────────────────────────────────┐
│  GBP YIELD VAULT                                            │
│      │                                                       │
│      │ withdraw(450 USDC)                                   │
│      └────────────────────> MORPHO STRATEGY                 │
│                                     │                        │
│                                     │ previewWithdraw()      │
│                                     │ shares = 440           │
│                                     │                        │
│                                     │ redeem(440 shares)     │
│                                     └───────> MORPHO VAULT  │
│                                              (ERC4626)       │
│                                                  │           │
│                          Returns 450 USDC <──────┘          │
│      <─────────────────────────────────────────             │
│                                                              │
│  Vault receives: 450 USDC                                   │
└─────────────────────────────────────────────────────────────┘

STEP 3: Withdraw from perp position
┌─────────────────────────────────────────────────────────────┐
│  GBP YIELD VAULT                                            │
│      │                                                       │
│      │ reducePosition(50 USDC)                              │
│      └────────────────────> PERP POSITION MANAGER           │
│                                     │                        │
│                                     │ Calculate PnL          │
│                                     │ Close partial position │
│                                     │                        │
│                                     └───────> OSTIUM        │
│                                              (Perp DEX)      │
│                                                  │           │
│                          Returns 50 USDC <───────┘          │
│      <─────────────────────────────────────────             │
│                                                              │
│  Vault receives: 50 USDC (includes PnL)                     │
└─────────────────────────────────────────────────────────────┘

STEP 4: Send USDC to user
┌─────────────────────────────────────────────────────────────┐
│  GBP YIELD VAULT                                            │
│      │                                                       │
│      │ 1. Burn 489 shares from user                         │
│      │ 2. Transfer 500 USDC to user                         │
│      └───────────────────────────────────────> USER         │
│                                                              │
│  User receives: 500 USDC                                    │
│  User still has: 511 shares (1000 - 489)                    │
│  Value: 522.48 USDC                                         │
└─────────────────────────────────────────────────────────────┘
```

**Final state:**
- User withdrew: 500 USDC
- User still has: 511 shares worth 522.48 USDC
- Total realized: 1,022.48 USDC (from initial 1000 USDC)
- Profit: 22.48 USDC (2.25% net gain)

---

## 🔄 BACKGROUND OPERATIONS

### A. Strategy Rebalancing (Owner Action)

```
Owner decides to switch from Morpho to Euler for better rates

┌─────────────────────────────────────────────────────────────┐
│  STEP 1: Propose new strategy                               │
├─────────────────────────────────────────────────────────────┤
│  owner.proposeStrategyChange(eulerStrategyAddress)          │
│  - Timelock starts: 24 hours                                │
│  - Users can monitor and decide if they want to exit        │
└─────────────────────────────────────────────────────────────┘

[24 hours pass...]

┌─────────────────────────────────────────────────────────────┐
│  STEP 2: Execute strategy change                            │
├─────────────────────────────────────────────────────────────┤
│  1. Call old strategy.withdrawAll()                         │
│     → Withdraws 906 USDC from Morpho                        │
│                                                              │
│  2. Update activeStrategy = eulerStrategy                   │
│                                                              │
│  3. Call new strategy.deposit(906 USDC)                     │
│     → Deposits 906 USDC to Euler                            │
│                                                              │
│  Result: Funds moved from Morpho → Euler seamlessly         │
└─────────────────────────────────────────────────────────────┘
```

### B. Perp Provider Switching (Owner Action)

```
Owner wants to switch from Ostium to GMX

┌─────────────────────────────────────────────────────────────┐
│  STEP 1: Propose new provider                               │
├─────────────────────────────────────────────────────────────┤
│  perpManager.proposePerpProviderChange(gmxProviderAddress)  │
│  - Timelock starts: 24 hours                                │
│  - Cooldown enforced: Can't propose again for 12 hours      │
└─────────────────────────────────────────────────────────────┘

[24 hours pass...]

┌─────────────────────────────────────────────────────────────┐
│  STEP 2: Execute provider change                            │
├─────────────────────────────────────────────────────────────┤
│  1. Close position on Ostium                                │
│     → Realizes PnL, gets collateral back                    │
│                                                              │
│  2. Switch to GMX provider                                  │
│                                                              │
│  3. Open position on GMX                                    │
│     → Same GBP/USD long, similar leverage                   │
│                                                              │
│  Result: Perp hedge moved from Ostium → GMX                 │
└─────────────────────────────────────────────────────────────┘
```

### C. Emergency Pause (Owner Action)

```
Something goes wrong (oracle failure, perp liquidation risk, etc.)

┌─────────────────────────────────────────────────────────────┐
│  EMERGENCY PAUSE                                            │
├─────────────────────────────────────────────────────────────┤
│  owner.pause()                                              │
│                                                              │
│  BLOCKED OPERATIONS:                                        │
│  ❌ deposit() - No new deposits                             │
│  ❌ mint() - No new mints                                   │
│  ❌ withdraw() - No withdrawals                             │
│  ❌ redeem() - No redemptions                               │
│                                                              │
│  ALLOWED OPERATIONS:                                        │
│  ✅ emergencyWithdrawStrategy() - Pull from lending         │
│  ✅ closePosition() - Close perp position                   │
│  ✅ View functions - Check state                            │
│                                                              │
│  After fixing issue:                                        │
│  owner.unpause() → Normal operations resume                 │
└─────────────────────────────────────────────────────────────┘
```

### D. Circuit Breaker Activation (Automatic)

```
Dangerous condition detected (price spike, perp loss, etc.)

┌─────────────────────────────────────────────────────────────┐
│  CIRCUIT BREAKER TRIGGERS                                   │
├─────────────────────────────────────────────────────────────┤
│  Condition 1: Price volatility > 10%                        │
│  - GBP/USD moved from 1.27 → 1.41 in one update            │
│  - Change: 11% > 10% threshold                              │
│  → BLOCKS deposits automatically                            │
│                                                              │
│  Condition 2: Perp position loss > 40%                      │
│  - Position PnL: -45 USDC (45% of collateral)              │
│  → BLOCKS deposits automatically                            │
│                                                              │
│  Condition 3: TVL exceeds cap buffer                        │
│  - TVL cap: 10M USDC                                        │
│  - Buffer: 5% (500k USDC)                                   │
│  - Effective cap: 9.5M USDC                                 │
│  - Current TVL: 9.6M USDC                                   │
│  → BLOCKS deposits automatically                            │
│                                                              │
│  Owner must:                                                │
│  1. Fix underlying issue                                    │
│  2. Call updateLastPrice() to reset price check             │
│  3. Rebalance if needed                                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 COMPLETE SYSTEM STATE DIAGRAM

```
┌────────────────────────────────────────────────────────────────┐
│                      GBP YIELD VAULT                           │
│                                                                │
│  USER SHARES: 1000 shares                                     │
│  SHARE PRICE: 1.02248 USDC/share                             │
│  TOTAL VALUE: 1,022.48 USDC                                   │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  LENDING ALLOCATION (90%)                            │    │
│  │  ┌────────────────────────────────────────────────┐  │    │
│  │  │  Active Strategy: MorphoStrategyAdapter       │  │    │
│  │  │  Vault: Morpho USDC Vault                      │  │    │
│  │  │  Amount: 906 USDC                              │  │    │
│  │  │  APY: 8.0%                                     │  │    │
│  │  │  Status: Active                                │  │    │
│  │  └────────────────────────────────────────────────┘  │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  PERP ALLOCATION (10%)                               │    │
│  │  ┌────────────────────────────────────────────────┐  │    │
│  │  │  Perp Position Manager                         │  │    │
│  │  │  Provider: OstiumPerpProvider                  │  │    │
│  │  │  Market: GBP/USD                               │  │    │
│  │  │  Collateral: 100 USDC                          │  │    │
│  │  │  Leverage: 10x                                 │  │    │
│  │  │  Position Size: 1,000 USD notional             │  │    │
│  │  │  Entry Price: 1.27 USD/GBP                     │  │    │
│  │  │  Current Price: 1.30 USD/GBP                   │  │    │
│  │  │  PnL: +22.10 USDC                              │  │    │
│  │  │  Total Value: 122.10 USDC                      │  │    │
│  │  │  Health: 85% (healthy)                         │  │    │
│  │  └────────────────────────────────────────────────┘  │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  FEE SYSTEM                                          │    │
│  │  ┌────────────────────────────────────────────────┐  │    │
│  │  │  Fee Collector: FeeDistributor                 │  │    │
│  │  │  Performance Fee: 20%                          │  │    │
│  │  │  High Water Mark: 1.02248 USDC/share          │  │    │
│  │  │  Last Harvest: 30 days ago                     │  │    │
│  │  │  Accumulated Fees: 5.47 shares (5.62 USDC)    │  │    │
│  │  │  - Treasury (90%): 4.92 shares                 │  │    │
│  │  │  - Reserve (10%): 0.55 shares                  │  │    │
│  │  └────────────────────────────────────────────────┘  │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  SAFETY SYSTEMS                                      │    │
│  │  ┌────────────────────────────────────────────────┐  │    │
│  │  │  Pause Status: NOT PAUSED ✅                   │  │    │
│  │  │  TVL Cap: 10M USDC                             │  │    │
│  │  │  TVL Buffer: 5% (500k)                         │  │    │
│  │  │  Effective Cap: 9.5M USDC                      │  │    │
│  │  │  Current TVL: 1.02M USDC ✅                    │  │    │
│  │  │  Rate Limit: 1 min per user                    │  │    │
│  │  │  Price Check: Last updated 1 hour ago          │  │    │
│  │  │  Max Price Change: 10%                         │  │    │
│  │  │  Perp Loss Threshold: 40%                      │  │    │
│  │  │  Current Loss: 0% (in profit) ✅               │  │    │
│  │  └────────────────────────────────────────────────┘  │    │
│  └──────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────┘
```

---

## 🎮 USER INTERFACE FUNCTIONS

### For Users

```solidity
// Deposit USDC, get vault shares
deposit(uint256 assets, address receiver) → uint256 shares

// Mint specific amount of shares
mint(uint256 shares, address receiver) → uint256 assets

// Withdraw specific USDC amount
withdraw(uint256 assets, address receiver, address owner) → uint256 shares

// Redeem specific shares amount
redeem(uint256 shares, address receiver, address owner) → uint256 assets

// Preview functions (gas-free)
previewDeposit(uint256 assets) → uint256 shares
previewMint(uint256 shares) → uint256 assets
previewWithdraw(uint256 assets) → uint256 shares
previewRedeem(uint256 shares) → uint256 assets

// View functions
totalAssets() → uint256  // Total USDC value
balanceOf(address user) → uint256  // User's shares
convertToAssets(uint256 shares) → uint256  // Shares → USDC
convertToShares(uint256 assets) → uint256  // USDC → Shares
```

### For Owner

```solidity
// Strategy management
proposeStrategyChange(address newStrategy)
executeStrategyChange()
cancelStrategyChange()

// Perp management (via PerpPositionManager)
proposePerpProviderChange(address newProvider)
executePerpProviderChange()

// Fee management
harvest() → uint256 feeShares
setPerformanceFee(uint256 newFeeBPS)
setFeeCollector(address newCollector)

// Safety controls
pause()
unpause()
setTVLCap(uint256 newCap)
setUserOperationCooldown(uint256 newCooldown)
updateLastPrice()

// Emergency functions
emergencyWithdrawStrategy()
closePosition()
```

### For Treasury/Reserve

```solidity
// Fee claiming (via FeeDistributor)
feeDistributor.releaseTreasury()  // Claim treasury fees
feeDistributor.releaseReserve()   // Claim reserve fees
feeDistributor.releaseAll()       // Claim both at once

// View functions
feeDistributor.releasableTreasury() → uint256
feeDistributor.releasableReserve() → uint256
```

---

## 🔐 SECURITY CHECKPOINTS

Every user action goes through multiple security layers:

### On Deposit:
1. ✅ Check not paused
2. ✅ Check below TVL cap (with buffer)
3. ✅ Check user rate limit (1 min cooldown)
4. ✅ Check GBP price hasn't spiked (10% max change)
5. ✅ Check perp position health (not underwater)
6. ✅ Check first depositor protection (0xdead initial mint)

### On Withdraw:
1. ✅ Check not paused
2. ✅ Check user has enough shares
3. ✅ Check sufficient liquidity in strategies
4. ✅ Check perp position can be reduced safely
5. ✅ Revert if slippage too high

### On Strategy Change:
1. ✅ 24-hour timelock
2. ✅ Owner-only access
3. ✅ Safe withdrawal from old strategy
4. ✅ Safe deposit to new strategy

### On Perp Provider Change:
1. ✅ 24-hour timelock
2. ✅ 12-hour proposal cooldown
3. ✅ Owner-only access
4. ✅ Safe position closure
5. ✅ Safe position reopening

---

## 📈 KEY METRICS TRACKING

Users can monitor:

```solidity
// Personal metrics
balanceOf(user)           // Your shares
convertToAssets(shares)   // Your USDC value
// Current APY = (currentPrice - entryPrice) / entryPrice * 365 / days

// Vault metrics
totalAssets()             // Total USDC in vault
totalSupply()             // Total shares outstanding
// Share price = totalAssets() / totalSupply()

// Strategy metrics
activeStrategy.totalAssets()       // USDC in lending
activeStrategy.currentAPY()        // Lending APY

// Perp metrics
perpManager.getCollateralBalance() // Collateral in perp
perpManager.getPositionPnL()       // Current PnL
perpManager.getPositionHealth()    // Health percentage
```

---

## 🚨 FAILURE SCENARIOS & HANDLING

### Scenario 1: Oracle Fails
```
Problem: Chainlink oracle returns stale price
Response:
  - getGBPPriceWithCheck() reverts
  - Deposits blocked automatically
  - Withdrawals still work (use last known price)
  - Owner updates oracle or fixes issue
```

### Scenario 2: Perp Position Near Liquidation
```
Problem: GBP crashes, position underwater
Response:
  - Circuit breaker activates (loss > 40%)
  - Deposits blocked automatically
  - Owner can closePosition() to stop losses
  - Withdrawals still work
```

### Scenario 3: Lending Protocol Paused
```
Problem: Morpho paused, can't withdraw
Response:
  - Strategy.withdraw() fails
  - Vault.withdraw() reverts gracefully
  - Owner can emergencyWithdrawStrategy()
  - Or switch to different strategy
```

### Scenario 4: High Volatility
```
Problem: GBP/USD spikes 15% in 1 hour
Response:
  - Price sanity check fails
  - Deposits blocked automatically
  - Owner calls updateLastPrice() after confirming real
  - System resumes normal operation
```

---

## ✅ COMPLETE FLOW SUMMARY

1. **User deposits USDC** → Gets vault shares
2. **Vault allocates funds** → 90% lending, 10% perp
3. **Yield accrues** → Lending interest + perp PnL
4. **Fees harvested** → 20% to protocol, 80% to users
5. **User withdraws** → Burns shares, gets USDC back
6. **Owner manages** → Strategy switches, rebalancing
7. **Safety systems** → Circuit breakers, pause, rate limits

**Result:** Users get GBP-denominated yield on USDC deposits with downside protection.

---

**END OF USER FLOW**
