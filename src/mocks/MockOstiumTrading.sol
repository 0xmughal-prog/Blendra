// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/external/IOstiumTrading.sol";
import "../interfaces/external/IOstiumTradingStorage.sol";
import "../ChainlinkOracle.sol";
import "./MockOstiumTradingStorage.sol";

/**
 * @title MockOstiumTrading
 * @notice Mock implementation of Ostium Trading contract for testing
 */
contract MockOstiumTrading is IOstiumTrading {
    IOstiumTradingStorage public tradingStorage;
    ChainlinkOracle public priceOracle;

    event TradeOpened(address trader, uint16 pairIndex, uint8 index, uint256 collateral);
    event TradeClosed(address trader, uint16 pairIndex, uint8 index, uint256 percentageClosed);

    constructor(address _tradingStorage) {
        tradingStorage = IOstiumTradingStorage(_tradingStorage);
    }

    function setPriceOracle(address _oracle) external {
        priceOracle = ChainlinkOracle(_oracle);
    }

    function openTrade(
        IOstiumTradingStorage.Trade calldata t,
        IOstiumTradingStorage.BuilderFee calldata bf,
        IOstiumTradingStorage.OpenOrderType orderType,
        uint256 slippageP
    ) external override {
        // Simulate transferring collateral to storage
        tradingStorage.transferUsdc(msg.sender, address(tradingStorage), t.collateral);

        // Set openPrice from oracle if available (for market orders)
        IOstiumTradingStorage.Trade memory tradeToStore = t;
        if (tradeToStore.openPrice == 0 && address(priceOracle) != address(0)) {
            tradeToStore.openPrice = uint192(priceOracle.getGBPUSDPrice());
        }

        // Store the trade in TradingStorage
        MockOstiumTradingStorage(address(tradingStorage)).storeTrade(tradeToStore);

        emit TradeOpened(t.trader, t.pairIndex, t.index, t.collateral);
    }

    function closeTradeMarket(
        uint16 pairIndex,
        uint8 index,
        uint256 percentageClosed,
        uint256 expectedPrice,
        uint256 slippageP
    ) external override {
        // Get the trade - need to look it up by the actual trader address
        // The msg.sender here is the PerpPositionManager or vault
        IOstiumTradingStorage.Trade memory trade = tradingStorage.openTrades(msg.sender, pairIndex, index);

        require(trade.collateral > 0, "No trade to close");

        // Calculate collateral to return (simplified - no P&L in mock)
        uint256 collateralToReturn = (trade.collateral * percentageClosed) / 10000;

        // Remove or update trade in storage
        MockOstiumTradingStorage(address(tradingStorage)).closeTrade(
            msg.sender,
            pairIndex,
            index,
            percentageClosed
        );

        // Return collateral to trader
        tradingStorage.transferUsdc(address(tradingStorage), msg.sender, collateralToReturn);

        emit TradeClosed(msg.sender, pairIndex, index, percentageClosed);
    }

    function updateSl(uint16 pairIndex, uint8 index, uint192 newSl) external override {
        // Not implemented for mock
    }

    function updateTp(uint16 pairIndex, uint8 index, uint192 newTp) external override {
        // Not implemented for mock
    }
}
