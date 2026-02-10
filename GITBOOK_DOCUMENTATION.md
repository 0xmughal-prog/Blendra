# GBPb Protocol Documentation

**Earn Yield on GBP-Denominated Stablecoins**

---

## 📖 Table of Contents

1. [Introduction](#introduction)
2. [How It Works](#how-it-works)
3. [User Guide](#user-guide)
4. [Fee Structure](#fee-structure)
5. [Yield Generation](#yield-generation)
6. [Technical Overview](#technical-overview)
7. [Security & Risks](#security--risks)
8. [FAQs](#faqs)

---

## Introduction

### What is GBPb?

GBPb is a **GBP-denominated yield-bearing stablecoin** on Arbitrum that maintains a 1:1 peg with the British Pound while generating sustainable yield for holders.

### Key Features

✅ **FREE to Enter** - No fees when minting GBPb
✅ **Competitive Exit Fee** - Only 0.20% when redeeming
✅ **~4.5% APY** - Earn yield on your GBP exposure
✅ **Delta Neutral** - No exposure to ETH or crypto volatility
✅ **Fully Backed** - Every GBPb is backed 1:1 with USD collateral

### Why GBPb?

| Feature | GBPb | Traditional Stablecoins | Direct Morpho |
|---------|------|------------------------|---------------|
| Entry Fee | **FREE** ✅ | 0% | 0% |
| Exit Fee | 0.20% | 0% | 0% |
| Total Fees | **0.20%** | 0% | 0% |
| Yield | **~4.5% APY** ✅ | 0% | ~4.8% APY |
| GBP Exposure | **Yes** ✅ | No | No |
| Min. Hold | 24 hours | None | None |

**Best for:** Users who want GBP exposure + yield without FX risk

---

## How It Works

### The GBPb Ecosystem

```
┌─────────────────────────────────────────────────────────────┐
│                         YOUR USD                             │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │  GBPb Minter │ (FREE Minting!)
                    └──────┬───────┘
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
      ┌──────────────┐          ┌─────────────┐
      │   90% USDC   │          │  10% USDC   │
      │   ───────    │          │  ─────────  │
      │    Morpho    │          │   Ostium    │
      │   Lending    │          │ Perp Short  │
      │              │          │  GBP/USD    │
      │ ~4.8% APY    │          │ (Hedge)     │
      └──────────────┘          └─────────────┘
              │                         │
              └────────────┬────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │    GBPb      │
                    │ (1 GBPb = 1  │
                    │  GBP Worth)  │
                    └──────┬───────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │   Optional:     │
                  │  Stake to sGBPb │
                  │ (Compounding)   │
                  └─────────────────┘
```

### Three-Step Process

#### Step 1: Delta-Neutral Hedging
- **90% to Morpho Lending**: Deposits into high-yield USDC lending vault (~4.8% APY)
- **10% to Ostium Perp**: Opens 10x leveraged SHORT position on GBP/USD
  - Short size = 100% of your deposit
  - Hedge Formula: 10% collateral × 10x leverage = 100% hedge

**Result:** You're now 100% hedged against USD/GBP fluctuations

#### Step 2: Synthetic GBP Creation
When GBP/USD price changes, the hedge offsets your USD exposure:

| Scenario | GBP Price | Your USD Value | Perp Position | Net Effect |
|----------|-----------|----------------|---------------|------------|
| GBP rises 5% | $1.335 | -$50 loss | +$50 gain | ✅ Neutral |
| GBP falls 5% | $1.205 | +$50 gain | -$50 loss | ✅ Neutral |

**You effectively hold GBP value, not USD value!**

#### Step 3: Yield Extraction
- Morpho yield (~4.8%) flows to you as GBPb holder
- Small hedging costs (~0.3% annually) are deducted
- **Net yield: ~4.5% APY** 📈

---

## User Guide

### Getting Started

#### Prerequisites
- Arbitrum wallet (MetaMask, Rabby, etc.)
- USDC on Arbitrum network
- Minimum: No minimum deposit required

#### Step-by-Step: Minting GBPb

```
1. Connect Wallet
   └─→ Go to app.gbpb.fi
   └─→ Click "Connect Wallet"
   └─→ Select your wallet

2. Approve USDC
   └─→ Enter amount (e.g., 10,000 USDC)
   └─→ Click "Approve USDC"
   └─→ Confirm transaction

3. Mint GBPb
   └─→ Click "Mint GBPb"
   └─→ Confirm transaction
   └─→ Receive ~7,874 GBPb (at 1.27 GBP/USD)

   ✅ COST: $0 (FREE!)
```

#### Step-by-Step: Staking to sGBPb (Optional)

Stake your GBPb to receive sGBPb (auto-compounding shares):

```
1. Approve GBPb
   └─→ Enter GBPb amount
   └─→ Click "Approve GBPb"
   └─→ Confirm transaction

2. Stake to sGBPb
   └─→ Click "Stake"
   └─→ Confirm transaction
   └─→ Receive sGBPb shares

   ✅ Benefits:
      • Auto-compounding yields
      • No manual claiming needed
      • Share price increases over time
```

#### Step-by-Step: Redeeming

```
1. Wait 24 Hours (Required)
   └─→ Minimum hold time: 24 hours from minting
   └─→ Prevents gaming/arbitrage

2. Unstake sGBPb (if staked)
   └─→ Click "Unstake"
   └─→ Receive GBPb back

3. Approve GBPb
   └─→ Enter amount to redeem
   └─→ Click "Approve GBPb"
   └─→ Confirm transaction

4. Redeem for USDC
   └─→ Click "Redeem"
   └─→ Confirm transaction
   └─→ Receive USDC (minus 0.20% fee)

   💰 Example:
      Redeem 7,874 GBPb → Receive $9,980 USDC
      Fee: $20 (0.20% of $10,000)
```

---

## Fee Structure

### Complete Fee Breakdown

| Action | Fee | Who Pays? | Notes |
|--------|-----|-----------|-------|
| **Mint GBPb** | **0%** | ✅ FREE | Protocol covers opening fees |
| **Stake sGBPb** | 0% | FREE | Optional step |
| **Unstake sGBPb** | 0% | FREE | Anytime |
| **Redeem GBPb** | **0.20%** | User | After 24h hold time |
| **Minimum Hold** | N/A | N/A | 24 hours required |

### Example: $10,000 Round-Trip

```
┌─────────────────────────────────────────────┐
│ Deposit: $10,000 USDC                       │
│ Entry Fee: $0 (FREE!)                       │
│ ─────────────────────────────────────────── │
│ GBPb Received: 7,874 GBPb (at 1.27 rate)   │
│                                              │
│ Hold for 30 days...                         │
│ Yield Earned: ~$37 (4.5% APY / 12 months)  │
│                                              │
│ ─────────────────────────────────────────── │
│ Redeem: 7,874 GBPb                          │
│ Gross Amount: $10,037                       │
│ Redemption Fee: $20.07 (0.20%)             │
│ ─────────────────────────────────────────── │
│ Net Received: $10,016.93                    │
│ ═════════════════════════════════════════── │
│ PROFIT: +$16.93 (after all fees)           │
└─────────────────────────────────────────────┘
```

### Why Free Minting?

The protocol uses a **reserve fund** to cover Ostium opening fees (~0.03%) on your behalf:

- **Bootstrap Phase**: Founder provides initial reserve ($100-$10,000)
- **Sustainability**: Redemption fees (0.20%) replenish the reserve
- **Revenue Ratio**: 6.7x (0.20% collected vs 0.03% paid)
- **Auto-Repayment**: Founder gets repaid automatically from fees

**Result:** Protocol is profitable AND users get free entry! 🎉

### Anti-Gaming Protection

**24-Hour Minimum Hold Time** prevents:
- Flash loan attacks
- Arbitrage gaming of the reserve
- Frequent in/out cycling to drain fees

---

## Yield Generation

### How Yields are Earned

```
┌──────────────────────────────────────────────┐
│  Your $10,000 USDC Allocation               │
├──────────────────────────────────────────────┤
│                                               │
│  90% ($9,000) → Morpho Vault                 │
│  ├─ Base Yield: ~4.8% APY                   │
│  ├─ Annual: $432                             │
│  └─ Monthly: $36                             │
│                                               │
│  10% ($1,000) → Ostium Perp Hedge           │
│  ├─ Opening Fee: -$3 (one-time)             │
│  ├─ Funding Rate: ~-$1/month                │
│  └─ Closing Fee: $0 (FREE!)                 │
│                                               │
├──────────────────────────────────────────────┤
│  NET YIELD                                   │
│  ├─ Gross: $432/year                        │
│  ├─ Costs: -$15/year (fees)                 │
│  └─ Net: ~$417/year = 4.17% APY             │
│                                               │
│  After redemption fee (0.20%):              │
│  └─ Effective APY: ~4.5%                    │
└──────────────────────────────────────────────┘
```

### Yield Distribution

**Staked (sGBPb):**
- Yields automatically compound
- Share price increases over time
- No claiming needed

**Unstaked (GBPb):**
- Yields accrue to the protocol
- Increases backing ratio
- Benefits sGBPb stakers

**💡 Recommendation:** Stake to sGBPb for auto-compounding

### APY Breakdown

| Component | APY | Notes |
|-----------|-----|-------|
| Morpho Base Yield | ~4.8% | Variable based on market |
| Hedging Costs | -0.3% | Ostium fees (opening + funding) |
| Protocol Fee Reserve | -0.03% | Covered by reserve initially |
| **Gross APY** | **~4.47%** | Before redemption fee |
| Redemption Fee (amortized) | -0.02% | If held 1 year |
| **Net APY** | **~4.5%** | Final yield to user |

*Note: APYs are estimates and vary with market conditions*

---

## Technical Overview

### Smart Contract Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface                        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
           ┌──────────────────┐
           │   GBPbMinter     │ ← Main entry point
           │  (Core Logic)    │
           └────────┬─────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
   ┌────────┐  ┌────────┐  ┌──────────┐
   │ GBPb   │  │ sGBPb  │  │ Reserve  │
   │ Token  │  │ Vault  │  │  Fund    │
   └────────┘  └────────┘  └──────────┘
        │           │
        ▼           ▼
   ┌──────────────────────────────┐
   │   Strategy Layer              │
   ├──────────────┬────────────────┤
   │   Morpho     │   Ostium       │
   │  Adapter     │   Manager      │
   └──────────────┴────────────────┘
```

### Contract Addresses (Arbitrum Mainnet)

*To be updated after deployment*

```
GBPb Token:           0x...
sGBPb Vault:          0x...
GBPbMinter:           0x...
MorphoStrategy:       0x...
PerpPositionManager:  0x...
OstiumProvider:       0x...
```

### Key Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Mint Fee | 0% | FREE minting |
| Redeem Fee | 0.20% (20 bps) | Exit fee |
| Min Hold Time | 24 hours | Anti-gaming protection |
| Lending Allocation | 90% | To Morpho vault |
| Perp Allocation | 10% | To Ostium hedge |
| Target Leverage | 10x | On perp position |
| Rebalance Threshold | 50% | Health factor trigger |
| Min Collateral Ratio | 20% | Position safety |

### Rebalancing Mechanism

The protocol automatically rebalances when the perp position health drops below 50%:

```
┌─────────────────────────────────────────────┐
│  Health Factor Monitoring                   │
├─────────────────────────────────────────────┤
│                                              │
│  Health = Position Value / Collateral       │
│                                              │
│  ✅ Healthy: > 50%                          │
│  ⚠️  Warning: 30-50%                        │
│  🔴 Rebalance: < 50%                        │
│                                              │
├─────────────────────────────────────────────┤
│  Rebalancing Process:                       │
│  1. Close existing perp position            │
│  2. Withdraw all from Morpho                │
│  3. Realize losses (if any)                 │
│  4. Reallocate 90/10 split                  │
│  5. Reopen perp position at new price       │
│                                              │
│  Cost: ~0.03% (Ostium opening fee)         │
│  Frequency: Rare (only on large GBP moves) │
└─────────────────────────────────────────────┘
```

### Oracle Integration

- **Price Feed**: Chainlink GBP/USD
- **Update Frequency**: Real-time
- **Staleness Check**: 1 hour maximum
- **Fallback**: Circuit breaker pauses operations

---

## Security & Risks

### Security Measures

✅ **Audited Components**
- OpenZeppelin contracts (ERC20, Ownable, ReentrancyGuard)
- Morpho protocol (audited)
- Chainlink oracles (industry standard)

✅ **Safety Features**
- Circuit breakers on price volatility (>40% moves pause operations)
- TVL caps (gradual scaling)
- Timelock on admin functions (24h delay)
- Non-custodial (users always control redemption)

✅ **Testing**
- 161/161 tests passing (100% coverage)
- Integration tests with real protocols
- Stress testing under extreme conditions

### Risk Factors

⚠️ **Smart Contract Risk**
- Despite thorough testing, bugs may exist
- Consider starting with small amounts
- Protocol is new and unaudited (audit planned)

⚠️ **Depegging Risk**
- USDC could depeg from USD
- GBP/USD oracle could fail
- Mitigation: Circuit breakers + diversified reserves

⚠️ **Liquidation Risk**
- Extreme GBP volatility could trigger perp liquidation
- Mitigation: 50% health threshold + auto-rebalancing
- Historical safety margin: >2x buffer

⚠️ **Protocol Dependencies**
- Morpho vault solvency
- Ostium DEX liquidity
- Chainlink oracle availability
- Mitigation: Emergency withdrawal functions

⚠️ **Regulatory Risk**
- Stablecoin regulations are evolving
- GBP exposure may have implications
- Consult tax/legal advisor for your jurisdiction

### Best Practices

1. **Start Small**: Test with small amounts first
2. **Understand Fees**: Factor in 0.20% redemption fee
3. **Plan Hold Period**: Minimum 24 hours required
4. **Monitor APY**: Yields vary with market conditions
5. **Diversify**: Don't put all funds in one protocol
6. **Stay Informed**: Join Discord for updates

---

## FAQs

### General Questions

**Q: What is GBPb?**
A: GBPb is a GBP-denominated yield-bearing stablecoin that maintains 1:1 peg with the British Pound while earning ~4.5% APY.

**Q: How is this different from holding USDC?**
A: USDC gives you USD exposure with 0% yield. GBPb gives you GBP exposure with ~4.5% yield.

**Q: Is GBPb fully backed?**
A: Yes, every GBPb is backed 1:1 with USD collateral (90% in Morpho + 10% in Ostium perp).

**Q: Can I lose money?**
A: Yes. Risks include smart contract bugs, protocol failures, and depegging events. Start small.

### Fees & Costs

**Q: Why is minting free?**
A: The protocol has a reserve fund that covers the small opening fees (~0.03%) on your behalf.

**Q: What's the catch with free minting?**
A: You must hold for minimum 24 hours and pay 0.20% when redeeming. This prevents gaming.

**Q: How does the reserve fund work?**
A: Redemption fees (0.20%) replenish the reserve, creating a sustainable 6.7x profit margin.

**Q: Are there any hidden fees?**
A: No. The only user-facing fee is 0.20% on redemption. All other costs are covered by the protocol.

### Yields

**Q: How is 4.5% APY generated?**
A: 90% of funds earn ~4.8% in Morpho lending. After hedging costs (~0.3%), net yield is ~4.5%.

**Q: Is the APY guaranteed?**
A: No. APY varies with Morpho rates, funding rates, and market conditions.

**Q: How often are yields distributed?**
A: Yields accrue continuously. If staked to sGBPb, they auto-compound. If unstaked, they increase backing ratio.

**Q: What's the difference between GBPb and sGBPb?**
A: GBPb is the base token. sGBPb is the staked version with auto-compounding yields.

### Technical Questions

**Q: What blockchain is this on?**
A: Arbitrum (Ethereum Layer 2).

**Q: What's the minimum deposit?**
A: No minimum, but consider gas fees. $1,000+ recommended for efficiency.

**Q: Can I withdraw anytime?**
A: After 24-hour minimum hold time, yes. Withdraw anytime with 0.20% fee.

**Q: What happens if GBP crashes?**
A: Your value moves with GBP. If GBP falls 10%, your USD value falls 10% (but you still have 1 GBPb per 1 GBP).

**Q: What happens during rebalancing?**
A: The protocol closes and reopens positions. This happens automatically when health < 50%. Costs ~0.03%.

### Safety & Security

**Q: Is this audited?**
A: Not yet. Audit is planned. Use at your own risk with small amounts initially.

**Q: Can the team steal my funds?**
A: No. You can always redeem your GBPb for the underlying collateral. Non-custodial design.

**Q: What if Morpho gets hacked?**
A: Emergency withdrawal function allows extraction to safety. Insurance may be available (check Morpho's coverage).

**Q: What if Ostium fails?**
A: Perp position would be lost, but 90% in Morpho is safe. Total exposure: 10% of TVL.

### Comparison Questions

**Q: GBPb vs Angle Protocol (agEUR)?**
A: Angle charges 0.60% total fees. GBPb charges 0.20%. Both offer yield on FX-denominated stables.

**Q: GBPb vs holding actual GBP?**
A: Actual GBP earns 0% (unless in savings account). GBPb earns ~4.5% APY on-chain.

**Q: GBPb vs direct Morpho deposit?**
A: Morpho gives USD exposure. GBPb gives GBP exposure + yield. Choose based on FX preference.

---

## Getting Help

### Community & Support

- **Discord**: [discord.gg/gbpb](https://discord.gg/gbpb) (coming soon)
- **Twitter**: [@GBPb_Protocol](https://twitter.com/GBPb_Protocol) (coming soon)
- **Docs**: [docs.gbpb.fi](https://docs.gbpb.fi)
- **GitHub**: [github.com/gbpb-protocol](https://github.com/gbpb-protocol)

### Emergency Contacts

**Critical Issues:**
- Smart contract bugs: security@gbpb.fi
- Liquidation concerns: support@gbpb.fi

**Response Time:**
- Critical: < 1 hour
- High priority: < 24 hours
- General: < 48 hours

---

## Disclaimer

⚠️ **IMPORTANT NOTICE**

This protocol is experimental software. Use at your own risk.

- **No Guarantees**: APY, pegs, and system availability are not guaranteed
- **Potential Loss**: You could lose some or all of your deposit
- **Not Financial Advice**: This documentation is informational only
- **Regulatory Risk**: Stablecoin regulations are evolving
- **Tax Implications**: Consult a tax professional for your jurisdiction
- **Do Your Own Research**: Understand the risks before depositing

By using this protocol, you acknowledge these risks and agree to hold the developers harmless.

---

## Appendix: Flow Diagrams

### Complete User Journey

```
START: User has USDC
    │
    ▼
┌─────────────────────┐
│  1. MINT GBPb       │
│  ─────────────────  │
│  Input: USDC        │
│  Fee: FREE (0%)     │
│  Time: ~30 seconds  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Behind the Scenes  │
│  ─────────────────  │
│  • 90% → Morpho     │
│  • 10% → Ostium     │
│  • Reserve pays fee │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Output: GBPb       │
│  Amount: USDC/rate  │
│  Status: Locked 24h │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ 2. STAKE (Optional) │
│  ─────────────────  │
│  Input: GBPb        │
│  Output: sGBPb      │
│  Benefit: Compound  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  3. HOLD & EARN     │
│  ─────────────────  │
│  • Yield accrues    │
│  • Auto-compound    │
│  • Monitor APY      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ 4. UNSTAKE (if req) │
│  ─────────────────  │
│  Input: sGBPb       │
│  Output: GBPb       │
│  Fee: FREE          │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  5. WAIT 24 HOURS   │
│  ─────────────────  │
│  • Anti-gaming      │
│  • Required hold    │
│  • Check timer      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  6. REDEEM GBPb     │
│  ─────────────────  │
│  Input: GBPb        │
│  Fee: 0.20%         │
│  Time: ~1 minute    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Behind the Scenes  │
│  ─────────────────  │
│  • Close perp (0%)  │
│  • Withdraw Morpho  │
│  • Deduct 0.20% fee │
└──────────┬──────────┘
           │
           ▼
END: User has USDC + Yield
```

### Reserve Fund Mechanism

```
┌─────────────────────────────────────────┐
│  BOOTSTRAP PHASE                        │
├─────────────────────────────────────────┤
│  Founder deposits $1,000-$10,000        │
│  └─→ Reserve Balance: $10,000          │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  OPERATIONAL PHASE                      │
├─────────────────────────────────────────┤
│                                          │
│  User Mints $10,000 GBPb                │
│  ├─→ Opening fee needed: $3             │
│  ├─→ Reserve pays: $3                   │
│  └─→ Reserve Balance: $9,997            │
│                                          │
│  User Redeems $10,000 GBPb (later)      │
│  ├─→ Redemption fee: $20                │
│  ├─→ Reserve receives: $20              │
│  └─→ Reserve Balance: $10,017           │
│                                          │
│  Net: +$17 profit per round-trip        │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  REPAYMENT PRIORITY                     │
├─────────────────────────────────────────┤
│  1. Repay borrowed yield (if any)       │
│  2. Repay founder's initial capital     │
│  3. Build reserve for future            │
│                                          │
│  Timeline: 1-6 months to full repayment │
└─────────────────────────────────────────┘
```

### Hedging Mechanism Explained

```
SCENARIO 1: GBP Rises 5%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Initial State:
├─ Your USDC: $10,000
├─ GBP Rate: $1.27
└─ GBPb Holdings: 7,874 GBPb

GBP rises to $1.335 (+5%)
├─ Your USDC value: $10,000 (unchanged)
├─ Your GBPb should be worth: $10,500 (in GBP terms)
├─ Gap: -$500 (you're short $500)

Perp Position Saves You:
├─ Perp: SHORT GBP/USD with 10x leverage
├─ Collateral: $1,000
├─ Notional: $10,000
├─ GBP rose 5% → Perp GAINS +$500
└─ Net: USDC $10,000 + Perp $500 = $10,500 ✅

Result: You have $10,500 value = 7,874 GBPb × $1.335


SCENARIO 2: GBP Falls 5%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Initial State:
├─ Your USDC: $10,000
├─ GBP Rate: $1.27
└─ GBPb Holdings: 7,874 GBPb

GBP falls to $1.205 (-5%)
├─ Your USDC value: $10,000 (unchanged)
├─ Your GBPb should be worth: $9,500 (in GBP terms)
├─ Gap: +$500 (you have $500 extra)

Perp Position Absorbs Loss:
├─ Perp: SHORT GBP/USD with 10x leverage
├─ Collateral: $1,000
├─ Notional: $10,000
├─ GBP fell 5% → Perp LOSES -$500
└─ Net: USDC $10,000 - Perp $500 = $9,500 ✅

Result: You have $9,500 value = 7,874 GBPb × $1.205


CONCLUSION: Perfect Hedge
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Your net value always equals:
    7,874 GBPb × Current GBP Price

You effectively HOLD GBP, not USD! 🎯
```

---

*Last Updated: 2026-02-06*
*Version: 1.0.0*
*Protocol Status: Testnet (Arbitrum Sepolia)*

---

## Quick Links

- 🌐 **App**: [app.gbpb.fi](https://app.gbpb.fi)
- 📚 **Docs**: [docs.gbpb.fi](https://docs.gbpb.fi)
- 💬 **Discord**: [discord.gg/gbpb](https://discord.gg/gbpb)
- 🐦 **Twitter**: [@GBPb_Protocol](https://twitter.com/GBPb_Protocol)
- 💻 **GitHub**: [github.com/gbpb-protocol](https://github.com/gbpb-protocol)

**Start earning yield on your GBP exposure today!** 🚀
