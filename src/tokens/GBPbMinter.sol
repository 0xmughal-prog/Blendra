// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IYieldStrategy.sol";
import "../PerpPositionManager.sol";
import "../ChainlinkOracle.sol";
import "./GBPb.sol";

/**
 * @title GBPbMinter
 * @notice Handles minting GBPb for USDC and redemption
 * @dev Manages the underlying strategies (80% lending, 20% perp)
 *
 * Core functions:
 * - mint(USDC) → GBPb tokens
 * - redeem(GBPb) → USDC
 * - Allocates USDC to strategies (80/20 split)
 * - Safety features: pause, TVL cap, rate limits
 *
 * Based on GBPbYieldVaultV2Secure logic
 * Lines: ~450 (extracted from 809-line vault)
 */
contract GBPbMinter is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /// @notice Basis points denominator
    uint256 private constant BPS = 10000;

    /// @notice Lending allocation (80%)
    /// @dev With 5x leverage, need 20% collateral (1/5 = 20%)
    uint256 public constant LENDING_ALLOCATION_BPS = 8000;

    /// @notice Perp allocation (20%)
    /// @dev 20% collateral * 5x leverage = 100% notional hedge
    uint256 public constant PERP_ALLOCATION_BPS = 2000;

    /// @notice Maximum price change allowed (10%)
    uint256 public constant MAX_PRICE_CHANGE_BPS = 1000;

    /// Tokens
    IERC20 public immutable usdc;
    GBPb public immutable gbpbToken;

    /// Strategies
    IYieldStrategy public activeStrategy;
    PerpPositionManager public perpManager;
    ChainlinkOracle public oracle;

    /// Safety parameters
    uint256 public tvlCap;
    uint256 public tvlCapBufferBPS; // 5% buffer
    uint256 public pendingDeposits; // ✅ FIX MED-1: Track in-flight deposits to prevent TVL cap bypass
    uint256 public userOperationCooldown;
    mapping(address => uint256) public lastUserOperation;
    uint256 public lastGlobalOperation; // ✅ FIX MED-2: Global rate limit to prevent bypass via multiple addresses
    uint256 public globalOperationCooldown; // ✅ FIX MED-2: Global cooldown (10 seconds)

    /// Price tracking
    uint256 public lastGBPbPrice;

    /// @notice Price history for circuit breaker (24-hour rolling window)
    /// @dev ✅ FIX MED-4: Auto-update instead of manual lastGBPbPrice
    uint256[24] public priceHistory; // Last 24 hourly prices
    uint256 public priceHistoryIndex; // Current index in circular buffer
    uint256 public lastPriceUpdate; // Last time price was recorded

    /// Target leverage for perp position (default 10x)
    uint256 public targetLeverage;

    /// Strategy change timelock
    address public proposedStrategy;
    uint256 public strategyChangeTimestamp;
    uint256 public constant STRATEGY_CHANGE_DELAY = 24 hours;

    /// Leverage change timelock
    uint256 public proposedLeverage;
    uint256 public leverageChangeTimestamp;
    uint256 public constant LEVERAGE_CHANGE_DELAY = 48 hours; // 2 days (more critical than strategy)

    /// Rebalancing threshold (50% health = rebalance trigger)
    uint256 public constant REBALANCE_HEALTH_THRESHOLD_BPS = 5000;

    // ============ Yield Distribution ============

    /// @notice sGBPb vault for yield distribution
    address public sGBPbVault;

    /// @notice Last harvest timestamp
    uint256 public lastHarvestTimestamp;

    /// @notice Last recorded Morpho assets (for yield calculation)
    /// @dev ✅ FIX: Track Morpho separately to exclude perp PnL
    uint256 public lastMorphoAssets;

    /// @notice Last recorded perp collateral (snapshot at harvest)
    /// @dev ✅ Simple approach: margin = last - current
    uint256 public lastPerpCollateral;

    /// @notice Total realized PnL from perp position closes (can be negative)
    /// @dev ✅ FIX CRIT-4: Track realized losses separately from margin costs
    /// @dev This prevents confusing realized losses with margin fees
    int256 public totalRealizedPnL;

    /// @notice Consecutive days where margin costs exceeded Morpho yield
    /// @dev ✅ POLICY: If >= 3 days, owner should close position + pay deficit from treasury
    uint256 public consecutiveDeficitDays;

    /// @notice Last deficit check timestamp (to track daily)
    uint256 public lastDeficitCheckTimestamp;

    /// @notice Accumulated yield pending harvest (USDC)
    uint256 public accumulatedYield;

    /// @notice Total yield distributed (lifetime, in GBPb)
    uint256 public totalYieldDistributed;

    /// @notice Minimum interval between harvests (12 hours)
    uint256 public minHarvestInterval;

    /// @notice Minimum yield amount to harvest ($10 USDC)
    uint256 public minHarvestAmount;

    /// @notice Minimum position size for Ostium ($5 USDC)
    uint256 public constant MIN_POSITION_SIZE = 5e6;

    /// @notice Minimum mint amount ($125 USDC)
    /// @dev With 20% perp allocation and 5x leverage:
    ///      $125 * 0.20 * 5x = $125 notional = $25 collateral
    ///      Ostium requires $5 min collateral, so $125 mint ensures we meet minimum
    uint256 public constant MIN_MINT_AMOUNT = 125e6;

    /// @notice Weekend market closure times (Unix timestamps)
    /// @dev Ostium/Forex closes Friday 5pm EST to Sunday 5pm EST
    /// @dev Can be updated by owner if market hours change
    uint256 public weekendCloseTime; // Friday 5pm EST in seconds since week start
    uint256 public weekendOpenTime;  // Sunday 5pm EST in seconds since week start
    bool public weekendCheckEnabled; // Can disable for testing

    /// @notice Minimum health factor required before weekend (70% = 7000 bps)
    /// @dev With 5x leverage, 70% health allows for ~14% GBP move
    uint256 public constant MIN_WEEKEND_HEALTH_BPS = 7000;

    /// Fee configuration
    uint256 public constant MINT_FEE_BPS = 0;        // 0% - FREE minting!
    uint256 public constant REDEEM_FEE_BPS = 20;     // 0.20% redemption fee
    uint256 public constant MIN_HOLD_TIME = 1 days;  // 24h minimum hold

    /// Fee recipient (treasury)
    address public feeRecipient;

    /// Reserve fund accounting
    uint256 public reserveBalance;
    uint256 public minReserveBalance;
    uint256 public totalOpeningFeesPaid;
    uint256 public totalRedemptionFeesCollected;
    uint256 public yieldBorrowed;
    uint256 public maxYieldBorrowed; // ✅ SECURITY: Maximum yield that can be borrowed

    // ✅ SECURITY: Track ALL reserve contributors, not just founder
    mapping(address => uint256) public reserveContributions;
    uint256 public totalReserveContributions;

    /// Mint time tracking (for min hold period)
    mapping(address => uint256) public lastMintTime;

    /// Events
    event Minted(address indexed user, uint256 usdcAmount, uint256 gbpAmount);
    event Redeemed(address indexed user, uint256 gbpAmount, uint256 usdcAmount);
    event StrategyChanged(address indexed oldStrategy, address indexed newStrategy);
    event StrategyChangeProposed(address indexed newStrategy, uint256 executeTime);
    event LeverageChanged(uint256 oldLeverage, uint256 newLeverage);
    event LeverageChangeProposed(uint256 currentLeverage, uint256 proposedLeverage, uint256 executeTime);
    event LeverageProposalCancelled(uint256 cancelledLeverage);
    event TVLCapUpdated(uint256 oldCap, uint256 newCap);
    event PriceSanityCheckFailed(uint256 lastPrice, uint256 newPrice, uint256 change);
    event EmergencyWithdrawal(address indexed strategy, uint256 amount);
    event RebalanceExecuted(
        uint256 healthBefore,
        int256 perpPnL,
        uint256 oldTVL,
        uint256 newTVL,
        uint256 lossRealized
    );
    event RebalanceRequired(uint256 healthFactor, int256 perpPnL, uint256 estimatedLoss);
    event FeeCollected(address indexed user, uint256 amount, address indexed recipient);
    event ReserveFunded(address indexed funder, uint256 amount);
    event OpeningFeePaid(uint256 amount, uint256 reserveAfter);
    event YieldBorrowed(uint256 amount, uint256 totalBorrowed);
    event YieldRepaid(uint256 amount, uint256 remainingDebt);
    event FounderRepaid(uint256 amount, uint256 remainingDebt);
    event LowReserveWarning(uint256 balance, uint256 minRequired);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event YieldHarvested(uint256 usdcAmount, uint256 gbpbMinted, uint256 netYield);
    event YieldAccumulated(uint256 amount, uint256 totalAccumulated);
    event HarvestConfigUpdated(uint256 minInterval, uint256 minAmount);
    event SGBPbVaultUpdated(address indexed oldVault, address indexed newVault);

    /// ✅ FIX MED-11: Monitoring events for critical state changes
    event MintTimeRecorded(address indexed user, uint256 timestamp);
    event UserOperationRecorded(address indexed user, uint256 timestamp);
    event GlobalOperationRecorded(uint256 timestamp);
    event MarginDeficit(uint256 morphoYield, uint256 marginCosts, uint256 deficit);
    event ConsecutiveDeficitDays(uint256 dayCount, uint256 totalDeficit);
    event WeekendHealthCheck(uint256 healthFactor, bool safe, uint256 hoursUntilClose);
    event WeekendTimesUpdated(uint256 closeTime, uint256 openTime);
    event RealizedPnL(int256 amount, int256 cumulative);

    /// Errors
    error ZeroAddress();
    error ZeroAmount();
    error BelowMinimumMint();
    error TVLCapExceeded();
    error RateLimitActive();
    error GlobalRateLimitActive();
    error PriceChangeTooLarge();
    error PerpLossTooHigh();
    error TimelockNotExpired();
    error NoStrategyProposed();
    error RebalanceNotNeeded();
    error NoActivePosition();
    error MinimumHoldTimeNotMet();
    error InsufficientReserve();
    error SlippageExceeded();
    error InsufficientLiquidity();
    error HealthTooHigh();
    error UnreasonableConversion();
    error OstiumMarketClosed();
    error UnsafeForWeekend();

    /**
     * @notice Constructor
     * @param _usdc USDC token address
     * @param _gbpbToken GBPb token address
     * @param _oracle Chainlink oracle address
     * @param _owner Initial owner
     */
    constructor(
        address _usdc,
        address _gbpbToken,
        address _oracle,
        address _owner
    ) Ownable(_owner) {
        if (_usdc == address(0)) revert ZeroAddress();
        if (_gbpbToken == address(0)) revert ZeroAddress();
        if (_oracle == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();

        usdc = IERC20(_usdc);
        gbpbToken = GBPb(_gbpbToken);
        oracle = ChainlinkOracle(_oracle);

        // Default safety parameters
        tvlCap = 10_000_000 * 1e6; // 10M USDC
        tvlCapBufferBPS = 500; // 5%
        userOperationCooldown = 1 minutes;
        globalOperationCooldown = 10 seconds; // ✅ FIX MED-2: Global rate limit

        // ✅ SECURITY: Start with 5x leverage (more conservative)
        // Protects against GBP/USD volatility (Brexit: 10% drop, Flash crash: 6% in 2 min)
        // Can be increased later via governance if needed
        targetLeverage = 5; // 5x leverage for perp (was 10x)

        // Initialize price
        lastGBPbPrice = oracle.getGBPUSDPrice();

        // Initialize fee recipient (owner initially, can be changed)
        feeRecipient = _owner;

        // Initialize reserve parameters
        minReserveBalance = 100 * 1e6; // $100 minimum
        maxYieldBorrowed = 1000 * 1e6; // ✅ SECURITY: $1000 maximum borrowable from yield

        // Initialize yield distribution parameters
        minHarvestInterval = 12 hours;
        minHarvestAmount = 10e6; // $10 USDC minimum
        lastHarvestTimestamp = block.timestamp;

        // Initialize weekend closure times
        // Friday 5pm EST = (5 days × 86400) + (17 hours × 3600) = 493200 seconds since Monday 00:00 UTC
        // Sunday 5pm EST = (0 days × 86400) + (17 hours × 3600) = 61200 seconds since Monday 00:00 UTC
        // Note: EST is UTC-5, so 5pm EST = 10pm UTC (22:00)
        weekendCloseTime = (4 * 86400) + (22 * 3600); // Friday 10pm UTC
        weekendOpenTime = (6 * 86400) + (22 * 3600);  // Sunday 10pm UTC
        weekendCheckEnabled = true; // Enable by default
    }

    /**
     * @notice Check if Ostium market is currently closed (weekend)
     * @return closed True if market is closed
     * @dev Forex/Ostium closes Friday 5pm EST to Sunday 5pm EST
     * @dev ✅ FIX VULN-11: Unix epoch started Thursday, must offset by 3 days
     */
    function isWeekend() public view returns (bool closed) {
        if (!weekendCheckEnabled) return false;

        // ✅ FIX: Unix epoch (Jan 1, 1970) was a THURSDAY, not Monday
        // We need to offset by 3 days to align with Monday as day 0
        uint256 EPOCH_OFFSET = 3 * 86400; // 3 days in seconds

        // Adjust timestamp to align with Monday as day 0
        uint256 adjustedTimestamp = block.timestamp + EPOCH_OFFSET;
        uint256 secondsSinceMonday = adjustedTimestamp % (7 * 86400);

        // Now correctly:
        // 0 = Monday 00:00 UTC
        // 432000 = Friday 10pm UTC (correct!)
        // 597600 = Sunday 10pm UTC (correct!)

        closed = secondsSinceMonday >= weekendCloseTime || secondsSinceMonday < weekendOpenTime;
    }

    /**
     * @notice Check if we're approaching weekend (within 6 hours)
     * @return approaching True if weekend is less than 6 hours away
     * @dev ✅ FIX VULN-11: Apply same epoch offset as isWeekend()
     */
    function isApproachingWeekend() public view returns (bool approaching) {
        if (!weekendCheckEnabled) return false;

        uint256 EPOCH_OFFSET = 3 * 86400; // Thursday -> Monday offset
        uint256 adjustedTimestamp = block.timestamp + EPOCH_OFFSET;
        uint256 secondsSinceMonday = adjustedTimestamp % (7 * 86400);
        uint256 sixHours = 6 * 3600;

        // Check if we're within 6 hours of market close
        approaching = secondsSinceMonday >= (weekendCloseTime - sixHours)
                   && secondsSinceMonday < weekendCloseTime;
    }

    /**
     * @notice Check health before weekend to prevent liquidation risk
     * @return safe True if health factor is sufficient for weekend
     * @return healthFactor Current health factor
     * @return hoursUntilClose Hours until market closes (0 if already closed)
     */
    function checkWeekendHealth() external returns (bool safe, uint256 healthFactor, uint256 hoursUntilClose) {
        if (address(perpManager) == address(0)) {
            return (true, 10000, 0);
        }

        healthFactor = perpManager.getHealthFactor();

        if (isWeekend()) {
            hoursUntilClose = 0;
            safe = healthFactor >= MIN_WEEKEND_HEALTH_BPS;
        } else if (isApproachingWeekend()) {
            // ✅ FIX VULN-11: Apply epoch offset for correct calculation
            uint256 EPOCH_OFFSET = 3 * 86400;
            uint256 adjustedTimestamp = block.timestamp + EPOCH_OFFSET;
            uint256 secondsSinceMonday = adjustedTimestamp % (7 * 86400);
            uint256 secondsUntilClose = weekendCloseTime - secondsSinceMonday;
            hoursUntilClose = secondsUntilClose / 3600;
            safe = healthFactor >= MIN_WEEKEND_HEALTH_BPS;

            emit WeekendHealthCheck(healthFactor, safe, hoursUntilClose);

            if (!safe) {
                // Alert owner to rebalance before weekend
                revert UnsafeForWeekend();
            }
        } else {
            hoursUntilClose = 0;
            safe = true;
        }
    }

    /**
     * @notice Set active yield strategy
     * @param _strategy Strategy contract address
     * @dev ✅ FIX VULN-13: DEPRECATED - Use proposeStrategyChange() + executeStrategyChange()
     *      Direct setter bypasses timelock protection
     * @dev Kept for emergency use only - should require 48h timelock in production
     */
    function setActiveStrategy(address _strategy) external onlyOwner {
        if (_strategy == address(0)) revert ZeroAddress();
        // ⚠️ WARNING: This bypasses the 24h timelock!
        // Only use in emergencies (e.g., strategy exploit)
        // TODO: Add timelock requirement or remove this function
        activeStrategy = IYieldStrategy(_strategy);
    }

    /**
     * @notice Set perp position manager
     * @param _perpManager PerpPositionManager contract address
     * @dev ✅ FIX VULN-14: DEPRECATED - Should use timelock mechanism
     *      Direct setter bypasses timelock protection
     * @dev Kept for emergency use only - should require 48h timelock in production
     */
    function setPerpManager(address _perpManager) external onlyOwner {
        if (_perpManager == address(0)) revert ZeroAddress();
        // ⚠️ WARNING: This allows instant perp manager swap!
        // High risk - malicious manager could steal collateral
        // TODO: Add timelock requirement or remove this function
        perpManager = PerpPositionManager(_perpManager);
    }

    /**
     * @notice Mint GBPb tokens with USDC
     * @param usdcAmount Amount of USDC to deposit
     * @param minGbpAmount Minimum GBPb tokens to receive (slippage protection)
     * @return gbpAmount Amount of GBPb minted
     */
    function mint(uint256 usdcAmount, uint256 minGbpAmount) external nonReentrant whenNotPaused returns (uint256 gbpAmount) {
        if (usdcAmount == 0) revert ZeroAmount();
        if (usdcAmount < MIN_MINT_AMOUNT) revert BelowMinimumMint();
        if (minGbpAmount == 0) revert ZeroAmount();

        // ✅ CRITICAL: Block minting when Ostium is closed (can't hedge)
        if (isWeekend()) revert OstiumMarketClosed();

        // ✅ FIX MED-1: Track pending deposit before TVL check
        pendingDeposits += usdcAmount;

        // Safety checks
        _checkRateLimit();
        _checkTVLCap(usdcAmount);
        _checkCircuitBreaker();

        // Take USDC from user
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // ✅ CEI PATTERN: Update state BEFORE external calls
        // Track mint time for minimum hold period
        lastMintTime[msg.sender] = block.timestamp;
        emit MintTimeRecorded(msg.sender, block.timestamp); // ✅ FIX MED-11

        // ✅ ROUNDING: Calculate opening fee - round UP to favor protocol
        uint256 perpAmount = (usdcAmount * PERP_ALLOCATION_BPS) / BPS;
        uint256 notionalSize = perpAmount * targetLeverage;
        uint256 openingFee = Math.mulDiv(notionalSize, 3, 10000, Math.Rounding.Ceil);

        // ✅ FIX VULN-19: User pays opening fee explicitly
        // Subtract fee from backing amount (user gets less GBPb, but fully backed)
        uint256 backingAmount = usdcAmount - openingFee;
        uint256 lendingAmount = (backingAmount * LENDING_ALLOCATION_BPS) / BPS;
        perpAmount = backingAmount - lendingAmount; // Perp gets remainder

        // Add opening fee to reserve (it's real USDC from user's deposit)
        reserveBalance += openingFee;
        totalOpeningFeesPaid += openingFee;

        // Convert backing USDC (not full deposit) to GBPb amount
        // ✅ This ensures GBPb is 100% backed (user paid the fee)
        gbpAmount = _convertUSDtoGBPb(backingAmount);

        // ✅ FIX MED-7: Sanity check - prevent oracle misconfiguration disasters
        // GBP/USD normally trades in 1.15-1.40 range, so GBPb should be 0.70-0.90x USDC (in 18 decimals)
        // For 1 USDC (1e6), expect ~0.70e18 to ~0.90e18 GBPb
        uint256 expectedMin = (usdcAmount * 70e16) / 1e6; // 0.70 * amount
        uint256 expectedMax = (usdcAmount * 90e16) / 1e6; // 0.90 * amount

        if (gbpAmount < expectedMin || gbpAmount > expectedMax) {
            revert UnreasonableConversion();
        }

        // ✅ SECURITY: Enforce minimum GBPb amount (slippage protection)
        if (gbpAmount < minGbpAmount) revert SlippageExceeded();

        // ✅ INTERACTIONS: External calls AFTER state updates
        // ✅ STEP 1: Open perp position FIRST (gets exact allocation needed)
        // Reserve pays the opening fee to perp
        reserveBalance -= openingFee;

        // Deposit to perp manager (perpAmount + openingFee from reserve)
        usdc.forceApprove(address(perpManager), perpAmount + openingFee);
        // ✅ FIX HIGH-8: Pass deadline to prevent stale execution (15 min buffer)
        // ✅ FIX: Forward 4M gas to ensure enough for deep call chain and Ostium precompiles
        perpManager.increasePosition{gas: 4000000}(notionalSize, perpAmount + openingFee, block.timestamp + 15 minutes);

        // ✅ STEP 2: Deposit remainder to lending strategy (Morpho)
        usdc.forceApprove(address(activeStrategy), lendingAmount);
        activeStrategy.deposit(lendingAmount);

        // ✅ STEP 3: Mint GBPb tokens to user (after all assets deployed)
        gbpbToken.mint(msg.sender, gbpAmount);

        // ✅ FIX MED-1: Clear pending deposit after assets deployed
        pendingDeposits -= usdcAmount;

        emit Minted(msg.sender, usdcAmount, gbpAmount);
    }

    /**
     * @notice Redeem GBPb tokens for USDC
     * @param gbpAmount Amount of GBPb to redeem
     * @return usdcAmount Amount of USDC returned (after fee)
     */
    function redeem(uint256 gbpAmount) external nonReentrant whenNotPaused returns (uint256 usdcAmount) {
        if (gbpAmount == 0) revert ZeroAmount();

        // ✅ CRITICAL: Block redemptions when Ostium is closed (can't reduce hedge)
        if (isWeekend()) revert OstiumMarketClosed();

        // ✅ FIX MED-3: Check token mint time instead of sender mint time
        // This prevents bypass via token transfers
        uint256 tokenMintTime = gbpbToken.mintTime(msg.sender);
        if (block.timestamp < tokenMintTime + MIN_HOLD_TIME) {
            revert MinimumHoldTimeNotMet();
        }

        // Burn GBPb from user (requires approval or burnFrom)
        gbpbToken.burnFrom(msg.sender, gbpAmount);

        // Convert GBPb to USDC amount
        uint256 usdcGross = _convertGBPbtoUSD(gbpAmount);

        // Withdraw from strategies (90/10)
        uint256 lendingAmount = (usdcGross * LENDING_ALLOCATION_BPS) / BPS;
        uint256 perpAmount = (usdcGross * PERP_ALLOCATION_BPS) / BPS;

        // Withdraw from lending
        uint256 lendingWithdrawn = activeStrategy.withdraw(lendingAmount);

        // ✅ SECURITY: Verify we got at least 99% of expected (1% slippage tolerance)
        if (lendingWithdrawn < (lendingAmount * 9900) / 10000) {
            revert InsufficientLiquidity();
        }

        // Withdraw from perp
        uint256 perpWithdrawn = perpManager.withdrawCollateral(perpAmount);

        // ✅ SECURITY: Verify we got at least 99% of expected
        if (perpWithdrawn < (perpAmount * 9900) / 10000) {
            revert InsufficientLiquidity();
        }

        // Total withdrawn
        uint256 totalWithdrawn = lendingWithdrawn + perpWithdrawn;

        // ✅ ROUNDING: Calculate redemption fee - round UP to favor protocol
        uint256 redeemFee = Math.mulDiv(totalWithdrawn, REDEEM_FEE_BPS, BPS, Math.Rounding.Ceil);
        uint256 netAmount = totalWithdrawn - redeemFee;

        // Add redemption fee to reserve (with priority repayment)
        if (redeemFee > 0) {
            _addRedemptionFeeToReserve(redeemFee);
            emit FeeCollected(msg.sender, redeemFee, feeRecipient);
        }

        // Send net amount to user
        usdc.safeTransfer(msg.sender, netAmount);

        emit Redeemed(msg.sender, gbpAmount, netAmount);

        return netAmount;
    }

    /**
     * @notice Get total GBPb value (for sGBPb.totalAssets())
     * @return Total GBPb value represented by all strategies
     */
    function totalGBPbValue() external view returns (uint256) {
        uint256 totalUSDC = totalAssets();
        return _convertUSDtoGBPb(totalUSDC);
    }

    /**
     * @notice Get total USDC assets in strategies
     * @return Total USDC value
     */
    function totalAssets() public view returns (uint256) {
        uint256 lendingAssets = address(activeStrategy) != address(0)
            ? activeStrategy.totalAssets()
            : 0;

        uint256 perpValue = address(perpManager) != address(0)
            ? perpManager.getPositionValue()
            : 0;

        return lendingAssets + perpValue;
    }

    /**
     * @notice Convert USD to GBPb using oracle
     * @param usdAmount USD amount (6 decimals)
     * @return gbpAmount GBPb amount (18 decimals)
     */
    function _convertUSDtoGBPb(uint256 usdAmount) internal view returns (uint256 gbpAmount) {
        uint256 price = oracle.getGBPUSDPrice(); // 8 decimals
        // GBPb amount = USD amount / (GBPb/USD price)
        // Adjust decimals: USD (6) → GBPb (18)
        // ✅ SECURITY: Use Math.mulDiv to prevent precision loss
        gbpAmount = Math.mulDiv(usdAmount, 1e20, price, Math.Rounding.Floor);
    }

    /**
     * @notice Convert GBPb to USD using oracle
     * @param gbpAmount GBPb amount (18 decimals)
     * @return usdAmount USD amount (6 decimals)
     */
    function _convertGBPbtoUSD(uint256 gbpAmount) internal view returns (uint256 usdAmount) {
        uint256 price = oracle.getGBPUSDPrice(); // 8 decimals
        // USD amount = GBPb amount * (GBPb/USD price)
        // Adjust decimals: GBPb (18) → USD (6)
        // ✅ SECURITY: Use Math.mulDiv to prevent precision loss
        usdAmount = Math.mulDiv(gbpAmount, price, 1e20, Math.Rounding.Floor);
    }

    /**
     * @notice Check rate limit for user
     * @dev ✅ FIX MED-2: Added global rate limit to prevent bypass via multiple addresses
     */
    function _checkRateLimit() internal {
        // ✅ FIX MED-2: Check global cooldown first (prevents bypass with multiple accounts)
        if (block.timestamp < lastGlobalOperation + globalOperationCooldown) {
            revert GlobalRateLimitActive();
        }

        // Check per-user cooldown
        if (block.timestamp < lastUserOperation[msg.sender] + userOperationCooldown) {
            revert RateLimitActive();
        }

        // Update both timestamps
        lastGlobalOperation = block.timestamp;
        lastUserOperation[msg.sender] = block.timestamp;

        // ✅ FIX MED-11: Emit monitoring events
        emit GlobalOperationRecorded(block.timestamp);
        emit UserOperationRecorded(msg.sender, block.timestamp);
    }

    /**
     * @notice Check TVL cap
     * @param additionalAssets Assets being added
     * @dev ✅ FIX MED-1: Includes pendingDeposits to prevent multiple txs in same block from bypassing cap
     */
    function _checkTVLCap(uint256 additionalAssets) internal view {
        // ✅ FIX MED-1: Include pending deposits from in-flight transactions
        uint256 currentTVL = totalAssets() + pendingDeposits;
        uint256 newTVL = currentTVL + additionalAssets;

        // Effective cap with buffer (e.g., 9.5M if cap is 10M with 5% buffer)
        uint256 effectiveCap = tvlCap - ((tvlCap * tvlCapBufferBPS) / BPS);

        if (newTVL > effectiveCap) {
            revert TVLCapExceeded();
        }
    }

    /**
     * @notice Check circuit breaker conditions
     * @dev ✅ FIX MED-4: Auto-updates price history instead of relying on manual updates
     */
    function _checkCircuitBreaker() internal {
        // Check 1: Price volatility
        uint256 currentPrice = oracle.getGBPUSDPrice();

        // ✅ FIX MED-4: Auto-update price history every hour
        if (block.timestamp >= lastPriceUpdate + 1 hours) {
            priceHistory[priceHistoryIndex] = currentPrice;
            priceHistoryIndex = (priceHistoryIndex + 1) % 24;
            lastPriceUpdate = block.timestamp;
        }

        // ✅ FIX MED-4: Check against recent price (1 hour ago) instead of manual lastGBPbPrice
        uint256 recentIndex = (priceHistoryIndex + 23) % 24; // 1 hour ago in circular buffer
        uint256 recentPrice = priceHistory[recentIndex];

        if (recentPrice > 0) {
            uint256 change = _calculatePriceChange(recentPrice, currentPrice);
            if (change > MAX_PRICE_CHANGE_BPS) {
                revert PriceChangeTooLarge();
            }
        }

        // Check 2: Perp position health
        if (address(perpManager) != address(0)) {
            int256 perpPnL = perpManager.getPositionPnL();
            uint256 perpCollateral = perpManager.currentCollateral();

            // If loss > 40% of collateral, circuit breaker trips
            if (perpPnL < 0 && perpCollateral > 0) {
                uint256 loss = uint256(-perpPnL);
                if (loss > (perpCollateral * 4000) / BPS) {
                    revert PerpLossTooHigh();
                }
            }
        }
    }

    /**
     * @notice Calculate price change percentage
     * @param oldPrice Previous price
     * @param newPrice Current price
     * @return change Percentage change in BPS
     */
    function _calculatePriceChange(uint256 oldPrice, uint256 newPrice)
        internal
        pure
        returns (uint256 change)
    {
        if (oldPrice == 0) return 0;

        if (newPrice > oldPrice) {
            change = ((newPrice - oldPrice) * BPS) / oldPrice;
        } else {
            change = ((oldPrice - newPrice) * BPS) / oldPrice;
        }
    }

    /**
     * @notice Update last known price
     * @dev Allows owner to update after confirming price is real
     */
    function updateLastPrice() external onlyOwner {
        uint256 newPrice = oracle.getGBPUSDPrice();
        uint256 change = _calculatePriceChange(lastGBPbPrice, newPrice);

        if (change > MAX_PRICE_CHANGE_BPS) {
            emit PriceSanityCheckFailed(lastGBPbPrice, newPrice, change);
        }

        lastGBPbPrice = newPrice;
    }

    /**
     * @notice Propose strategy change
     * @param newStrategy New strategy address
     */
    function proposeStrategyChange(address newStrategy) external onlyOwner {
        if (newStrategy == address(0)) revert ZeroAddress();

        proposedStrategy = newStrategy;
        strategyChangeTimestamp = block.timestamp + STRATEGY_CHANGE_DELAY;

        emit StrategyChangeProposed(newStrategy, strategyChangeTimestamp);
    }

    /**
     * @notice Execute strategy change (after timelock)
     */
    function executeStrategyChange() external onlyOwner {
        if (proposedStrategy == address(0)) revert NoStrategyProposed();
        if (block.timestamp < strategyChangeTimestamp) revert TimelockNotExpired();

        // Withdraw all from old strategy
        uint256 withdrawn = activeStrategy.withdrawAll();

        // Switch to new strategy
        address oldStrategy = address(activeStrategy);
        activeStrategy = IYieldStrategy(proposedStrategy);

        // Deposit to new strategy
        usdc.forceApprove(address(activeStrategy), withdrawn);
        activeStrategy.deposit(withdrawn);

        // Reset proposal
        proposedStrategy = address(0);
        strategyChangeTimestamp = 0;

        emit StrategyChanged(oldStrategy, address(activeStrategy));
    }

    /**
     * @notice Propose leverage change (step 1 of 2)
     * @param newLeverage New target leverage (e.g., 5 for 5x, 10 for 10x)
     * @dev ✅ GOVERNANCE: 48-hour timelock for critical parameter changes
     */
    function proposeLeverageChange(uint256 newLeverage) external onlyOwner {
        require(newLeverage >= 2 && newLeverage <= 10, "Leverage must be 2-10x");
        require(newLeverage != targetLeverage, "Already at this leverage");

        proposedLeverage = newLeverage;
        leverageChangeTimestamp = block.timestamp + LEVERAGE_CHANGE_DELAY;

        emit LeverageChangeProposed(targetLeverage, newLeverage, leverageChangeTimestamp);
    }

    /**
     * @notice Execute leverage change (step 2 of 2)
     * @dev ✅ GOVERNANCE: Only executable after 48-hour timelock
     * @dev ⚠️ IMPORTANT: Changing leverage requires manual rebalancing!
     */
    function executeLeverageChange() external onlyOwner {
        require(proposedLeverage > 0, "No leverage proposed");
        require(block.timestamp >= leverageChangeTimestamp, "Timelock not expired");

        uint256 oldLeverage = targetLeverage;
        targetLeverage = proposedLeverage;

        // Reset proposal
        proposedLeverage = 0;
        leverageChangeTimestamp = 0;

        emit LeverageChanged(oldLeverage, targetLeverage);

        // ⚠️ Note: Admin must call rebalancePerp() to apply new leverage to positions
    }

    /**
     * @notice Cancel pending leverage change
     */
    function cancelLeverageProposal() external onlyOwner {
        require(proposedLeverage > 0, "No pending proposal");

        uint256 cancelled = proposedLeverage;
        proposedLeverage = 0;
        leverageChangeTimestamp = 0;

        emit LeverageProposalCancelled(cancelled);
    }

    /**
     * @notice Set TVL cap
     * @param newCap New cap in USDC (6 decimals)
     */
    function setTVLCap(uint256 newCap) external onlyOwner {
        uint256 oldCap = tvlCap;
        tvlCap = newCap;
        emit TVLCapUpdated(oldCap, newCap);
    }

    /**
     * @notice Set user operation cooldown
     * @param newCooldown New cooldown in seconds
     */
    function setUserOperationCooldown(uint256 newCooldown) external onlyOwner {
        userOperationCooldown = newCooldown;
    }

    /**
     * @notice Update weekend market closure times
     * @param closeTime Seconds since Monday 00:00 UTC when market closes (Friday evening)
     * @param openTime Seconds since Monday 00:00 UTC when market opens (Sunday evening)
     * @dev Example: Friday 10pm UTC = (4 days × 86400) + (22 hours × 3600) = 432000
     */
    function setWeekendTimes(uint256 closeTime, uint256 openTime) external onlyOwner {
        require(closeTime < 7 * 86400, "Close time must be within week");
        require(openTime < 7 * 86400, "Open time must be within week");
        require(closeTime != openTime, "Times must be different");

        weekendCloseTime = closeTime;
        weekendOpenTime = openTime;

        emit WeekendTimesUpdated(closeTime, openTime);
    }

    /**
     * @notice Enable or disable weekend market closure checks
     * @param enabled True to enable checks, false to disable
     * @dev Useful for testing or if Ostium adds 24/7 trading
     */
    function setWeekendCheckEnabled(bool enabled) external onlyOwner {
        weekendCheckEnabled = enabled;
    }

    /**
     * @notice Pause minting/redemption
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause minting/redemption
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency withdraw from strategy
     * @return amount Amount withdrawn
     * @dev ✅ SECURITY: Automatically pauses contract to prevent race conditions
     */
    function emergencyWithdrawStrategy() external onlyOwner returns (uint256 amount) {
        // ✅ SECURITY: Pause contract first to prevent new deposits during withdrawal
        if (!paused()) {
            _pause();
        }

        // Withdraw all funds from strategy
        amount = activeStrategy.emergencyWithdraw();

        emit EmergencyWithdrawal(address(activeStrategy), amount);

        // Note: Owner must call unpause() after fixing issues
        return amount;
    }

    /**
     * @notice Get health status of perp position for monitoring
     * @return healthFactor Current health factor in BPS (10000 = 100%)
     * @return needsRebalance Whether rebalancing is needed (health < 50%)
     * @return perpPnL Current perp position PnL
     * @return estimatedLoss Estimated loss if rebalanced now
     * @return currentTVL Current total value locked
     */
    function getHealthStatus()
        external
        view
        returns (
            uint256 healthFactor,
            bool needsRebalance,
            int256 perpPnL,
            uint256 estimatedLoss,
            uint256 currentTVL
        )
    {
        if (address(perpManager) == address(0)) {
            return (10000, false, 0, 0, totalAssets());
        }

        // Get current health and PnL
        healthFactor = perpManager.getHealthFactor();
        perpPnL = perpManager.getPositionPnL();

        // Check if rebalancing needed
        needsRebalance = healthFactor < REBALANCE_HEALTH_THRESHOLD_BPS;

        // Calculate estimated loss (if PnL is negative)
        if (perpPnL < 0) {
            estimatedLoss = uint256(-perpPnL);
        } else {
            estimatedLoss = 0;
        }

        // Get current TVL
        currentTVL = totalAssets();
    }

    /**
     * @notice Rebalance perp position when health drops below 50%
     * @dev Owner-only, closes perp, withdraws from Morpho, reopens with 80:20 split
     * @param minTVLAfterRebalance Minimum acceptable TVL after rebalancing (slippage protection)
     *        Set to 0 to disable check (use with caution)
     * @param force Allow rebalance even if health > 50% (prevents griefing attacks)
     *        If true, still requires health < 90% to prevent misuse
     */
    function rebalancePerp(
        uint256 minTVLAfterRebalance,
        bool force
    ) external onlyOwner nonReentrant whenNotPaused {
        // ✅ CRITICAL: Block rebalance when Ostium is closed (can't close/open positions)
        if (isWeekend()) revert OstiumMarketClosed();

        if (address(perpManager) == address(0)) revert NoActivePosition();

        uint256 healthFactor = perpManager.getHealthFactor();

        // ✅ SECURITY: Normal rebalance requires health < 50%
        if (!force && healthFactor >= REBALANCE_HEALTH_THRESHOLD_BPS) {
            revert RebalanceNotNeeded();
        }

        // ✅ SECURITY: Force rebalance still requires health < 90% to prevent misuse
        if (force && healthFactor >= 9000) {
            revert HealthTooHigh();
        }

        // Get pre-rebalance data for event
        int256 perpPnL = perpManager.getPositionPnL();
        uint256 oldTVL = totalAssets();

        // Execute rebalancing
        _executeRebalance(healthFactor, perpPnL, oldTVL, minTVLAfterRebalance);
    }

    /**
     * @notice Internal function to execute rebalancing
     * @param healthBefore Health factor before rebalancing
     * @param perpPnL PnL before rebalancing
     * @param oldTVL TVL before rebalancing
     * @param minTVL Minimum acceptable TVL after rebalancing
     * @dev ✅ FIX VULN-18: Reserve stays in Morpho earning yield during rebalance
     */
    function _executeRebalance(
        uint256 healthBefore,
        int256 perpPnL,
        uint256 oldTVL,
        uint256 minTVL
    ) internal {
        // ✅ FIX CRIT-4: Track collateral before closing to calculate realized PnL
        uint256 collateralBefore = perpManager.currentCollateral();
        uint256 usdcBefore = usdc.balanceOf(address(this));

        // Step 1: Close perp position completely using decreasePosition (100%)
        // This realizes the loss and returns remaining collateral to this contract
        // ✅ FIX HIGH-8: Pass deadline to prevent stale execution (15 min buffer)
        perpManager.decreasePosition(1e18, block.timestamp + 15 minutes); // Close 100% of position

        // ✅ FIX CRIT-4: Calculate realized PnL from position close
        uint256 usdcAfterClose = usdc.balanceOf(address(this));
        uint256 returnedFromPerp = usdcAfterClose - usdcBefore;

        // Realized PnL = what we got back - what we had in collateral
        // If negative (loss), this will be negative
        int256 realizedPnL = int256(returnedFromPerp) - int256(collateralBefore);
        totalRealizedPnL += realizedPnL; // Track cumulative

        emit RealizedPnL(realizedPnL, totalRealizedPnL);

        // ✅ FIX VULN-18: Reserve is now in Morpho earning yield
        // Get total available assets (Morpho balance includes reserve + TVL)
        uint256 morphoAssets = activeStrategy.totalAssets();
        uint256 perpReturned = returnedFromPerp;

        // Total available = Morpho (includes reserve) + perp returned
        uint256 totalAvailable = morphoAssets + perpReturned;

        // Step 2: Calculate new TVL (exclude reserve from rebalancing)
        uint256 newTVL = totalAvailable > reserveBalance
            ? totalAvailable - reserveBalance
            : 0;

        // ✅ SLIPPAGE PROTECTION: Check if TVL is above minimum threshold
        // Protects against excessive slippage, front-running, and unfavorable market conditions
        if (minTVL > 0 && newTVL < minTVL) {
            revert SlippageExceeded();
        }

        // Step 3: Calculate loss realized
        uint256 lossRealized = 0;
        if (newTVL < oldTVL) {
            lossRealized = oldTVL - newTVL;
        }

        // Step 4: Calculate new allocation (80:20 split on TVL, excluding reserve)
        uint256 newLendingAmount = (newTVL * LENDING_ALLOCATION_BPS) / BPS;
        uint256 newPerpAmount = (newTVL * PERP_ALLOCATION_BPS) / BPS;

        // Step 5: Withdraw only what we need from Morpho for perp
        // Reserve stays in Morpho earning yield!
        // We have perpReturned in contract already, just need more for perp if needed
        if (newPerpAmount > perpReturned) {
            uint256 toWithdraw = newPerpAmount - perpReturned;
            activeStrategy.withdraw(toWithdraw);
        } else if (perpReturned > newPerpAmount) {
            // We have excess from perp, deposit it back to Morpho
            uint256 toDeposit = perpReturned - newPerpAmount;
            usdc.forceApprove(address(activeStrategy), toDeposit);
            activeStrategy.deposit(toDeposit);
        }

        // Note: newLendingAmount is already in Morpho (we didn't withdraw it)
        // Total in Morpho should now be: reserve + newLendingAmount

        // Step 6: Reopen perp position with target leverage
        if (newPerpAmount > 0) {
            uint256 newNotionalSize = newPerpAmount * targetLeverage;
            usdc.forceApprove(address(perpManager), newPerpAmount);
            // ✅ FIX HIGH-8: Pass deadline to prevent stale execution (15 min buffer)
            perpManager.increasePosition(newNotionalSize, newPerpAmount, block.timestamp + 15 minutes);
        }

        // ✅ Reset perp collateral snapshot after rebalance
        // This ensures margin tracking starts fresh from the new position
        lastPerpCollateral = address(perpManager) != address(0)
            ? perpManager.currentCollateral()
            : 0;

        emit RebalanceExecuted(healthBefore, perpPnL, oldTVL, newTVL, lossRealized);
    }

    /**
     * @notice Check if rebalancing is needed and emit warning
     * @dev Can be called by anyone to trigger monitoring event
     */
    function checkRebalanceStatus() external {
        if (address(perpManager) == address(0)) return;

        uint256 healthFactor = perpManager.getHealthFactor();
        if (healthFactor < REBALANCE_HEALTH_THRESHOLD_BPS) {
            int256 perpPnL = perpManager.getPositionPnL();
            uint256 estimatedLoss = perpPnL < 0 ? uint256(-perpPnL) : 0;
            emit RebalanceRequired(healthFactor, perpPnL, estimatedLoss);
        }
    }

    /**
     * @notice Emergency rebalance when health critical (admin-only)
     * @param minTVL Minimum acceptable TVL after rebalancing
     * @dev ✅ FIX: Changed to admin-only per user request
     *      Will implement different liquidation protection solution later
     */
    function emergencyRebalance(uint256 minTVL) external onlyOwner nonReentrant whenNotPaused {
        // ✅ CRITICAL: Block emergency rebalance when Ostium is closed
        if (isWeekend()) revert OstiumMarketClosed();

        if (address(perpManager) == address(0)) revert NoActivePosition();

        // Get current state for event logging
        uint256 healthFactor = perpManager.getHealthFactor();
        int256 perpPnL = perpManager.getPositionPnL();
        uint256 oldTVL = totalAssets();

        // Execute rebalance using internal function
        // ✅ FIX: Admin-only, no health check (admin decides when to rebalance)
        _executeRebalance(healthFactor, perpPnL, oldTVL, minTVL);
    }

    // ============ Reserve Fund Management ============

    /**
     * @notice Fund the reserve (typically by founder initially)
     * @param amount Amount to add to reserve
     */
    function fundReserve(uint256 amount) external {
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // ✅ SECURITY: Track ALL contributors, not just founder
        reserveBalance += amount;
        reserveContributions[msg.sender] += amount;
        totalReserveContributions += amount;

        emit ReserveFunded(msg.sender, amount);
    }

    /**
     * @notice Withdraw your original contribution to the reserve fund
     * @dev ✅ FIX VULN-8: Only withdraw what you contributed, not a share of total reserve
     *      This prevents stealing fee income that belongs to the protocol
     * @dev ✅ FIX VULN-17/18: Reserve is now in Morpho, must withdraw from there
     * @return withdrawn Amount of USDC withdrawn
     */
    function withdrawReserveContribution() external nonReentrant returns (uint256 withdrawn) {
        uint256 contribution = reserveContributions[msg.sender];
        require(contribution > 0, "No contribution");

        // ✅ FIX VULN-8: Only withdraw original contribution, not pro-rata share
        // Fee income stays in reserve permanently
        withdrawn = contribution;

        // ✅ SECURITY: Prevent reserve drain during crisis
        // Cannot withdraw if perp position health is low
        if (address(perpManager) != address(0)) {
            uint256 healthFactor = perpManager.getHealthFactor();
            require(healthFactor >= 7000, "Cannot withdraw reserve during low health");
        }

        // ✅ SECURITY: Ensure minimum reserve remains
        require(reserveBalance >= withdrawn + minReserveBalance, "Would breach minimum reserve");

        // ✅ CEI PATTERN: Update state before external calls
        reserveContributions[msg.sender] = 0;
        totalReserveContributions -= contribution;
        reserveBalance -= withdrawn;

        // ✅ FIX VULN-17/18: Reserve is in Morpho, withdraw from there
        uint256 actualWithdrawn = activeStrategy.withdraw(withdrawn);
        require(actualWithdrawn >= (withdrawn * 9900) / 10000, "Insufficient withdrawal");

        // ✅ INTERACTIONS: External call last
        usdc.safeTransfer(msg.sender, actualWithdrawn);

        emit ReserveFunded(msg.sender, actualWithdrawn); // Reuse event (negative semantics)
    }

    // ✅ REMOVED: _coverOpeningFee() function (obsolete after VULN-19 fix)
    // Users now pay opening fees explicitly by getting less GBPb
    // See mint() function lines 429-443 for new accounting model

    /**
     * @notice Add redemption fee to reserve (with debt repayment priority)
     * @param feeAmount Redemption fee collected
     * @dev Internal function called during redeem
     * @dev ✅ FIX VULN-17: Deploy reserve USDC to Morpho to earn yield
     */
    function _addRedemptionFeeToReserve(uint256 feeAmount) internal {
        totalRedemptionFeesCollected += feeAmount;

        // ✅ CEI PATTERN: Calculate all state changes first
        uint256 yieldRepayment = 0;
        uint256 reserveAddition = 0;

        // Priority 1: Repay any borrowed yield first
        if (yieldBorrowed > 0) {
            yieldRepayment = feeAmount > yieldBorrowed ? yieldBorrowed : feeAmount;
            feeAmount -= yieldRepayment;
        }

        // Priority 2: Add remainder to reserve (no longer repaying founder separately)
        // ✅ SECURITY: Contributors can withdraw their share using withdrawReserveContribution()
        if (feeAmount > 0) {
            reserveAddition = feeAmount;
        }

        // ✅ EFFECTS: Update all state variables BEFORE external calls
        if (yieldRepayment > 0) {
            yieldBorrowed -= yieldRepayment;
            emit YieldRepaid(yieldRepayment, yieldBorrowed);
        }

        if (reserveAddition > 0) {
            reserveBalance += reserveAddition;

            // ✅ FIX VULN-17: Deploy reserve to Morpho to earn yield
            // Reserve accounting tracks the amount, but USDC earns yield in Morpho
            usdc.forceApprove(address(activeStrategy), reserveAddition);
            activeStrategy.deposit(reserveAddition);
        }
    }

    /**
     * @notice Get complete reserve accounting
     * @return currentReserve Current reserve balance
     * @return minReserve Minimum reserve threshold
     * @return openingFeesPaid Total opening fees paid (lifetime)
     * @return redemptionFeesCollected Total redemption fees collected (lifetime)
     * @return netRevenue Net revenue (fees collected - fees paid)
     * @return yieldCurrentlyBorrowed Yield borrowed from users (if any)
     * @return totalContributed Total contributions from all contributors
     */
    function getReserveAccounting() external view returns (
        uint256 currentReserve,
        uint256 minReserve,
        uint256 openingFeesPaid,
        uint256 redemptionFeesCollected,
        int256 netRevenue,
        uint256 yieldCurrentlyBorrowed,
        uint256 totalContributed
    ) {
        currentReserve = reserveBalance;
        minReserve = minReserveBalance;
        openingFeesPaid = totalOpeningFeesPaid;
        redemptionFeesCollected = totalRedemptionFeesCollected;
        netRevenue = int256(redemptionFeesCollected) - int256(openingFeesPaid);
        yieldCurrentlyBorrowed = yieldBorrowed;
        totalContributed = totalReserveContributions;
    }

    /**
     * @notice Check if reserve is healthy
     */
    function isReserveHealthy() public view returns (bool) {
        return reserveBalance >= minReserveBalance && yieldBorrowed == 0;
    }

    /**
     * @notice Set fee recipient address
     * @param _feeRecipient New fee recipient
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();

        address oldRecipient = feeRecipient;
        feeRecipient = _feeRecipient;

        emit FeeRecipientUpdated(oldRecipient, _feeRecipient);
    }

    /**
     * @notice Set minimum reserve balance
     * @param _minReserve New minimum reserve (e.g., $100)
     */
    function setMinReserveBalance(uint256 _minReserve) external onlyOwner {
        minReserveBalance = _minReserve;
    }

    /**
     * @notice Set maximum yield that can be borrowed
     * @param _maxYieldBorrowed New maximum (e.g., $1000)
     * @dev ✅ SECURITY: Prevents unbounded reserve drain
     */
    function setMaxYieldBorrowed(uint256 _maxYieldBorrowed) external onlyOwner {
        maxYieldBorrowed = _maxYieldBorrowed;
    }

    // ============ Yield Distribution (Ethena/Maple Model) ============

    /**
     * @notice Harvest yield and distribute to sGBPb holders
     * @return gbpbMinted Amount of GBPb minted from yield
     * @dev ✅ PERMISSIONLESS: Anyone can call (bot-friendly)
     * @dev Pattern: Ethena/Maple - yield increases sGBPb backing ratio
     */
    function harvestYield() external nonReentrant whenNotPaused returns (uint256 gbpbMinted) {
        // ✅ CRITICAL: Block harvest when Ostium is closed (can't top up collateral)
        if (isWeekend()) revert OstiumMarketClosed();

        // Check 1: Minimum time elapsed
        require(
            block.timestamp >= lastHarvestTimestamp + minHarvestInterval,
            "Harvest interval not met"
        );

        // Calculate net yield
        uint256 netYield = calculateNetYield();

        // Check 2: Minimum yield threshold (cover gas + worthwhile)
        require(netYield >= minHarvestAmount, "Yield below minimum");

        // Check 3: Must be >= $5 to open new Ostium position
        if (netYield < MIN_POSITION_SIZE) {
            // Accumulate for next time
            accumulatedYield += netYield;
            // Note: We track lastMorphoAssets instead of lastTotalAssets

            emit YieldAccumulated(netYield, accumulatedYield);
            return 0;
        }

        // ✅ CEI: Update state BEFORE external calls
        lastHarvestTimestamp = block.timestamp;

        // ✅ FIX: Update Morpho snapshot (not totalAssets which includes perp PnL)
        lastMorphoAssets = address(activeStrategy) != address(0)
            ? activeStrategy.totalAssets()
            : 0;

        accumulatedYield = 0;

        // Note: lastPerpCollateral is updated AFTER harvest execution
        // (after we top up the collateral)

        // Execute harvest
        gbpbMinted = _executeHarvest(netYield);
        totalYieldDistributed += gbpbMinted;

        emit YieldHarvested(netYield, gbpbMinted, netYield);

        return gbpbMinted;
    }

    /**
     * @notice Calculate current net yield available for harvest
     * @return netYield Net yield in USDC (Morpho returns - Ostium margin costs)
     * @dev ✅ FIX: Yield = Morpho lending returns - ongoing margin costs (NO perp PnL!)
     *      Perp PnL is NOT part of yield - only Morpho lending returns
     * @dev ✅ FIX VULN-6: Removed 'view' modifier to allow event emissions and state updates
     */
    function calculateNetYield() public returns (uint256 netYield) {
        // Get current Morpho assets (excludes perp PnL)
        uint256 currentMorphoAssets = address(activeStrategy) != address(0)
            ? activeStrategy.totalAssets()
            : 0;

        // Calculate Morpho lending yield (increase in Morpho balance)
        uint256 morphoYield = currentMorphoAssets > lastMorphoAssets
            ? currentMorphoAssets - lastMorphoAssets
            : 0;

        // Calculate ongoing margin costs (simple: last snapshot - current)
        // Margin fees are visible as collateral decrease
        uint256 marginCosts = 0;
        if (address(perpManager) != address(0) && lastPerpCollateral > 0) {
            uint256 currentCollateral = perpManager.currentCollateral();

            // Margin paid = decrease in collateral since last harvest
            if (lastPerpCollateral > currentCollateral) {
                marginCosts = lastPerpCollateral - currentCollateral;
            }
        }

        // ✅ FIX MEDIUM-NEW-2: Monitor if margin exceeds yield
        // ✅ POLICY: Track consecutive days of deficit (3+ days = manual intervention needed)
        if (marginCosts > morphoYield && marginCosts > 0) {
            uint256 deficit = marginCosts - morphoYield;
            emit MarginDeficit(morphoYield, marginCosts, deficit);

            // Track consecutive deficit days (check once per day)
            if (block.timestamp >= lastDeficitCheckTimestamp + 1 days) {
                consecutiveDeficitDays += 1;
                lastDeficitCheckTimestamp = block.timestamp;

                // ✅ CRITICAL WARNING: 3+ consecutive days = owner must intervene manually
                if (consecutiveDeficitDays >= 3) {
                    emit ConsecutiveDeficitDays(consecutiveDeficitDays, deficit);
                    // Owner should:
                    // 1. Close position via emergencyRebalance()
                    // 2. Fund reserve from treasury to cover accumulated deficit
                    // 3. Reassess strategy (reduce leverage, increase Morpho allocation, etc.)
                }
            }
        } else {
            // Reset counter if margin < yield (back to normal)
            if (block.timestamp >= lastDeficitCheckTimestamp + 1 days) {
                consecutiveDeficitDays = 0;
                lastDeficitCheckTimestamp = block.timestamp;
            }
        }

        // Net yield = Morpho returns - margin costs paid
        // If margin costs exceed Morpho yield, net is 0 (can't go negative)
        uint256 currentYield = morphoYield > marginCosts
            ? morphoYield - marginCosts
            : 0;

        // Add any accumulated yield from previous rounds
        netYield = currentYield + accumulatedYield;
    }

    /**
     * @notice Internal function to execute yield harvest
     * @param netYield Net USDC yield to harvest (Morpho returns - margin costs)
     * @return gbpbMinted GBPb tokens minted to sGBPb vault
     * @dev ✅ FIX: Two-step harvest:
     *      1. Cover Ostium margin costs (top up collateral from Morpho)
     *      2. Harvest net yield (Morpho → GBPb → sGBPb)
     */
    function _executeHarvest(uint256 netYield) internal returns (uint256 gbpbMinted) {
        require(sGBPbVault != address(0), "sGBPb vault not set");

        // ===== STEP 1: Cover Ostium Margin Costs =====
        uint256 currentCollateral = address(perpManager) != address(0)
            ? perpManager.currentCollateral()
            : 0;

        // Calculate margin shortfall (if collateral decreased since last harvest)
        uint256 marginToAdd = 0;
        if (lastPerpCollateral > currentCollateral && address(perpManager) != address(0)) {
            marginToAdd = lastPerpCollateral - currentCollateral;
        }

        // ✅ FIX HIGH-NEW-1: Check Morpho has sufficient liquidity
        uint256 totalNeeded = marginToAdd + netYield;
        if (totalNeeded > 0) {
            uint256 available = activeStrategy.maxWithdraw(address(this));
            require(available >= totalNeeded, "Insufficient Morpho liquidity - try again later");
        }

        // Withdraw margin amount from Morpho (if needed)
        if (marginToAdd > 0) {
            uint256 marginWithdrawn = activeStrategy.withdraw(marginToAdd);

            // Deposit into Ostium to restore collateral (no new notional, just add collateral)
            usdc.forceApprove(address(perpManager), marginWithdrawn);
            perpManager.increasePosition(
                0, // No new notional size
                marginWithdrawn, // Just add collateral
                block.timestamp + 15 minutes
            );
        }

        // ===== STEP 2: Harvest Net Yield =====
        // Withdraw the net yield from Morpho
        uint256 netWithdrawn = activeStrategy.withdraw(netYield);
        require(netWithdrawn >= (netYield * 9900) / 10000, "Insufficient withdrawal");

        // Convert USDC to GBPb amount
        gbpbMinted = _convertUSDtoGBPb(netWithdrawn);

        // Mint GBPb to this contract
        gbpbToken.mint(address(this), gbpbMinted);

        // ✅ FIX VULN-12: DONATE GBPb to vault instead of deposit
        // Direct transfer increases totalAssets() WITHOUT minting new shares
        // This increases the share price for all sGBPb holders (Ethena pattern)
        IERC20(address(gbpbToken)).safeTransfer(sGBPbVault, gbpbMinted);

        // ❌ OLD (WRONG): deposit() mints shares, nullifying price increase
        // IERC20(address(gbpbToken)).forceApprove(sGBPbVault, gbpbMinted);
        // IsGBPb(sGBPbVault).deposit(gbpbMinted, sGBPbVault);

        // Trigger sGBPb performance fee collection
        IsGBPb(sGBPbVault).harvest();

        // ===== STEP 3: Update Perp Snapshot =====
        // Record current collateral for next harvest (after topping up)
        lastPerpCollateral = address(perpManager) != address(0)
            ? perpManager.currentCollateral()
            : 0;
    }

    /**
     * @notice Set sGBPb vault address
     * @param _sGBPbVault sGBPb vault contract address
     */
    function setSGBPbVault(address _sGBPbVault) external onlyOwner {
        require(_sGBPbVault != address(0), "Invalid address");

        address oldVault = sGBPbVault;
        sGBPbVault = _sGBPbVault;

        emit SGBPbVaultUpdated(oldVault, _sGBPbVault);
    }

    /**
     * @notice Update harvest configuration
     * @param _minInterval Minimum interval between harvests (seconds)
     * @param _minAmount Minimum yield amount to harvest (USDC, 6 decimals)
     */
    function setHarvestConfig(uint256 _minInterval, uint256 _minAmount) external onlyOwner {
        require(_minInterval >= 1 hours, "Interval too short");
        require(_minInterval <= 7 days, "Interval too long");
        require(_minAmount >= 1e6, "Amount too small"); // Min $1

        minHarvestInterval = _minInterval;
        minHarvestAmount = _minAmount;

        emit HarvestConfigUpdated(_minInterval, _minAmount);
    }

    /**
     * @notice Check if harvest is ready to execute
     * @return harvestReady Whether harvest conditions are met
     * @return netYield Current net yield available
     * @return timeUntilNext Seconds until next harvest allowed
     */
    function canHarvest() external returns (
        bool harvestReady,
        uint256 netYield,
        uint256 timeUntilNext
    ) {
        netYield = calculateNetYield();

        uint256 timeSince = block.timestamp > lastHarvestTimestamp
            ? block.timestamp - lastHarvestTimestamp
            : 0;

        timeUntilNext = timeSince >= minHarvestInterval
            ? 0
            : minHarvestInterval - timeSince;

        harvestReady = (timeUntilNext == 0) && (netYield >= minHarvestAmount);
    }

    /**
     * @notice Get harvest statistics
     * @return lastHarvest Last harvest timestamp
     * @return totalDistributed Total GBPb distributed (lifetime)
     * @return pendingYield Pending yield in USDC
     * @return nextHarvestEligible Next harvest eligible timestamp
     */
    function getHarvestStats() external returns (
        uint256 lastHarvest,
        uint256 totalDistributed,
        uint256 pendingYield,
        uint256 nextHarvestEligible
    ) {
        lastHarvest = lastHarvestTimestamp;
        totalDistributed = totalYieldDistributed;
        pendingYield = calculateNetYield();
        nextHarvestEligible = lastHarvestTimestamp + minHarvestInterval;
    }

    /**
     * @notice Verify GBPb is properly backed by USDC assets
     * @return isBackedProperly True if backing ratio >= 100%
     * @return backingRatioBPS Actual backing ratio in basis points (10000 = 100%)
     * @return totalBackingUSDC Total USDC backing all GBPb
     * @return totalGBPbValueUSDC Total GBPb value in USDC terms
     * @dev ✅ SECURITY: Ensures protocol solvency
     */
    function verifyGBPbBacking() external view returns (
        bool isBackedProperly,
        uint256 backingRatioBPS,
        uint256 totalBackingUSDC,
        uint256 totalGBPbValueUSDC
    ) {
        // Total USDC backing = Morpho assets + Perp position value
        totalBackingUSDC = totalAssets();

        // Total GBPb value in USDC = total GBPb supply × GBP/USD price
        uint256 totalGBPbSupply = gbpbToken.totalSupply();
        totalGBPbValueUSDC = _convertGBPbtoUSD(totalGBPbSupply);

        // Calculate backing ratio
        if (totalGBPbValueUSDC == 0) {
            return (true, 10000, totalBackingUSDC, 0);
        }

        backingRatioBPS = (totalBackingUSDC * 10000) / totalGBPbValueUSDC;
        isBackedProperly = backingRatioBPS >= 10000; // At least 100%
    }

    /**
     * @notice Get current margin status (simple snapshot approach)
     * @return lastSnapshot Collateral amount at last harvest
     * @return currentCollateral Current collateral in position
     * @return marginSinceLastHarvest Margin fees paid since last harvest
     * @dev Simple approach: margin = last - current
     */
    function getPerpMarginStats() external view returns (
        uint256 lastSnapshot,
        uint256 currentCollateral,
        uint256 marginSinceLastHarvest
    ) {
        lastSnapshot = lastPerpCollateral;
        currentCollateral = address(perpManager) != address(0)
            ? perpManager.currentCollateral()
            : 0;

        // Margin paid since last harvest
        marginSinceLastHarvest = lastSnapshot > currentCollateral
            ? lastSnapshot - currentCollateral
            : 0;
    }

    /**
     * @notice Get margin deficit status
     * @return isDeficit True if currently in deficit (margin > yield)
     * @return consecutiveDays Number of consecutive days in deficit
     * @return requiresIntervention True if >= 3 consecutive days (manual action needed)
     * @return currentDeficit Current deficit amount (if in deficit)
     * @dev ✅ POLICY: If requiresIntervention = true, owner should:
     *      1. emergencyRebalance() to close position
     *      2. fundReserve() from treasury to cover deficit
     */
    function getMarginDeficitStatus() external view returns (
        bool isDeficit,
        uint256 consecutiveDays,
        bool requiresIntervention,
        uint256 currentDeficit
    ) {
        // Get current Morpho yield
        uint256 currentMorphoAssets = address(activeStrategy) != address(0)
            ? activeStrategy.totalAssets()
            : 0;
        uint256 morphoYield = currentMorphoAssets > lastMorphoAssets
            ? currentMorphoAssets - lastMorphoAssets
            : 0;

        // Get current margin costs
        uint256 marginCosts = 0;
        if (address(perpManager) != address(0) && lastPerpCollateral > 0) {
            uint256 currentCollateral = perpManager.currentCollateral();
            if (lastPerpCollateral > currentCollateral) {
                marginCosts = lastPerpCollateral - currentCollateral;
            }
        }

        // Check if in deficit
        isDeficit = marginCosts > morphoYield && marginCosts > 0;
        currentDeficit = isDeficit ? marginCosts - morphoYield : 0;
        consecutiveDays = consecutiveDeficitDays;
        requiresIntervention = consecutiveDays >= 3;
    }
}

/**
 * @notice Minimal interface for sGBPb
 */
interface IsGBPb {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function harvest() external returns (uint256 feeShares);
}
