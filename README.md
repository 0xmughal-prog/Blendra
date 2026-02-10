# GBP Yield Vault

A DeFi vault that provides GBP-denominated yield through USD stablecoin strategies combined with GBP/USD perpetual hedging.

## Overview

The GBP Yield Vault allows users to:
- Deposit USD stablecoins (USDC)
- Earn yield through Aave V3 lending (with potential for other strategies)
- Maintain GBP exposure through perpetual futures positions
- Redeem shares for USD stablecoins with accrued yield

**Target APR**: 2.5% - 7.5% (GBP-denominated)

## Architecture

### Key Innovation: ATOMIC Operations

All user operations (deposits and withdrawals) happen in **single transactions**:

**Atomic Deposit Flow**:
```
User deposits USDC
    ↓ (same transaction)
80% → Deployed to Aave V3 for yield
20% → Used as collateral for GBP/USD long position (5x leverage)
    ↓
User receives GBP-denominated shares
```

**Atomic Withdrawal Flow**:
```
User redeems shares
    ↓ (same transaction)
Close proportional perp position
    ↓
Withdraw from Aave strategy
    ↓
User receives USDC (+ yield)
```

### Smart Contract Architecture

```
┌─────────────────────────────────────────┐
│         GBPYieldVault (ERC4626)          │
│  - Atomic deposit/withdraw              │
│  - GBP-denominated share pricing        │
│  - Allocation management (80/20 split)  │
└────────────┬───────────────┬─────────────┘
             │               │
   ┌─────────▼──────┐   ┌────▼────────────────┐
   │ AaveStrategy   │   │ PerpPositionManager │
   │ (Yield Gen)    │   │ (GBP Hedge)         │
   └────────┬───────┘   └────┬────────────────┘
            │                │
   ┌────────▼───────┐   ┌────▼──────────────┐
   │  Aave V3 Pool  │   │ GMX V2 / Avantis  │
   │  (on Arbitrum) │   │ (Perp DEX)        │
   └────────────────┘   └───────────────────┘

┌────────────────────────────────────────┐
│     ChainlinkOracle (GBP/USD)          │
│  - Price feeds for NAV calculation     │
└────────────────────────────────────────┘
```

### Core Components

1. **GBPYieldVault.sol** - Main vault contract (ERC4626)
   - Handles deposits and withdrawals
   - Manages allocation between yield and perp strategies
   - Calculates GBP-denominated NAV

2. **AaveStrategy.sol** - Yield generation strategy
   - Deposits USDC into Aave V3
   - Earns lending yield
   - Implements IYieldStrategy interface for modularity

3. **PerpPositionManager.sol** - Perpetual position management
   - Opens/closes GBP/USD long positions
   - Manages collateral
   - Abstracted interface supports multiple perp DEXes

4. **ChainlinkOracle.sol** - Price feed integration
   - Fetches GBP/USD price from Chainlink
   - Converts between USD and GBP values
   - Includes staleness checks

## Installation

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js v16+ (for optional frontend integration)

### Setup

```bash
# Clone the repository
cd gbp-yield-vault

# Install dependencies
forge install

# Copy environment variables
cp .env.example .env
# Edit .env with your values

# Build contracts
forge build

# Run tests
forge test
```

## Testing

The project includes comprehensive unit tests covering:
- Deposit and withdrawal flows
- Multi-user scenarios
- Price movements and P&L impact
- Pause functionality
- Admin functions
- Edge cases

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vv

# Run specific test
forge test --match-test testDeposit

# Generate gas report
forge test --gas-report

# Generate coverage report
forge coverage
```

**Current Test Results**: 21/21 tests passing ✓

## Deployment

### 1. Configure Environment

Edit `.env` file:
```bash
PRIVATE_KEY=your_private_key_here
ARBITRUM_RPC_URL=https://arb1.arbitrum.io/rpc
ARBISCAN_API_KEY=your_api_key
```

### 2. Deploy to Testnet

```bash
# Deploy to Arbitrum Sepolia
forge script script/Deploy.s.sol:DeployGBPYieldVault \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --verify

# Deploy to Base Sepolia
forge script script/Deploy.s.sol:DeployGBPYieldVault \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

### 3. Deploy to Mainnet

⚠️ **IMPORTANT**: Complete security audit before mainnet deployment!

```bash
# Deploy to Arbitrum
forge script script/Deploy.s.sol:DeployGBPYieldVault \
  --rpc-url $ARBITRUM_RPC_URL \
  --broadcast \
  --verify \
  --slow

# Deploy to Base
forge script script/Deploy.s.sol:DeployGBPYieldVault \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --verify \
  --slow
```

## Usage

### Depositing

```bash
# Set environment variables
export VAULT_ADDRESS=0x...
export DEPOSIT_AMOUNT=10000000000  # 10,000 USDC (6 decimals)

# Execute deposit
forge script script/Interact.s.sol:DepositToVault \
  --rpc-url $ARBITRUM_RPC_URL \
  --broadcast
```

### Withdrawing

```bash
# Set environment variables
export VAULT_ADDRESS=0x...
export SHARES_AMOUNT=1000000000000000000  # 1 share (18 decimals)

# Execute withdrawal
forge script script/Interact.s.sol:WithdrawFromVault \
  --rpc-url $ARBITRUM_RPC_URL \
  --broadcast
```

### Checking Status

```bash
# Check vault status
export VAULT_ADDRESS=0x...
forge script script/Interact.s.sol:CheckVaultStatus \
  --rpc-url $ARBITRUM_RPC_URL

# Check user balance
export USER_ADDRESS=0x...
forge script script/Interact.s.sol:CheckUserBalance \
  --rpc-url $ARBITRUM_RPC_URL
```

## Configuration

### Allocation Parameters

- **Yield Allocation**: 80% (8000 basis points) - deployed to Aave
- **Perp Allocation**: 20% (2000 basis points) - used as perp collateral
- **Target Leverage**: 5x - achieves 100% notional hedge with 20% collateral

### Adjusting Allocations (Owner Only)

```bash
export YIELD_ALLOCATION=7000  # 70%
export PERP_ALLOCATION=3000   # 30%

forge script script/Interact.s.sol:UpdateAllocations \
  --rpc-url $ARBITRUM_RPC_URL \
  --broadcast
```

## Economics

### Yield Sources

1. **Aave Lending**: 5-8% APR on USDC
2. **Perp Funding**: -2.5% to -4.5% APR (cost)
3. **Net APR**: ~2.5% to 5.5% in GBP terms

### Fee Structure

- **Performance Fee**: 10% on profits (configurable)
- **Management Fee**: 1-2% annually (optional)
- **Withdrawal Fee**: 0-0.5% (configurable)

### Cost Analysis (Per $100k)

**Aave Yield**: +$5,000 - $8,000/year
**Perp Costs**: -$2,500 - $4,500/year
**Net Yield**: ~$2,500 - $5,500/year

## Security

### Audits

⚠️ **NOT YET AUDITED** - This is an MVP implementation

**Recommended audit firms**:
- Code4rena (competitive audit, $5-15k)
- Sherlock
- Trail of Bits
- OpenZeppelin

### Security Features

- ✅ ReentrancyGuard on all state-changing functions
- ✅ Pausable for emergency situations
- ✅ Owner-only admin functions
- ✅ SafeERC20 for token transfers
- ✅ Chainlink oracle with staleness checks
- ✅ No bridging (single-chain architecture reduces risk)

### Risks

1. **Smart Contract Risk**: Bugs in vault or integration contracts
2. **Oracle Risk**: GBP/USD price manipulation or staleness
3. **Liquidation Risk**: Perp position liquidation if under-collateralized
4. **Funding Rate Risk**: Negative funding rates reduce yield
5. **Protocol Risk**: Aave or Perp DEX vulnerabilities
6. **Depegging Risk**: USDC depegging affects collateral value

## Roadmap

### MVP (Current - Day 1-4) ✓
- [x] Core vault implementation
- [x] Aave strategy integration
- [x] Perp position management (abstracted interface)
- [x] Chainlink oracle integration
- [x] Comprehensive unit tests
- [x] Deployment scripts
- [x] Documentation

### Phase 2A: Additional Yield Strategies (Week 2-3)
- [ ] Pendle PT integration (8-15% APY)
- [ ] Morpho optimizer
- [ ] Strategy allocation optimization

### Phase 2B: Real Perp Integrations (Week 3-4)
- [ ] GMX V2 integration
- [ ] Avantis integration
- [ ] Provider routing based on funding rates

### Phase 2C: Advanced Features (Week 4-5)
- [ ] Automated rebalancing keeper bot
- [ ] Performance fee accounting
- [ ] Withdrawal queue for large exits
- [ ] Gradual TVL ramp mechanisms

### Phase 2D: Audit & Mainnet (Week 6-12)
- [ ] Security review and hardening
- [ ] Code4rena competitive audit
- [ ] Bug bounty program
- [ ] Mainnet deployment with caps
- [ ] Gradual TVL increase

## Contributing

This is an MVP prototype. Contributions welcome for:
- Additional yield strategies
- Perp DEX integrations
- Gas optimizations
- Security improvements
- Documentation

## License

MIT

## Disclaimer

This software is provided "as is" without warranty. Use at your own risk. Not financial advice. Always DYOR and understand the risks before investing.

## Contact

For questions or support:
- GitHub Issues: [Create an issue](https://github.com/your-repo/issues)
- Documentation: See `/docs` folder (coming soon)

---

**Built with Foundry** 🔨
