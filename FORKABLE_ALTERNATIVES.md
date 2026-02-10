# Audited Alternatives for Our Custom Code
**Date:** January 31, 2026
**Purpose:** Identify what can be forked vs what must stay custom

---

## 🎯 Executive Summary

**Analysis of 2,280 lines of custom code:**
- ✅ **670 lines CAN be replaced** with audited forks (30%)
- ⚠️ **1,610 lines MUST stay custom** (70%)

---

## ✅ RECOMMENDED: Replace with Audited Code

### 1. **ERC4626 Vault with Fees** ⭐ HIGH PRIORITY

**Our Current Code:**
- `GBPYieldVaultV2Secure.sol` - 650 lines
- Custom ERC4626 implementation with performance fees

**Audited Alternative: MetaMorpho by Morpho**
- **Repository:** [morpho-org/metamorpho](https://github.com/morpho-org/metamorpho)
- **Audits:** Multiple (stored in audits/ folder)
- **Features:**
  - ✅ ERC4626 standard
  - ✅ Performance fees (up to 50%)
  - ✅ Fee recipient management
  - ✅ Extensively audited
  - ✅ Battle-tested ($1B+ TVL)
  - ✅ Active development (updated Dec 2025)

**Lines We Can Eliminate:** ~400 lines (fee logic + vault base)

**What We Still Need Custom:**
- Strategy allocation (90% lending, 10% perp)
- Circuit breaker logic
- TVL cap with buffer
- Rate limiting
- Price sanity checks
- Integration with PerpPositionManager

**Verdict:** ✅ **FORK METAMORPHO + EXTEND**

**Implementation:**
```solidity
import {MetaMorpho} from "morpho-org/metamorpho/MetaMorpho.sol";

contract GBPYieldVault is MetaMorpho {
    // Add our custom features:
    // - Circuit breakers
    // - Perp allocation
    // - Rate limiting
    // - TVL cap
}
```

**Effort:** 2-3 days to integrate
**Risk Reduction:** High (400 lines eliminated)

---

**Alternative Option: Euler Earn**
- **Repository:** [euler-xyz/euler-earn](https://github.com/euler-xyz/euler-earn)
- **Based on:** MetaMorpho v1.1
- **Features:** Same as MetaMorpho
- **Audits:** Stored in audits/ folder

---

### 2. **Chainlink Oracle Wrapper** ⭐ MEDIUM PRIORITY

**Our Current Code:**
- `ChainlinkOracle.sol` - 100 lines
- Wrapper with staleness checks

**Audited Alternative: Morpho Chainlink Oracle**
- **Repository:** [morpho-org/morpho-blue-oracles](https://github.com/morpho-org/morpho-blue-oracles)
- **Features:**
  - ✅ Chainlink price feed wrapper
  - ✅ Staleness checks
  - ✅ Data validation
  - ✅ Audited by Morpho's auditors

**Lines We Can Eliminate:** ~80 lines

**What We Still Need:**
- GBP/USD specific configuration (20 lines)

**Verdict:** ✅ **FORK MORPHO ORACLE**

**Effort:** 1 day
**Risk Reduction:** Medium (80 lines eliminated)

---

**Alternative: Aave Oracle Wrapper**
- Used by Aave Protocol
- Similar functionality
- Extensively audited

---

### 3. **ERC4626 Strategy Adapters** ⭐ LOW PRIORITY

**Our Current Code:**
- `MorphoStrategyAdapter.sol` - 180 lines
- `EulerStrategy.sol` - 150 lines

**Audited Alternative: Use MetaMorpho's Allocator Pattern**
- **Part of:** MetaMorpho vault
- **Features:**
  - ✅ Built-in strategy allocation
  - ✅ Multiple ERC4626 vault support
  - ✅ Rebalancing logic
  - ✅ Audited

**Lines We Can Eliminate:** ~200 lines

**Verdict:** ✅ **USE METAMORPHO ALLOCATOR**

If we fork MetaMorpho, we get strategy allocation for free!

**Effort:** Included in MetaMorpho integration
**Risk Reduction:** Medium (200 lines eliminated)

---

### 4. **FeeDistributor (Already Adapted)** ⭐ LOW PRIORITY

**Our Current Code:**
- `FeeDistributor.sol` - 220 lines
- Based on OpenZeppelin PaymentSplitter v4.x

**Audited Alternative: OpenZeppelin PaymentSplitter v4.9.6**
- **Repository:** [OpenZeppelin/openzeppelin-contracts v4.9.6](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v4.9.6)
- **File:** `contracts/finance/PaymentSplitter.sol`
- **Status:** Fully audited

**Note:** PaymentSplitter was removed in v5.x but exists in v4.9.6

**Lines We Can Eliminate:** ~100 lines

**What We Still Need:**
- Convenience functions (releaseAll, etc.) - ~50 lines
- ERC20-only simplification (we don't need ETH support)

**Verdict:** 🟡 **OPTIONAL - Already 90% based on it**

**Effort:** 1 day to switch
**Risk Reduction:** Low (already using the pattern)

**Alternative Approach:**
- Keep our current implementation (already secure)
- Or install v4.9.6 alongside v5.2.0 just for PaymentSplitter

---

## ⚠️ MUST STAY CUSTOM (No Good Alternatives)

### 1. **PerpPositionManager.sol** - 420 lines ❌

**Why Custom:**
- Unique position tracking logic
- Health monitoring system
- Multi-provider abstraction (works with any perp DEX)
- Liquidation warning system
- Timelock + cooldown for provider changes

**Checked Alternatives:**
- ❌ GMX BasePositionManager - Too tightly coupled to GMX
- ❌ Gains Network Position Manager - Different architecture
- ❌ Perpetual Protocol - V2/V3 architecture doesn't fit

**Verdict:** ❌ **MUST STAY CUSTOM**

**Reason:** Our use case is unique (perp hedging for vault, not trading platform)

---

### 2. **OstiumPerpProvider.sol** - 460 lines ❌

**Why Custom:**
- Ostium-specific integration
- IPerpProvider interface implementation
- PnL calculation with fee estimation
- Position verification after operations

**Checked Alternatives:**
- ❌ No generic perp DEX adapters exist
- ❌ Each DEX has unique interface

**Verdict:** ❌ **MUST STAY CUSTOM**

**Reason:** Integration layer for specific protocol (Ostium)

**Note:** If we add GMX/Gains Network support, we'd build similar providers

---

### 3. **IPerpProvider.sol** - 30 lines ❌
### 4. **IYieldStrategy.sol** - 50 lines ❌

**Why Custom:**
- Our abstractions for hot-swappability
- Unique to our architecture

**Verdict:** ❌ **MUST STAY CUSTOM**

**Reason:** Core architectural interfaces

---

## 📊 Summary Table

| Component | Lines | Can Fork? | Alternative | Lines Saved | Effort | Priority |
|-----------|-------|-----------|-------------|-------------|--------|----------|
| Vault (fees + base) | 400 | ✅ Yes | MetaMorpho | 400 | 2-3 days | ⭐⭐⭐ High |
| Oracle Wrapper | 80 | ✅ Yes | Morpho Oracle | 80 | 1 day | ⭐⭐ Med |
| Strategy Adapters | 200 | ✅ Yes | MetaMorpho Allocator | 200 | Included | ⭐ Low |
| FeeDistributor | ~100 | 🟡 Maybe | PaymentSplitter v4.9.6 | 100 | 1 day | ⭐ Low |
| PerpPositionManager | 420 | ❌ No | None | 0 | - | - |
| OstiumPerpProvider | 460 | ❌ No | None | 0 | - | - |
| Interfaces | 80 | ❌ No | None | 0 | - | - |
| **TOTAL** | **1,740** | - | - | **780** | **4-5 days** | - |

**Potential Risk Reduction: 45% of custom code eliminated**

---

## 🎯 Recommended Action Plan

### Phase 1: HIGH PRIORITY ⭐⭐⭐

**Fork MetaMorpho Vault**
- **What:** Replace our ERC4626 + fee logic with MetaMorpho
- **Saves:** 400 lines of custom code
- **Risk Reduction:** High
- **Effort:** 2-3 days
- **Status:** Ready to implement

**Implementation Steps:**
```bash
# 1. Install MetaMorpho
forge install morpho-org/metamorpho

# 2. Create wrapper
contract GBPYieldVault is MetaMorpho {
    // Keep our custom features:
    // - Circuit breakers
    // - Perp allocation
    // - Rate limiting
    // - TVL cap with buffer
}

# 3. Migrate state variables
# 4. Update deployment script
# 5. Test thoroughly
```

**Audits:**
- [MetaMorpho Audits](https://github.com/morpho-org/metamorpho/tree/main/audits)
- Multiple firms
- Production-ready

---

### Phase 2: MEDIUM PRIORITY ⭐⭐

**Fork Morpho Chainlink Oracle**
- **What:** Replace ChainlinkOracle.sol with Morpho's implementation
- **Saves:** 80 lines
- **Risk Reduction:** Medium
- **Effort:** 1 day

```bash
forge install morpho-org/morpho-blue-oracles
```

---

### Phase 3: LOW PRIORITY ⭐

**Optional: Switch to PaymentSplitter v4.9.6**
- **What:** Use actual OpenZeppelin PaymentSplitter
- **Saves:** 100 lines
- **Risk Reduction:** Low (already using the pattern)
- **Effort:** 1 day

**Note:** Current implementation is already 90% OZ pattern, so this is optional.

---

## 📋 What Stays Custom (1,160 lines)

After forking MetaMorpho + Oracle:

### Must Keep Custom:
1. **PerpPositionManager** (420 lines) - Unique position management
2. **OstiumPerpProvider** (460 lines) - Ostium integration
3. **Custom vault features** (250 lines):
   - Circuit breakers
   - Perp allocation (90/10 split)
   - Rate limiting
   - TVL cap with buffer
   - Price sanity checks
4. **Interfaces** (80 lines) - Our abstractions

**Total Custom After Optimization: ~1,160 lines**

**Down from:** 2,280 lines
**Reduction:** 49% fewer custom lines to audit

---

## 💰 Cost-Benefit Analysis

### Before Optimization
- **Custom Code:** 2,280 lines
- **Audit Cost:** $35-45k (Trail of Bits)
- **Risk:** Medium-High

### After Forking MetaMorpho + Oracle
- **Custom Code:** 1,160 lines
- **Audit Cost:** $20-25k (49% less)
- **Risk:** Medium-Low

**Savings:**
- ✅ $15-20k in audit costs
- ✅ 780 lines less to maintain
- ✅ Leveraging battle-tested code ($1B+ TVL)
- ✅ Faster time to production

**Trade-offs:**
- ⚠️ 4-5 days integration work
- ⚠️ New dependency (MetaMorpho)
- ⚠️ Need to track MetaMorpho updates

---

## 🔗 Source Links

### MetaMorpho (Morpho)
- **Repository:** https://github.com/morpho-org/metamorpho
- **Documentation:** https://docs.morpho.org/
- **Audits:** https://github.com/morpho-org/metamorpho/tree/main/audits
- **TVL:** $1B+ (battle-tested)

### Euler Earn (Alternative)
- **Repository:** https://github.com/euler-xyz/euler-earn
- **Based on:** MetaMorpho v1.1
- **Audits:** https://github.com/euler-xyz/euler-earn/tree/main/audits

### Morpho Blue Oracles
- **Repository:** https://github.com/morpho-org/morpho-blue-oracles
- **Audits:** Included in Morpho Blue audits

### OpenZeppelin PaymentSplitter
- **Repository (v4.9.6):** https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v4.9.6
- **File:** `contracts/finance/PaymentSplitter.sol`
- **Note:** Removed in v5.x, use v4.9.6

### Aave Vault (Reference)
- **Repository:** https://github.com/aave/Aave-Vault
- **Features:** ERC4626 with fee on yield
- **Audits:** In repository

### Solmate ERC4626 (Alternative)
- **Repository:** https://github.com/transmissions11/solmate
- **File:** `src/tokens/ERC4626.sol`
- **Note:** Gas-optimized, widely used
- **Caveat:** "Not designed with user safety in mind"

---

## 🎓 Implementation Guide

### Step 1: Fork MetaMorpho

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MetaMorpho} from "morpho-org/metamorpho/src/MetaMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GBPYieldVault is MetaMorpho {
    // Our custom state variables
    PerpPositionManager public perpManager;
    uint256 public perpAllocation; // 1000 = 10%
    uint256 public tvlCapBufferBPS;
    mapping(address => uint256) public lastUserOperation;
    uint256 public userOperationCooldown;

    constructor(
        address owner,
        address morphoBlue,
        uint256 timelock,
        address asset,
        string memory name,
        string memory symbol
    ) MetaMorpho(owner, morphoBlue, timelock, asset, name, symbol) {
        // Initialize our custom features
    }

    // Override deposit to add our custom logic
    function deposit(uint256 assets, address receiver)
        public
        override
        returns (uint256 shares)
    {
        // Our circuit breaker checks
        _enforceCircuitBreaker();

        // Our rate limiting
        _checkRateLimit();

        // Our TVL cap
        _checkTVLCap(assets);

        // Call parent (MetaMorpho handles fees!)
        shares = super.deposit(assets, receiver);

        // Split allocation: 90% stays in vault, 10% to perp
        uint256 perpAmount = (assets * perpAllocation) / 10000;
        if (perpAmount > 0) {
            IERC20(asset()).approve(address(perpManager), perpAmount);
            // ... perp logic
        }
    }

    // Our custom functions
    function _enforceCircuitBreaker() internal view { ... }
    function _checkRateLimit() internal { ... }
    function _checkTVLCap(uint256 assets) internal view { ... }
}
```

### Step 2: Test Migration

```bash
# 1. Write tests for new implementation
forge test --match-contract GBPYieldVaultTest

# 2. Compare gas costs
forge snapshot

# 3. Verify all features work
# 4. Deploy to testnet
# 5. Full integration test
```

---

## ✅ Final Recommendation

**DO THIS:**
1. ✅ **Fork MetaMorpho** - Eliminates 400 lines, highly audited
2. ✅ **Fork Morpho Oracle** - Eliminates 80 lines, battle-tested
3. 🟡 **Consider PaymentSplitter v4.9.6** - Optional, already using pattern

**KEEP CUSTOM:**
- PerpPositionManager (no alternative)
- OstiumPerpProvider (integration layer)
- Custom vault features (circuit breakers, etc.)

**Result:**
- 49% less custom code to audit
- $15-20k savings on audit costs
- Leveraging $1B+ battle-tested code
- 4-5 days of integration work

**Priority:** ⭐⭐⭐ HIGH - Start with MetaMorpho

---

**Next Step:** Review MetaMorpho source code and plan integration strategy.
