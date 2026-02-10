# Simple Strategy Swap Guide

## Overview

Your vault now supports **hot-swapping** the lending protocol (Morpho → Euler → Aave, etc.) with admin controls and 24-hour timelock protection.

---

## What Changed?

### Before (Current)
```
GBPYieldVault
    └── KPKMorphoStrategy (hardcoded)
            └── KPK Morpho Vault
```
❌ Locked into Morpho - can't change without redeployment

### After (New)
```
GBPYieldVaultV2
    └── activeStrategy (IYieldStrategy interface)
            ├── MorphoStrategyAdapter (current)
            ├── EulerStrategy (can switch to)
            ├── AaveStrategy (can switch to)
            └── ... (any future protocol)
```
✅ Can swap between protocols anytime with admin controls

---

## How It Works

### Architecture

1. **IYieldStrategy Interface** - Standard interface all strategies must implement
2. **Strategy Adapters** - Wrappers for each protocol (Morpho, Euler, Aave, etc.)
3. **Vault with Strategy Slot** - Vault holds reference to active strategy
4. **Timelock Protection** - 24-hour delay before strategy changes take effect

### Two-Step Process

```
Day 0: Admin proposes new strategy
       ↓
       24-hour timelock
       ↓
Day 1: Admin executes change
       ↓
       Funds migrate automatically
```

---

## Admin Operations

### 1. Check Current Strategy

```solidity
// View current and pending strategy info
function getStrategyInfo() external view returns (
    string memory activeName,      // "KPK Morpho USDC"
    string memory activeProtocol,  // "Morpho"
    uint256 activeAPY,             // 600 (6%)
    bool hasPending,               // false
    string memory pendingName,     // ""
    uint256 timeUntilActivation    // 0
)
```

**Using cast:**
```bash
cast call $VAULT "getStrategyInfo()(string,string,uint256,bool,string,uint256)" \
  --rpc-url $ARBITRUM_RPC_URL
```

**Expected Output:**
```
"KPK Morpho USDC"
"Morpho"
600
false
""
0
```

---

### 2. Propose Strategy Change

**Scenario:** You want to switch from Morpho to Euler because Euler is offering better rates.

```bash
# Deploy Euler strategy adapter first
NEW_STRATEGY=0x... # EulerStrategy address

# Propose the change (starts 24h timelock)
cast send $VAULT \
  "proposeStrategyChange(address)" $NEW_STRATEGY \
  --private-key $ADMIN_KEY \
  --rpc-url $ARBITRUM_RPC_URL
```

**Event Emitted:**
```
StrategyProposed(
    oldStrategy: 0xMorphoAddress,
    newStrategy: 0xEulerAddress,
    activationTime: 1738368000  // Unix timestamp
)
```

**What Happens:**
- Pending strategy set to new strategy
- Activation timestamp set to now + 24 hours
- Old strategy keeps running (no downtime)
- Users can still deposit/withdraw normally

---

### 3. Wait for Timelock (24 Hours)

During this time:
- ✅ Users can review the proposed change
- ✅ Community can discuss
- ✅ You can cancel if issues found
- ✅ Vault continues operating normally

**Check time remaining:**
```bash
cast call $VAULT "strategyChangeTimestamp()(uint256)" --rpc-url $ARBITRUM_RPC_URL

# Compare with current time
date +%s
```

---

### 4. Cancel (Optional)

If you change your mind or find an issue:

```bash
cast send $VAULT \
  "cancelStrategyProposal()" \
  --private-key $ADMIN_KEY \
  --rpc-url $ARBITRUM_RPC_URL
```

**What Happens:**
- Pending strategy cleared
- Activation timestamp reset
- Old strategy continues
- No migration occurs

---

### 5. Execute Strategy Change

After 24 hours have passed:

```bash
cast send $VAULT \
  "executeStrategyChange()" \
  --private-key $ADMIN_KEY \
  --rpc-url $ARBITRUM_RPC_URL
```

**What Happens Automatically:**
1. All funds withdrawn from old strategy (Morpho)
2. All funds deposited into new strategy (Euler)
3. Active strategy updated
4. Pending strategy cleared
5. Vault continues with new strategy

**Event Emitted:**
```
StrategyChanged(
    oldStrategy: 0xMorphoAddress,
    newStrategy: 0xEulerAddress,
    migratedAmount: 1000000000000  // Amount in USDC
)
```

**Gas Cost:** ~400-500k gas (~0.0002 ETH on Arbitrum)

---

## Example: Switching from Morpho to Euler

### Prerequisites

1. **Deploy Euler Strategy Adapter**

```bash
# Deploy EulerStrategy
forge create src/strategies/EulerStrategy.sol:EulerStrategy \
  --constructor-args \
    $USDC \
    $EULER_VAULT \
    $GBP_YIELD_VAULT \
    1 \
    6 \
  --private-key $DEPLOYER_KEY \
  --rpc-url $ARBITRUM_RPC_URL
```

2. **Note the deployed address**
```
Deployed to: 0x1234567890abcdef...
```

### Step-by-Step Migration

**Day 0 - Morning:**
```bash
# 1. Check current strategy
cast call $VAULT "activeStrategy()(address)" --rpc-url $ARBITRUM_RPC_URL
# Returns: 0xMorphoStrategyAddress

# 2. Propose Euler
EULER_STRATEGY=0x1234567890abcdef...

cast send $VAULT \
  "proposeStrategyChange(address)" $EULER_STRATEGY \
  --private-key $ADMIN_KEY \
  --rpc-url $ARBITRUM_RPC_URL

# 3. Verify proposal
cast call $VAULT "pendingStrategy()(address)" --rpc-url $ARBITRUM_RPC_URL
# Returns: 0xEulerStrategyAddress

# 4. Check activation time
cast call $VAULT "strategyChangeTimestamp()(uint256)" --rpc-url $ARBITRUM_RPC_URL
# Returns: 1738368000 (Unix timestamp)
```

**Day 1 - After 24 Hours:**
```bash
# 5. Check timelock expired
TIMESTAMP=$(cast call $VAULT "strategyChangeTimestamp()(uint256)" --rpc-url $ARBITRUM_RPC_URL)
NOW=$(date +%s)
if [ $NOW -ge $TIMESTAMP ]; then
    echo "Ready to execute!"
else
    echo "Wait $(($TIMESTAMP - $NOW)) more seconds"
fi

# 6. Execute migration
cast send $VAULT \
  "executeStrategyChange()" \
  --private-key $ADMIN_KEY \
  --rpc-url $ARBITRUM_RPC_URL \
  --gas-limit 500000

# 7. Verify new strategy active
cast call $VAULT "activeStrategy()(address)" --rpc-url $ARBITRUM_RPC_URL
# Returns: 0xEulerStrategyAddress ✅

# 8. Check funds migrated
cast call $VAULT "totalAssets()(uint256)" --rpc-url $ARBITRUM_RPC_URL
# Should be same as before (minus small gas costs)
```

---

## Safety Features

### 1. **Timelock Protection (24 hours)**
- Prevents instant strategy changes
- Gives time to review and cancel
- Community can react to bad proposals

### 2. **Only Owner Can Change**
- `onlyOwner` modifier on all admin functions
- Recommend using multisig as owner
- 3-of-5 for production

### 3. **Atomic Migration**
- All-or-nothing swap
- No partial state issues
- Reverts if anything fails

### 4. **Emergency Withdraw**
```bash
# If strategy is compromised, admin can emergency withdraw
cast send $VAULT \
  "emergencyWithdrawStrategy()" \
  --private-key $ADMIN_KEY \
  --rpc-url $ARBITRUM_RPC_URL
```
- Bypasses normal flow
- Pulls all funds to vault
- Pauses further operations

### 5. **Pausability**
```bash
# Pause deposits/withdrawals during migration if needed
cast send $VAULT "pause()" --private-key $ADMIN_KEY --rpc-url $ARBITRUM_RPC_URL

# Unpause after migration confirmed
cast send $VAULT "unpause()" --private-key $ADMIN_KEY --rpc-url $ARBITRUM_RPC_URL
```

---

## Adding New Protocol Strategies

### Template

To add support for a new lending protocol:

1. **Create Strategy Adapter**

```solidity
// src/strategies/NewProtocolStrategy.sol
contract NewProtocolStrategy is IYieldStrategy, Ownable {
    // Implement all IYieldStrategy functions:
    // - deposit()
    // - withdraw()
    // - withdrawAll()
    // - totalAssets()
    // - currentAPY()
    // - emergencyWithdraw()
    // - getMetadata()
    // - supportsAsset()
    // - estimateDepositGas()
    // - estimateWithdrawGas()
}
```

2. **Deploy Adapter**
```bash
forge create src/strategies/NewProtocolStrategy.sol:NewProtocolStrategy \
  --constructor-args $USDC $PROTOCOL_VAULT $GBP_VAULT \
  --private-key $DEPLOYER_KEY
```

3. **Propose to Vault**
```bash
cast send $VAULT "proposeStrategyChange(address)" $NEW_STRATEGY \
  --private-key $ADMIN_KEY
```

4. **Wait 24h, Execute**
```bash
cast send $VAULT "executeStrategyChange()" --private-key $ADMIN_KEY
```

---

## Current Available Strategies

### 1. MorphoStrategyAdapter ✅
- **Protocol:** Morpho (KPK Vault)
- **Interface:** ERC4626
- **Risk:** 5/10
- **APY:** ~6%
- **Status:** Active (default)

### 2. EulerStrategy ⏳
- **Protocol:** Euler v2
- **Interface:** ERC4626
- **Risk:** 6/10
- **APY:** ~5%
- **Status:** Ready to deploy

### 3. AaveStrategy 🔜
- **Protocol:** Aave v3
- **Interface:** Custom
- **Risk:** 3/10
- **APY:** ~4%
- **Status:** Can implement in 2-3 days

### 4. DolomiteStrategy 🔮
- **Protocol:** Dolomite
- **Interface:** Custom
- **Risk:** 7/10
- **APY:** ~8%
- **Status:** Can implement in 5-7 days

---

## Best Practices

### ✅ DO:
1. **Test strategy adapters thoroughly** before proposing
2. **Use multisig** as vault owner
3. **Monitor APYs** - only switch if worthwhile (1%+ improvement)
4. **Announce to community** when proposing changes
5. **Verify migrations** - check totalAssets before/after

### ❌ DON'T:
1. **Don't rush migrations** - use the 24h timelock
2. **Don't switch frequently** - gas costs add up
3. **Don't use unaudited strategies** - risk isn't worth it
4. **Don't forget to check** - verify new strategy works as expected
5. **Don't skip testing** - test on testnet first

---

## Comparison with Current System

| Feature | Current (V1) | New (V2) |
|---------|--------------|----------|
| **Lending Protocol** | Morpho (hardcoded) | Any (swappable) |
| **Change Protocol** | Redeploy vault | Admin function |
| **Downtime** | Hours/days | None (atomic) |
| **User Impact** | Must migrate | Transparent |
| **Flexibility** | None | Full |
| **Risk Protection** | None | 24h timelock |
| **Cost to Change** | Gas + migration | Just gas |

---

## Migration from V1 to V2

If you want to upgrade existing vault:

### Option A: New Deployment
1. Deploy GBPYieldVaultV2
2. Deploy MorphoStrategyAdapter (wraps existing KPKMorphoStrategy)
3. Pause old vault
4. Users migrate to new vault
5. Deprecate old vault

### Option B: Proxy Upgrade (if using proxy pattern)
1. Implement V2 logic
2. Upgrade proxy to V2
3. Deploy strategy adapters
4. No user migration needed

**Recommendation:** Option A (cleaner, safer)

---

## Monitoring & Alerts

### Set up monitoring for:

1. **Pending Strategy Changes**
   - Alert when strategy proposed
   - Notify team to review

2. **Timelock Expiration**
   - Alert when timelock expires
   - Reminder to execute or cancel

3. **Strategy Health**
   - Monitor APY changes
   - Alert if APY drops significantly
   - Watch for protocol issues

4. **Migration Events**
   - Log all strategy changes
   - Verify totalAssets consistent
   - Check for failed migrations

---

## Summary

### What You Get:
✅ Easy protocol switching (Morpho → Euler → Aave)
✅ Admin-controlled with timelock safety
✅ No downtime during migrations
✅ Transparent to users
✅ Future-proof architecture

### What You Need to Do:
1. Use GBPYieldVaultV2 instead of current vault
2. Wrap current Morpho strategy with MorphoStrategyAdapter
3. Deploy strategy adapters for other protocols
4. Use admin functions to propose/execute changes
5. Monitor and maintain

### Gas Costs:
- Propose: ~50k gas (~$0.02)
- Execute: ~400k gas (~$0.16)
- **Total migration: ~$0.18 on Arbitrum**

**Ready to implement? The contracts are ready to deploy!** 🚀
