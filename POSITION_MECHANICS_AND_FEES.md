# Position Opening/Closing Mechanics & Fees Analysis

## Question 1: How Quickly Do Positions Open/Close During User Operations?

### TL;DR
**All operations happen synchronously within a single transaction** - there's no waiting period or delay. Users get their tokens/USDC immediately.

---

### During MINT (User Deposits USDC)

**Transaction Flow (ALL in one tx):**

```solidity
User → GBPbMinter.mint(10,000 USDC)
├─ 1. Transfer USDC from user to minter ⚡ instant
├─ 2. Split: 9,000 USDC (90%) + 1,000 USDC (10%)
├─ 3. Deposit 9,000 USDC to Morpho lending ⚡ instant
├─ 4. Open perp position ⚡ instant
│   ├─ Transfer 1,000 USDC to PerpPositionManager
│   ├─ PerpPositionManager → OstiumProvider.increasePosition()
│   ├─ OstiumProvider → Ostium Protocol
│   │   ├─ Transfer collateral to Ostium
│   │   ├─ Open 10,000 USDC notional position (10x leverage)
│   │   ├─ Deduct opening fees (~0.1% of notional = ~10 USDC)
│   │   └─ Position is LIVE immediately
│   └─ Return control to minter
└─ 5. Mint GBPb tokens to user ⚡ instant
```

**Timeline:** Single transaction, ~500-700k gas
- **Opening fee:** ~0.1% of notional size (paid from collateral)
- **User receives:** GBPb tokens immediately
- **Position status:** Fully open by end of transaction

**Code Reference:** `src/tokens/GBPbMinter.sol:155-186`

---

### During REDEEM (User Withdraws USDC)

**Transaction Flow (ALL in one tx):**

```solidity
User → GBPbMinter.redeem(7,874 GBPb)
├─ 1. Burn GBPb tokens from user ⚡ instant
├─ 2. Calculate USDC amount: 10,000 USDC
├─ 3. Calculate split: 9,000 lending + 1,000 perp
├─ 4. Withdraw 9,000 USDC from Morpho ⚡ instant
├─ 5. Close proportional perp position ⚡ instant
│   ├─ PerpPositionManager.withdrawCollateral(1,000 USDC)
│   ├─ Calculate share: 1,000/total collateral
│   ├─ Close that % of position via OstiumProvider
│   │   ├─ Calculate PnL at current market price
│   │   ├─ Deduct closing fees (~0.1% of notional)
│   │   ├─ Apply any accumulated funding fees
│   │   ├─ Realize profit/loss
│   │   └─ Transfer net collateral back
│   └─ Return collateral to minter
└─ 6. Transfer total USDC to user ⚡ instant
```

**Timeline:** Single transaction, ~700-900k gas
- **Closing fee:** ~0.1% of notional size (deducted from collateral)
- **Funding fees:** Accumulated hourly fees (can be positive or negative)
- **User receives:** Net USDC after all fees and PnL
- **Position status:** Partially/fully closed by end of transaction

**Code Reference:** `src/tokens/GBPbMinter.sol:188-221`

---

### Key Points on Timing

1. **No Async Operations:** Everything is synchronous on-chain
2. **No Waiting Period:** User gets tokens/USDC in same block
3. **Atomic Execution:** All-or-nothing - if perp fails, entire tx reverts
4. **Immediate Settlement:** Positions are live/closed by end of transaction

---

## Question 2: What Happens During 50% Health Rebalancing?

### TL;DR
**Complete position tear-down and rebuild** - Close position (realize losses + pay fees), consolidate all funds, then reopen fresh position with remaining capital.

---

### Rebalancing Trigger

```solidity
Health Factor = (Collateral + PnL) / Collateral * 10000

Example:
- Initial collateral: 1,000 USDC
- PnL: -500 USDC (50% loss)
- Health: (1,000 - 500) / 1,000 * 10000 = 5,000 (50%)
```

**When health < 5,000 (50%):** Rebalancing needed
**Buffer before liquidation:** ~40-45% health = liquidation risk

---

### Complete Rebalancing Process

**Step 1: Close Position & Realize Loss**
```solidity
perpManager.decreasePosition(1e18) // Close 100%
```

**What happens:**
- Close entire 10,000 USDC notional position
- Calculate final PnL at current market price
- **Pay closing fees:** ~0.1% of notional (~10 USDC)
- **Settle funding fees:** Accumulated hourly fees
- **Realize loss:** Convert unrealized PnL to actual loss
- Example: Started with 1,000 USDC → Get back ~490 USDC

**Code:** `src/tokens/GBPbMinter.sol:507`

---

**Step 2: Consolidate All Funds**
```solidity
activeStrategy.withdrawAll()
```

**What happens:**
- Withdraw entire 9,000 USDC from Morpho lending
- Add to the ~490 USDC from closed perp position
- Total available: ~9,490 USDC
- **Loss realized:** 510 USDC (1,000 initial perp → 490 returned)

**Code:** `src/tokens/GBPbMinter.sol:510`

---

**Step 3: Recalculate New TVL**
```solidity
uint256 totalUSDC = usdc.balanceOf(address(this))
uint256 newTVL = totalUSDC // 9,490 USDC
```

**Loss accounting:**
- Old TVL: 10,000 USDC
- New TVL: 9,490 USDC
- **Realized loss: 510 USDC** (5.1% of original TVL)

**Code:** `src/tokens/GBPbMinter.sol:513-515`

---

**Step 4: Reallocate with Fresh 90:10 Split**
```solidity
newLendingAmount = 9,490 * 90% = 8,541 USDC
newPerpAmount = 9,490 * 10% = 949 USDC
```

**Code:** `src/tokens/GBPbMinter.sol:518-519`

---

**Step 5: Deposit to Lending**
```solidity
activeStrategy.deposit(8,541 USDC)
```

**What happens:**
- Deposit 8,541 USDC to Morpho
- Start earning yield immediately

**Code:** `src/tokens/GBPbMinter.sol:522-525`

---

**Step 6: Reopen Perp Position**
```solidity
perpManager.increasePosition(9,490 USDC notional, 949 USDC collateral)
```

**What happens:**
- Open new position with 949 USDC collateral
- 10x leverage → 9,490 USDC notional
- **Pay opening fees:** ~0.1% of notional (~9.5 USDC)
- Actual collateral after fees: ~939.5 USDC
- New position starts at current market price (zero PnL)

**Code:** `src/tokens/GBPbMinter.sol:527-531`

---

### Fee Breakdown During Rebalancing

**Fees Paid:**

1. **Closing Fees (on old position):**
   - Rate: ~0.1% of notional
   - Calculation: 10,000 USDC notional × 0.1% = ~10 USDC
   - Deducted from: Returned collateral

2. **Accumulated Funding Fees (on old position):**
   - Rate: ~0.01% per day × days held
   - Example: If held 10 days = 0.1% = ~10 USDC
   - Can be positive or negative depending on funding rate

3. **Opening Fees (on new position):**
   - Rate: ~0.1% of notional
   - Calculation: 9,490 USDC notional × 0.1% = ~9.5 USDC
   - Deducted from: New collateral

**Total Fees Example:**
- Closing: ~10 USDC
- Funding (10 days): ~10 USDC
- Opening: ~9.5 USDC
- **Total fees: ~29.5 USDC** (0.3% of original TVL)

---

### Complete Example: $10,000 TVL with 50% Perp Loss

**Before Rebalancing:**
- Morpho lending: 9,000 USDC
- Perp position:
  - Collateral: 1,000 USDC
  - Notional: 10,000 USDC (10x leverage)
  - PnL: -500 USDC (50% loss)
  - Health: 50%
- Total TVL: 9,500 USDC (9,000 lending + 500 perp value)

**Rebalancing Process:**

1. **Close perp position:**
   - PnL realized: -500 USDC loss
   - Closing fee: -10 USDC
   - Funding fees: -10 USDC
   - Collateral returned: 480 USDC

2. **Withdraw from lending:**
   - Morpho withdrawal: 9,000 USDC

3. **Total available:**
   - 9,000 + 480 = 9,480 USDC
   - Loss realized: 520 USDC (5.2%)

4. **Reallocate 90:10:**
   - Lending: 8,532 USDC (90%)
   - Perp: 948 USDC (10%)

5. **Reopen perp:**
   - Collateral: 948 USDC
   - Opening fee: -9.5 USDC
   - Net collateral: 938.5 USDC
   - Notional: 9,385 USDC (10x)
   - New health: 100% (zero PnL initially)

**After Rebalancing:**
- Morpho lending: 8,532 USDC
- Perp position:
  - Collateral: 938.5 USDC
  - Notional: 9,385 USDC
  - PnL: 0 USDC (fresh position)
  - Health: 100%
- Total TVL: 9,470.5 USDC
- **Total loss from rebalancing: 529.5 USDC (5.3%)**

---

### Important Considerations

#### 1. **Fee Impact on Losses**
- Perp losses: 500 USDC (50% of collateral)
- Fees paid: ~29.5 USDC (0.3% of TVL)
- **Total cost: 529.5 USDC (5.3% of original TVL)**

#### 2. **Position Reset**
- Old position had -500 USDC unrealized loss
- After rebalancing, new position starts at zero PnL
- Same market exposure maintained (long GBP/USD)

#### 3. **Slippage Risk**
- Closing large position may face slippage
- Opening new position may face slippage
- Market movements during transaction can impact outcome

#### 4. **Gas Costs**
- Rebalancing tx: ~1.2M gas
- At 50 gwei & $3000 ETH: ~$180 gas cost
- Should be factored into rebalancing decision

---

### Position Management Strategy

**Health Monitoring:**
```
100% - 70%: Healthy (green) ✅
70% - 60%:  Warning (yellow) ⚠️
60% - 50%:  Alert (orange) ⚠️⚠️
< 50%:      Critical - REBALANCE NOW (red) 🚨
< 40%:      Liquidation risk (red) ☠️
```

**Fee Optimization:**
- Frequent rebalancing = more fees paid
- Infrequent rebalancing = higher liquidation risk
- Optimal: Rebalance at 50% threshold (current design)

**Alternative Approaches (Not Implemented):**
1. Add collateral without closing position
   - Pro: No closing/opening fees
   - Con: Requires fresh capital
2. Partial position close
   - Pro: Smaller fees
   - Con: Complex calculation, still pays fees
3. Automated keeper
   - Pro: Fast response to health drops
   - Con: Gas costs, keeper fees

---

## Summary

### Normal Operations (Mint/Redeem)
✅ **Instant:** All in one transaction
✅ **Synchronous:** No waiting period
✅ **Low fees:** ~0.1-0.2% total (opening/closing fees)
✅ **Atomic:** All-or-nothing execution

### Rebalancing (50% Health)
⚠️ **Complete rebuild:** Close everything, reopen fresh
⚠️ **Higher fees:** ~0.3% total (close old + open new)
⚠️ **Loss realization:** Unrealized losses become real
⚠️ **Capital preservation:** Maintains 90:10 allocation
✅ **Health restored:** New position at 100% health

### Cost Example
For $10,000 TVL with 50% perp loss:
- Perp loss: $500 (5.0%)
- Fees: $30 (0.3%)
- **Total cost: $530 (5.3%)**

This is significantly better than liquidation, which could cost 100% of collateral.
