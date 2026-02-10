# Lending Protocol Comparison for GBP Yield Vault

## Quick Decision Matrix

| Protocol | APY Range | Risk Score | Integration | Arbitrum | Recommendation |
|----------|-----------|------------|-------------|----------|----------------|
| **Morpho (KPK)** | 4-8% | 5/10 | ✅ ERC4626 | ✅ Live | **PRIMARY** ⭐ |
| **Euler v2** | 3-7% | 6/10 | ✅ ERC4626 | ✅ Live | **BACKUP** |
| **Aave v3** | 2-5% | 3/10 | ⚠️ Custom | ✅ Live | **CONSERVATIVE** |
| **Dolomite** | 5-10% | 7/10 | ⚠️ Custom | ✅ Live | **HIGH YIELD** |
| **Curvance** | 4-9% | 6/10 | ⚠️ Custom | 🔄 Coming | **FUTURE** |

---

## Detailed Protocol Analysis

### 1. Morpho (Current - KPK Vault)

**Status:** ✅ **Currently Integrated**

#### Overview
- P2P lending optimizer built on top of Aave/Compound
- KPK (Steakhouse) curates specific Morpho vaults
- Matches lenders with borrowers directly for better rates
- Falls back to underlying pools for unmatched liquidity

#### Technical Details
```
Interface:     ERC4626 ✅
Audits:        Spearbit, Cantina, Trail of Bits
TVL:           $2B+ (across all vaults)
KPK USDC TVL:  $50M+
Arbitrum:      ✅ Live
```

#### Risk Profile (5/10)
✅ **Strengths:**
- Battle-tested code (2+ years)
- Multiple audits
- Curator oversight (KPK)
- Liquid underlying (Aave/Compound)
- Insurance available

⚠️ **Risks:**
- Curator risk (KPK management)
- P2P matching complexity
- Smart contract risk
- Oracle dependencies

#### APY Mechanics
- **Base APY:** Aave/Compound rates (2-4%)
- **P2P Boost:** +1-3% from direct matching
- **Total APY:** 4-8% typically
- **Volatility:** Medium (changes with utilization)

#### Integration Effort
- **Difficulty:** ✅ Easy (ERC4626)
- **Code:** Already implemented!
- **Maintenance:** Low

**Verdict:** ⭐ **KEEP AS PRIMARY**
- Already integrated and tested
- Good risk/reward balance
- Strong track record
- ERC4626 makes swapping easy later

---

### 2. Euler v2

**Status:** 🔄 **Recommended as Backup**

#### Overview
- Isolated lending markets (each market independent)
- Risk tiers: Collateral < Isolation < Cross
- Permissionless market creation
- ERC4626 compliant

#### Technical Details
```
Interface:     ERC4626 ✅
Audits:        Spearbit, OpenZeppelin
TVL:           $100M+ (v2)
USDC Markets:  Multiple tiers available
Arbitrum:      ✅ Live (multiple markets)
```

#### Risk Profile (6/10)
✅ **Strengths:**
- Isolated markets (contained risk)
- Flexibility (multiple tiers)
- ERC4626 standard
- Ethereum Vault Connector (EVC) for advanced features

⚠️ **Risks:**
- Isolated markets = less liquidity
- Oracle risk per market
- Complexity of tier system
- Newer protocol (v2 launched 2024)

#### APY Mechanics
- **Collateral Tier:** 2-4% (safest)
- **Isolation Tier:** 4-6% (medium risk)
- **Cross Tier:** 5-7% (higher risk)
- **Volatility:** Medium-High

#### Integration Effort
- **Difficulty:** ✅ Easy (ERC4626)
- **Code:** Simple adapter (see EulerStrategy.sol)
- **Maintenance:** Low
- **Time:** 1-2 days

**Verdict:** ✅ **GREAT BACKUP OPTION**
- Easy integration (ERC4626)
- Good for diversification
- Can choose tier based on risk appetite
- Strong team and audits

**Recommendation:** Implement as fallback strategy

---

### 3. Aave v3

**Status:** ⚠️ **Conservative Alternative**

#### Overview
- Blue-chip lending protocol
- Largest TVL in DeFi lending
- Cross-chain liquidity
- Isolation mode for new assets

#### Technical Details
```
Interface:     Custom (not ERC4626) ⚠️
Audits:        Multiple (ABDK, OpenZeppelin, Trail of Bits, etc.)
TVL:           $10B+ (all chains)
Arbitrum TVL:  $500M+
Arbitrum:      ✅ Live (v3)
```

#### Risk Profile (3/10) - **LOWEST RISK**
✅ **Strengths:**
- Most battle-tested protocol
- Huge liquidity
- Multiple layers of audits
- Safety module insurance
- Governance by large DAO

⚠️ **Risks:**
- Still smart contract risk
- Governance attack risk (very low)
- Oracle risk (Chainlink)

#### APY Mechanics
- **Supply APY:** 2-5% typically
- **Volatility:** Low (huge liquidity pool)
- **Incentives:** Sometimes AAVE rewards

#### Integration Effort
- **Difficulty:** ⚠️ **Medium** (custom interface)
- **Code:** Need custom adapter (~500 lines)
- **Maintenance:** Low (stable interface)
- **Time:** 2-3 days

**Verdict:** ✅ **BEST FOR CONSERVATIVE**
- Lowest risk option
- Huge liquidity
- Lower APY trade-off
- Non-ERC4626 = more integration work

**Recommendation:** Consider for ultra-conservative mode or if need very large capacity

---

### 4. Dolomite

**Status:** 🎯 **High Yield Option**

#### Overview
- Margin trading + lending platform
- Built specifically for Arbitrum
- Leverage trading features
- Cross-collateralization

#### Technical Details
```
Interface:     Custom ⚠️
Audits:        Quantstamp, Omniscia
TVL:           $30M+
Arbitrum:      ✅ Live (Arbitrum-native)
```

#### Risk Profile (7/10) - **HIGHER RISK**
✅ **Strengths:**
- Arbitrum-native (optimized)
- Higher yields
- Unique features
- Growing ecosystem

⚠️ **Risks:**
- Smaller TVL = less battle-tested
- Margin trading increases risk
- Less liquidity
- Fewer audits than competitors
- Newer protocol

#### APY Mechanics
- **Supply APY:** 5-10%
- **Leverage APY:** Can be higher with margin
- **Volatility:** High

#### Integration Effort
- **Difficulty:** ⚠️ **Hard** (custom interface + margin features)
- **Code:** Complex adapter (~800 lines)
- **Maintenance:** Medium (margin logic)
- **Time:** 5-7 days

**Verdict:** ⚠️ **HIGH RISK, HIGH REWARD**
- Significantly higher APYs
- More complex integration
- Less proven track record
- Good for users seeking max yield

**Recommendation:** Potentially add later for "aggressive" vault variant

---

### 5. Curvance

**Status:** 🔮 **Future Consideration**

#### Overview
- Omnichain lending protocol
- Gauge-based yield optimization
- Cross-chain liquidity
- Built by ex-Curve devs

#### Technical Details
```
Interface:     Custom (unique gauge system)
Audits:        TBD (new protocol)
TVL:           TBD (not yet launched)
Arbitrum:      🔄 Coming Soon
```

#### Risk Profile (6/10)
✅ **Strengths:**
- Built by experienced team (ex-Curve)
- Cross-chain features
- Gauge optimization
- Anticipates good liquidity

⚠️ **Risks:**
- Brand new protocol
- Unproven in production
- Complexity of omnichain design
- No historical track record

#### APY Mechanics
- **Expected APY:** 4-9%
- **Gauge Rewards:** CVE token incentives
- **Volatility:** Unknown

#### Integration Effort
- **Difficulty:** ⚠️ **Medium-Hard** (custom gauge system)
- **Code:** ~600 lines
- **Maintenance:** Medium
- **Time:** 4-5 days

**Verdict:** ⏳ **WAIT AND SEE**
- Too new to integrate now
- Monitor after launch
- Potentially strong option in 6-12 months
- Could offer unique cross-chain features

**Recommendation:** Add to watchlist, evaluate after 6+ months of mainnet operation

---

## Integration Priority Recommendations

### Phase 1: Current (Now)
✅ **Keep Morpho (KPK) as primary**
- Already tested
- Good APY/risk balance
- ERC4626 = easy to replace later

### Phase 2: Add Flexibility (Next 2-4 weeks)
✅ **Implement StrategyManager**
1. Deploy StrategyManager contract
2. Wrap existing KPKMorphoStrategy with IYieldStrategy interface
3. Add strategy approval & timelock system
4. Test strategy switching on testnet

### Phase 3: Add Backup (Month 2)
✅ **Integrate Euler v2**
1. Deploy EulerStrategy (Collateral Tier)
2. Approve as backup strategy
3. Test gradual migration on testnet
4. Document APY comparison process

### Phase 4: Expand Options (Month 3-4)
⚠️ **Consider Aave v3**
- If need ultra-low risk option
- If need very large capacity (>$10M)
- Build custom adapter

### Phase 5: Advanced (Month 6+)
🎯 **Evaluate Dolomite or Curvance**
- If users want higher yields
- After protocols are more proven
- Consider separate "aggressive" vault

---

## Decision Framework

### When to Switch Strategies?

```solidity
function shouldSwitch(
    address currentStrategy,
    address proposedStrategy
) public view returns (bool) {
    uint256 currentAPY = IYieldStrategy(currentStrategy).currentAPY();
    uint256 proposedAPY = IYieldStrategy(proposedStrategy).currentAPY();
    uint256 currentRisk = IYieldStrategy(currentStrategy).getRiskScore();
    uint256 proposedRisk = IYieldStrategy(proposedStrategy).getRiskScore();

    // Calculate risk-adjusted improvement
    uint256 riskAdjustedCurrent = currentAPY * (10 - currentRisk) / 10;
    uint256 riskAdjustedProposed = proposedAPY * (10 - proposedRisk) / 10;

    // Switch if risk-adjusted APY is 1%+ better
    return riskAdjustedProposed >= riskAdjustedCurrent + 100; // 100 bps = 1%
}
```

### Risk-Adjusted APY Examples

| Protocol | Raw APY | Risk | Risk-Adjusted APY | Rank |
|----------|---------|------|-------------------|------|
| Aave v3 | 4% | 3/10 | 2.8% | 3 |
| Morpho | 6% | 5/10 | 3.0% | **1** ⭐ |
| Euler | 5% | 6/10 | 2.0% | 4 |
| Dolomite | 8% | 7/10 | 2.4% | 2 |

**Winner:** Morpho (best risk-adjusted return)

---

## Key Takeaways

### ✅ DO THIS:
1. **Keep Morpho as primary** - it's working well
2. **Implement StrategyManager** - adds flexibility
3. **Add Euler as backup** - easy integration, good insurance
4. **Use timelock** - 24h minimum for strategy changes
5. **Monitor APYs** - switch when justified (1%+ improvement)

### ❌ DON'T DO THIS:
1. **Don't switch often** - gas costs + risk
2. **Don't use unaudited protocols** - too risky
3. **Don't migrate 100% at once** - gradual is safer
4. **Don't ignore risk scores** - APY isn't everything
5. **Don't add too many options** - complexity = bugs

### 🎯 Optimal Setup:
```
Primary Strategy:    Morpho (KPK) - 90% of time
Backup Strategy:     Euler (Collateral) - if Morpho issues
Conservative Mode:   Aave v3 - if ultra-safety needed
Aggressive Mode:     Dolomite - separate vault later
```

---

## Implementation Checklist

### Week 1-2: Foundation
- [ ] Create IYieldStrategy interface
- [ ] Build StrategyManager contract
- [ ] Refactor KPKMorphoStrategy to implement IYieldStrategy
- [ ] Add strategy approval whitelist
- [ ] Implement timelock mechanism
- [ ] Write unit tests

### Week 3-4: Euler Integration
- [ ] Deploy EulerStrategy adapter
- [ ] Test Euler deposits/withdrawals
- [ ] Add to approved strategies
- [ ] Test gradual migration
- [ ] Monitor APYs on testnet

### Month 2: Production
- [ ] Security audit of new contracts
- [ ] Deploy StrategyManager to mainnet
- [ ] Approve Morpho + Euler strategies
- [ ] Set up APY monitoring
- [ ] Create operator playbook

### Month 3+: Expansion
- [ ] Evaluate other protocols
- [ ] Build additional adapters as needed
- [ ] Optimize gas costs
- [ ] Consider multi-strategy allocation

---

## Questions to Consider

1. **How often should we check for better APYs?**
   - Recommendation: Daily automated checks, weekly human review

2. **What's the minimum APY improvement to justify a switch?**
   - Recommendation: 1% (100 bps) risk-adjusted improvement

3. **Should we allow multiple active strategies?**
   - Start: Single strategy (simpler)
   - Later: Consider 80/20 split (primary/backup)

4. **Who should control strategy changes?**
   - Start: Multisig (3-of-5)
   - Later: DAO governance with timelock

5. **How to handle strategy failures?**
   - Emergency withdraw → Hold in vault → Switch to backup
   - Guardian role can trigger emergency mode

---

**Ready to implement? Let me know which approach you'd like to start with!**
