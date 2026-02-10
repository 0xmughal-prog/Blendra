// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/external/IOstiumTradingStorage.sol";

/**
 * @title MockOstiumTradingStorage
 * @notice Mock implementation of Ostium TradingStorage contract for testing
 */
contract MockOstiumTradingStorage is IOstiumTradingStorage {
    using SafeERC20 for IERC20;

    IERC20 public usdc;

    // Mapping: trader => pairIndex => index => Trade
    mapping(address => mapping(uint16 => mapping(uint8 => Trade))) private _openTrades;
    mapping(address => mapping(uint16 => mapping(uint8 => Trade))) private _openLimitOrders;

    // Simulated P&L for testing
    mapping(address => mapping(uint16 => mapping(uint8 => int256))) public simulatedPnL;

    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }

    function openTrades(address trader, uint16 pairIndex, uint8 index)
        external
        view
        override
        returns (Trade memory)
    {
        return _openTrades[trader][pairIndex][index];
    }

    function openLimitOrders(address trader, uint16 pairIndex, uint8 index)
        external
        view
        override
        returns (Trade memory)
    {
        return _openLimitOrders[trader][pairIndex][index];
    }

    function transferUsdc(address from, address to, uint256 amount) external override {
        if (from == address(this)) {
            usdc.safeTransfer(to, amount);
        } else {
            usdc.safeTransferFrom(from, to, amount);
        }
    }

    // Helper functions for mock (not in real interface)
    function storeTrade(Trade calldata t) external {
        Trade storage existing = _openTrades[t.trader][t.pairIndex][t.index];

        // If position already exists, increase it (add collateral)
        if (existing.collateral > 0) {
            existing.collateral += t.collateral;
            // Keep the original openPrice (weighted average could be more accurate but simple for mock)
            // Leverage stays the same
        } else {
            // New position
            _openTrades[t.trader][t.pairIndex][t.index] = t;
        }
    }

    function closeTrade(address trader, uint16 pairIndex, uint8 index, uint256 percentageClosed) external {
        Trade storage trade = _openTrades[trader][pairIndex][index];

        if (percentageClosed >= 10000) {
            // Full close - delete the trade
            delete _openTrades[trader][pairIndex][index];
        } else {
            // Partial close - reduce collateral proportionally
            uint256 remainingPercentage = 10000 - percentageClosed;
            trade.collateral = (trade.collateral * remainingPercentage) / 10000;
            // Leverage stays the same
        }
    }

    function setPnL(address trader, uint16 pairIndex, uint8 index, int256 pnl) external {
        simulatedPnL[trader][pairIndex][index] = pnl;
    }

    function getPnL(address trader, uint16 pairIndex, uint8 index) external view returns (int256) {
        return simulatedPnL[trader][pairIndex][index];
    }
}
