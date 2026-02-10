# Testnet Deployment - Summary & Answers

## Your Questions Answered

### 1. Does Arbitrum Sepolia have the same contracts (KPK, Ostium)?

**Answer: NO**

Neither KPK Morpho vault nor Ostium perp DEX are available on Arbitrum Sepolia testnet:

| Protocol | Mainnet | Testnet Available? |
|----------|---------|-------------------|
| KPK Morpho Vault | `0x2C609d9CfC9dda2dB5C128B2a665D921ec53579d` | ❌ No |
| Ostium Trading | `0x6D0bA1f9996DBD8885827e1b2e8f6593e7702411` | ❌ No |
| Ostium Storage | `0xcCd5891083A8acD2074690F65d3024E7D13d66E7` | ❌ No |
| Chainlink GBP/USD | `0x9C4424Fd84C6661F97D8d6b3fc3C1aAc2BeDd137` | ⚠️ Different address |

**Why?**
- KPK and Ostium are mainnet-only production protocols
- Testnets don't generate real yield or have real liquidity
- Chainlink may have test feeds but with different addresses

---

### 2. Should we deploy with mocks if protocols aren't on testnet?

**Answer: YES - Absolutely!**

This is the **recommended approach** for testnet deployment. Your codebase already has excellent mock contracts:

✅ **Available Mocks:**
- `MockERC20.sol` - Simulates USDC with mint functionality
- `MockERC4626Vault.sol` - Simulates KPK with configurable yield accrual
- `MockOstiumTrading.sol` - Simulates Ostium perp trading
- `MockOstiumTradingStorage.sol` - Simulates Ostium position storage
- `MockChainlinkOracle.sol` - Simulates Chainlink price feed

**Benefits:**
1. **Full integration testing** - Test complete deposit → yield → perp → withdrawal flow
2. **Controllable environment** - Manually trigger yield accrual, price updates
3. **No external dependencies** - Deploy anytime without waiting for protocols
4. **Cost effective** - No real funds at risk
5. **Matches mainnet architecture** - Same contract interfaces

---

### 3. What's the testing strategy on testnet?

**Answer: Comprehensive integration testing with mocks**

#### Architecture on Testnet

```
┌─────────────────────────────────────────────────┐
│              GBPYieldVault (Real)               │
│  - Deposit/Withdraw logic                       │
│  - NAV calculation                              │
│  - Fee management                               │
└──────────┬──────────────────────┬────────────────┘
           │                      │
           │                      │
  ┌────────▼────────┐    ┌────────▼──────────┐
  │ KPKMorphoStrategy│    │ PerpPositionManager│
  │     (Real)       │    │      (Real)        │
  └────────┬────────┘    └────────┬───────────┘
           │                      │
           │                      │
  ┌────────▼────────┐    ┌────────▼──────────┐
  │  MockKPKVault   │    │ OstiumPerpProvider │
  │   (ERC4626)     │    │      (Real)        │
  │  - Yield accrual│    └────────┬───────────┘
  └─────────────────┘             │
                         ┌────────▼──────────┐
                         │ MockOstiumTrading │
                         │ MockOstiumStorage │
                         └───────────────────┘
```

#### Testing Flow

**Phase 1: Deployment Verification** (5-10 minutes)
- Deploy all contracts using `DeployTestnet.s.sol`
- Verify all addresses deployed correctly
- Check contract ownerships and permissions
- Verify initial configuration (90/10 split, 10x leverage)

**Phase 2: Basic Operations** (15-20 minutes)
- Deposit 1,000 USDC
- Verify 90% goes to MockKPKVault
- Verify 10% opens perp position
- Check share minting
- Withdraw 50%
- Verify proportional withdrawal from both strategies

**Phase 3: Yield Simulation** (10-15 minutes)
- Manually trigger `accrueYield()` on MockKPKVault
- Verify totalAssets increases
- Deposit more funds
- Verify shares priced correctly with yield
- Withdraw and verify profit distribution

**Phase 4: Perp Mechanics** (10-15 minutes)
- Verify GBP/USD position opened with correct leverage
- Update MockChainlinkFeed price
- Check totalAssetsGBP reflects currency changes
- Verify sharePriceGBP updates correctly

**Phase 5: Edge Cases** (15-20 minutes)
- Test large deposits (>10,000 USDC)
- Test small deposits (<10 USDC)
- Test full withdrawal
- Test pause/unpause functionality
- Test emergency withdrawal functions

**Phase 6: Multi-User Testing** (20-30 minutes)
- Create 2-3 test wallets
- Have multiple users deposit at different times
- Accrue yield
- Verify each user's share value is correct
- Test simultaneous withdrawals

---

## What I Created For You

### 1. **DeployTestnet.s.sol** - Comprehensive Deployment Script

Located: `script/DeployTestnet.s.sol`

**Features:**
- Deploys ALL mock infrastructure (USDC, KPK, Ostium, Chainlink)
- Deploys real production contracts
- Configures permissions automatically
- Mints initial test USDC (100,000)
- Includes address prediction for proper dependency setup
- Comprehensive console logging

**Deploy command:**
```bash
forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

### 2. **TESTNET_GUIDE.md** - Complete Testing Guide

Located: `TESTNET_GUIDE.md`

**Includes:**
- Prerequisites and setup instructions
- Environment configuration
- Step-by-step deployment
- 6 comprehensive test scenarios with commands
- Contract verification guide
- Troubleshooting section
- Mainnet deployment differences

### 3. **DEPLOYMENT_CHECKLIST.md** - Quick Reference

Located: `DEPLOYMENT_CHECKLIST.md`

**Includes:**
- Pre-deployment checklist
- Deployment steps
- Post-deployment verification
- Testing checklist
- Quick command reference

---

## Architecture Summary

### Deployed Contract Hierarchy

```
Mocks (Testnet Only):
├── MockERC20 (USDC)
├── MockERC4626Vault (KPK Morpho)
├── MockOstiumTrading
├── MockOstiumStorage
└── MockChainlinkOracle

Production Contracts:
├── GBPYieldVault (Main vault - ERC4626)
├── KPKMorphoStrategy (90% allocation)
├── PerpPositionManager (Wrapper)
├── OstiumPerpProvider (10% allocation, 10x leverage)
└── ChainlinkOracle (Wrapper)
```

### Ownership Structure

After deployment:
- **GBPYieldVault**: Owned by deployer
- **KPKMorphoStrategy**: Owned by GBPYieldVault (for emergency functions)
- **PerpPositionManager**: Owned by GBPYieldVault (for onlyVault modifier)
- **OstiumPerpProvider**: Owned by deployer (for parameter tuning)
- **ChainlinkOracle**: Owned by deployer

---

## Next Steps

### Immediate (Today):

1. **Set up environment**
   ```bash
   cd gbp-yield-vault
   # Create .env file with PRIVATE_KEY and RPC_URL
   forge build
   ```

2. **Get testnet ETH**
   - Visit: https://faucet.quicknode.com/arbitrum/sepolia
   - Get 0.1 ETH for gas

3. **Deploy to testnet**
   ```bash
   forge script script/DeployTestnet.s.sol:DeployTestnet \
     --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
     --broadcast
   ```

4. **Save addresses** from deployment output

5. **Run basic tests** (deposit, withdraw, yield)

### Short Term (This Week):

6. Run all 6 test scenarios from TESTNET_GUIDE.md
7. Test with multiple wallets
8. Document any issues
9. Verify contracts on Arbiscan

### Before Mainnet:

10. Review and fix any bugs found on testnet
11. Get security audit (Trail of Bits, OpenZeppelin, Cyfrin)
12. Create mainnet deployment script (using real addresses)
13. Set up multisig for ownership
14. Prepare monitoring infrastructure
15. Create incident response plan

---

## Key Configuration

| Parameter | Value | Notes |
|-----------|-------|-------|
| Yield Allocation | 90% (9000 bps) | To KPK Morpho |
| Perp Allocation | 10% (1000 bps) | To Ostium |
| Target Leverage | 10x | On perp position |
| GBP/USD Pair Index | 3 | Verified from Ostium |
| Max Price Age | 3600s (1 hour) | For Chainlink |
| Initial Test USDC | 100,000 | Minted to deployer |

---

## Important Notes

### Mock Limitations

While mocks are great for testing, they have limitations:

1. **No real slippage** - MockOstium accepts trades instantly
2. **No liquidations** - Positions won't be liquidated in mocks
3. **Manual yield** - Must call `accrueYield()` manually
4. **No real market conditions** - Prices are manually set

### What This Tests

✅ Contract integration and data flow
✅ Deposit/withdrawal mechanics
✅ Share pricing and NAV calculation
✅ Permission and ownership structure
✅ Emergency functions
✅ Gas costs and optimization

❌ Real market conditions
❌ Actual yield generation
❌ Liquidation risk
❌ Oracle failures
❌ Protocol upgrades

---

## Cost Estimates

**Testnet Deployment:**
- Gas cost: ~0.01-0.05 ETH (free testnet ETH)
- Time: 10-15 minutes
- Cost: $0 (testnet)

**Mainnet Deployment:**
- Gas cost: ~0.005-0.01 ETH ($10-20 at current prices)
- Audit: $50k-150k (comprehensive)
- Bug bounty: $10k-50k ongoing
- Monitoring: $100-500/month

---

## Support & Resources

- **Documentation**: See TESTNET_GUIDE.md
- **Quick Reference**: See DEPLOYMENT_CHECKLIST.md
- **Deployment Script**: `script/DeployTestnet.s.sol`
- **Run Tests**: `forge test -vvv`

---

**Status**: ✅ Ready for testnet deployment
**Last Updated**: 2024-01-29
**Network**: Arbitrum Sepolia (ChainID: 421614)
