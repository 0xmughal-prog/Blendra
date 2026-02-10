# GBP Yield Vault - Testnet Deployment Guide

Complete guide for deploying and testing the GBP Yield Vault on Arbitrum Sepolia testnet.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Deployment](#deployment)
4. [Testing Strategy](#testing-strategy)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools
- Foundry (forge, cast, anvil)
- Git
- Node.js (for optional verification scripts)

### Required Accounts
- Ethereum wallet with private key
- Arbitrum Sepolia testnet ETH for gas ([Faucet](https://faucet.quicknode.com/arbitrum/sepolia))
- Arbiscan API key (optional, for contract verification)

### Get Testnet ETH
```bash
# Visit Arbitrum Sepolia faucet
https://faucet.quicknode.com/arbitrum/sepolia

# Or use Alchemy faucet
https://www.alchemy.com/faucets/arbitrum-sepolia
```

---

## Environment Setup

### 1. Clone and Install Dependencies

```bash
cd gbp-yield-vault
forge install
forge build
```

### 2. Create Environment File

Create `.env` file in the project root:

```bash
# Deployer private key (NEVER commit this!)
PRIVATE_KEY=0x...your...private...key...

# RPC URLs
ARBITRUM_SEPOLIA_RPC_URL=https://arb-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
# Or use public RPC:
# ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc

# Optional: For contract verification
ARBISCAN_API_KEY=your_arbiscan_api_key
```

### 3. Load Environment

```bash
source .env
```

---

## Deployment

### Step 1: Dry Run (Recommended)

Test the deployment script without broadcasting:

```bash
forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --sender $(cast wallet address $PRIVATE_KEY)
```

### Step 2: Deploy to Testnet

```bash
forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --legacy
```

**Expected Output:**
```
=== Deploying to Arbitrum Sepolia ===
Deployer: 0x...
Chain ID: 421614

=== Step 1: Deploying Mocks ===
MockUSDC deployed: 0x...
MockKPKVault deployed: 0x...
MockOstiumStorage deployed: 0x...
MockOstiumTrading deployed: 0x...
MockChainlinkFeed deployed: 0x...

=== Step 2: Deploying Real Contracts ===
ChainlinkOracle deployed: 0x...
KPKMorphoStrategy deployed: 0x...
OstiumPerpProvider deployed: 0x...
PerpPositionManager deployed: 0x...
GBPYieldVault deployed: 0x...

=== Step 3: Configuring Contracts ===
✓ All configured successfully
```

### Step 3: Save Deployment Addresses

The script will output all deployed addresses. Save them to `deployments/sepolia.json`:

```json
{
  "network": "arbitrum-sepolia",
  "chainId": 421614,
  "deployedAt": "2024-01-29T12:00:00Z",
  "mocks": {
    "mockUSDC": "0x...",
    "mockKPKVault": "0x...",
    "mockOstiumTrading": "0x...",
    "mockOstiumStorage": "0x...",
    "mockChainlinkFeed": "0x..."
  },
  "contracts": {
    "vault": "0x...",
    "kpkStrategy": "0x...",
    "perpManager": "0x...",
    "ostiumProvider": "0x...",
    "chainlinkOracle": "0x..."
  }
}
```

---

## Testing Strategy

### Overview

The testnet deployment uses **mock contracts** for protocols not available on testnet:
- ✅ MockERC20 (USDC)
- ✅ MockERC4626Vault (simulates KPK Morpho with yield accrual)
- ✅ MockOstiumTrading/Storage (perp DEX simulation)
- ✅ MockChainlinkOracle (GBP/USD price feed)

### Test 1: Basic Deposit and Withdrawal

```bash
# Set your deployed addresses
export VAULT_ADDRESS=0x...
export USDC_ADDRESS=0x...
export DEPLOYER_ADDRESS=$(cast wallet address $PRIVATE_KEY)

# 1. Check initial USDC balance (should be 100,000 from deployment)
cast call $USDC_ADDRESS "balanceOf(address)(uint256)" $DEPLOYER_ADDRESS --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# 2. Approve vault to spend USDC (approve 10,000 USDC = 10,000 * 10^6)
cast send $USDC_ADDRESS \
  "approve(address,uint256)" \
  $VAULT_ADDRESS 10000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# 3. Deposit 1,000 USDC into vault (1,000 * 10^6 = 1,000,000,000)
cast send $VAULT_ADDRESS \
  "deposit(uint256,address)(uint256)" \
  1000000000 $DEPLOYER_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# 4. Check vault shares balance
cast call $VAULT_ADDRESS "balanceOf(address)(uint256)" $DEPLOYER_ADDRESS --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# 5. Check total assets
cast call $VAULT_ADDRESS "totalAssets()(uint256)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Test 2: Yield Accrual Simulation

```bash
# Accrue yield on mock KPK vault
cast send $KPK_VAULT_ADDRESS \
  "accrueYield()" \
  --private-key $PRIVATE_KEY \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check total assets again (should be higher due to yield)
cast call $VAULT_ADDRESS "totalAssets()(uint256)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Test 3: Check Position Details

```bash
# Check perp position details
cast call $VAULT_ADDRESS "perpManager()(address)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
export PERP_MANAGER=<address_from_above>

cast call $PERP_MANAGER "getPositionDetails()(uint256,uint256,uint256)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Test 4: Withdrawal

```bash
# Get your share balance
SHARES=$(cast call $VAULT_ADDRESS "balanceOf(address)(uint256)" $DEPLOYER_ADDRESS --rpc-url $ARBITRUM_SEPOLIA_RPC_URL)

# Redeem 50% of shares
HALF_SHARES=$((SHARES / 2))

cast send $VAULT_ADDRESS \
  "redeem(uint256,address,address)(uint256)" \
  $HALF_SHARES $DEPLOYER_ADDRESS $DEPLOYER_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check USDC balance (should have received USDC back)
cast call $USDC_ADDRESS "balanceOf(address)(uint256)" $DEPLOYER_ADDRESS --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Test 5: Price Feed Updates

```bash
# Update GBP/USD price on mock Chainlink feed
export CHAINLINK_FEED=0x...

# Set new price (e.g., 1.27 GBP/USD = 127000000 with 8 decimals)
cast send $CHAINLINK_FEED \
  "updateAnswer(int256)" \
  127000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check new GBP value
cast call $VAULT_ADDRESS "totalAssetsGBP()(uint256)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
cast call $VAULT_ADDRESS "sharePriceGBP()(uint256)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Test 6: Emergency Functions

```bash
# Test emergency pause (only owner)
cast send $VAULT_ADDRESS \
  "pause()" \
  --private-key $PRIVATE_KEY \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Try to deposit while paused (should fail)
cast send $VAULT_ADDRESS \
  "deposit(uint256,address)(uint256)" \
  100000000 $DEPLOYER_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Unpause
cast send $VAULT_ADDRESS \
  "unpause()" \
  --private-key $PRIVATE_KEY \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

---

## Verification

### Verify Contracts on Arbiscan

If you didn't use `--verify` during deployment, verify manually:

```bash
# 1. Verify GBPYieldVault
forge verify-contract \
  --chain arbitrum-sepolia \
  --constructor-args $(cast abi-encode \
    "constructor(address,string,string,address,address,address,uint256,uint256,uint256)" \
    $USDC_ADDRESS \
    "GBP Yield Vault" \
    "gbpUSDC" \
    $STRATEGY_ADDRESS \
    $PERP_MANAGER_ADDRESS \
    $ORACLE_ADDRESS \
    9000 \
    1000 \
    10) \
  $VAULT_ADDRESS \
  src/GBPYieldVault.sol:GBPYieldVault

# 2. Verify other contracts similarly
```

### Check Contract State

```bash
# Check allocations
cast call $VAULT_ADDRESS "yieldAllocation()(uint256)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
cast call $VAULT_ADDRESS "perpAllocation()(uint256)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check leverage
cast call $VAULT_ADDRESS "targetLeverage()(uint256)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check ownership
cast call $VAULT_ADDRESS "owner()(address)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

---

## Troubleshooting

### Issue: Deployment Fails with "Vault address mismatch"

**Cause:** Nonce calculation was incorrect

**Solution:**
1. Check your current nonce: `cast nonce $DEPLOYER_ADDRESS --rpc-url $ARBITRUM_SEPOLIA_RPC_URL`
2. Clear any pending transactions
3. Try deployment again

### Issue: "Insufficient funds for gas"

**Cause:** Not enough ETH on Arbitrum Sepolia

**Solution:**
```bash
# Get more testnet ETH from faucets
https://faucet.quicknode.com/arbitrum/sepolia
```

### Issue: "execution reverted" on deposit

**Possible causes:**
1. USDC not approved
2. Vault is paused
3. Depositing zero amount

**Debug:**
```bash
# Check approval
cast call $USDC_ADDRESS "allowance(address,address)(uint256)" \
  $DEPLOYER_ADDRESS $VAULT_ADDRESS \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check if paused
cast call $VAULT_ADDRESS "paused()(bool)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Issue: Tests fail locally

**Solution:**
```bash
# Clean and rebuild
forge clean
forge build

# Run specific test with verbose output
forge test --match-test testDeposit -vvvv
```

---

## Next Steps

After successful testnet deployment and testing:

1. ✅ Document any issues or edge cases discovered
2. ✅ Test with multiple users (create additional test wallets)
3. ✅ Stress test with large deposits/withdrawals
4. ✅ Monitor gas costs for all operations
5. ✅ Review and audit code before mainnet deployment
6. ✅ Create mainnet deployment checklist
7. ✅ Set up monitoring and alerting for mainnet

---

## Mainnet Deployment Differences

When deploying to mainnet, you'll need to:

1. **Use real protocol addresses** (no mocks):
   - USDC: `0xaf88d065e77c8cC2239327C5EDb3A432268e5831`
   - KPK Vault: `0x2C609d9CfC9dda2dB5C128B2a665D921ec53579d`
   - Ostium Trading: `0x6D0bA1f9996DBD8885827e1b2e8f6593e7702411`
   - Ostium Storage: `0xcCd5891083A8acD2074690F65d3024E7D13d66E7`
   - Chainlink GBP/USD: `0x9C4424Fd84C6661F97D8d6b3fc3C1aAc2BeDd137`

2. **Skip mock deployments** - Create a separate `DeployMainnet.s.sol` script

3. **Use multisig** for ownership instead of EOA

4. **Add timelock** for critical parameter changes

5. **Set up monitoring** with Tenderly, Defender, etc.

6. **Purchase comprehensive audit** from Trail of Bits, OpenZeppelin, etc.

---

## Support

For issues or questions:
- GitHub Issues: [Create an issue](https://github.com/your-repo/issues)
- Documentation: See `/docs` folder
- Run local tests: `forge test -vvv`
