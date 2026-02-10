// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ChainlinkOracle
 * @notice Fetches GBP/USD price from Chainlink and provides conversion utilities
 * @dev Used for calculating GBP-denominated NAV
 */
contract ChainlinkOracle is Ownable {
    /// @notice Primary Chainlink GBP/USD price feed
    /// @dev Arbitrum: 0x9C4424Fd84C6661F97D8d6b3fc3C1aAc2BeDd137
    AggregatorV3Interface public immutable gbpUsdFeed;

    /// @notice Backup Chainlink GBP/USD price feed (optional)
    /// @dev Set via setBackupFeed() - used if primary fails
    AggregatorV3Interface public backupFeed;

    /// @notice Whether to use backup feed
    bool public useBackup;

    /// @notice Maximum age of price data before considered stale (default: 1 hour)
    uint256 public maxPriceAge;

    /// @notice Minimum acceptable GBP/USD price (8 decimals) - default 1.15
    uint256 public minPrice;

    /// @notice Maximum acceptable GBP/USD price (8 decimals) - default 1.40
    uint256 public maxPrice;

    /// @notice Emitted when max price age is updated
    event MaxPriceAgeUpdated(uint256 oldAge, uint256 newAge);

    /// @notice Emitted when price is fetched
    event PriceFetched(int256 price, uint256 timestamp);

    /// @notice Emitted when price bounds are updated
    event PriceBoundsUpdated(uint256 minPrice, uint256 maxPrice);

    /// @notice Emitted when backup feed is updated
    event BackupFeedUpdated(address indexed backupFeed);

    /// @notice Emitted when backup feed usage is toggled
    event BackupFeedToggled(bool enabled);

    error StalePrice();
    error InvalidPrice();
    error InvalidMaxAge();
    error PriceOutOfBounds();
    error DecimalsMismatch();
    error FeedNotResponsive();

    /**
     * @notice Constructor
     * @param _gbpUsdFeed Address of Chainlink GBP/USD price feed
     * @param _maxPriceAge Maximum acceptable age of price data in seconds
     * @param _owner Initial owner address (should be governance multisig)
     */
    constructor(address _gbpUsdFeed, uint256 _maxPriceAge, address _owner) Ownable(_owner) {
        require(_gbpUsdFeed != address(0), "Invalid feed address");
        require(_maxPriceAge > 0, "Invalid max age");
        require(_owner != address(0), "Invalid owner");

        gbpUsdFeed = AggregatorV3Interface(_gbpUsdFeed);
        maxPriceAge = _maxPriceAge;

        // ✅ SECURITY: Set reasonable bounds for GBP/USD (historical range: ~1.15-1.40)
        // Protects against oracle manipulation or extreme market events
        minPrice = 1.15e8; // $1.15 (8 decimals)
        maxPrice = 1.40e8; // $1.40 (8 decimals)
    }

    /**
     * @notice Get the latest GBP/USD price from Chainlink (with backup)
     * @return price The latest GBP/USD price (8 decimals)
     * @dev Tries primary feed first, falls back to backup if primary fails
     */
    function getGBPUSDPrice() external view returns (uint256 price) {
        // Try primary feed first
        try this._getPriceFromFeed(gbpUsdFeed) returns (uint256 primaryPrice) {
            return primaryPrice;
        } catch {
            // If primary fails and backup exists, try backup
            if (address(backupFeed) != address(0) && useBackup) {
                return this._getPriceFromFeed(backupFeed);
            }
            // No backup available, revert
            revert InvalidPrice();
        }
    }

    /**
     * @notice Internal function to get price from a specific feed
     * @param feed The price feed to query
     * @return price The price from the feed
     * @dev External to allow try/catch
     */
    function _getPriceFromFeed(AggregatorV3Interface feed) external view returns (uint256 price) {
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.latestRoundData();

        // Validate price data
        if (answer <= 0) revert InvalidPrice();
        if (updatedAt == 0) revert InvalidPrice();
        if (answeredInRound < roundId) revert StalePrice();

        // Check price freshness
        if (block.timestamp - updatedAt > maxPriceAge) revert StalePrice();

        price = uint256(answer);

        // ✅ SECURITY: Bounds check to prevent oracle manipulation
        // GBP/USD historically trades in 1.15-1.40 range
        if (price < minPrice || price > maxPrice) revert PriceOutOfBounds();

        return price;
    }

    /**
     * @notice Get validated GBP/USD price with comprehensive checks
     * @return price The latest GBP/USD price (8 decimals)
     * @return isValid Whether all validation checks passed
     * @dev Use this in critical operations for extra safety
     */
    function getGBPUSDPriceWithValidation() external view returns (uint256 price, bool isValid) {
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = gbpUsdFeed.latestRoundData();

        // Check 1: Price is positive
        if (answer <= 0) return (0, false);

        // Check 2: Timestamp is set
        if (updatedAt == 0) return (0, false);

        // Check 3: Round is complete
        if (answeredInRound < roundId) return (0, false);

        // Check 4: Price is fresh (< maxPriceAge)
        if (block.timestamp - updatedAt > maxPriceAge) return (0, false);

        price = uint256(answer);

        // Check 5: Price is within reasonable bounds
        if (price < minPrice || price > maxPrice) return (0, false);

        return (price, true);
    }

    /**
     * @notice Get the latest GBP/USD price with timestamp
     * @return price The latest GBP/USD price (8 decimals)
     * @return updatedAt The timestamp when price was last updated
     */
    function getGBPUSDPriceWithTimestamp() external view returns (uint256 price, uint256 updatedAt) {
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 timestamp,
            uint80 answeredInRound
        ) = gbpUsdFeed.latestRoundData();

        // Validate price data
        if (answer <= 0) revert InvalidPrice();
        if (timestamp == 0) revert InvalidPrice();
        if (answeredInRound < roundId) revert StalePrice();

        // Check price freshness
        if (block.timestamp - timestamp > maxPriceAge) revert StalePrice();

        return (uint256(answer), timestamp);
    }

    /**
     * @notice Convert USD amount to GBP value using current price
     * @param usdAmount Amount in USD (with appropriate decimals)
     * @return gbpValue The equivalent value in GBP terms
     */
    function convertUSDtoGBP(uint256 usdAmount) external view returns (uint256 gbpValue) {
        uint256 price = this.getGBPUSDPrice();
        // GBP value = USD amount / (GBP/USD price)
        // Price has 8 decimals, so we multiply by 1e8 then divide by price
        gbpValue = (usdAmount * 1e8) / price;
        return gbpValue;
    }

    /**
     * @notice Convert GBP value to USD amount using current price
     * @param gbpValue Amount in GBP terms
     * @return usdAmount The equivalent amount in USD
     */
    function convertGBPtoUSD(uint256 gbpValue) external view returns (uint256 usdAmount) {
        uint256 price = this.getGBPUSDPrice();
        // USD amount = GBP value * (GBP/USD price)
        // Price has 8 decimals, so we multiply then divide by 1e8
        usdAmount = (gbpValue * price) / 1e8;
        return usdAmount;
    }

    /**
     * @notice Update the maximum price age
     * @param newMaxAge New maximum age in seconds
     */
    function setMaxPriceAge(uint256 newMaxAge) external onlyOwner {
        if (newMaxAge == 0) revert InvalidMaxAge();
        uint256 oldAge = maxPriceAge;
        maxPriceAge = newMaxAge;
        emit MaxPriceAgeUpdated(oldAge, newMaxAge);
    }

    /**
     * @notice Update price bounds for sanity checks
     * @param _minPrice New minimum acceptable price (8 decimals)
     * @param _maxPrice New maximum acceptable price (8 decimals)
     * @dev Should be updated carefully during extreme market conditions
     */
    function setPriceBounds(uint256 _minPrice, uint256 _maxPrice) external onlyOwner {
        require(_minPrice > 0, "Min price must be positive");
        require(_maxPrice > _minPrice, "Max must be greater than min");
        require(_maxPrice < 10e8, "Max price unreasonably high"); // Sanity check

        minPrice = _minPrice;
        maxPrice = _maxPrice;

        emit PriceBoundsUpdated(_minPrice, _maxPrice);
    }

    /**
     * @notice Set backup price feed
     * @param _backupFeed Address of backup Chainlink feed
     * @dev ✅ REDUNDANCY: Backup oracle in case primary fails
     * @dev ✅ SECURITY: Validates decimals match and feed is responsive
     */
    function setBackupFeed(address _backupFeed) external onlyOwner {
        require(_backupFeed != address(0), "Invalid backup feed");
        require(_backupFeed != address(gbpUsdFeed), "Backup cannot be same as primary");

        AggregatorV3Interface newFeed = AggregatorV3Interface(_backupFeed);

        // ✅ SECURITY: Verify decimals match primary feed
        if (newFeed.decimals() != gbpUsdFeed.decimals()) {
            revert DecimalsMismatch();
        }

        // ✅ SECURITY: Verify feed is working and returns valid data
        try newFeed.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256 /* startedAt */,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            if (answer <= 0) revert InvalidPrice();
            if (updatedAt == 0) revert InvalidPrice();
            if (answeredInRound < roundId) revert StalePrice();

            // ✅ Verify price is within reasonable bounds
            uint256 price = uint256(answer);
            if (price < minPrice || price > maxPrice) revert PriceOutOfBounds();
        } catch {
            revert FeedNotResponsive();
        }

        backupFeed = newFeed;

        emit BackupFeedUpdated(_backupFeed);
    }

    /**
     * @notice Enable or disable backup feed usage
     * @param _enabled Whether to use backup feed
     */
    function setUseBackup(bool _enabled) external onlyOwner {
        useBackup = _enabled;

        emit BackupFeedToggled(_enabled);
    }

    /**
     * @notice Get the decimals of the price feed
     * @return decimals The number of decimals (should be 8 for Chainlink)
     */
    function decimals() external view returns (uint8) {
        return gbpUsdFeed.decimals();
    }
}
