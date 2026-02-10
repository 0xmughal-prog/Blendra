// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IOstiumTradingStorage.sol";

/**
 * @title IOstiumTrading
 * @notice Interface for Ostium's Trading contract
 * @dev Based on Ostium's smart contract at 0x6d0ba1f9996dbd8885827e1b2e8f6593e7702411
 */
interface IOstiumTrading {
    /**
     * @notice Open a new trade
     * @param t Trade parameters
     * @param bf Builder fee parameters
     * @param orderType Market or limit order
     * @param slippageP Slippage percentage (PRECISION_2, e.g., 500 = 5%)
     */
    function openTrade(
        IOstiumTradingStorage.Trade calldata t,
        IOstiumTradingStorage.BuilderFee calldata bf,
        IOstiumTradingStorage.OpenOrderType orderType,
        uint256 slippageP
    ) external;

    /**
     * @notice Close a trade at market price
     * @param pairIndex Trading pair index
     * @param index Position index
     * @param percentageClosed Percentage to close (PRECISION_2, 10000 = 100%)
     * @param expectedPrice Expected closing price
     * @param slippageP Slippage percentage (PRECISION_2)
     */
    function closeTradeMarket(
        uint16 pairIndex,
        uint8 index,
        uint256 percentageClosed,
        uint256 expectedPrice,
        uint256 slippageP
    ) external;

    /**
     * @notice Update stop loss for a position
     * @param pairIndex Trading pair index
     * @param index Position index
     * @param newSl New stop loss price (18 decimals, 0 = remove)
     */
    function updateSl(
        uint16 pairIndex,
        uint8 index,
        uint192 newSl
    ) external;

    /**
     * @notice Update take profit for a position
     * @param pairIndex Trading pair index
     * @param index Position index
     * @param newTp New take profit price (18 decimals, 0 = remove)
     */
    function updateTp(
        uint16 pairIndex,
        uint8 index,
        uint192 newTp
    ) external;
}
