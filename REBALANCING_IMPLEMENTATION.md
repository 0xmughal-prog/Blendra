# Rebalancing Implementation Summary

## Overview
Successfully implemented rebalancing logic in GBPbMinter.sol to handle perp position losses and maintain protocol health.

## Implementation Details

### Core Functions Added

#### 1. `getHealthStatus()` - View Function
Returns comprehensive health monitoring data:
- `healthFactor`: Current health in BPS (10000 = 100%)
- `needsRebalance`: Boolean flag (true if health < 50%)
- `perpPnL`: Current PnL of perp position
- `estimatedLoss`: Estimated loss if rebalanced now
- `currentTVL`: Total value locked in protocol

**Location:** `src/tokens/GBPbMinter.sol:440-468`

#### 2. `rebalancePerp()` - Owner-Only Function
Triggers rebalancing when health drops below 50%:
- Validates health is below threshold (5000 BPS)
- Calls internal `_executeRebalance()` function
- Emits `RebalanceExecuted` event

**Location:** `src/tokens/GBPbMinter.sol:470-486`

#### 3. `_executeRebalance()` - Internal Function
Executes the full rebalancing process:
1. Closes perp position completely (realizes loss)
2. Withdraws all funds from Morpho lending
3. Calculates new TVL after loss realization
4. Reallocates with fresh 90:10 split
5. Reopens perp position with 10x leverage

**Location:** `src/tokens/GBPbMinter.sol:488-526`

#### 4. `checkRebalanceStatus()` - Public View Function
Monitoring helper that emits warning event:
- Can be called by anyone
- Emits `RebalanceRequired` event if health < 50%
- Useful for off-chain monitoring systems

**Location:** `src/tokens/GBPbMinter.sol:528-537`

### Key Parameters

```solidity
uint256 public constant REBALANCE_HEALTH_THRESHOLD_BPS = 5000; // 50%
```

Rebalancing triggers when position health drops below 50%, providing ~4-5% buffer before liquidation at ~40-45% health.

### Events Added

```solidity
event RebalanceExecuted(
    uint256 healthBefore,
    int256 perpPnL,
    uint256 oldTVL,
    uint256 newTVL,
    uint256 lossRealized
);

event RebalanceRequired(
    uint256 healthFactor,
    int256 perpPnL,
    uint256 estimatedLoss
);
```

### Errors Added

```solidity
error RebalanceNotNeeded();
error NoActivePosition();
```

## Test Coverage

### Tests Implemented (13 total - ALL PASSING ✅)

#### Health Status Tests (3)
- ✅ `test_GetHealthStatusNoPosition`: Returns 100% health with no position
- ✅ `test_GetHealthStatusHealthyPosition`: Correctly reports healthy position
- ✅ `test_GetHealthStatusUnhealthyPosition`: Detects when rebalancing needed

#### Rebalancing Execution Tests (8)
- ✅ `test_RebalancePerpRevertsWhenHealthy`: Prevents unnecessary rebalancing
- ✅ `test_RebalancePerpRevertsWithNoPosition`: Handles missing position
- ✅ `test_RebalancePerpOnlyOwner`: Enforces owner-only access
- ✅ `test_RebalancePerpSuccess`: Full rebalancing workflow
- ✅ `test_RebalancePerpRecalculates90_10Split`: Verifies correct allocation
- ✅ `test_RebalancePerpReopensWithCorrectLeverage`: Validates 10x leverage
- ✅ `test_RebalancePerpMultipleTimes`: Handles sequential rebalancing
- ✅ `test_RebalancePerpWithExactly50PercentHealth`: Tests boundary condition

#### Monitoring Tests (2)
- ✅ `test_CheckRebalanceStatusEmitsEvent`: Emits warning when needed
- ✅ `test_CheckRebalanceStatusNoEventWhenHealthy`: Silent when healthy

**Test File:** `test/unit/GBPbMinter.t.sol:618-916`

## Overall Test Results

**Full Protocol Test Suite:**
- **Total Tests:** 161
- **Passing:** 152 (94.4%)
- **Failing:** 9 (pre-existing, unrelated to rebalancing)

**Breakdown by Contract:**
- ✅ UserFlowTest: 4/4 passing (100%)
- ⚠️ GBPbMinterTest: 42/48 passing (87.5%)
  - All 13 rebalancing tests passing ✅
  - 6 pre-existing failures in other areas
- ✅ OstiumPerpProviderTest: 22/22 passing (100%)
- ⚠️ PerpPositionManagerTest: 43/46 passing (93.5%)
- ✅ sGBPbTest: 41/41 passing (100%)

## How Rebalancing Works

### Trigger Conditions
Rebalancing is needed when perp position health drops below 50% due to:
- Adverse GBP/USD price movements
- Accumulated losses from leverage exposure

### Rebalancing Process
1. **Monitor Health**: Use `getHealthStatus()` to check position health
2. **Trigger**: When health < 50%, call `rebalancePerp()` (owner only)
3. **Close Position**: Close entire perp position, realize losses
4. **Consolidate**: Withdraw all funds from lending strategy
5. **Recalculate**: Determine new TVL after loss realization
6. **Reallocate**: Split funds 90:10 (lending:perp)
7. **Reopen**: Open new perp position with 10x leverage
8. **Verify**: Confirm new position is healthy (>50% health)

### Safety Features
- **Owner-Only**: Prevents unauthorized rebalancing
- **Health Check**: Prevents unnecessary rebalancing when healthy
- **Loss Tracking**: Emits detailed events with loss amounts
- **Reentrancy Protection**: Uses nonReentrant modifier
- **Pause Support**: Respects whenNotPaused modifier

## Monitoring Recommendations

### Off-Chain Monitoring
Monitor position health using `getHealthStatus()`:
```solidity
(
    uint256 healthFactor,
    bool needsRebalance,
    int256 perpPnL,
    uint256 estimatedLoss,
    uint256 currentTVL
) = minter.getHealthStatus();
```

### Alert Thresholds
- **70% health**: Warning - monitor closely
- **60% health**: Alert - prepare for rebalancing
- **50% health**: Critical - rebalance immediately
- **40% health**: Emergency - risk of liquidation

### Event Monitoring
Listen for events:
- `RebalanceRequired`: Indicates rebalancing needed
- `RebalanceExecuted`: Confirms rebalancing completed
- `LiquidationWarning` (from PerpPositionManager): Position approaching liquidation

## Gas Costs

Approximate gas costs (from tests):
- `getHealthStatus()`: ~65k gas (view function)
- `rebalancePerp()`: ~1.2M gas (includes multiple operations)
- `checkRebalanceStatus()`: ~673k gas (with event emission)

## Next Steps

The rebalancing implementation is complete and tested. Recommended next steps:

1. **Set up monitoring**: Implement off-chain monitoring of health status
2. **Define procedures**: Create runbooks for manual rebalancing
3. **Test on testnet**: Deploy and test with real market conditions
4. **Consider automation**: Explore keeper/bot solutions for automated rebalancing
5. **Emergency procedures**: Document emergency response for rapid health deterioration

## Files Modified

- `src/tokens/GBPbMinter.sol`: Added rebalancing functions
- `test/unit/GBPbMinter.t.sol`: Added 13 comprehensive tests

## Technical Notes

- Rebalancing uses `decreasePosition(1e18)` to close 100% of perp position
- Loss realization happens when position is closed
- New position opens at current market price (zero initial PnL)
- TVL reflects realized losses after rebalancing
- 90:10 split recalculated based on post-loss TVL
