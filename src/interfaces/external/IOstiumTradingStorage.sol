// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOstiumTradingStorage
 * @notice Interface for Ostium's TradingStorage contract
 * @dev Based on Ostium's smart contract at 0xcCd5891083A8acD2074690F65d3024E7D13d66E7
 */
interface IOstiumTradingStorage {
    struct Trade {
        uint256 collateral;      // USDC amount (6 decimals)
        uint192 openPrice;       // Execution price limit (18 decimals)
        uint192 tp;              // Take profit (18 decimals, 0 = none)
        uint192 sl;              // Stop loss (18 decimals, 0 = none)
        address trader;          // Trader address (our vault)
        uint32 leverage;         // Leverage with PRECISION_2 (1000 = 10x)
        uint16 pairIndex;        // Trading pair index (e.g., GBP/USD)
        uint8 index;             // Position index for the trader
        bool buy;                // true = long, false = short
    }

    struct BuilderFee {
        address builder;         // Fee recipient address
        uint32 builderFee;       // Fee % with PRECISION_6 (5000 = 0.005%)
    }

    enum OpenOrderType {
        MARKET,
        LIMIT
    }

    /**
     * @notice Get a trader's position
     * @param trader The trader address
     * @param pairIndex The pair index
     * @param index The position index
     * @return The trade struct
     */
    function openTrades(address trader, uint16 pairIndex, uint8 index)
        external
        view
        returns (Trade memory);

    /**
     * @notice Get trader's open limit order
     * @param trader The trader address
     * @param pairIndex The pair index
     * @param index The order index
     * @return The trade struct
     */
    function openLimitOrders(address trader, uint16 pairIndex, uint8 index)
        external
        view
        returns (Trade memory);

    /**
     * @notice Transfer USDC tokens
     * @param from Source address
     * @param to Destination address
     * @param amount Amount to transfer
     */
    function transferUsdc(address from, address to, uint256 amount) external;
}
