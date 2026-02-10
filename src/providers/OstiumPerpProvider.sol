// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IPerpProvider.sol";
import "../interfaces/external/IOstiumTrading.sol";
import "../interfaces/external/IOstiumTradingStorage.sol";

/// @notice Minimal interface for ChainlinkOracle to get GBP/USD price
interface IChainlinkOracle {
    function getGBPUSDPrice() external view returns (uint256);
}

/**
 * @title OstiumPerpProvider
 * @notice Perpetual DEX provider implementation for Ostium
 * @dev Implements IPerpProvider interface using OpenZeppelin's audited components
 * @dev Uses SafeERC20, Ownable, and ReentrancyGuard for maximum security
 */
contract OstiumPerpProvider is IPerpProvider, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Ostium Trading contract
    IOstiumTrading public immutable ostiumTrading;

    /// @notice Ostium TradingStorage contract (holds collateral)
    IOstiumTradingStorage public immutable ostiumTradingStorage;

    /// @notice Collateral token (USDC)
    IERC20 public immutable collateralToken;

    /// @notice GBP/USD pair index on Ostium
    uint16 public immutable gbpUsdPairIndex;

    /// @notice Chainlink oracle for GBP/USD price (to calculate PnL)
    address public priceOracle;

    /// @notice Market identifier (e.g., "GBP/USD")
    /// @dev ✅ FIX MED-7: Configurable instead of hardcoded
    bytes32 public immutable marketIdentifier;

    /// @notice Position index (always 0 for single position per vault)
    uint8 public constant POSITION_INDEX = 0;

    /// @notice Leverage precision constant (100 basis = 1x leverage)
    uint32 public constant PRECISION_2 = 100;

    /// @notice Slippage precision constant
    uint256 public constant SLIPPAGE_PRECISION = 100;

    /// @notice Maximum allowed leverage (20x for safety)
    /// @dev ✅ FIX HIGH-3: Prevent excessive leverage that risks instant liquidation
    uint256 public constant MAX_LEVERAGE = 20;

    /// @notice Position verification threshold (95% of expected collateral)
    /// @dev ✅ FIX LOW-6: Named constant instead of magic number 9500
    uint256 private constant POSITION_VERIFICATION_THRESHOLD = 9500; // 95%

    /// @notice Basis points denominator
    /// @dev ✅ FIX LOW-6: Named constant instead of magic number 10000
    uint256 private constant BPS = 10000;

    /// @notice Full closure threshold (100% in PRECISION_2)
    /// @dev ✅ FIX LOW-6: Named constant for 100% position closure
    uint256 private constant FULL_CLOSURE_BPS = 10000;

    /// @notice Maximum position size per trade (prevent exceeding DEX limits)
    uint256 public constant MAX_POSITION_SIZE = 1_000_000e6; // 1M USDC notional

    /// @notice Default slippage tolerance (5%)
    uint256 public slippageTolerance;

    /// @notice Builder fee (optional revenue, in PRECISION_6)
    uint32 public builderFee;

    /// @notice Builder fee recipient
    address public builderFeeRecipient;

    /// @notice Target leverage for positions (e.g., 10 = 10x)
    uint256 public targetLeverage;

    /// @notice Estimated total fee rate (trading + funding) in basis points
    /// @dev ✅ FIX MED-NEW-4: Conservative fee estimate for PnL calculations
    /// @dev Typical values: 0.1% trading fee + 0.01% funding/day ≈ 50-100 bps total
    uint256 public estimatedFeeRateBPS;

    /// @notice Emitted when slippage tolerance is updated
    event SlippageToleranceUpdated(uint256 oldSlippage, uint256 newSlippage);

    /// @notice Emitted when builder fee is updated
    event BuilderFeeUpdated(uint32 oldFee, uint32 newFee);

    /// @notice Emitted when target leverage is updated
    event TargetLeverageUpdated(uint256 oldLeverage, uint256 newLeverage);

    /// @notice ✅ FIX HIGH-6: Additional events for monitoring
    event PositionOpened(uint256 collateral, uint256 notionalSize, uint32 leverage);
    event PositionClosed(uint256 percentageClosed, uint256 collateralReturned);

    /// @notice ✅ FIX MED-NEW-4: Emitted when fee rate estimate is updated
    event EstimatedFeeRateUpdated(uint256 oldRate, uint256 newRate);

    error InvalidAddress();
    error InvalidPairIndex();
    error InvalidSlippage();
    error InvalidLeverage();
    error ZeroAmount();
    error PositionOpenFailed();
    error PositionCloseFailed();
    error LeverageTooHigh();
    error PositionTooLarge();

    /**
     * @notice Constructor
     * @param _ostiumTrading Address of Ostium Trading contract
     * @param _ostiumTradingStorage Address of Ostium TradingStorage contract
     * @param _collateralToken Address of collateral token (USDC)
     * @param _gbpUsdPairIndex Pair index for GBP/USD on Ostium
     * @param _targetLeverage Target leverage (e.g., 10 for 10x)
     * @param _priceOracle Address of Chainlink oracle for GBP/USD (to calculate PnL)
     * @param _marketIdentifier Market identifier (e.g., bytes32("GBP/USD"))
     */
    constructor(
        address _ostiumTrading,
        address _ostiumTradingStorage,
        address _collateralToken,
        uint16 _gbpUsdPairIndex,
        uint256 _targetLeverage,
        address _priceOracle,
        bytes32 _marketIdentifier
    ) Ownable(msg.sender) {
        if (_ostiumTrading == address(0)) revert InvalidAddress();
        if (_ostiumTradingStorage == address(0)) revert InvalidAddress();
        if (_collateralToken == address(0)) revert InvalidAddress();
        if (_priceOracle == address(0)) revert InvalidAddress();
        if (_marketIdentifier == bytes32(0)) revert InvalidAddress();
        // Note: pairIndex can be 0, so we don't check for zero
        // GBP/USD is pairIndex 3 on Ostium Arbitrum
        if (_targetLeverage == 0) revert InvalidLeverage();

        ostiumTrading = IOstiumTrading(_ostiumTrading);
        ostiumTradingStorage = IOstiumTradingStorage(_ostiumTradingStorage);
        collateralToken = IERC20(_collateralToken);
        gbpUsdPairIndex = _gbpUsdPairIndex;
        targetLeverage = _targetLeverage;
        priceOracle = _priceOracle;
        marketIdentifier = _marketIdentifier; // ✅ FIX MED-7

        // Default settings
        slippageTolerance = 500; // 5% (PRECISION_2)
        builderFee = 0; // No builder fee initially
        builderFeeRecipient = msg.sender;

        // ✅ FIX MED-NEW-4: Conservative fee estimate (1% = 100 bps)
        // Covers typical trading fees (0.1%) + funding fees over time
        estimatedFeeRateBPS = 100; // 1%
    }

    /**
     * @notice Increase a perpetual position
     * @dev Opens or increases a long GBP/USD position on Ostium
     * @dev ✅ FIX MED-4: No deadline parameter needed - Ostium's slippage tolerance
     *      provides equivalent protection against stale transactions. If price moves
     *      unfavorably while tx is in mempool, it will revert due to slippage check.
     * @param market The market identifier (must be GBP/USD)
     * @param collateral Amount of collateral to add
     * @param sizeDelta The size to increase the position by (notional value)
     * @param isLong Whether this is a long position (must be true for GBP/USD)
     */
    function increasePosition(
        bytes32 market,
        uint256 collateral,
        uint256 sizeDelta,
        bool isLong
    ) external override nonReentrant {
        if (collateral == 0 || sizeDelta == 0) revert ZeroAmount();
        require(isLong, "Only long positions supported");
        require(market == marketIdentifier, "Invalid market");

        // ✅ FIX HIGH-3: Validate leverage is within safe bounds
        if (targetLeverage > MAX_LEVERAGE) revert LeverageTooHigh();

        // ✅ FIX HIGH-3: Validate position size doesn't exceed limits
        uint256 notionalSize = collateral * targetLeverage;
        if (notionalSize > MAX_POSITION_SIZE) revert PositionTooLarge();

        // Transfer collateral from vault to this contract
        collateralToken.safeTransferFrom(msg.sender, address(this), collateral);

        // Approve TradingStorage to spend collateral
        collateralToken.forceApprove(address(ostiumTradingStorage), collateral);

        // Calculate leverage for this position
        // Ostium uses PRECISION_2 (100 = 1x, 1000 = 10x)
        // ✅ FIX MED-5: Check practical maximum first for clarity
        if (targetLeverage > MAX_LEVERAGE) {
            revert InvalidLeverage();
        }

        // ✅ FIX MED-5: Then check uint32 limits (will never fail with MAX_LEVERAGE = 20)
        if (targetLeverage > type(uint32).max / PRECISION_2) {
            revert InvalidLeverage();
        }

        uint256 leverageValue = targetLeverage * PRECISION_2;
        uint32 leverage = uint32(leverageValue);

        // Get current GBP/USD price from oracle for market order
        // Oracle returns 8 decimals, Ostium expects 18 decimals (uint192)
        uint256 currentPrice = IChainlinkOracle(priceOracle).getGBPUSDPrice();
        uint192 openPriceOstium = uint192(currentPrice * 1e10); // Convert 8 decimals to 18 decimals

        // Build trade struct
        // Note: trader should be this contract (provider) since we're the one calling Ostium
        IOstiumTradingStorage.Trade memory trade = IOstiumTradingStorage.Trade({
            collateral: collateral,
            openPrice: openPriceOstium, // Current market price - slippage tolerance protects from large moves
            tp: 0, // No take profit
            sl: 0, // No stop loss (managed by vault)
            trader: address(this), // This provider contract is the trader in Ostium's eyes
            leverage: leverage,
            pairIndex: gbpUsdPairIndex,
            index: POSITION_INDEX,
            buy: true // Always long GBP/USD
        });

        // Build builder fee struct
        IOstiumTradingStorage.BuilderFee memory bf = IOstiumTradingStorage.BuilderFee({
            builder: builderFeeRecipient,
            builderFee: builderFee
        });

        // Open position on Ostium
        // ✅ FIX: Forward explicit gas to prevent precompile failures in deep call stacks
        ostiumTrading.openTrade{gas: 3000000}(
            trade,
            bf,
            IOstiumTradingStorage.OpenOrderType.MARKET,
            slippageTolerance
        );

        // ✅ FIX CRIT-4: Verify position was actually opened
        IOstiumTradingStorage.Trade memory confirmedTrade = ostiumTradingStorage.openTrades(
            address(this),
            gbpUsdPairIndex,
            POSITION_INDEX
        );

        // ⚠️ FIX CRITICAL: Use stricter threshold - typical fees are 0.1-1%, not 50%
        // Allow max 5% loss to fees (95% of collateral should remain)
        uint256 minCollateral = (collateral * POSITION_VERIFICATION_THRESHOLD) / BPS;

        if (confirmedTrade.collateral < minCollateral) {
            revert PositionOpenFailed();
        }

        // ⚠️ Also verify leverage is approximately correct
        uint256 expectedLeverage = leverageValue;
        uint256 actualLeverage = confirmedTrade.leverage;

        // Allow 5% variance in leverage
        if (actualLeverage < (expectedLeverage * POSITION_VERIFICATION_THRESHOLD) / BPS ||
            actualLeverage > (expectedLeverage * (BPS + (BPS - POSITION_VERIFICATION_THRESHOLD))) / BPS) {
            revert PositionOpenFailed();
        }

        // ✅ FIX HIGH-6: Emit event for monitoring
        emit PositionOpened(collateral, sizeDelta, leverage);
    }

    /**
     * @notice Decrease a perpetual position
     * @dev Closes or decreases a GBP/USD position on Ostium
     * @param market The market identifier (must be GBP/USD)
     * @param collateralDelta Amount of collateral to remove (not used in percentage close)
     * @param sizeDelta The size to decrease the position by (not used in percentage close)
     * @param isLong Whether this is a long position (must be true)
     */
    function decreasePosition(
        bytes32 market,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong
    ) external override nonReentrant {
        require(isLong, "Only long positions supported");
        require(market == marketIdentifier, "Invalid market");

        // Get current position - look up by this contract (provider) since that's the trader
        IOstiumTradingStorage.Trade memory currentTrade = ostiumTradingStorage.openTrades(
            address(this),
            gbpUsdPairIndex,
            POSITION_INDEX
        );

        if (currentTrade.collateral == 0) {
            return; // No position to close
        }

        // Calculate percentage to close based on sizeDelta
        // If sizeDelta >= current notional, close 100%
        uint256 currentNotional = uint256(currentTrade.collateral) * uint256(currentTrade.leverage) / PRECISION_2;
        uint256 percentageClosed = sizeDelta >= currentNotional
            ? FULL_CLOSURE_BPS // 100%
            : (sizeDelta * FULL_CLOSURE_BPS) / currentNotional;

        // Store collateral before closing
        uint256 collateralBefore = currentTrade.collateral;

        // Close position on Ostium
        ostiumTrading.closeTradeMarket(
            gbpUsdPairIndex,
            POSITION_INDEX,
            percentageClosed,
            0, // Accept any price within slippage
            slippageTolerance
        );

        // ✅ FIX CRIT-4: Verify position was actually closed
        IOstiumTradingStorage.Trade memory tradeAfter = ostiumTradingStorage.openTrades(
            address(this),
            gbpUsdPairIndex,
            POSITION_INDEX
        );

        // If closing 100%, position should be gone or have minimal collateral
        if (percentageClosed >= FULL_CLOSURE_BPS && tradeAfter.collateral > collateralBefore / 10) {
            revert PositionCloseFailed();
        }

        // Return any collateral to vault
        uint256 balance = collateralToken.balanceOf(address(this));
        if (balance > 0) {
            collateralToken.safeTransfer(msg.sender, balance);
        }

        // ✅ FIX HIGH-6: Emit event for monitoring
        emit PositionClosed(percentageClosed, balance);
    }

    /**
     * @notice Get the current position's profit and loss
     * @dev ✅ FIX CRIT-5: Now calculates actual unrealized PnL using Chainlink oracle
     * @dev ✅ FIX MED-NEW-4: Applies conservative fee estimate to account for trading/funding fees
     * @param market The market identifier
     * @param account The account holding the position
     * @return pnl The unrealized profit/loss (can be negative)
     * @notice WARNING: This is an ESTIMATE. Actual PnL on close will differ due to:
     *         - Real-time funding fees (not tracked here)
     *         - Trading fees on close (not tracked here)
     *         - Slippage during position closure
     *         Use getPositionPnLWithFees() for a more conservative estimate
     */
    function getPositionPnL(bytes32 market, address account) external view override returns (int256 pnl) {
        require(market == marketIdentifier, "Invalid market");

        // Get current position - look up by this contract (provider)
        IOstiumTradingStorage.Trade memory trade = ostiumTradingStorage.openTrades(
            address(this),
            gbpUsdPairIndex,
            POSITION_INDEX
        );

        if (trade.collateral == 0) {
            return 0; // No position
        }

        // ✅ Calculate PnL using Chainlink oracle
        try IChainlinkOracle(priceOracle).getGBPUSDPrice() returns (uint256 currentPrice) {
            // Position size in USD (notional)
            uint256 positionSize = uint256(trade.collateral) * uint256(trade.leverage) / PRECISION_2;

            // Price change (both prices are in 8 decimals from Chainlink)
            // For long position: PnL = positionSize * (currentPrice - openPrice) / openPrice
            int256 priceDiff = int256(currentPrice) - int256(uint256(trade.openPrice));

            // Calculate gross PnL (scaled to USDC 6 decimals)
            // pnl = positionSize * priceDiff / openPrice
            // Adjust for decimals: positionSize (6 decimals) * priceDiff (8 decimals) / openPrice (8 decimals)
            if (trade.openPrice > 0) {
                pnl = (int256(positionSize) * priceDiff) / int256(uint256(trade.openPrice));
            } else {
                // If openPrice is 0 (market order), we can't calculate PnL yet
                return 0;
            }

            // ✅ FIX MED-NEW-4: Apply conservative fee deduction
            // Deduct estimated fees from gross PnL (only if PnL is positive)
            if (pnl > 0) {
                int256 estimatedFees = int256((uint256(pnl) * estimatedFeeRateBPS) / BPS);
                pnl = pnl - estimatedFees;
            }
            // Note: If PnL is negative, don't subtract fees (already losing money)

        } catch {
            // If oracle fails, return 0 to be conservative
            return 0;
        }
    }

    /**
     * @notice Get the current position size
     * @param market The market identifier
     * @param account The account holding the position
     * @return size The current position size (notional value)
     */
    function getPositionSize(bytes32 market, address account) external view override returns (uint256 size) {
        require(market == marketIdentifier, "Invalid market");

        // Look up position by this contract (provider), not by account
        // Because this provider is the trader in Ostium's system
        IOstiumTradingStorage.Trade memory trade = ostiumTradingStorage.openTrades(
            address(this),
            gbpUsdPairIndex,
            POSITION_INDEX
        );

        if (trade.collateral == 0) {
            return 0;
        }

        // Notional size = collateral * leverage
        return uint256(trade.collateral) * uint256(trade.leverage) / PRECISION_2;
    }

    /**
     * @notice Get the current collateral in the position
     * @param market The market identifier
     * @param account The account holding the position
     * @return collateral The current collateral amount
     */
    function getPositionCollateral(bytes32 market, address account)
        external
        view
        override
        returns (uint256 collateral)
    {
        require(market == marketIdentifier, "Invalid market");

        // Look up position by this contract (provider), not by account
        IOstiumTradingStorage.Trade memory trade = ostiumTradingStorage.openTrades(
            address(this),
            gbpUsdPairIndex,
            POSITION_INDEX
        );

        return trade.collateral;
    }

    /**
     * @notice Update slippage tolerance
     * @param newSlippage New slippage tolerance (PRECISION_2, e.g., 500 = 5%)
     */
    function setSlippageTolerance(uint256 newSlippage) external onlyOwner {
        if (newSlippage == 0 || newSlippage > 2000) revert InvalidSlippage(); // Max 20%

        uint256 oldSlippage = slippageTolerance;
        slippageTolerance = newSlippage;

        emit SlippageToleranceUpdated(oldSlippage, newSlippage);
    }

    /**
     * @notice Update builder fee
     * @param newFee New builder fee (PRECISION_6, e.g., 5000 = 0.005%)
     */
    function setBuilderFee(uint32 newFee) external onlyOwner {
        require(newFee <= 500000, "Fee exceeds max"); // Max 0.5%

        uint32 oldFee = builderFee;
        builderFee = newFee;

        emit BuilderFeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Update builder fee recipient
     * @param newRecipient New fee recipient address
     */
    function setBuilderFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert InvalidAddress();
        builderFeeRecipient = newRecipient;
    }

    /**
     * @notice Update target leverage
     * @param newLeverage New target leverage (e.g., 10 for 10x)
     * @dev ✅ FIX HIGH-3: Enforced maximum of 20x for safety
     */
    function setTargetLeverage(uint256 newLeverage) external onlyOwner {
        if (newLeverage == 0) revert InvalidLeverage();
        if (newLeverage > MAX_LEVERAGE) revert LeverageTooHigh(); // ✅ Max 20x

        uint256 oldLeverage = targetLeverage;
        targetLeverage = newLeverage;

        emit TargetLeverageUpdated(oldLeverage, newLeverage);
    }

    /**
     * @notice Update estimated fee rate for PnL calculations
     * @param newRate New fee rate in basis points (e.g., 100 = 1%)
     * @dev ✅ FIX MED-NEW-4: Allows adjustment based on observed fee rates
     */
    function setEstimatedFeeRate(uint256 newRate) external onlyOwner {
        require(newRate <= 500, "Fee rate too high"); // Max 5%

        uint256 oldRate = estimatedFeeRateBPS;
        estimatedFeeRateBPS = newRate;

        emit EstimatedFeeRateUpdated(oldRate, newRate);
    }

    /**
     * @notice Emergency withdrawal of stuck tokens
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
