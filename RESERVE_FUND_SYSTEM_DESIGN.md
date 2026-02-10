# Reserve Fund System Design

## Overview

To offer **FREE minting** while covering 3 bps (0.03%) Ostium opening fees, we need:

1. **Reserve Fund** - Pool of USDC to cover opening fees instantly
2. **Automated Replenishment** - Harvest Morpho yield to refill reserve
3. **Real-time Tracking** - Monitor reserve health at all times
4. **Emergency Procedures** - Handle edge cases when reserve runs low

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GBPbMinter (Main)                       │
│                                                             │
│  User Mints → Needs $3 for opening → Draws from Reserve   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                   ReserveFund Contract                      │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Reserve    │  │  Yield to    │  │   Tracking   │    │
│  │   Balance    │  │  Replenish   │  │   & Stats    │    │
│  │   (USDC)     │  │              │  │              │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                             │
│  Functions:                                                 │
│  - coverOpeningFee(amount) → Pay for new position          │
│  - replenishFromYield(amount) → Refill from Morpho         │
│  - getReserveStatus() → Health metrics                     │
│  - emergencyTopUp() → Owner adds funds                     │
└─────────────────────────────────────────────────────────────┘
                     ↑
                     │
┌────────────────────┴────────────────────────────────────────┐
│               Automated Keeper (Gelato/Chainlink)           │
│                                                             │
│  1. Check reserve every 6 hours                             │
│  2. If below threshold → harvest Morpho yield              │
│  3. Transfer to reserve                                     │
│  4. Emit event for monitoring                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Component 1: ReserveFund Contract

### Core State Variables:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ReserveFund is Ownable {
    using SafeERC20 for IERC20;

    /// @notice USDC token
    IERC20 public immutable usdc;

    /// @notice The GBPbMinter contract (authorized caller)
    address public immutable minter;

    /// @notice Minimum reserve balance (e.g., $10,000)
    /// @dev Should cover ~3,333 mints at $3 each
    uint256 public minReserveBalance;

    /// @notice Target reserve balance (e.g., $50,000)
    /// @dev Optimal level to maintain
    uint256 public targetReserveBalance;

    /// @notice Total opening fees paid (lifetime)
    uint256 public totalOpeningFeesPaid;

    /// @notice Total yield harvested (lifetime)
    uint256 public totalYieldHarvested;

    /// @notice Last harvest timestamp
    uint256 public lastHarvestTime;

    /// @notice Harvest interval (e.g., 6 hours)
    uint256 public harvestInterval;

    /// @notice Emergency mode (pauses fee coverage)
    bool public emergencyMode;

    /// Events
    event OpeningFeeCovered(uint256 amount, uint256 reserveAfter);
    event YieldHarvested(uint256 amount, uint256 reserveAfter);
    event EmergencyTopUp(address indexed from, uint256 amount);
    event ReserveThresholdUpdated(uint256 minReserve, uint256 targetReserve);
    event EmergencyModeToggled(bool enabled);
    event LowReserveWarning(uint256 currentBalance, uint256 minRequired);

    /// Errors
    error OnlyMinter();
    error InsufficientReserve();
    error EmergencyModeActive();
    error HarvestTooSoon();
    error InvalidThreshold();

    modifier onlyMinter() {
        if (msg.sender != minter) revert OnlyMinter();
        _;
    }

    constructor(
        address _usdc,
        address _minter,
        address _owner
    ) Ownable(_owner) {
        usdc = IERC20(_usdc);
        minter = _minter;

        // Default thresholds
        minReserveBalance = 10_000 * 1e6;      // $10,000
        targetReserveBalance = 50_000 * 1e6;    // $50,000
        harvestInterval = 6 hours;
        lastHarvestTime = block.timestamp;
    }

    /**
     * @notice Get current reserve balance
     */
    function getReserveBalance() public view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    /**
     * @notice Check if reserve is healthy
     */
    function isReserveHealthy() public view returns (bool) {
        return getReserveBalance() >= minReserveBalance;
    }

    /**
     * @notice Get comprehensive reserve status
     */
    function getReserveStatus() external view returns (
        uint256 currentBalance,
        uint256 minBalance,
        uint256 targetBalance,
        uint256 healthPercent,
        bool isHealthy,
        uint256 totalFeesPaid,
        uint256 totalYieldCollected,
        int256 netPosition,
        bool canHarvest
    ) {
        currentBalance = getReserveBalance();
        minBalance = minReserveBalance;
        targetBalance = targetReserveBalance;
        healthPercent = (currentBalance * 100) / targetBalance;
        isHealthy = currentBalance >= minBalance;
        totalFeesPaid = totalOpeningFeesPaid;
        totalYieldCollected = totalYieldHarvested;
        netPosition = int256(totalYieldCollected) - int256(totalFeesPaid);
        canHarvest = block.timestamp >= lastHarvestTime + harvestInterval;
    }

    /**
     * @notice Cover opening fee for a new mint
     * @param amount Amount needed for opening fee
     * @dev Only callable by GBPbMinter
     */
    function coverOpeningFee(uint256 amount) external onlyMinter {
        if (emergencyMode) revert EmergencyModeActive();

        uint256 balance = getReserveBalance();

        // Check if we have enough
        if (balance < amount) {
            revert InsufficientReserve();
        }

        // Warn if getting low
        if (balance - amount < minReserveBalance) {
            emit LowReserveWarning(balance - amount, minReserveBalance);
        }

        // Transfer to minter
        usdc.safeTransfer(minter, amount);

        // Update accounting
        totalOpeningFeesPaid += amount;

        emit OpeningFeeCovered(amount, getReserveBalance());
    }

    /**
     * @notice Replenish reserve from Morpho yield
     * @param amount Amount to add to reserve
     * @dev Callable by keeper or owner
     */
    function replenishFromYield(uint256 amount) external {
        // Transfer yield from minter
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Update accounting
        totalYieldHarvested += amount;
        lastHarvestTime = block.timestamp;

        emit YieldHarvested(amount, getReserveBalance());
    }

    /**
     * @notice Check if harvest is needed and possible
     */
    function needsHarvest() public view returns (bool needed, uint256 deficit) {
        uint256 balance = getReserveBalance();

        // Need harvest if below target
        needed = balance < targetReserveBalance;

        // Calculate deficit
        if (needed) {
            deficit = targetReserveBalance - balance;
        }
    }

    /**
     * @notice Emergency top-up by owner
     * @param amount Amount to add
     */
    function emergencyTopUp(uint256 amount) external onlyOwner {
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        emit EmergencyTopUp(msg.sender, amount);
    }

    /**
     * @notice Update reserve thresholds
     */
    function setReserveThresholds(
        uint256 _minReserve,
        uint256 _targetReserve
    ) external onlyOwner {
        if (_minReserve >= _targetReserve) revert InvalidThreshold();

        minReserveBalance = _minReserve;
        targetReserveBalance = _targetReserve;

        emit ReserveThresholdUpdated(_minReserve, _targetReserve);
    }

    /**
     * @notice Toggle emergency mode
     * @param enabled Enable or disable
     */
    function setEmergencyMode(bool enabled) external onlyOwner {
        emergencyMode = enabled;
        emit EmergencyModeToggled(enabled);
    }

    /**
     * @notice Set harvest interval
     */
    function setHarvestInterval(uint256 _interval) external onlyOwner {
        harvestInterval = _interval;
    }

    /**
     * @notice Emergency withdraw (only owner, extreme cases)
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        usdc.safeTransfer(to, amount);
    }
}
```

---

## Component 2: Modified GBPbMinter Integration

### Add to GBPbMinter.sol:

```solidity
// At top of contract:
ReserveFund public reserveFund;

// In constructor or setup:
function setReserveFund(address _reserveFund) external onlyOwner {
    if (_reserveFund == address(0)) revert ZeroAddress();
    reserveFund = ReserveFund(_reserveFund);
}

// Modified mint() function:
function mint(uint256 usdcAmount) external nonReentrant whenNotPaused returns (uint256 gbpAmount) {
    if (usdcAmount == 0) revert ZeroAmount();

    // Safety checks
    _checkRateLimit();
    _checkTVLCap(usdcAmount);
    _checkCircuitBreaker();

    // Take USDC from user
    usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

    // Allocate to strategies (90/10)
    uint256 lendingAmount = (usdcAmount * LENDING_ALLOCATION_BPS) / BPS;
    uint256 perpAmount = (usdcAmount * PERP_ALLOCATION_BPS) / BPS;

    // Deposit to lending strategy
    usdc.forceApprove(address(activeStrategy), lendingAmount);
    activeStrategy.deposit(lendingAmount);

    // Calculate opening fee (3 bps on notional)
    uint256 notionalSize = perpAmount * targetLeverage;
    uint256 openingFee = (notionalSize * 3) / 10000; // 3 bps

    // Get opening fee from reserve fund
    reserveFund.coverOpeningFee(openingFee);

    // Total amount for perp = user's perpAmount + opening fee from reserve
    uint256 totalPerpAmount = perpAmount + openingFee;

    // Deposit to perp manager and open position
    usdc.forceApprove(address(perpManager), totalPerpAmount);
    perpManager.increasePosition(notionalSize, totalPerpAmount);

    // Convert USDC to GBPb amount
    gbpAmount = _convertUSDtoGBPb(usdcAmount);

    // Mint GBPb tokens to user
    gbpbToken.mint(msg.sender, gbpAmount);

    // Track mint time for min hold
    lastMintTime[msg.sender] = block.timestamp;

    emit Minted(msg.sender, usdcAmount, gbpAmount);
}
```

---

## Component 3: Automated Yield Harvester

### Option A: Keeper Function (Manual/Gelato/Chainlink)

```solidity
// Add to GBPbMinter.sol:

/**
 * @notice Harvest Morpho yield and replenish reserve
 * @dev Can be called by anyone, automated by keeper
 */
function harvestAndReplenishReserve() external nonReentrant {
    // Check if harvest is needed
    (bool needed, uint256 deficit) = reserveFund.needsHarvest();
    if (!needed) {
        return; // Nothing to do
    }

    // Calculate how much yield we can harvest
    uint256 currentYield = activeStrategy.totalAssets();
    uint256 principalInStrategy = _calculatePrincipal(); // Track separately

    if (currentYield <= principalInStrategy) {
        return; // No yield to harvest yet
    }

    uint256 availableYield = currentYield - principalInStrategy;

    // Harvest the lesser of deficit or available yield
    uint256 harvestAmount = deficit > availableYield ? availableYield : deficit;

    if (harvestAmount == 0) {
        return;
    }

    // Withdraw from Morpho
    uint256 withdrawn = activeStrategy.withdraw(harvestAmount);

    // Approve reserve fund to take it
    usdc.forceApprove(address(reserveFund), withdrawn);

    // Replenish reserve
    reserveFund.replenishFromYield(withdrawn);

    emit ReserveReplenished(withdrawn, reserveFund.getReserveBalance());
}

/**
 * @notice Calculate principal (non-yield) in Morpho
 */
function _calculatePrincipal() internal view returns (uint256) {
    // This should track actual deposits minus withdrawals
    // Implementation depends on your accounting system
    return morphoPrincipal; // State variable tracking principal
}

/**
 * @notice View function to check if harvest would be profitable
 */
function canHarvestForReserve() external view returns (
    bool canHarvest,
    uint256 harvestAmount,
    uint256 deficit
) {
    (bool needed, uint256 _deficit) = reserveFund.needsHarvest();
    deficit = _deficit;

    if (!needed) {
        return (false, 0, 0);
    }

    uint256 currentYield = activeStrategy.totalAssets();
    uint256 principalInStrategy = _calculatePrincipal();

    if (currentYield <= principalInStrategy) {
        return (false, 0, deficit);
    }

    uint256 availableYield = currentYield - principalInStrategy;
    harvestAmount = deficit > availableYield ? availableYield : deficit;
    canHarvest = harvestAmount > 0;
}
```

### Option B: Automatic on Every Redemption (Gas Efficient)

```solidity
// Add to redeem() function:

function redeem(uint256 gbpAmount) external nonReentrant whenNotPaused returns (uint256 usdcAmount) {
    // ... existing checks ...

    // Check if we should opportunistically harvest
    (bool needed, uint256 deficit) = reserveFund.needsHarvest();
    if (needed && deficit > 0) {
        _tryHarvestForReserve(deficit);
    }

    // ... rest of redeem logic ...
}

function _tryHarvestForReserve(uint256 deficit) internal {
    // Only harvest if we're withdrawing from lending anyway
    uint256 availableYield = _getAvailableYield();

    if (availableYield > 0) {
        uint256 harvestAmount = deficit > availableYield ? availableYield : deficit;

        // Already withdrawing, so include harvest in withdrawal
        // (implementation depends on your flow)
    }
}
```

---

## Component 4: Monitoring Dashboard (View Functions)

### Add comprehensive monitoring:

```solidity
/**
 * @notice Get complete protocol health metrics
 */
function getProtocolHealth() external view returns (
    uint256 totalTVL,
    uint256 totalGBPbSupply,
    uint256 reserveBalance,
    bool reserveHealthy,
    uint256 openingFeesCovered,
    uint256 yieldGenerated,
    int256 netReservePosition,
    uint256 estimatedDaysOfCoverage
) {
    // TVL
    totalTVL = totalAssets();

    // GBPb supply
    totalGBPbSupply = gbpbToken.totalSupply();

    // Reserve status
    (
        reserveBalance,
        ,
        ,
        ,
        reserveHealthy,
        openingFeesCovered,
        yieldGenerated,
        netReservePosition,
    ) = reserveFund.getReserveStatus();

    // Estimate days of coverage at current mint rate
    uint256 avgDailyMints = _getAverageDailyMints(); // Track this
    if (avgDailyMints > 0) {
        uint256 avgDailyFees = (avgDailyMints * 3) / 10000; // 3 bps
        if (avgDailyFees > 0) {
            estimatedDaysOfCoverage = reserveBalance / avgDailyFees;
        }
    }
}

/**
 * @notice Get reserve fund detailed metrics
 */
function getReserveMetrics() external view returns (
    uint256 currentBalance,
    uint256 utilizationPercent,
    uint256 coverageRatio,
    bool needsReplenishment,
    uint256 recommendedHarvest
) {
    currentBalance = reserveFund.getReserveBalance();

    uint256 targetBalance = reserveFund.targetReserveBalance();
    utilizationPercent = (currentBalance * 100) / targetBalance;

    // Coverage = how many times yield can cover fees
    uint256 totalFees = reserveFund.totalOpeningFeesPaid();
    uint256 totalYield = reserveFund.totalYieldHarvested();

    if (totalFees > 0) {
        coverageRatio = (totalYield * 100) / totalFees;
    }

    (needsReplenishment, recommendedHarvest) = reserveFund.needsHarvest();
}
```

---

## Component 5: Initial Setup & Funding

### Deployment Script:

```solidity
// Deploy script (Foundry):

function run() external {
    vm.startBroadcast();

    // 1. Deploy ReserveFund
    ReserveFund reserveFund = new ReserveFund(
        USDC_ADDRESS,
        address(minter),
        msg.sender // owner
    );

    // 2. Set thresholds
    reserveFund.setReserveThresholds(
        10_000 * 1e6,  // Min: $10,000
        50_000 * 1e6   // Target: $50,000
    );

    // 3. Initial funding from treasury
    IERC20(USDC_ADDRESS).approve(address(reserveFund), 50_000 * 1e6);
    reserveFund.emergencyTopUp(50_000 * 1e6);

    // 4. Connect to minter
    minter.setReserveFund(address(reserveFund));

    vm.stopBroadcast();
}
```

### Initial Funding Options:

| Option | Amount | Coverage | Notes |
|--------|--------|----------|-------|
| **Conservative** | $10,000 | ~3,333 mints | Minimum viable |
| **Moderate** | $50,000 | ~16,667 mints | Recommended |
| **Aggressive** | $100,000 | ~33,333 mints | Maximum safety |

**Recommendation: Start with $50,000**
- Covers 16,667 mints ($500k TVL growth)
- Refilled by yield after ~2.4 days per position
- Low risk of depletion

---

## Component 6: Monitoring & Alerts

### Events to Monitor:

```solidity
// Critical events:
event LowReserveWarning(uint256 currentBalance, uint256 minRequired);
event EmergencyModeToggled(bool enabled);
event OpeningFeeCovered(uint256 amount, uint256 reserveAfter);
event YieldHarvested(uint256 amount, uint256 reserveAfter);
event ReserveReplenished(uint256 amount, uint256 reserveAfter);
```

### Alert System (Off-chain):

```javascript
// Monitoring script (runs every 5 minutes):

async function monitorReserve() {
  const status = await reserveFund.getReserveStatus();

  // Alert levels
  if (status.currentBalance < status.minBalance) {
    sendCriticalAlert("🚨 CRITICAL: Reserve below minimum!");
    // Auto-trigger emergency top-up?
  } else if (status.currentBalance < status.targetBalance * 0.5) {
    sendWarningAlert("⚠️ WARNING: Reserve at 50% of target");
    // Trigger harvest?
  } else if (status.healthPercent < 70) {
    sendInfoAlert("ℹ️ INFO: Reserve below 70% - consider harvest");
  }

  // Check if harvest is needed
  const { canHarvest, harvestAmount } = await minter.canHarvestForReserve();
  if (canHarvest) {
    sendInfoAlert(`💰 Harvest available: ${harvestAmount} USDC`);
    // Auto-execute harvest via keeper
  }
}
```

---

## Economic Analysis

### Reserve Fund Dynamics:

```
Scenario: $10M TVL, 100% annual turnover

Mints per year:
├─ $10M new deposits
├─ Avg deposit: $1,000
└─ = 10,000 mints/year

Opening fees per year:
├─ 10,000 mints × $1,000 each
├─ Notional: $10,000 each (10x leverage)
├─ Fee: $10,000 × 0.03% = $3 per mint
└─ Total: $30,000/year

Morpho yield per year:
├─ $10M × 90% × 5% APY
└─ = $450,000/year

Coverage ratio:
├─ Yield / Fees
├─ $450,000 / $30,000
└─ = 15x ✅✅✅

Reserve depletion rate:
├─ Daily mints: 27.4 mints
├─ Daily fees: $82.20
├─ $50,000 reserve lasts: 608 days ✅

Replenishment rate:
├─ Daily yield: $1,233
├─ Harvest 10% to reserve: $123.30/day
├─ Net daily: +$41.10 ✅
```

**Conclusion: Reserve is extremely safe and self-sustaining**

---

## Emergency Procedures

### If Reserve Runs Low:

1. **Automatic (Contract Level):**
   ```solidity
   // In mint():
   if (!reserveFund.isReserveHealthy()) {
       // Option 1: Revert and require top-up
       revert InsufficientReserveFund();

       // Option 2: Switch to charging mint fee temporarily
       uint256 mintFee = openingFee;
       usdc.safeTransferFrom(msg.sender, address(this), mintFee);
   }
   ```

2. **Manual (Owner):**
   - Call `emergencyTopUp()` with funds from treasury
   - Trigger manual harvest: `harvestAndReplenishReserve()`
   - Temporarily enable emergency mode to pause free minting

3. **Keeper (Automated):**
   - Gelato/Chainlink monitors reserve
   - Auto-triggers harvest when needed
   - Alerts team if critical

---

## Summary

### Implementation Checklist:

- [ ] Deploy `ReserveFund` contract
- [ ] Initial funding ($50,000 recommended)
- [ ] Integrate with `GBPbMinter`
- [ ] Add harvest function
- [ ] Set up Gelato/Chainlink keeper
- [ ] Configure monitoring alerts
- [ ] Test emergency procedures
- [ ] Document for team

### Key Metrics to Track:

1. **Reserve Balance** (real-time)
2. **Coverage Ratio** (yield/fees)
3. **Days of Coverage** (runway)
4. **Net Position** (yield - fees)
5. **Harvest Opportunities** (available yield)

### Expected Behavior:

```
Week 1: Reserve starts at $50,000
Week 2: Reserve at $45,000 (paid $5,000 in fees)
Week 3: Harvest $10,000 yield → Reserve at $55,000
Week 4: Reserve at $50,000 (paid $5,000 fees)
...
Steady state: Reserve oscillates $45k-$55k ✅
```

This system ensures **FREE minting** remains sustainable indefinitely! 🎉
