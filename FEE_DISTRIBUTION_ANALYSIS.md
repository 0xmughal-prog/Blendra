# Fee Distribution & Revenue Splitting Analysis
**Date:** January 31, 2026
**Status:** ⚠️ NOT IMPLEMENTED - Needs Addition

---

## 🔍 Current State

### What We Have ✅
- **OstiumPerpProvider:** Builder fee (paid to Ostium, not to us)
- **Old GBPYieldVault.sol:** Had `performanceFee` and `feeRecipient` variables (not implemented in V2Secure)

### What's Missing ❌
- ❌ **NO performance fee on yield**
- ❌ **NO management fee**
- ❌ **NO fee splitter for distribution**
- ❌ **NO treasury/admin revenue**
- ❌ **NO reserve pot for insurance**
- ❌ **NO fee collection mechanism**

**Current Reality:** All yield goes to users, zero protocol revenue 💸

---

## 🏦 Industry Standard Fee Structures

### Yearn Finance (Battle-Tested)
**Sources:** [Yearn V3 Vaults](https://github.com/yearn/yearn-vaults-v3), [Yearn Docs](https://docs.yearn.finance/getting-started/products/yvaults/overview)

**Fee Structure:**
- **Performance Fee:** 10% (factory vaults) or 20% (custom vaults)
- **Management Fee:** 0-2% annually (most vaults: 0%)
- **Extracted via:** Minting new shares at harvest time

**Key Features:**
- High water mark system (fees only on new profits)
- Management fee dilutes existing shareholders
- Performance fee taken from yield at harvest

---

### Ribbon Finance
**Sources:** [Ribbon Fees](https://docs.ribbon.finance/theta-vault/theta-vault/fees), [Fee Distribution](https://docs.ribbon.finance/ribbon-dao/fee-collection-and-distribution)

**Fee Structure:**
- **Performance Fee:** 10% on premiums earned
- **Management Fee:** 2% annualized on AUM
- **Distribution:** Originally 75/25 split (LPs/Treasury) discussed

**Key Features:**
- Weekly fee collection on profitable strategies
- Fees compound for remaining vault participants
- Treasury receives portion for development

---

### Typical DeFi Vault Standards

| Fee Type | Typical Range | When Charged | Purpose |
|----------|---------------|--------------|---------|
| **Performance Fee** | 10-20% | On realized profits | Revenue from successful strategies |
| **Management Fee** | 0-2% annually | Continuous (time-based) | Operational costs |
| **Entry Fee** | 0-0.5% | On deposit | Discourage short-term deposits |
| **Exit Fee** | 0-1% | On withdrawal | Prevent gaming/flash deposits |

---

## 🛠️ Battle-Tested Solutions to Fork

### Option 1: OpenZeppelin PaymentSplitter ⭐ RECOMMENDED
**Source:** [OpenZeppelin PaymentSplitter](https://docs.openzeppelin.com/contracts/4.x/api/finance#PaymentSplitter)

**Pros:**
- ✅ Audited by OpenZeppelin (industry standard)
- ✅ Simple, gas-efficient
- ✅ Pull payment model (secure)
- ✅ Supports ETH and ERC20
- ✅ Battle-tested in production

**Cons:**
- ⚠️ Static shares (set at deployment)
- ⚠️ No automatic distribution (recipients must claim)

**Use Case:**
Perfect for splitting collected fees between:
- Treasury (e.g., 50%)
- Reserve pot (e.g., 25%)
- Operations (e.g., 15%)
- Development (e.g., 10%)

**Implementation:**
```solidity
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract GBPVaultFeeSplitter is PaymentSplitter {
    constructor(
        address[] memory payees,
        uint256[] memory shares_
    ) PaymentSplitter(payees, shares_) {
        // payees: [treasury, reserve, operations, development]
        // shares: [50, 25, 15, 10]
    }
}
```

---

### Option 2: Custom ERC4626 Fee Extension
**Source:** [ERC4626 Extensions](https://speedrunethereum.com/guides/erc-4626-vaults), [OpenZeppelin ERC4626](https://docs.openzeppelin.com/contracts/4.x/erc4626)

**Pros:**
- ✅ Native integration with vault
- ✅ Can implement performance + management fees
- ✅ High water mark support
- ✅ Flexible fee logic

**Cons:**
- ⚠️ Custom implementation (needs audit)
- ⚠️ More complex than PaymentSplitter
- ⚠️ OpenZeppelin's fee example "not production ready"

**Use Case:**
Integrated fee mechanism within the vault contract itself.

**Implementation Pattern:**
```solidity
// Override totalAssets() to deduct accrued fees
function totalAssets() public view override returns (uint256) {
    uint256 grossAssets = _calculateGrossAssets();
    uint256 accruedFees = _calculateAccruedFees();
    return grossAssets - accruedFees;
}

// Harvest function to collect fees
function harvest() external {
    uint256 profit = _calculateProfit();
    uint256 performanceFee = (profit * performanceFeeBPS) / 10000;

    // Mint shares to fee recipients
    _mintFeeShares(performanceFee);
}
```

---

### Option 3: Yearn V3 Vault Pattern
**Source:** [Yearn V3 Vaults](https://github.com/yearn/yearn-vaults-v3)

**Pros:**
- ✅ Production-tested at scale ($2B+ TVL)
- ✅ Sophisticated fee accounting
- ✅ Performance + management fees
- ✅ Vyper implementation available

**Cons:**
- ⚠️ Written in Vyper (we use Solidity)
- ⚠️ Complex codebase to adapt
- ⚠️ May be over-engineered for our needs

**Use Case:**
If we need advanced features like dynamic fee rates, multiple fee recipients, etc.

---

## 💡 Recommended Architecture for GBP Vault

### Proposed Fee Structure

**Performance Fee: 10%**
- Charged on realized profits from yield strategies
- Only when vault is above high water mark
- Collected at harvest/rebalance

**Management Fee: 1% annually**
- Charged on total assets under management
- Extracted by minting shares (dilution method)
- Accrued continuously, collected at harvest

**Reserve Allocation: 5% of fees**
- From collected fees, not from user deposits
- Creates insurance buffer for black swan events

### Fee Distribution Split

**From collected fees (after deducting from yield):**
- 50% → Treasury/Admin (operational costs, development)
- 25% → Reserve Pot (insurance, emergency fund)
- 15% → DAO/Governance (future decentralization)
- 10% → Strategic Reserve (future initiatives)

---

## 🏗️ Implementation Plan

### Phase 1: Add Fee Collection to Vault ⭐ START HERE

**1. Add Fee State Variables**
```solidity
// In GBPYieldVaultV2Secure.sol

/// @notice Performance fee in basis points (1000 = 10%)
uint256 public performanceFeeBPS = 1000; // 10%

/// @notice Management fee in basis points (100 = 1% annually)
uint256 public managementFeeBPS = 100; // 1%

/// @notice Fee collector address (will be fee splitter contract)
address public feeCollector;

/// @notice High water mark for performance fees
uint256 public highWaterMark;

/// @notice Last harvest timestamp for management fee calculation
uint256 public lastHarvestTimestamp;
```

**2. Implement Fee Calculation**
```solidity
function _calculatePerformanceFee() internal view returns (uint256) {
    uint256 currentValue = totalAssets();
    uint256 totalShares = totalSupply();

    if (totalShares == 0) return 0;

    uint256 currentPricePerShare = (currentValue * 1e18) / totalShares;

    // Only charge fee if above high water mark
    if (currentPricePerShare <= highWaterMark) return 0;

    uint256 profit = ((currentPricePerShare - highWaterMark) * totalShares) / 1e18;
    return (profit * performanceFeeBPS) / BPS;
}

function _calculateManagementFee() internal view returns (uint256) {
    uint256 timeSinceLastHarvest = block.timestamp - lastHarvestTimestamp;
    uint256 annualizedFee = (totalAssets() * managementFeeBPS) / BPS;

    // Prorate for time since last harvest
    return (annualizedFee * timeSinceLastHarvest) / 365 days;
}
```

**3. Add Harvest Function**
```solidity
function harvest() external onlyOwner returns (uint256 totalFeesCollected) {
    // Calculate fees
    uint256 performanceFee = _calculatePerformanceFee();
    uint256 managementFee = _calculateManagementFee();
    totalFeesCollected = performanceFee + managementFee;

    if (totalFeesCollected > 0) {
        // Mint shares to fee collector
        uint256 feeShares = previewDeposit(totalFeesCollected);
        _mint(feeCollector, feeShares);

        // Update high water mark
        highWaterMark = (totalAssets() * 1e18) / totalSupply();

        emit FeesCollected(performanceFee, managementFee, feeCollector);
    }

    lastHarvestTimestamp = block.timestamp;
}
```

---

### Phase 2: Deploy Fee Splitter Contract

**Use OpenZeppelin PaymentSplitter:**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GBPVaultFeeSplitter
 * @notice Splits collected fees between treasury, reserve, DAO, and strategic reserve
 * @dev Uses OpenZeppelin's audited PaymentSplitter
 */
contract GBPVaultFeeSplitter is PaymentSplitter {
    IERC20 public immutable vaultShares;

    // Fee recipients
    address public immutable treasury;
    address public immutable reservePot;
    address public immutable daoMultisig;
    address public immutable strategicReserve;

    event SharesReleased(address indexed recipient, uint256 amount);

    constructor(
        address _vaultShares,
        address _treasury,
        address _reservePot,
        address _daoMultisig,
        address _strategicReserve
    ) PaymentSplitter(
        _buildPayees(_treasury, _reservePot, _daoMultisig, _strategicReserve),
        _buildShares() // [50, 25, 15, 10]
    ) {
        vaultShares = IERC20(_vaultShares);
        treasury = _treasury;
        reservePot = _reservePot;
        daoMultisig = _daoMultisig;
        strategicReserve = _strategicReserve;
    }

    function _buildPayees(
        address _treasury,
        address _reservePot,
        address _daoMultisig,
        address _strategicReserve
    ) private pure returns (address[] memory) {
        address[] memory payees = new address[](4);
        payees[0] = _treasury;      // 50%
        payees[1] = _reservePot;    // 25%
        payees[2] = _daoMultisig;   // 15%
        payees[3] = _strategicReserve; // 10%
        return payees;
    }

    function _buildShares() private pure returns (uint256[] memory) {
        uint256[] memory shares_ = new uint256[](4);
        shares_[0] = 50; // Treasury
        shares_[1] = 25; // Reserve
        shares_[2] = 15; // DAO
        shares_[3] = 10; // Strategic
        return shares_;
    }

    /**
     * @notice Release vault shares to a specific recipient
     * @param account Address to release shares to
     */
    function releaseShares(address account) external {
        uint256 payment = releasable(vaultShares, account);
        require(payment > 0, "No shares to release");

        release(vaultShares, account);
        emit SharesReleased(account, payment);
    }

    /**
     * @notice Release vault shares to all recipients
     */
    function releaseAll() external {
        releaseShares(treasury);
        releaseShares(reservePot);
        releaseShares(daoMultisig);
        releaseShares(strategicReserve);
    }
}
```

---

### Phase 3: Integration

**1. Deploy Fee Splitter**
```solidity
// In deployment script
GBPVaultFeeSplitter feeSplitter = new GBPVaultFeeSplitter(
    address(vault),           // Vault shares token
    treasuryAddress,          // 50%
    reservePotAddress,        // 25%
    daoMultisigAddress,       // 15%
    strategicReserveAddress   // 10%
);
```

**2. Set Fee Collector in Vault**
```solidity
vault.setFeeCollector(address(feeSplitter));
```

**3. Regular Harvest**
```solidity
// Called by keeper/owner periodically (e.g., weekly)
vault.harvest();

// Recipients can claim their share anytime
feeSplitter.releaseShares(treasuryAddress);
```

---

## 📊 Fee Projections

### Example Scenario
**Assumptions:**
- TVL: $10M
- Annual Yield: 8% ($800k)
- Performance Fee: 10%
- Management Fee: 1%

**Annual Fee Revenue:**
- Performance Fee: $80k (10% of $800k yield)
- Management Fee: $100k (1% of $10M TVL)
- **Total Fees:** $180k/year

**Fee Distribution:**
- Treasury: $90k (50%)
- Reserve Pot: $45k (25%)
- DAO: $27k (15%)
- Strategic: $18k (10%)

**Insurance Reserve (5% of total revenue):**
- $9k/year accumulates in reserve pot
- After 5 years: $45k emergency fund

---

## ✅ Recommended Actions

### Immediate (This Week)
1. ✅ **Decide on fee structure** (recommend 10% performance, 1% management)
2. ✅ **Decide on distribution split** (recommend 50/25/15/10)
3. ✅ **Fork OpenZeppelin PaymentSplitter** (battle-tested, audited)

### Short Term (1-2 Weeks)
4. ⏭️ Add fee collection mechanism to vault
5. ⏭️ Deploy fee splitter contract
6. ⏭️ Write tests for fee calculation and distribution
7. ⏭️ Document fee structure for users

### Medium Term (2-4 Weeks)
8. ⏭️ Implement harvest keeper (automate fee collection)
9. ⏭️ Set up reserve pot management
10. ⏭️ External audit of fee mechanism
11. ⏭️ Deploy to testnet and test thoroughly

---

## ⚠️ Important Considerations

### Security
- **High Water Mark:** Prevents charging fees during drawdowns
- **Timelock:** Consider 24h timelock on fee changes
- **Cap Fees:** Max performance fee (e.g., 20%), max management fee (e.g., 2%)
- **Pull Payments:** OpenZeppelin PaymentSplitter uses pull model (secure)

### User Experience
- **Transparency:** Clearly document fees in UI and contracts
- **Competitive:** 10% performance + 1% management is market-standard
- **No Entry/Exit Fees:** Keeps user experience simple
- **Fee Display:** Show fees deducted in harvest events

### Governance
- **DAO Control:** Fee splitter recipients could be DAO-controlled
- **Adjustable:** Allow governance to adjust fee splits
- **Reserve Usage:** Define clear rules for using reserve pot

### Legal/Tax
- **Consult Lawyer:** Fee collection may have legal implications
- **Tax Reporting:** Recipients will need tax information
- **Entity Structure:** Consider using a legal entity for treasury

---

## 📚 Sources & References

**Industry Standards:**
- [Yearn V3 Vaults](https://github.com/yearn/yearn-vaults-v3)
- [Yearn Docs - Fee Structure](https://docs.yearn.finance/getting-started/products/yvaults/overview)
- [Ribbon Finance Fees](https://docs.ribbon.finance/theta-vault/theta-vault/fees)
- [Ribbon Fee Distribution](https://docs.ribbon.finance/ribbon-dao/fee-collection-and-distribution)

**OpenZeppelin Libraries:**
- [PaymentSplitter Documentation](https://docs.openzeppelin.com/contracts/4.x/api/finance#PaymentSplitter)
- [ERC4626 Documentation](https://docs.openzeppelin.com/contracts/4.x/erc4626)

**ERC4626 Resources:**
- [ERC4626 Vault Security](https://speedrunethereum.com/guides/erc-4626-vaults)
- [ERC4626 Standard](https://ethereum.org/developers/docs/standards/tokens/erc-4626/)

---

## 🎯 Conclusion

**Current Status:** ⚠️ Zero fee collection = zero protocol revenue

**Recommended Solution:**
1. **Add fee collection** to GBPYieldVaultV2Secure (10% performance, 1% management)
2. **Fork OpenZeppelin PaymentSplitter** for distribution (audited, battle-tested)
3. **Split fees:** 50% treasury, 25% reserve, 15% DAO, 10% strategic

**Benefits:**
- ✅ Sustainable protocol revenue ($180k/year at $10M TVL)
- ✅ Insurance reserve for emergencies
- ✅ Audited, secure implementation
- ✅ Industry-standard fee structure
- ✅ Simple, gas-efficient

**Next Step:** Decide on exact fee percentages and implement Phase 1 (vault fee collection).

---

**Status:** Proposal ready for review and implementation
**Priority:** HIGH - Essential for protocol sustainability
