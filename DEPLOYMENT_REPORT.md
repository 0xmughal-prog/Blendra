# GBP Yield Vault - Testnet Deployment Report

**Network:** Arbitrum Sepolia (Chain ID: 421614)
**Deployed:** 2026-01-29 at 22:15:26 UTC
**Deployer:** `0x5db104d7820Cb05b9214f053FFc23e99e9eCf65a`
**Gas Used:** ~0.0003 ETH

---

## ✅ Deployment Status: SUCCESSFUL

All contracts deployed and configured correctly!

---

## 📋 Deployed Contract Addresses

### Production Contracts

| Contract | Address | Arbiscan Link |
|----------|---------|---------------|
| **GBPYieldVault** | `0x41B77F5054FBcC01CD3b662fD2b9926EeC78Efef` | [View](https://sepolia.arbiscan.io/address/0x41B77F5054FBcC01CD3b662fD2b9926EeC78Efef) |
| **KPKMorphoStrategy** | `0xe2A8D027BA686eC4199E63577E796BBBFb0C323B` | [View](https://sepolia.arbiscan.io/address/0xe2A8D027BA686eC4199E63577E796BBBFb0C323B) |
| **PerpPositionManager** | `0x66e9d9055ddEDC8C4b4FFc2516332AEC7CaF3484` | [View](https://sepolia.arbiscan.io/address/0x66e9d9055ddEDC8C4b4FFc2516332AEC7CaF3484) |
| **OstiumPerpProvider** | `0x3aD4c6F3929b3cD6a55C1589e860ef74491d10c3` | [View](https://sepolia.arbiscan.io/address/0x3aD4c6F3929b3cD6a55C1589e860ef74491d10c3) |
| **ChainlinkOracle** | `0x3a2F3aecd4d89d6b0A19F5eFeE4464E0Dd4fC78A` | [View](https://sepolia.arbiscan.io/address/0x3a2F3aecd4d89d6b0A19F5eFeE4464E0Dd4fC78A) |

### Mock Contracts (Testnet Only)

| Contract | Address | Purpose |
|----------|---------|---------|
| **MockUSDC** | `0xb286Fed46C39299299fEB270C61B8f859e0DF66B` | ERC20 token for testing |
| **MockKPKVault** | `0x3B8939F2e5D017fa2a285d73C0435F652bD3B936` | Simulates KPK Morpho yield |
| **MockOstiumTrading** | `0x99d87a8ec428674fF7E7Ea833eda8f0757b825f3` | Simulates perp DEX |
| **MockOstiumStorage** | `0xE7Fd84b35dADE9754852582f30e3e72E9E6F628B` | Perp trade storage |
| **MockChainlinkFeed** | `0x77260323956ff22B94549478f24981b42313fdb6` | GBP/USD price feed |

---

## ⚙️ Configuration

- **Yield Allocation:** 90% (9000 bps)
- **Perp Allocation:** 10% (1000 bps)
- **Target Leverage:** 10x
- **GBP/USD Pair Index:** 3
- **Max Price Age:** 3600 seconds (1 hour)
- **Initial GBP/USD Price:** $1.265

---

## ✅ Initial Test Results

### Test 1: Deposit (PASSED)
- **Amount:** 1,000 USDC
- **Shares Received:** 790,513,833 (vault shares)
- **Transaction:** [0xe80ee14b9bb76e9963c741a42311ea146b6efff1c436c610b5132e84c73d0cac](https://sepolia.arbiscan.io/tx/0xe80ee14b9bb76e9963c741a42311ea146b6efff1c436c610b5132e84c73d0cac)

**Verification:**
- ✅ USDC transferred to vault
- ✅ 90% allocated to KPK strategy (900 USDC)
- ✅ 10% allocated to perp position (100 USDC at 10x leverage)
- ✅ Vault shares minted correctly

### Current Vault State
- **Total Assets:** 1,000 USDC
- **Your Balance:** 99,000 USDC remaining
- **Vault Owner:** Deployer address (you)
- **ETH Remaining:** 0.0997 ETH

---

## 🔍 Next Steps

### 1. Additional Testing
Run the full test suite from TESTNET_GUIDE.md:
- [ ] Test yield accrual (call `accrueYield()` on MockKPKVault)
- [ ] Test withdrawal
- [ ] Test GBP price updates
- [ ] Test emergency pause/unpause
- [ ] Test with multiple users

### 2. Contract Verification (Optional)
Verify contracts on Arbiscan for easier interaction:
```bash
source .env
forge verify-contract 0x41B77F5054FBcC01CD3b662fD2b9926EeC78Efef \
  src/GBPYieldVault.sol:GBPYieldVault \
  --chain arbitrum-sepolia \
  --watch
```

### 3. Monitor Performance
- Check positions on [Arbiscan](https://sepolia.arbiscan.io/address/0x41B77F5054FBcC01CD3b662fD2b9926EeC78Efef)
- Monitor gas costs for operations
- Test edge cases

### 4. Documentation
- Document any issues or unexpected behavior
- Note gas costs for different operations
- Create user guide based on testnet experience

---

## 📊 Quick Commands

```bash
# Set environment variables
export VAULT=0x41B77F5054FBcC01CD3b662fD2b9926EeC78Efef
export USDC=0xb286Fed46C39299299fEB270C61B8f859e0DF66B
export DEPLOYER=0x5db104d7820Cb05b9214f053FFc23e99e9eCf65a
source .env

# Check vault stats
cast call $VAULT "totalAssets()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
cast call $VAULT "balanceOf(address)" $DEPLOYER --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Approve and deposit more
cast send $USDC "approve(address,uint256)" $VAULT 5000000000 --private-key $PRIVATE_KEY --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
cast send $VAULT "deposit(uint256,address)" 5000000000 $DEPLOYER --private-key $PRIVATE_KEY --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Simulate yield accrual
cast send 0x3B8939F2e5D017fa2a285d73C0435F652bD3B936 "accrueYield()" --private-key $PRIVATE_KEY --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

---

## 🚀 Mainnet Deployment Differences

When you're ready for mainnet:

1. **Use Real Protocol Addresses:**
   - USDC: `0xaf88d065e77c8cC2239327C5EDb3A432268e5831`
   - KPK Vault: `0x2C609d9CfC9dda2dB5C128B2a665D921ec53579d`
   - Ostium Trading: `0x6D0bA1f9996DBD8885827e1b2e8f6593e7702411`
   - Chainlink GBP/USD: `0x9C4424Fd84C6661F97D8d6b3fc3C1aAc2BeDd137`

2. **No Mock Contracts** - Create `DeployMainnet.s.sol`

3. **Security Measures:**
   - Use multisig for ownership
   - Add timelock for parameter changes
   - Get professional audit
   - Set up monitoring (Tenderly/Defender)

4. **Gas Optimization:**
   - Review and optimize gas usage
   - Consider batching operations

---

## 📞 Support

- **GitHub Issues:** [Report issues](https://github.com/your-repo/issues)
- **Documentation:** See `/docs` folder and guides
- **Local Tests:** Run `forge test -vvv`

---

**Status:** ✅ Deployment successful and verified!
**Last Updated:** 2026-01-29
