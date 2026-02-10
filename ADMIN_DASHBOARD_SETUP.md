# 🎛️ Admin Dashboard - Complete Setup Guide

## 🎉 What's Been Created

### 1. **ConfigurableFeeDistributor.sol**
A new smart contract that allows you to change revenue splits anytime:
- Adjust treasury vs reserve percentages on the fly
- Change treasury and reserve addresses
- Pull-payment model for claiming fees
- Fully configurable after deployment

### 2. **Admin.s.sol**
Comprehensive CLI admin tool with functions for:
- **Protocol Management:** Pause, unpause, set TVL caps, cooldowns
- **Reserve Management:** Fund, withdraw, view accounting
- **Strategy & Perp:** Rebalance, emergency withdraw
- **Revenue Share:** View split, change percentages, claim fees
- **Testing:** Simulate mints and redeems

### 3. **DeployConfigurableFeeDistributor.s.sol**
Easy deployment script for the configurable fee distributor

### 4. **ADMIN_COMMANDS.md**
Complete command reference with all admin functions

---

## 🚀 Quick Start (Get Your Admin Dashboard Running)

### Step 1: Update Your .env

First, add these contract addresses to your `.env` file:

```bash
# You already have these from deployment:
GBPB_ADDRESS=0x59a7A23c1246713352B663690C3ac6D280a40176
SGBPB_ADDRESS=0x0D9Fdc66E774FDa67607D02c498d8dc3AD4F6683
MINTER_ADDRESS=0x680A5F9d86accdcfd0aaCdaf533896A5B6c0F11d
STRATEGY_ADDRESS=0x75A0403A8b9327C1163bF77Af0224107C2c99231
PERP_MANAGER_ADDRESS=0xd7046325c9F798CE0CD16d7286738CA9F4865228

# Add this (we'll deploy it next):
FEE_DISTRIBUTOR_ADDRESS=
```

### Step 2: Deploy Configurable Fee Distributor

```bash
cd "/Users/wajahat/Downloads/Claude Work/New idea for GBP yield product/gbp-yield-vault"
source .env

# Deploy with default 90/10 split
forge script script/DeployConfigurableFeeDistributor.s.sol:DeployConfigurableFeeDistributor \
  --rpc-url $ARBITRUM_RPC \
  --broadcast
```

This will output the new FeeDistributor address. **Copy it and add to your .env:**

```bash
FEE_DISTRIBUTOR_ADDRESS=0xYOUR_NEW_FEE_DISTRIBUTOR_ADDRESS
```

### Step 3: Update sGBPb Vault

Point the sGBPb vault to use your new configurable fee distributor:

```bash
source .env

cast send $SGBPB_ADDRESS \
  "setFeeCollector(address)" \
  $FEE_DISTRIBUTOR_ADDRESS \
  --rpc-url $ARBITRUM_RPC \
  --private-key $PRIVATE_KEY
```

### Step 4: Test Your Admin Dashboard!

```bash
# View protocol status
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "viewStatus()"

# View revenue split
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "viewRevenueSplit()"

# View reserve accounting
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "viewReserveAccounting()"
```

---

## 💰 Managing Revenue Share

### View Current Split
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "viewRevenueSplit()"
```

### Change Revenue Split Examples

**Example 1: 80% Treasury / 20% Reserve**
```bash
forge script script/Admin.s.sol:AdminTool \
  --rpc-url $ARBITRUM_RPC \
  --sig "setRevenueSplit(uint256,uint256)" 80 20 \
  --broadcast
```

**Example 2: 95% Treasury / 5% Reserve (Aggressive)**
```bash
forge script script/Admin.s.sol:AdminTool \
  --rpc-url $ARBITRUM_RPC \
  --sig "setRevenueSplit(uint256,uint256)" 95 5 \
  --broadcast
```

**Example 3: 70% Treasury / 30% Reserve (Conservative)**
```bash
forge script script/Admin.s.sol:AdminTool \
  --rpc-url $ARBITRUM_RPC \
  --sig "setRevenueSplit(uint256,uint256)" 70 30 \
  --broadcast
```

**Example 4: 50/50 Split**
```bash
forge script script/Admin.s.sol:AdminTool \
  --rpc-url $ARBITRUM_RPC \
  --sig "setRevenueSplit(uint256,uint256)" 50 50 \
  --broadcast
```

### Claim Fees

**Claim Treasury Fees:**
```bash
forge script script/Admin.s.sol:AdminTool \
  --rpc-url $ARBITRUM_RPC \
  --sig "claimTreasuryFees()" \
  --broadcast
```

**Claim Reserve Fees:**
```bash
forge script script/Admin.s.sol:AdminTool \
  --rpc-url $ARBITRUM_RPC \
  --sig "claimReserveFees()" \
  --broadcast
```

---

## 🎯 Common Admin Tasks

### Daily Monitoring

```bash
# Check everything is healthy
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "viewStatus()"

# Check reserve accounting
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "viewReserveAccounting()"
```

### Initial Setup (Your Current Task)

```bash
# 1. Lower min reserve to $5
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setMinReserve(uint256)" 5 --broadcast

# 2. Fund reserve with $5
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "fundReserve(uint256)" 5 --broadcast

# 3. Unpause protocol
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "unpauseProtocol()" --broadcast

# 4. Check status
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "viewStatus()"

# 5. Test mint with $10
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "testMint(uint256)" 10 --broadcast
```

### Scaling Up

```bash
# Increase TVL cap to $25,000
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setTVLCap(uint256)" 25000 --broadcast

# Increase min reserve to $100
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setMinReserve(uint256)" 100 --broadcast

# Fund with more USDC
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "fundReserve(uint256)" 500 --broadcast
```

### Emergency Situations

```bash
# Pause immediately
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "pauseProtocol()" --broadcast

# Emergency withdraw from strategy
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "emergencyWithdraw()" --broadcast

# Rebalance perp if health low
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "rebalancePerp()" --broadcast
```

---

## 📋 Complete Function Reference

See `ADMIN_COMMANDS.md` for the complete list of all available commands.

### Categories:
1. **View Commands** - Read-only status checks
2. **Protocol Settings** - Pause, TVL caps, cooldowns
3. **Reserve Management** - Fund, withdraw, accounting
4. **Strategy & Perp** - Rebalance, emergency withdraw
5. **Revenue Share** - View/change splits, claim fees
6. **Testing** - Simulate user actions

---

## 🌐 Want a Web Dashboard?

I can create a visual web admin panel with:
- **React/Next.js** frontend
- **Web3** integration (MetaMask, WalletConnect)
- **Real-time** protocol metrics
- **One-click** parameter changes
- **Charts** and analytics
- **Alert** notifications

Let me know if you want me to build it!

---

## 🎓 Tips

1. **Always source .env first:**
   ```bash
   source .env
   ```

2. **Check before broadcasting:**
   Remove `--broadcast` to simulate first

3. **Save command history:**
   Create aliases for common commands

4. **Monitor regularly:**
   Set up cron jobs or use monitoring tools

---

## 🆘 Need Help?

All commands are in `ADMIN_COMMANDS.md`

**Current Status:**
- ✅ Contracts deployed
- ✅ Admin tool ready
- ⏳ Need to deploy ConfigurableFeeDistributor
- ⏳ Need to fund reserve and unpause

**Next Step:** Deploy the configurable fee distributor! 🚀
