// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NAVCalculator
 * @notice Library for Net Asset Value calculations
 * @dev Handles USD to GBP conversions and NAV computations
 */
library NAVCalculator {
    uint256 private constant PRICE_PRECISION = 1e8; // Chainlink uses 8 decimals
    uint256 private constant SHARE_PRECISION = 1e18;

    /**
     * @notice Convert USD amount to GBP value
     * @param usdAmount Amount in USD (with token decimals, e.g., 6 for USDC)
     * @param gbpUsdPrice GBP/USD price from Chainlink (8 decimals)
     * @param decimals The decimals of the USD token
     * @return gbpValue The equivalent value in GBP terms
     */
    function convertUSDtoGBP(
        uint256 usdAmount,
        uint256 gbpUsdPrice,
        uint8 decimals
    ) internal pure returns (uint256 gbpValue) {
        // Convert USD to GBP: divide by GBP/USD price
        // Scale appropriately for decimals
        gbpValue = (usdAmount * PRICE_PRECISION) / gbpUsdPrice;
        return gbpValue;
    }

    /**
     * @notice Convert GBP value to USD amount
     * @param gbpValue Amount in GBP terms
     * @param gbpUsdPrice GBP/USD price from Chainlink (8 decimals)
     * @param decimals The decimals of the USD token
     * @return usdAmount The equivalent amount in USD
     */
    function convertGBPtoUSD(
        uint256 gbpValue,
        uint256 gbpUsdPrice,
        uint8 decimals
    ) internal pure returns (uint256 usdAmount) {
        // Convert GBP to USD: multiply by GBP/USD price
        usdAmount = (gbpValue * gbpUsdPrice) / PRICE_PRECISION;
        return usdAmount;
    }

    /**
     * @notice Calculate share price in GBP terms
     * @param totalAssetsUSD Total vault assets in USD
     * @param totalShares Total shares outstanding
     * @param gbpUsdPrice GBP/USD price from Chainlink
     * @param decimals The decimals of the USD token
     * @return pricePerShare The price per share in GBP terms (1e18 precision)
     */
    function calculateSharePrice(
        uint256 totalAssetsUSD,
        uint256 totalShares,
        uint256 gbpUsdPrice,
        uint8 decimals
    ) internal pure returns (uint256 pricePerShare) {
        if (totalShares == 0) return SHARE_PRECISION; // 1:1 initially

        uint256 totalAssetsGBP = convertUSDtoGBP(totalAssetsUSD, gbpUsdPrice, decimals);
        pricePerShare = (totalAssetsGBP * SHARE_PRECISION) / totalShares;
        return pricePerShare;
    }

    /**
     * @notice Calculate shares to mint for a given USD deposit
     * @param depositAmountUSD Amount being deposited in USD
     * @param totalAssetsUSD Current total assets in USD (before deposit)
     * @param totalShares Current total shares
     * @param gbpUsdPrice GBP/USD price from Chainlink
     * @param decimals The decimals of the USD token
     * @return shares The number of shares to mint
     */
    function calculateSharesForDeposit(
        uint256 depositAmountUSD,
        uint256 totalAssetsUSD,
        uint256 totalShares,
        uint256 gbpUsdPrice,
        uint8 decimals
    ) internal pure returns (uint256 shares) {
        if (totalShares == 0) {
            // First deposit: convert to GBP value and mint 1:1
            return convertUSDtoGBP(depositAmountUSD, gbpUsdPrice, decimals);
        }

        // Calculate based on current share price
        uint256 depositGBP = convertUSDtoGBP(depositAmountUSD, gbpUsdPrice, decimals);
        uint256 totalAssetsGBP = convertUSDtoGBP(totalAssetsUSD, gbpUsdPrice, decimals);

        shares = (depositGBP * totalShares) / totalAssetsGBP;
        return shares;
    }

    /**
     * @notice Calculate assets to return for a given share redemption
     * @param sharesToRedeem Shares being redeemed
     * @param totalAssetsUSD Current total assets in USD
     * @param totalShares Current total shares
     * @return assetsUSD The amount of USD to return
     */
    function calculateAssetsForShares(
        uint256 sharesToRedeem,
        uint256 totalAssetsUSD,
        uint256 totalShares
    ) internal pure returns (uint256 assetsUSD) {
        if (totalShares == 0) return 0;

        assetsUSD = (sharesToRedeem * totalAssetsUSD) / totalShares;
        return assetsUSD;
    }
}
