# Multi-Protocol Yield Strategy Architecture

## Overview

Design for supporting multiple lending protocols (Morpho, Euler, Dolomite, Curvance) with hot-swappable strategies for optimal yield and risk management.

---

## Current Architecture

```
GBPYieldVault
    └── KPKMorphoStrategy (hardcoded)
            └── KPK Morpho Vault (ERC4626)
```

**Problem:** Locked into one protocol. If KPK Morpho:
- Reduces APY
- Has security issues
- Becomes deprecated
- Faces liquidity issues

We're stuck or need a full migration.

---

## Proposed Architecture

```
GBPYieldVault
    └── StrategyManager
            ├── MorphoStrategy (ERC4626 adapter)
            ├── EulerStrategy (ERC4626 adapter)
            ├── DolomiteStrategy (custom adapter)
            └── CurvanceStrategy (custom adapter)
```

---

## Key Considerations

### 1. Protocol Characteristics

| Protocol | Type | Interface | Risk Profile | APY Type | Arbitrum Support |
|----------|------|-----------|--------------|----------|------------------|
| **Morpho** | P2P Optimizer | ERC4626 | Medium | Variable | ✅ Yes (KPK) |
| **Euler** | Isolated Markets | ERC4626 | Medium-High | Variable | ✅ Yes (v2) |
| **Dolomite** | Margin Trading | Custom | High | Variable | ✅ Yes |
| **Curvance** | Omnichain Lending | Custom | Medium | Gauge-based | ✅ Yes |
| **Aave** | Blue Chip | Custom | Low-Medium | Variable | ✅ Yes (v3) |

### 2. Interface Standardization

**Best Practice:** Prefer ERC4626-compliant protocols for easy integration.

**Problem:** Not all protocols are ERC4626:
- Morpho: ✅ ERC4626 (new vaults)
- Euler v2: ✅ ERC4626
- Dolomite: ❌ Custom interface
- Curvance: ❌ Custom interface
- Aave v3: ❌ Custom interface

**Solution:** Create adapter pattern.

---

## Architecture Design

### Option 1: Single Active Strategy (Recommended)

**Simplest approach - one strategy at a time with migration capability.**

```
GBPYieldVault
    ├── activeStrategy (address)
    ├── pendingStrategy (address)
    ├── strategyRegistry (mapping: address => bool)
    └── Migration logic
```

**Pros:**
- Simple to implement
- Clear accounting
- Low gas costs
- Easy to understand

**Cons:**
- Downtime during migration
- No diversification
- Migration costs gas

### Option 2: Multi-Strategy with Allocation

**Multiple strategies with % allocation to each.**

```
GBPYieldVault
    ├── strategies[] (array of addresses)
    ├── allocations[] (% to each strategy)
    ├── Rebalancing logic
    └── APY comparison oracle
```

**Pros:**
- Diversification across protocols
- No single point of failure
- Can gradually shift allocations
- Optimal yield via allocation

**Cons:**
- Complex accounting
- Higher gas costs
- Rebalancing overhead
- More surface area for bugs

### Option 3: Hybrid (Recommended for Production)

**Single active strategy + emergency fallback.**

```
GBPYieldVault
    ├── primaryStrategy (90%+ of funds)
    ├── fallbackStrategy (emergency backup)
    ├── Migration with gradual shift
    └── APY monitoring
```

**Pros:**
- Best of both worlds
- Emergency resilience
- Gradual migration capability
- Lower complexity than full multi-strategy

---

## Implementation Design

### Core Interface: IYieldStrategy

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IYieldStrategy
 * @notice Standard interface for all yield strategies
 */
interface IYieldStrategy {
    /// @notice Deposit USDC into the strategy
    /// @param amount Amount of USDC to deposit
    /// @return shares Amount of strategy shares received
    function deposit(uint256 amount) external returns (uint256 shares);

    /// @notice Withdraw USDC from the strategy
    /// @param amount Amount of USDC to withdraw
    /// @return actualAmount Actual USDC withdrawn
    function withdraw(uint256 amount) external returns (uint256 actualAmount);

    /// @notice Get total assets in the strategy (in USDC)
    function totalAssets() external view returns (uint256);

    /// @notice Get current APY (in basis points, e.g., 500 = 5%)
    function currentAPY() external view returns (uint256);

    /// @notice Emergency withdraw all funds
    function emergencyWithdraw() external returns (uint256);

    /// @notice Get strategy metadata
    function getMetadata() external view returns (
        string memory name,
        string memory protocol,
        uint256 riskScore, // 1-10, 10 = highest risk
        bool isActive
    );
}
```

### StrategyManager Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IYieldStrategy.sol";

/**
 * @title StrategyManager
 * @notice Manages multiple yield strategies with hot-swap capability
 */
contract StrategyManager is Ownable {
    /// @notice Active strategy receiving deposits
    IYieldStrategy public activeStrategy;

    /// @notice Pending strategy for migration
    IYieldStrategy public pendingStrategy;

    /// @notice Whitelist of approved strategies
    mapping(address => bool) public approvedStrategies;

    /// @notice Timelock for strategy changes (24 hours)
    uint256 public constant STRATEGY_TIMELOCK = 24 hours;
    uint256 public strategyChangeTimestamp;

    /// Events
    event StrategyProposed(address indexed oldStrategy, address indexed newStrategy, uint256 executeTime);
    event StrategyActivated(address indexed oldStrategy, address indexed newStrategy);
    event StrategyApproved(address indexed strategy, bool approved);
    event StrategyMigrated(address indexed from, address indexed to, uint256 amount);

    /// Errors
    error StrategyNotApproved();
    error TimelockNotExpired();
    error NoPendingStrategy();
    error MigrationFailed();

    constructor(address _initialStrategy) Ownable(msg.sender) {
        require(_initialStrategy != address(0), "Invalid strategy");
        activeStrategy = IYieldStrategy(_initialStrategy);
        approvedStrategies[_initialStrategy] = true;
    }

    /**
     * @notice Propose a new strategy (step 1 of 2)
     * @param newStrategy Address of the new strategy
     */
    function proposeStrategy(address newStrategy) external onlyOwner {
        if (!approvedStrategies[newStrategy]) revert StrategyNotApproved();

        pendingStrategy = IYieldStrategy(newStrategy);
        strategyChangeTimestamp = block.timestamp + STRATEGY_TIMELOCK;

        emit StrategyProposed(
            address(activeStrategy),
            newStrategy,
            strategyChangeTimestamp
        );
    }

    /**
     * @notice Execute strategy change (step 2 of 2)
     * @dev Migrates all funds from old to new strategy
     */
    function executeStrategyChange() external onlyOwner {
        if (address(pendingStrategy) == address(0)) revert NoPendingStrategy();
        if (block.timestamp < strategyChangeTimestamp) revert TimelockNotExpired();

        // Withdraw from old strategy
        uint256 totalAssets = activeStrategy.totalAssets();
        uint256 withdrawn = activeStrategy.emergencyWithdraw();

        // Deposit into new strategy
        IERC20(usdc).approve(address(pendingStrategy), withdrawn);
        uint256 deposited = pendingStrategy.deposit(withdrawn);

        emit StrategyMigrated(
            address(activeStrategy),
            address(pendingStrategy),
            withdrawn
        );

        // Activate new strategy
        IYieldStrategy oldStrategy = activeStrategy;
        activeStrategy = pendingStrategy;
        pendingStrategy = IYieldStrategy(address(0));

        emit StrategyActivated(address(oldStrategy), address(activeStrategy));
    }

    /**
     * @notice Add/remove strategy from approved list
     */
    function setStrategyApproval(address strategy, bool approved) external onlyOwner {
        approvedStrategies[strategy] = approved;
        emit StrategyApproved(strategy, approved);
    }

    /**
     * @notice Get current strategy info
     */
    function getStrategyInfo() external view returns (
        string memory name,
        string memory protocol,
        uint256 totalAssets,
        uint256 currentAPY,
        uint256 riskScore
    ) {
        (name, protocol, riskScore,) = activeStrategy.getMetadata();
        totalAssets = activeStrategy.totalAssets();
        currentAPY = activeStrategy.currentAPY();
    }
}
```

### Protocol Adapters

#### 1. Morpho Strategy (ERC4626)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IYieldStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract MorphoStrategy is IYieldStrategy, Ownable {
    IERC20 public immutable usdc;
    IERC4626 public immutable morphoVault;
    address public immutable vault; // GBPYieldVault

    constructor(address _usdc, address _morphoVault, address _vault) Ownable(msg.sender) {
        usdc = IERC20(_usdc);
        morphoVault = IERC4626(_morphoVault);
        vault = _vault;
    }

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault");
        _;
    }

    function deposit(uint256 amount) external onlyVault returns (uint256 shares) {
        usdc.transferFrom(msg.sender, address(this), amount);
        usdc.approve(address(morphoVault), amount);
        shares = morphoVault.deposit(amount, address(this));
    }

    function withdraw(uint256 amount) external onlyVault returns (uint256 actualAmount) {
        uint256 shares = morphoVault.previewWithdraw(amount);
        actualAmount = morphoVault.redeem(shares, msg.sender, address(this));
    }

    function totalAssets() external view returns (uint256) {
        uint256 shares = morphoVault.balanceOf(address(this));
        return morphoVault.convertToAssets(shares);
    }

    function currentAPY() external view returns (uint256) {
        // Would need to calculate based on historical returns or oracle
        // For Morpho, could fetch from their analytics API
        return 500; // 5% placeholder
    }

    function emergencyWithdraw() external onlyOwner returns (uint256) {
        uint256 shares = morphoVault.balanceOf(address(this));
        return morphoVault.redeem(shares, vault, address(this));
    }

    function getMetadata() external pure returns (
        string memory name,
        string memory protocol,
        uint256 riskScore,
        bool isActive
    ) {
        return ("Morpho USDC Vault", "Morpho", 5, true);
    }
}
```

#### 2. Euler Strategy (ERC4626)

```solidity
contract EulerStrategy is IYieldStrategy, Ownable {
    // Very similar to Morpho since Euler v2 is also ERC4626
    // Key difference: Euler has isolated markets with different risk tiers

    IERC4626 public immutable eulerVault;
    uint256 public immutable riskTier; // Euler's risk tier (1-5)

    // Implementation similar to MorphoStrategy
    // Main difference: track which Euler vault/tier we're using
}
```

#### 3. Dolomite Strategy (Custom)

```solidity
contract DolomiteStrategy is IYieldStrategy, Ownable {
    // Dolomite uses custom interface, not ERC4626
    // Need to wrap their specific deposit/withdraw functions

    IDolomiteMargin public immutable dolomite;
    uint256 public immutable marketId; // USDC market ID

    function deposit(uint256 amount) external onlyVault returns (uint256) {
        usdc.transferFrom(msg.sender, address(this), amount);
        usdc.approve(address(dolomite), amount);

        // Dolomite-specific deposit
        IDolomiteMargin.AssetAmount memory assetAmount = IDolomiteMargin.AssetAmount({
            sign: true,
            denomination: IDolomiteMargin.AssetDenomination.Wei,
            ref: IDolomiteMargin.AssetReference.Delta,
            value: amount
        });

        dolomite.operate(/* Dolomite-specific params */);
        return amount; // Dolomite doesn't have shares, tracks balances
    }

    // Similar adaptations for withdraw, totalAssets, etc.
}
```

#### 4. Curvance Strategy (Custom)

```solidity
contract CurvanceStrategy is IYieldStrategy, Ownable {
    // Curvance uses gauge-based yield
    // Need to handle gauge staking for rewards

    ICurvancePool public immutable pool;
    ICurvanceGauge public immutable gauge;

    function deposit(uint256 amount) external onlyVault returns (uint256) {
        // 1. Deposit USDC into Curvance pool
        // 2. Stake LP tokens in gauge
        // 3. Track rewards
    }

    // Custom logic for claiming CVE rewards
    function harvestRewards() external returns (uint256) {
        // Claim CVE tokens, swap to USDC, compound
    }
}
```

---

## Integration with GBPYieldVault

### Modified Vault Contract

```solidity
contract GBPYieldVault is ERC4626, Ownable, Pausable {
    // Replace single strategy with StrategyManager
    StrategyManager public strategyManager;

    // Rest remains the same...

    function deposit(uint256 assets, address receiver)
        public
        override
        whenNotPaused
        returns (uint256 shares)
    {
        // ... existing logic ...

        // Instead of:
        // strategy.deposit(yieldAmount);

        // Use:
        IYieldStrategy activeStrategy = strategyManager.activeStrategy();
        activeStrategy.deposit(yieldAmount);

        // ... rest of logic ...
    }

    function totalAssets() public view override returns (uint256) {
        IYieldStrategy activeStrategy = strategyManager.activeStrategy();
        uint256 strategyAssets = activeStrategy.totalAssets();
        uint256 perpAssets = perpManager.getPositionValue();
        return strategyAssets + perpAssets;
    }
}
```

---

## Key Considerations

### 1. **Risk Management**

Each protocol has different risk profiles:

| Protocol | Risk Factors | Mitigation |
|----------|--------------|------------|
| **Morpho** | P2P matching risk, curator risk | Use established vaults (KPK) |
| **Euler** | Isolated market risk, oracle risk | Stick to tier 1 markets |
| **Dolomite** | Margin trading risk, liquidation | Monitor positions closely |
| **Curvance** | Gauge incentive changes | Lock periods |

**Strategy:**
- Whitelist only battle-tested protocols
- Set risk score thresholds (max 7/10)
- Regular audits of integrated protocols
- Monitor TVL and activity

### 2. **APY Comparison & Optimization**

```solidity
contract APYOracle {
    mapping(address => uint256) public strategyAPYs;

    // Update APYs from off-chain data
    function updateAPYs(
        address[] calldata strategies,
        uint256[] calldata apys
    ) external onlyOracle {
        // Update APYs with timestamp
    }

    // Get best strategy by APY
    function getBestStrategy() external view returns (address) {
        // Return strategy with highest risk-adjusted APY
    }

    // Calculate risk-adjusted APY
    function getRiskAdjustedAPY(address strategy)
        external
        view
        returns (uint256)
    {
        uint256 rawAPY = strategyAPYs[strategy];
        uint256 riskScore = IYieldStrategy(strategy).getRiskScore();

        // Penalize higher risk (simple model)
        return rawAPY * (10 - riskScore) / 10;
    }
}
```

### 3. **Migration Strategy**

**Gradual Migration (Recommended):**

```solidity
function migrateGradually(
    address fromStrategy,
    address toStrategy,
    uint256 percentageToMigrate // 2500 = 25%
) external onlyOwner {
    uint256 totalAssets = IYieldStrategy(fromStrategy).totalAssets();
    uint256 toMigrate = totalAssets * percentageToMigrate / 10000;

    // Withdraw from old
    uint256 withdrawn = IYieldStrategy(fromStrategy).withdraw(toMigrate);

    // Deposit into new
    IERC20(usdc).approve(toStrategy, withdrawn);
    IYieldStrategy(toStrategy).deposit(withdrawn);

    emit PartialMigration(fromStrategy, toStrategy, withdrawn, percentageToMigrate);
}
```

**Benefits:**
- Test new strategy with small amount first
- No downtime
- Can abort if issues arise
- Monitor performance during migration

### 4. **Gas Optimization**

**Problem:** Swapping strategies costs gas.

**Solutions:**
- Batch migrations (migrate 25% at a time)
- Only migrate when APY difference > threshold (e.g., 1%)
- Use Gelato/Chainlink Automation for optimal timing
- Consider migration costs in ROI calculation

```solidity
function shouldMigrate(
    address currentStrategy,
    address proposedStrategy
) public view returns (bool) {
    uint256 currentAPY = IYieldStrategy(currentStrategy).currentAPY();
    uint256 proposedAPY = IYieldStrategy(proposedStrategy).currentAPY();

    // Only migrate if new APY is 1% higher (100 basis points)
    return proposedAPY > currentAPY + 100;
}
```

### 5. **Emergency Procedures**

```solidity
contract EmergencyWithdrawal {
    // If strategy is compromised, quickly exit
    function emergencyExitStrategy(address strategy) external onlyGuardian {
        // Pause vault
        vault.pause();

        // Withdraw all from compromised strategy
        uint256 withdrawn = IYieldStrategy(strategy).emergencyWithdraw();

        // Hold in vault until safe strategy found
        emit EmergencyExit(strategy, withdrawn);
    }

    // Multi-sig guardian role for emergencies
    mapping(address => bool) public guardians;
}
```

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
- [ ] Create IYieldStrategy interface
- [ ] Build StrategyManager contract
- [ ] Implement MorphoStrategy adapter
- [ ] Add strategy registry
- [ ] Write comprehensive tests

### Phase 2: Multi-Protocol (Week 3-4)
- [ ] Implement EulerStrategy adapter
- [ ] Research Dolomite integration
- [ ] Research Curvance integration
- [ ] APY oracle design
- [ ] Migration testing

### Phase 3: Optimization (Week 5-6)
- [ ] Gradual migration logic
- [ ] APY comparison automation
- [ ] Gas optimization
- [ ] Emergency procedures
- [ ] Integration tests

### Phase 4: Production (Week 7-8)
- [ ] Security audit
- [ ] Mainnet fork testing
- [ ] Guardian multisig setup
- [ ] Monitoring dashboards
- [ ] Deploy to mainnet

---

## Testing Strategy

```solidity
// Test scenarios
contract StrategyManagerTest {
    function testStrategySwitching() public {
        // 1. Deploy with Morpho
        // 2. Propose Euler strategy
        // 3. Wait timelock
        // 4. Execute migration
        // 5. Verify all funds transferred
        // 6. Verify accounting correct
    }

    function testGradualMigration() public {
        // Migrate 25% at a time, verify at each step
    }

    function testEmergencyExit() public {
        // Simulate strategy failure, verify emergency withdraw
    }

    function testAPYComparison() public {
        // Mock different APYs, verify correct strategy chosen
    }
}
```

---

## Security Considerations

### Critical
1. **Timelock Requirements** - 24-48h for strategy changes
2. **Whitelist Only** - No arbitrary strategy addresses
3. **Gradual Migration** - Never migrate 100% at once
4. **Emergency Multisig** - 3-of-5 for emergency actions
5. **Strategy Audits** - Only use audited protocols

### Important
6. **Slippage Protection** - Set max slippage on migrations
7. **APY Oracle Security** - Protect APY data source
8. **Reentrancy Guards** - On all deposit/withdraw
9. **Access Control** - Separate roles (owner, guardian, operator)
10. **Circuit Breakers** - Pause if anomalies detected

---

## Cost-Benefit Analysis

### Benefits
✅ **Flexibility** - Switch to better yields
✅ **Risk Mitigation** - Exit compromised protocols
✅ **Optimization** - Always use best APY
✅ **Future-Proof** - Add new protocols easily
✅ **Competitive Edge** - Adapt faster than competitors

### Costs
❌ **Complexity** - More contracts, more code
❌ **Gas Costs** - Migrations cost gas
❌ **Audit Costs** - More code to audit
❌ **Maintenance** - Track multiple protocols
❌ **Risk** - More attack surface

### Recommendation

**Start with Option 1 (Single Strategy with Migration)**
- Simplest implementation
- Proven pattern (used by Yearn, Beefy)
- Can evolve to multi-strategy later
- Lower audit costs

**Evolve to Option 3 (Hybrid) for Production**
- Add emergency fallback strategy
- Gradual migration capability
- APY monitoring
- Best balance of flexibility and simplicity

---

## Next Steps

Would you like me to:
1. ✅ Implement the StrategyManager contract?
2. ✅ Create adapters for Euler/Dolomite/Curvance?
3. ✅ Build APY comparison oracle?
4. ✅ Set up gradual migration system?
5. ✅ Write comprehensive tests?

Let me know which direction you'd like to pursue!
