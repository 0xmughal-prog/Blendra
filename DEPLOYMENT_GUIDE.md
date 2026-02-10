# GBPb Protocol Mainnet Deployment Guide

**Network:** Arbitrum One (Mainnet)
**Initial TVL Cap:** $5,000
**Initial Reserve:** $500
**Status:** Production-ready with safety limits

---

## 📋 Pre-Deployment Checklist

### 1. Environment Setup

- [ ] Install Foundry (latest version)
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

- [ ] Clone repository and install dependencies
  ```bash
  cd gbp-yield-vault
  forge install
  ```

- [ ] Copy and configure environment
  ```bash
  cp .env.example .env
  # Edit .env with your values
  ```

### 2. Wallet Preparation

- [ ] Create dedicated deployer wallet (or use existing)
- [ ] Fund deployer wallet:
  - **ETH**: ~0.01 ETH for gas (~$30-50)
  - **USDC**: $500 for initial reserve funding
- [ ] Add private key to `.env` file
  ```
  PRIVATE_KEY=0xYOUR_PRIVATE_KEY_HERE
  ```

### 3. RPC & API Keys

- [ ] Get Arbitrum RPC URL:
  - [Alchemy](https://www.alchemy.com/) (recommended)
  - [Infura](https://www.infura.io/)
  - [QuickNode](https://www.quicknode.com/)

- [ ] Get Arbiscan API key:
  - Register at [arbiscan.io](https://arbiscan.io/myapikey)

- [ ] Add to `.env`:
  ```
  ARBITRUM_RPC=https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY
  ARBISCAN_API_KEY=YOUR_ARBISCAN_KEY
  ```

### 4. Final Checks

- [ ] Run tests locally:
  ```bash
  forge test
  ```
  Expected: 161/161 passing ✅

- [ ] Check deployer balance:
  ```bash
  cast balance $DEPLOYER_ADDRESS --rpc-url $ARBITRUM_RPC
  cast balance $DEPLOYER_ADDRESS --rpc-url $ARBITRUM_RPC --erc20 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
  ```

---

## 🚀 Deployment Process

### Step 1: Dry Run (Simulation)

Test deployment without broadcasting:

```bash
forge script script/Deploy.s.sol:DeployGBPb \
  --rpc-url $ARBITRUM_RPC \
  -vvvv
```

**Expected output:**
- Contract addresses (simulated)
- Gas estimates
- Configuration summary

### Step 2: Deploy Contracts

**⚠️ THIS WILL SPEND REAL ETH AND DEPLOY TO MAINNET**

```bash
forge script script/Deploy.s.sol:DeployGBPb \
  --rpc-url $ARBITRUM_RPC \
  --broadcast \
  --verify \
  --etherscan-api-key $ARBISCAN_API_KEY \
  -vvvv
```

**What happens:**
1. Deploys all 8 contracts
2. Wires contracts together
3. Sets safety parameters
4. Pauses protocol
5. Verifies on Arbiscan
6. Prints deployment summary

**⏱️ Expected time:** 5-10 minutes

**📝 Save the output!** You'll need the contract addresses.

### Step 3: Update .env with Addresses

From deployment output, fill in `.env`:

```bash
MINTER_ADDRESS=0x...
GBPB_ADDRESS=0x...
SGBPB_ADDRESS=0x...
STRATEGY_ADDRESS=0x...
PERP_MANAGER_ADDRESS=0x...
```

### Step 4: Verify Deployment

```bash
forge script script/Verify.s.sol:VerifyDeployment \
  --rpc-url $ARBITRUM_RPC
```

**Check:**
- ✅ All contracts configured correctly
- ✅ Safety parameters set
- ✅ Protocol is PAUSED
- ⚠️ Reserve is EMPTY (expected)

---

## 💰 Fund Reserve & Activate

### Step 5: Approve USDC

```bash
cast send 0xaf88d065e77c8cC2239327C5EDb3A432268e5831 \
  "approve(address,uint256)" \
  $MINTER_ADDRESS \
  500000000 \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY
```

**Amount:** 500000000 = $500 USDC (6 decimals)

### Step 6: Fund Reserve

```bash
cast send $MINTER_ADDRESS \
  "fundReserve(uint256)" \
  500000000 \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY
```

**Verify funding:**
```bash
cast call $MINTER_ADDRESS "reserveBalance()" --rpc-url $ARBITRUM_RPC
```

**Expected:** 500000000 (500 USDC)

### Step 7: Unpause Protocol

```bash
cast send $MINTER_ADDRESS \
  "unpause()" \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY
```

**🎉 Protocol is now LIVE!**

---

## 🧪 Initial Testing

### Test 1: Mint Small Amount

**Amount:** $100 USDC (safe test)

```bash
# 1. Approve USDC
cast send 0xaf88d065e77c8cC2239327C5EDb3A432268e5831 \
  "approve(address,uint256)" \
  $MINTER_ADDRESS \
  100000000 \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY

# 2. Mint GBPb
cast send $MINTER_ADDRESS \
  "mint(uint256)" \
  100000000 \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY

# 3. Check GBPb balance
cast call $GBPB_ADDRESS "balanceOf(address)" $DEPLOYER_ADDRESS --rpc-url $ARBITRUM_RPC
```

**Expected:**
- GBPb received: ~78.74 GBPb (at 1.27 GBP/USD rate)
- Reserve decreased by ~$0.30 (opening fee)

### Test 2: Monitor for 24 Hours

Check reserve and health after first mint:

```bash
forge script script/Verify.s.sol:VerifyDeployment --rpc-url $ARBITRUM_RPC
```

**Monitor:**
- Reserve balance (should be ~$499.70)
- TVL ($100)
- Perp health (should be >90%)
- Morpho holdings ($90)

### Test 3: Test Redemption (After 24h)

```bash
# 1. Approve GBPb
cast send $GBPB_ADDRESS \
  "approve(address,uint256)" \
  $MINTER_ADDRESS \
  78740000000000000000 \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY

# 2. Redeem
cast send $MINTER_ADDRESS \
  "redeem(uint256)" \
  78740000000000000000 \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY

# 3. Check USDC received
cast call 0xaf88d065e77c8cC2239327C5EDb3A432268e5831 "balanceOf(address)" $DEPLOYER_ADDRESS --rpc-url $ARBITRUM_RPC
```

**Expected:**
- USDC received: ~$99.80 (minus 0.20% fee)
- Reserve increased by ~$0.20 (redemption fee)

---

## 📊 Monitoring & Health Checks

### Daily Health Check

Run verification script daily:

```bash
forge script script/Verify.s.sol:VerifyDeployment --rpc-url $ARBITRUM_RPC
```

**Monitor:**
1. **Reserve Health**
   - Current: Should be >$100
   - Warnings: <$100 (top up needed)
   - Critical: <$50 (top up immediately)

2. **TVL Status**
   - Current: <$5,000 (within cap)
   - Warning: >$4,500 (approaching cap)

3. **Perp Health**
   - Healthy: >50%
   - Warning: 30-50% (rebalancing recommended)
   - Critical: <30% (rebalance immediately)

4. **Net Revenue**
   - Should be positive after ~10 round-trips
   - Break-even: ~$150 in redemption fees

### Rebalancing (If Needed)

If perp health <50%:

```bash
cast send $MINTER_ADDRESS \
  "rebalancePerp()" \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY
```

**Cost:** ~$0.30 in opening fees (covered by reserve)

### Emergency Pause

If critical issue detected:

```bash
cast send $MINTER_ADDRESS \
  "pause()" \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY
```

**Effect:**
- Stops all minting
- Redemptions still allowed
- Investigate and fix issue
- Unpause when safe

---

## 📈 Scaling Plan

### Week 1: Conservative Testing
- **TVL Cap:** $5,000 ✅ (deployed)
- **Reserve:** $500
- **Testing:** Your own funds only
- **Goal:** Validate all flows work

### Week 2-4: Limited Launch
- **TVL Cap:** Increase to $25,000
  ```bash
  cast send $MINTER_ADDRESS "setTVLCap(uint256)" 25000000000 --rpc-url $ARBITRUM_RPC --private-key $PRIVATE_KEY
  ```
- **Reserve:** Top up to $1,000
- **Testing:** Invite 5-10 trusted users
- **Goal:** Real-world usage patterns

### Month 2: Public Beta
- **TVL Cap:** Increase to $100,000
- **Reserve:** Top up to $2,500
- **Testing:** Soft launch announcement
- **Goal:** Community feedback

### Month 3+: Growth
- **TVL Cap:** Gradually increase based on confidence
- **Reserve:** Scale proportionally (~2.5% of TVL)
- **Audit:** Commission professional audit at $500K+ TVL
- **Goal:** Sustainable growth

---

## 🆘 Emergency Procedures

### Critical: Protocol Compromised

1. **Immediate pause:**
   ```bash
   cast send $MINTER_ADDRESS "pause()" --rpc-url $ARBITRUM_RPC --private-key $PRIVATE_KEY
   ```

2. **Notify users** (Discord, Twitter)

3. **Enable emergency withdrawals** (users can still redeem)

4. **Investigate root cause**

5. **Deploy fix or migrate to new contracts**

### Non-Critical: Reserve Low

1. **Check reserve status:**
   ```bash
   cast call $MINTER_ADDRESS "reserveBalance()" --rpc-url $ARBITRUM_RPC
   ```

2. **Fund reserve:**
   ```bash
   # Approve
   cast send 0xaf88d065e77c8cC2239327C5EDb3A432268e5831 "approve(address,uint256)" $MINTER_ADDRESS 500000000 --rpc-url $ARBITRUM_RPC --private-key $PRIVATE_KEY

   # Fund
   cast send $MINTER_ADDRESS "fundReserve(uint256)" 500000000 --rpc-url $ARBITRUM_RPC --private-key $PRIVATE_KEY
   ```

3. **Monitor for 24h**

### Non-Critical: Perp Needs Rebalancing

1. **Check health:**
   ```bash
   cast call $PERP_MANAGER_ADDRESS "getHealthFactor()" --rpc-url $ARBITRUM_RPC
   ```

2. **Rebalance if <50% (5000):**
   ```bash
   cast send $MINTER_ADDRESS "rebalancePerp()" --rpc-url $ARBITRUM_RPC --private-key $PRIVATE_KEY
   ```

3. **Verify health improved:**
   ```bash
   cast call $PERP_MANAGER_ADDRESS "getHealthFactor()" --rpc-url $ARBITRUM_RPC
   ```

---

## 🔐 Security Best Practices

### Wallet Security
- [ ] Use hardware wallet for deployment (Ledger/Trezor)
- [ ] Use different wallet for daily operations
- [ ] Enable 2FA on all accounts
- [ ] Store private keys in password manager
- [ ] Never share private keys

### Operational Security
- [ ] Set up monitoring alerts (Discord webhook)
- [ ] Check health daily for first month
- [ ] Keep reserve well-funded (>$500)
- [ ] Document all parameter changes
- [ ] Test changes on fork first

### Incident Response
- [ ] Have emergency pause ready
- [ ] Document emergency contacts
- [ ] Plan communication strategy
- [ ] Keep backup of deployment artifacts
- [ ] Test emergency procedures

---

## 📝 Post-Deployment Checklist

- [ ] All contracts deployed and verified on Arbiscan
- [ ] Reserve funded with $500 USDC
- [ ] Protocol unpaused and active
- [ ] Initial test mint successful ($100)
- [ ] 24h test redemption successful
- [ ] Monitoring script runs successfully
- [ ] Emergency pause tested (on fork)
- [ ] Contract addresses documented
- [ ] Team notified of deployment
- [ ] Community announcement prepared

---

## 🔗 Important Links

**Deployed Contracts (Arbiscan):**
- GBPb Token: [Check on Arbiscan]
- GBPbMinter: [Check on Arbiscan]
- sGBPb Vault: [Check on Arbiscan]

**External Dependencies:**
- USDC: [0xaf88d065e77c8cC2239327C5EDb3A432268e5831](https://arbiscan.io/token/0xaf88d065e77c8cC2239327C5EDb3A432268e5831)
- Morpho Vault: [0x4881Ef0BF6d2365D3dd6499ccd7532bcdBCE0658](https://arbiscan.io/address/0x4881Ef0BF6d2365D3dd6499ccd7532bcdBCE0658)
- Ostium Trading: [0x6D0bA1f9996DBD8885827e1b2e8f6593e7702411](https://arbiscan.io/address/0x6D0bA1f9996DBD8885827e1b2e8f6593e7702411)
- GBP/USD Oracle: [0x9C4424Fd84C6661F97D8d6b3fc3C1aAc2BeDd137](https://arbiscan.io/address/0x9C4424Fd84C6661F97D8d6b3fc3C1aAc2BeDd137)

**Tools:**
- Arbiscan: https://arbiscan.io
- Alchemy: https://www.alchemy.com
- Foundry Docs: https://book.getfoundry.sh

---

## 📞 Support

**Technical Issues:**
- GitHub: [Create Issue](https://github.com/gbpb-protocol/issues)
- Discord: Coming soon

**Security Issues:**
- Email: security@gbpb.fi (confidential)
- Bug Bounty: Coming soon

---

**Last Updated:** 2026-02-06
**Version:** 1.0.0
**Status:** Production-Ready with Safety Limits

**Good luck with your deployment! 🚀**
