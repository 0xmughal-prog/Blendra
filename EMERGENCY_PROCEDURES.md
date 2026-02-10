# 🆘 Emergency Procedures Guide

**CRITICAL: Keep this document accessible at all times**

---

## 🚨 Emergency Contacts

| Role | Contact | Response Time |
|------|---------|---------------|
| Protocol Owner | YOUR_PHONE | Immediate |
| Technical Lead | YOUR_PHONE | <15 min |
| Community Manager | YOUR_PHONE | <30 min |

**Discord:** [Emergency Channel Link]
**Status Page:** [Coming Soon]

---

## ⚡ Quick Actions

### EMERGENCY PAUSE (Critical Issues)

**When to use:** Smart contract bug, exploit, or critical vulnerability detected

```bash
# From any terminal with access to PRIVATE_KEY
export PRIVATE_KEY="0xYOUR_KEY"
export MINTER_ADDRESS="0xYOUR_MINTER_ADDRESS"
export ARBITRUM_RPC="https://arb1.arbitrum.io/rpc"

cast send $MINTER_ADDRESS \
  "pause()" \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY
```

**Effect:**
- ✅ Stops all new mints immediately
- ✅ Users can still redeem (withdraw funds)
- ✅ Prevents further damage

**Next steps:**
1. Announce on Discord/Twitter: "Protocol paused for maintenance"
2. Investigate issue
3. Prepare fix
4. Test on fork
5. Deploy fix or enable withdrawals

---

### EMERGENCY UNPAUSE (False Alarm)

**When to use:** After resolving issue or if pause was accidental

```bash
cast send $MINTER_ADDRESS \
  "unpause()" \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY
```

**Verify:**
```bash
cast call $MINTER_ADDRESS "paused()" --rpc-url $ARBITRUM_RPC
```
Expected: `false` (0x0000...0000)

---

### EMERGENCY RESERVE FUNDING

**When to use:** Reserve balance critically low (<$50)

```bash
# Quick fund with $500
AMOUNT=500000000  # $500 USDC

# 1. Approve
cast send 0xaf88d065e77c8cC2239327C5EDb3A432268e5831 \
  "approve(address,uint256)" \
  $MINTER_ADDRESS \
  $AMOUNT \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY

# 2. Fund
cast send $MINTER_ADDRESS \
  "fundReserve(uint256)" \
  $AMOUNT \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY

# 3. Verify
cast call $MINTER_ADDRESS "reserveBalance()" --rpc-url $ARBITRUM_RPC
```

---

### EMERGENCY REBALANCING

**When to use:** Perp health factor <30% (risk of liquidation)

```bash
# Check health first
cast call $PERP_MANAGER_ADDRESS "getHealthFactor()" --rpc-url $ARBITRUM_RPC

# If <3000 (30%), rebalance immediately
cast send $MINTER_ADDRESS \
  "rebalancePerp()" \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY \
  --gas-limit 5000000

# Verify health improved
cast call $PERP_MANAGER_ADDRESS "getHealthFactor()" --rpc-url $ARBITRUM_RPC
```

**Expected result:** Health >90% (9000)

---

## 📊 Emergency Health Check

Run this immediately when alerted:

```bash
# 1. Check if paused
cast call $MINTER_ADDRESS "paused()" --rpc-url $ARBITRUM_RPC

# 2. Check TVL
cast call $MINTER_ADDRESS "totalAssets()" --rpc-url $ARBITRUM_RPC

# 3. Check reserve
cast call $MINTER_ADDRESS "reserveBalance()" --rpc-url $ARBITRUM_RPC

# 4. Check perp health
cast call $PERP_MANAGER_ADDRESS "getHealthFactor()" --rpc-url $ARBITRUM_RPC

# 5. Get full accounting
cast call $MINTER_ADDRESS "getReserveAccounting()" --rpc-url $ARBITRUM_RPC
```

---

## 🔴 Incident Severity Levels

### CRITICAL (P0) - Immediate Action Required

**Indicators:**
- Smart contract exploit detected
- Funds at risk of theft
- Perp position near liquidation (<20%)
- Oracle failure/manipulation

**Response:**
1. **PAUSE IMMEDIATELY** (use command above)
2. Call all team members
3. Start incident call
4. Investigate root cause
5. Prepare emergency announcement
6. Plan remediation

**SLA:** Pause within 5 minutes of detection

---

### HIGH (P1) - Action Required <1 Hour

**Indicators:**
- Reserve balance <$50
- Perp health 20-30%
- Unusual redemption patterns
- Morpho vault issues

**Response:**
1. Investigate immediately
2. Fund reserve if needed
3. Rebalance perp if needed
4. Monitor closely
5. Prepare update for community

**SLA:** Response within 1 hour

---

### MEDIUM (P2) - Action Required <24 Hours

**Indicators:**
- Reserve balance $50-100
- Perp health 30-50%
- Minor oracle delays
- High gas costs affecting users

**Response:**
1. Monitor situation
2. Plan intervention
3. Schedule maintenance window
4. Notify users in advance

**SLA:** Response within 24 hours

---

### LOW (P3) - Informational

**Indicators:**
- Reserve balance stable
- All systems healthy
- Normal operations

**Response:**
1. Regular monitoring
2. Weekly health checks
3. Plan improvements

---

## 📞 Communication Templates

### Template 1: Emergency Pause

**Discord/Twitter:**
```
🚨 NOTICE: GBPb Protocol Paused

The protocol has been temporarily paused for maintenance.

✅ Your funds are SAFE
✅ You can still redeem GBPb for USDC
❌ New mints are temporarily disabled

We're investigating and will update within 1 hour.

Status: [link to status page]
```

### Template 2: Reserve Low Warning

**Discord:**
```
⚠️ Maintenance Notice

Reserve fund is being topped up.
This may cause brief delays in minting.

Expected completion: 30 minutes
No action needed from users.
```

### Template 3: All Clear

**Discord/Twitter:**
```
✅ All Clear

Issue resolved. Protocol is fully operational.

Summary: [brief description]
Impact: [who was affected]
Prevention: [what we're doing to prevent this]

Thank you for your patience! 🙏
```

---

## 🛠️ Recovery Procedures

### Scenario 1: Perp Liquidation

**If perp position gets liquidated:**

1. **Assess damage:**
   ```bash
   cast call $PERP_MANAGER_ADDRESS "currentCollateral()" --rpc-url $ARBITRUM_RPC
   ```

2. **Calculate loss:** Max loss = 10% of TVL (perp collateral)

3. **Options:**
   - **A)** Fund loss from reserve
   - **B)** Socialize loss across all GBPb holders
   - **C)** Pause and plan migration

4. **Recommended:** Fund from reserve if loss <$500

5. **Restart hedging:**
   ```bash
   # Will auto-create new position on next mint
   cast send $MINTER_ADDRESS "updateLastPrice()" --rpc-url $ARBITRUM_RPC --private-key $PRIVATE_KEY
   ```

---

### Scenario 2: Morpho Vault Issues

**If Morpho vault paused/exploited:**

1. **Emergency withdraw from Morpho:**
   ```bash
   cast send $MINTER_ADDRESS "emergencyWithdrawStrategy()" --rpc-url $ARBITRUM_RPC --private-key $PRIVATE_KEY
   ```

2. **This withdraws all funds to minter contract**

3. **Pause minting:**
   ```bash
   cast send $MINTER_ADDRESS "pause()" --rpc-url $ARBITRUM_RPC --private-key $PRIVATE_KEY
   ```

4. **Users can still redeem** (funds in minter contract)

5. **Plan migration** to new strategy

---

### Scenario 3: Oracle Failure

**If Chainlink GBP/USD feed fails:**

1. **Check oracle status:**
   ```bash
   cast call $ORACLE_ADDRESS "getGBPUSDPrice()" --rpc-url $ARBITRUM_RPC
   ```

2. **If stale (>1 hour), mints will auto-revert** ✅

3. **Circuit breaker protects against bad prices** ✅

4. **No action needed** - wait for oracle recovery

5. **If >24h downtime:**
   - Deploy new oracle with backup feed
   - Update minter: `setOracle(newOracle)`

---

## 📋 Post-Incident Checklist

After resolving any incident:

- [ ] **Document timeline** (what happened, when, why)
- [ ] **Calculate impact** (users affected, funds at risk, actual loss)
- [ ] **Root cause analysis** (why it happened)
- [ ] **Prevention plan** (code changes, monitoring, process)
- [ ] **User communication** (final update with details)
- [ ] **Post-mortem** (share with team, learn lessons)
- [ ] **Update procedures** (improve this document)

---

## 🔧 Developer Emergency Access

### Quick Fork for Testing

```bash
# Fork mainnet to test fixes
anvil --fork-url $ARBITRUM_RPC --fork-block-number $(cast block-number --rpc-url $ARBITRUM_RPC)

# In new terminal, test fix on fork
forge script script/EmergencyFix.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Emergency Contract Upgrade Path

**Current contracts are NOT upgradeable by design** (security)

**If critical bug found:**
1. Deploy new fixed contracts
2. Pause old contracts
3. Migrate TVL to new contracts
4. Announce migration window (e.g., 7 days)
5. Users redeem from old, mint in new

**Alternatively:**
- Use timelock to execute emergency fix
- Requires 24h delay (gives users time to exit)

---

## 🎯 Monitoring Alerts Setup

### Critical Alerts (Immediate Action)

Set up alerts for:
- Reserve balance <$50
- Perp health <30%
- TVL >90% of cap
- Protocol paused/unpaused
- Large redemptions (>10% TVL)

### Warning Alerts (Review <1h)

Set up alerts for:
- Reserve balance <$100
- Perp health <50%
- TVL >80% of cap
- Rebalancing executed
- Multiple failed transactions

### Info Alerts (Daily Summary)

Monitor:
- Daily volume
- Total fees collected
- Reserve net change
- Number of unique users
- Average position size

---

## 💾 Backup & Recovery

### Essential Backups (Keep Secure)

- [ ] Deployment private key (encrypted)
- [ ] Contract addresses (all 8 contracts)
- [ ] Deployment transaction hashes
- [ ] Contract source code (git commit hash)
- [ ] Deployment configuration (.env backup)
- [ ] Reserve funding transaction hashes

### Store Backups In:

1. **Password manager** (1Password, Bitwarden)
2. **Encrypted cloud storage** (Google Drive with encryption)
3. **Physical backup** (USB drive, paper wallet)
4. **Team shared vault** (not just one person)

---

## ⚠️ Final Reminders

1. **Test emergency procedures regularly** (on fork)
2. **Keep this document updated** after incidents
3. **Train team members** on procedures
4. **Have multiple people with access** (no single point of failure)
5. **Stay calm** - users' funds are safe with pause + redeem
6. **Communicate transparently** - users appreciate honesty

---

**Remember: The pause button is your friend. When in doubt, pause and investigate!**

**Last Updated:** 2026-02-06
**Next Review:** Weekly for first month, then monthly
