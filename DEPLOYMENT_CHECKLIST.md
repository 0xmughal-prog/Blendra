# Testnet Deployment Checklist

Quick reference for deploying GBP Yield Vault to Arbitrum Sepolia.

## Pre-Deployment

- [ ] Foundry installed (`forge --version`)
- [ ] All dependencies installed (`forge install`)
- [ ] Code compiles (`forge build`)
- [ ] All tests pass (`forge test`)
- [ ] `.env` file created with:
  - [ ] `PRIVATE_KEY`
  - [ ] `ARBITRUM_SEPOLIA_RPC_URL`
  - [ ] `ARBISCAN_API_KEY` (optional)
- [ ] Testnet ETH in deployer wallet
- [ ] Deployer address confirmed: `cast wallet address $PRIVATE_KEY`

## Deployment

- [ ] Run dry-run simulation:
  ```bash
  forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
  ```

- [ ] Deploy contracts:
  ```bash
  forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --legacy
  ```

- [ ] Save all deployed addresses to `deployments/sepolia.json`

## Post-Deployment Verification

### Mock Contracts
- [ ] MockUSDC deployed: `0x...`
- [ ] MockKPKVault deployed: `0x...`
- [ ] MockOstiumTrading deployed: `0x...`
- [ ] MockOstiumStorage deployed: `0x...`
- [ ] MockChainlinkFeed deployed: `0x...`

### Production Contracts
- [ ] GBPYieldVault deployed: `0x...`
- [ ] KPKMorphoStrategy deployed: `0x...`
- [ ] PerpPositionManager deployed: `0x...`
- [ ] OstiumPerpProvider deployed: `0x...`
- [ ] ChainlinkOracle deployed: `0x...`

### Configuration Checks
- [ ] Vault owner is deployer address
- [ ] Strategy owner is vault address
- [ ] PerpManager owner is vault address
- [ ] Yield allocation = 9000 (90%)
- [ ] Perp allocation = 1000 (10%)
- [ ] Target leverage = 10
- [ ] Initial USDC minted to deployer = 100,000

## Testing

### Test 1: Basic Operations
- [ ] Approve USDC for vault
- [ ] Deposit 1,000 USDC
- [ ] Check shares received
- [ ] Check totalAssets
- [ ] Redeem 50% shares
- [ ] Verify USDC returned

### Test 2: Yield Mechanics
- [ ] Call `accrueYield()` on MockKPKVault
- [ ] Verify totalAssets increased
- [ ] Check sharePriceGBP

### Test 3: Perp Position
- [ ] Check position details via PerpManager
- [ ] Verify collateral = 10% of deposit
- [ ] Verify leverage = 10x

### Test 4: Price Updates
- [ ] Update MockChainlinkFeed price
- [ ] Check totalAssetsGBP reflects new price
- [ ] Verify sharePriceGBP updated

### Test 5: Emergency Functions
- [ ] Pause vault
- [ ] Confirm deposits blocked
- [ ] Unpause vault
- [ ] Confirm deposits work

## Contract Verification

- [ ] Verify GBPYieldVault on Arbiscan
- [ ] Verify KPKMorphoStrategy on Arbiscan
- [ ] Verify PerpPositionManager on Arbiscan
- [ ] Verify OstiumPerpProvider on Arbiscan
- [ ] Verify ChainlinkOracle on Arbiscan

## Documentation

- [ ] Update README with testnet addresses
- [ ] Document any issues encountered
- [ ] Note gas costs for all operations
- [ ] Record test transaction hashes
- [ ] Create deployment report

## Next Steps

- [ ] Run extended stress tests
- [ ] Test with multiple users
- [ ] Monitor for 24-48 hours
- [ ] Prepare mainnet deployment plan
- [ ] Schedule security audit

---

## Quick Commands

```bash
# Check balance
cast call $USDC "balanceOf(address)" $DEPLOYER --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check vault total assets
cast call $VAULT "totalAssets()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check share balance
cast call $VAULT "balanceOf(address)" $DEPLOYER --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check vault owner
cast call $VAULT "owner()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check if paused
cast call $VAULT "paused()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

---

## Emergency Contacts

- Deployer Address: `0x...`
- Multisig Address: `N/A (testnet)`
- Monitoring Dashboard: `N/A (testnet)`

---

**Last Updated:** 2024-01-29
**Network:** Arbitrum Sepolia (421614)
**Status:** ⏳ Pending Deployment
