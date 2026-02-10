# Ostium Actual Fees & Redemption Fee Analysis

## 🎯 Key Discovery: Fees are MUCH Lower Than Expected

### Actual Ostium Fee Structure (GBP/USD Forex)

| Fee Type | Rate | Cost on $10k Position |
|----------|------|----------------------|
| **Opening** | 3 bps (0.03%) | $3 ✅ |
| **Closing** | 0 bps (FREE!) | $0 ✅✅✅ |
| **Rollover/Funding** | ~0.01% per day | ~$1/day |
| **Oracle** | $0.10 flat | $0.10 |

**Source:** [Ostium Fee Breakdown Documentation](https://ostium-labs.gitbook.io/ostium-docs/fee-breakdown)

---

## Updated Rebalancing Cost Analysis

### Original (Incorrect) Estimate:
```
Opening fee:   $10 (0.10%)  ❌ WRONG
Closing fee:   $10 (0.10%)  ❌ WRONG
Funding:       $10 (10 days)
──────────────────────────────
Total:         $30 (0.3%)
```

### Actual Ostium Fees:
```
Opening fee:   $3 (0.03%)   ✅ CORRECT
Closing fee:   $0 (FREE!)   ✅ CORRECT
Funding:       $10 (10 days, ~0.01%/day)
──────────────────────────────
Total:         $13 (0.13%)   ← 57% cheaper!
```

---

## Normal Operations: Mint & Redeem

### Mint (User Deposits $10,000 USDC)

**Current Fee Structure:**
```
Split: $9,000 Morpho + $1,000 Perp

Perp Position:
├─ Notional: $10,000 (10x leverage)
├─ Opening fee: $10,000 × 0.03% = $3
├─ Oracle fee: $0.10
└─ Total cost: $3.10

User receives: $10,000 worth of GBPb
Protocol cost: $3.10 (0.031%)
```

### Redeem (User Withdraws $10,000 USDC)

**Current Fee Structure:**
```
Close proportional perp position:
├─ Notional: $10,000
├─ Closing fee: $0 (FREE!) ✅
├─ Funding fees: ~$10 (if held 10 days)
├─ Oracle fee: $0.10 (refunded on success)
└─ Total cost: ~$10

Protocol cost: $10 (0.1%)
```

---

## 💡 User's Brilliant Suggestion: Redemption Fee

### The Idea:
Since closing is **FREE** and opening is **cheap** (3 bps), we could:
1. **Mint:** FREE or minimal fee
2. **Redeem:** Charge small redemption fee to cover:
   - Accumulated funding fees
   - Future rebalancing costs
   - Protocol sustainability

### Economic Model

#### Option A: No Redemption Fee (Current)
```
Per $10,000 operation:
├─ Mint cost: $3 (opening)
├─ Redeem cost: $10 (funding)
├─ Rebalancing: $13 per event (amortized)
└─ Net cost: ~$26 per round-trip

Revenue: $0
Coverage: Rely on Morpho yield (5% APY)
```

#### Option B: Small Redemption Fee (Proposed)
```
Per $10,000 operation:
├─ Mint cost: $3 (opening)
├─ Mint fee charged: $0 (free minting!)
├─ Redeem cost: $10 (funding)
├─ Redeem fee charged: 0.2% = $20
└─ Net revenue: $20 - $10 = +$10

Revenue: $10 per redemption
Coverage: Covers funding + contributes to rebalancing costs
```

---

## Proposed Fee Structure

### Strategy 1: Pure Cost Recovery
```
Mint Fee:    0 bps (FREE)
Redeem Fee:  10 bps (0.10%)

Rationale:
- Free minting encourages TVL growth
- 10 bps redemption covers funding fees
- Competitive with other stablecoins (USDC redemption = free, but we offer yield)
```

### Strategy 2: Sustainability Buffer
```
Mint Fee:    0 bps (FREE)
Redeem Fee:  20 bps (0.20%)

Rationale:
- Free minting encourages TVL growth
- 20 bps redemption covers:
  - Funding fees: ~10 bps
  - Rebalancing buffer: ~10 bps
  - Protocol sustainability: Small profit margin
```

### Strategy 3: Balanced Fees
```
Mint Fee:    5 bps (0.05%)
Redeem Fee:  15 bps (0.15%)

Rationale:
- Minimal mint fee (covers opening cost)
- Moderate redeem fee (covers funding + buffer)
- Total round-trip: 20 bps (0.20%)
- Still competitive with alternatives
```

---

## Competitive Analysis

### Other GBP Stablecoins/Protocols:

| Protocol | Mint Fee | Redeem Fee | Yield | Notes |
|----------|----------|------------|-------|-------|
| **Angle Protocol** | 0-0.3% | 0-0.3% | Variable | Dynamic fees based on reserves |
| **Paxos USDP** | 0% | 0% | 0% | No yield, pure stablecoin |
| **Compound** | 0% | 0% | ~3% | Protocol risk, no stablecoin |
| **Our Protocol** | **0-5 bps** | **10-20 bps** | **~4-5%** | GBP-denominated + yield |

**Competitive Advantage:**
- Lower fees than Angle (0-0.3%)
- Higher yield than alternatives
- GBP exposure + USD collateral = unique offering

---

## Updated Economics Model

### Assuming 20 bps (0.20%) Redemption Fee

#### Per $10,000 Position (30-day hold):

**Revenue:**
```
Morpho yield:         $10,000 × 90% × 5% / 12 = $37.50
Redemption fee:       $10,000 × 0.20% = $20.00
──────────────────────────────────────────────────
Total revenue:                                $57.50
```

**Costs:**
```
Opening fee:          $10,000 × 0.03% = $3.00
Funding fees (30d):   $10,000 × 0.01% × 30 = $30.00
Oracle fees:          $0.20
Gas (amortized):      ~$5.00
──────────────────────────────────────────────────
Total costs:                                  $38.20
```

**Net Profit:**
```
Revenue - Costs = $57.50 - $38.20 = $19.30
Monthly return: 1.93%
Annualized: ~23% on the fees alone!
```

---

## Implementation Recommendations

### Recommended Fee Structure:
```solidity
uint256 public constant MINT_FEE_BPS = 0;     // FREE minting
uint256 public constant REDEEM_FEE_BPS = 20;   // 0.20% redemption
```

### Why This Works:

1. **Free Minting:**
   - Encourages TVL growth
   - Marketing advantage ("No fees to enter!")
   - Covers opening cost from redemption fees

2. **20 bps Redemption:**
   - Covers funding fees (~10 bps)
   - Creates rebalancing buffer (~5 bps)
   - Protocol profit margin (~5 bps)
   - Still competitive (vs Angle's 0-30 bps)

3. **Economic Sustainability:**
   - Morpho yield: ~4.5% APY
   - Redemption fees: ~0.5% (assuming 20% annual turnover)
   - **Total revenue: ~5% APY**
   - **Total costs: ~1.5% APY** (funding + rebalancing)
   - **Net profit: ~3.5% APY** ✅

---

## Rebalancing Cost Coverage

### With Redemption Fees:

Assume:
- TVL: $10M
- Annual redemptions: $20M (200% turnover - conservative)
- Redemption fee: 20 bps

**Annual Revenue from Fees:**
```
$20M × 0.20% = $40,000 per year
```

**Annual Rebalancing Costs:**
Assume rebalancing 2x per year:
```
Opening fees:   $10M × 0.03% × 2 = $6,000
Funding fees:   $10M × 0.01% × 365 = $36,500
──────────────────────────────────────────────
Total costs:                        $42,500
```

**Coverage Ratio:**
```
Revenue / Costs = $40,000 / $42,500 = 94%

Plus Morpho yield: $10M × 90% × 5% = $450,000
──────────────────────────────────────────────
Total coverage: More than sufficient ✅
```

---

## User Experience Impact

### Scenario: User deposits $10,000 for 6 months

**With 0 bps mint / 20 bps redeem:**
```
Deposit:          $10,000 (no fee)
Mint:             7,874 GBPb (at 1.27 GBP/USD)

Hold 6 months:    Earn ~2.5% yield = $250

Redeem:           $10,250 (with yield)
Redemption fee:   $10,250 × 0.20% = $20.50
Net received:     $10,229.50

Net gain: $229.50 (2.3% over 6 months = 4.6% APY)
```

**User still gets:**
- 4.6% APY net (after fees)
- GBP exposure
- Single-sided USDC deposit
- Better than:
  - USDC in wallet: 0%
  - Most stablecoins: 0-3%
  - Morpho direct: ~5% but no GBP exposure

---

## Code Implementation

### Add to GBPbMinter.sol:

```solidity
// Fee constants
uint256 public constant MINT_FEE_BPS = 0;     // 0% - free minting
uint256 public constant REDEEM_FEE_BPS = 20;   // 0.20% redemption fee

// Fee recipient
address public feeRecipient;

// In mint():
function mint(uint256 usdcAmount) external nonReentrant whenNotPaused returns (uint256 gbpAmount) {
    // ... existing code ...

    // No mint fee (MINT_FEE_BPS = 0)
    // But if we want to add it later:
    // uint256 mintFee = (usdcAmount * MINT_FEE_BPS) / BPS;
    // if (mintFee > 0) {
    //     usdc.safeTransfer(feeRecipient, mintFee);
    //     usdcAmount -= mintFee;
    // }

    // ... rest of code ...
}

// In redeem():
function redeem(uint256 gbpAmount) external nonReentrant whenNotPaused returns (uint256 usdcAmount) {
    // ... existing code ...

    // Calculate redemption fee
    uint256 redeemFee = (totalWithdrawn * REDEEM_FEE_BPS) / BPS;
    uint256 netAmount = totalWithdrawn - redeemFee;

    // Transfer fee to fee recipient
    if (redeemFee > 0) {
        usdc.safeTransfer(feeRecipient, redeemFee);
    }

    // Send net amount to user
    usdc.safeTransfer(msg.sender, netAmount);

    emit Redeemed(msg.sender, gbpAmount, netAmount);
    emit FeeCollected(msg.sender, redeemFee);

    return netAmount;
}
```

---

## Summary & Recommendation

### 🎯 Key Findings:

1. **Ostium fees are much lower than estimated:**
   - Opening: 3 bps (not 10 bps)
   - Closing: FREE (not 10 bps)
   - Total: 57% cheaper than expected!

2. **Redemption fee makes economic sense:**
   - Covers funding costs
   - Creates rebalancing buffer
   - Aligns incentives (holders = yield earners)

3. **Competitive positioning:**
   - 0 bps mint + 20 bps redeem = 20 bps total
   - vs Angle: 0-30 bps
   - vs other protocols: Similar or better
   - Plus: ~4.5% net yield!

### 📊 Recommended Implementation:

```
Mint Fee:     0 bps (FREE)
Redeem Fee:   20 bps (0.20%)
────────────────────────────
Total cost:   20 bps round-trip
Net yield:    ~4.5% APY
```

### ✅ Benefits:

1. **For Users:**
   - Free entry (no mint fee)
   - Competitive redemption fee
   - Net yield: ~4.5% APY (after fees)
   - GBP exposure

2. **For Protocol:**
   - Sustainable economics
   - Covers all operational costs
   - Buffer for rebalancing
   - ~3.5% profit margin

3. **For Growth:**
   - "Free minting" marketing message
   - Competitive with alternatives
   - Encourages TVL growth
   - Aligns incentives (long-term holders benefit)

### 🚀 Next Steps:

1. Implement redemption fee in GBPbMinter
2. Add fee recipient management
3. Create fee tracking/reporting
4. Update tests to verify fee calculations
5. Document fee structure in user-facing materials

**This changes the economics from "break-even" to "profitable" while remaining highly competitive!**
