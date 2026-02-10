# GBP Yield Vault - Quick Start Guide

Get up and running in 5 minutes!

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Basic understanding of Solidity and DeFi

## Setup (2 minutes)

```bash
# Navigate to project
cd gbp-yield-vault

# Build contracts
forge build

# Run tests
forge test

# See detailed test output
forge test -vv
```

## Test Results

All tests should pass:
```
Suite result: ok. 21 passed; 0 failed; 0 skipped
```

## Contract Sizes

All contracts are optimized and under the 24KB limit:
- **GBPYieldVault**: 8.8 KB ✅
- **AaveStrategy**: 3.2 KB ✅
- **PerpPositionManager**: 3.9 KB ✅
- **ChainlinkOracle**: 2.1 KB ✅

## Key Files

### Smart Contracts
- `src/GBPYieldVault.sol` - Main vault (ERC4626)
- `src/AaveStrategy.sol` - Yield generation
- `src/PerpPositionManager.sol` - Perp hedging
- `src/ChainlinkOracle.sol` - Price feeds

### Tests
- `test/unit/GBPYieldVault.t.sol` - 21 comprehensive tests

### Scripts
- `script/Deploy.s.sol` - Deployment automation
- `script/Interact.s.sol` - Vault interaction helpers

## Quick Test

Run a specific test:
```bash
forge test --match-test testDeposit -vv
```

Expected output:
```
[PASS] testDeposit() (gas: 493507)
```

## Architecture at a Glance

```
User deposits USDC
    ↓
[GBPYieldVault]
    ↓           ↓
  80% →    20% →
[Aave]    [Perp Position]
Earns     GBP/USD Long
Yield     (5x leverage)
    ↓           ↓
GBP-denominated shares
```

## Understanding the Code

### 1. Deposit Flow (GBPYieldVault.sol:115-180)

```solidity
function deposit(uint256 assets, address receiver) {
    // 1. Accept USDC from user
    IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);

    // 2. Deploy 80% to Aave
    yieldStrategy.deposit(yieldAmount);

    // 3. Open perp position with 20% as collateral
    perpManager.increasePosition(assets, perpCollateral);

    // 4. Mint GBP-denominated shares
    _mint(receiver, shares);
}
```

### 2. NAV Calculation (GBPYieldVault.sol:274-297)

```solidity
function totalAssets() {
    return idle + inYield + perpCollateral + perpPnL;
}
```

### 3. GBP Pricing (libraries/NAVCalculator.sol)

```solidity
function convertUSDtoGBP(uint256 usdAmount, uint256 gbpUsdPrice) {
    return (usdAmount * 1e8) / gbpUsdPrice;
}
```

## Common Commands

```bash
# Build
forge build

# Test
forge test
forge test -vv              # Verbose
forge test --gas-report     # Gas usage

# Clean
forge clean

# Update dependencies
forge update
```

## Next Steps

1. **Review Documentation**: Read [README.md](README.md) for full details
2. **Understand Architecture**: Check [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)
3. **Explore Tests**: Look at `test/unit/GBPYieldVault.t.sol`
4. **Modify & Test**: Try changing allocation percentages and re-run tests

## Development Workflow

1. Make changes to contracts
2. Run tests: `forge test`
3. Check gas: `forge test --gas-report`
4. Build: `forge build`
5. Deploy to testnet when ready

## Getting Help

- **Documentation**: See README.md
- **Code Comments**: All functions have NatSpec documentation
- **Tests**: Look at tests for usage examples

## Key Concepts

### ERC4626
Standard vault interface:
- `deposit()` - Add funds
- `withdraw()` - Remove funds
- `totalAssets()` - Get NAV
- `convertToShares()` - Calculate shares

### Atomic Operations
Everything happens in one transaction:
- ✅ No manual steps
- ✅ No waiting
- ✅ All or nothing

### GBP Denomination
- Shares priced in GBP
- USD deposits converted via Chainlink oracle
- Tracks GBP/USD exposure

## Troubleshooting

### Tests Fail
```bash
forge clean
forge build
forge test
```

### Build Errors
Check Solidity version (should be 0.8.20):
```bash
forge --version
```

### Import Errors
Reinstall dependencies:
```bash
rm -rf lib/
forge install
```

## Ready to Deploy?

See [README.md](README.md) deployment section for testnet/mainnet instructions.

---

**You're all set!** 🎉

Start exploring the code or jump to the [full documentation](README.md).
