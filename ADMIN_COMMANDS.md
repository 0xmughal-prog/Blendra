# 🔧 Admin Command Reference

Complete guide to managing your GBPb protocol via CLI.

---

## 📊 View Commands (Read-Only)

### View Protocol Status
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "viewStatus()"
```
Shows: Pause status, TVL, reserve, prices, holdings, addresses

### View Reserve Accounting
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "viewReserveAccounting()"
```
Shows: Reserve balance, fees collected/paid, net revenue, yield borrowed

---

## ⚙️ Protocol Settings

### Pause Protocol (Emergency)
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "pauseProtocol()" --broadcast
```

### Unpause Protocol
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "unpauseProtocol()" --broadcast
```

### Set TVL Cap
```bash
# Set to $25,000
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setTVLCap(uint256)" 25000 --broadcast
```

### Set Minimum Reserve
```bash
# Set to $5
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setMinReserve(uint256)" 5 --broadcast
```

### Set User Cooldown
```bash
# Set to 1 day
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setCooldown(uint256)" 1 --broadcast

# Set to 7 days
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setCooldown(uint256)" 7 --broadcast
```

### Change Fee Recipient
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setFeeRecipient(address)" 0xYOUR_NEW_ADDRESS --broadcast
```

---

## 💰 Reserve Management

### Fund Reserve
```bash
# Fund with $5
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "fundReserve(uint256)" 5 --broadcast

# Fund with $100
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "fundReserve(uint256)" 100 --broadcast
```

### Withdraw from Reserve
```bash
# Withdraw $50
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "withdrawReserve(uint256)" 50 --broadcast
```

---

## 🔄 Strategy & Perp Management

### Rebalance Perp Position
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "rebalancePerp()" --broadcast
```
Use when perp health factor drops below 50%

### Emergency Withdraw from Strategy
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "emergencyWithdraw()" --broadcast
```
⚠️ **EMERGENCY ONLY** - Withdraws all funds from Morpho to minter

### Update Price Oracle
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "updatePrice()" --broadcast
```

---

## 🧪 Testing Commands

### Test Mint
```bash
# Mint $100 worth of GBPb
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "testMint(uint256)" 100 --broadcast
```

### Test Redeem
```bash
# Redeem 78.74 GBPb (example amount)
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "testRedeem(uint256)" 78 --broadcast
```

---

## 🚀 Quick Start Sequence

### 1. First setup your environment
```bash
cd "/Users/wajahat/Downloads/Claude Work/New idea for GBP yield product/gbp-yield-vault"
source .env
```

### 2. Lower min reserve to $5
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setMinReserve(uint256)" 5 --broadcast
```

### 3. Fund reserve with $5
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "fundReserve(uint256)" 5 --broadcast
```

### 4. Unpause protocol
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "unpauseProtocol()" --broadcast
```

### 5. Check status
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "viewStatus()"
```

### 6. Test with small mint ($10)
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "testMint(uint256)" 10 --broadcast
```

---

## 📈 Scaling Checklist

### Week 2: Increase to $25K TVL
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setTVLCap(uint256)" 25000 --broadcast
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "fundReserve(uint256)" 500 --broadcast
```

### Month 2: Increase to $100K TVL
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setTVLCap(uint256)" 100000 --broadcast
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "fundReserve(uint256)" 2000 --broadcast
```

---

## 💰 Revenue Share Management

### View Current Revenue Split
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "viewRevenueSplit()"
```
Shows: Current split %, addresses, pending fees

### Change Revenue Split
```bash
# Set to 80% Treasury / 20% Reserve
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setRevenueSplit(uint256,uint256)" 80 20 --broadcast

# Set to 95% Treasury / 5% Reserve
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setRevenueSplit(uint256,uint256)" 95 5 --broadcast

# Set to 70% Treasury / 30% Reserve
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setRevenueSplit(uint256,uint256)" 70 30 --broadcast
```
**Note:** Treasury% + Reserve% must equal 100%

### Update Treasury Address
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setTreasuryAddress(address)" 0xNEW_TREASURY_ADDRESS --broadcast
```

### Update Reserve Buffer Address
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "setReserveBufferAddress(address)" 0xNEW_BUFFER_ADDRESS --broadcast
```

### Claim Treasury Fees
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "claimTreasuryFees()" --broadcast
```
Sends pending sGBPb fees to treasury address

### Claim Reserve Fees
```bash
forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "claimReserveFees()" --broadcast
```
Sends pending sGBPb fees to reserve buffer address

---

## 🔐 Security Notes

- All commands require your PRIVATE_KEY from .env
- Commands with `--broadcast` will spend gas and modify state
- Commands without `--broadcast` are read-only (no cost)
- Always test on small amounts first
- Keep backups of all contract addresses

---

## 💡 Tips

1. **Always check status before making changes:**
   ```bash
   forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "viewStatus()"
   ```

2. **Monitor reserve health regularly:**
   ```bash
   forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "viewReserveAccounting()"
   ```

3. **Set up alerts:**
   - Reserve < $10
   - Perp health < 50%
   - TVL > 90% of cap

4. **Emergency procedure:**
   ```bash
   # If critical issue detected
   forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "pauseProtocol()" --broadcast

   # Withdraw from strategy if needed
   forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "emergencyWithdraw()" --broadcast
   ```

---

## 🌐 Want a Web Dashboard?

I can create a Next.js admin dashboard with:
- Visual protocol status
- One-click parameter changes
- Real-time metrics
- Transaction history
- Alert notifications

Let me know if you want the web version!
