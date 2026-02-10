// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Constants
 * @notice Arbitrum Mainnet contract addresses and configuration
 */
library Constants {
    // ============ Tokens ============

    /// @notice USDC on Arbitrum
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    // ============ Yield Sources ============

    /// @notice KPK Agent-Powered Morpho Vault (ERC4626)
    address internal constant KPK_VAULT = 0x2C609d9CfC9dda2dB5C128B2a665D921ec53579d;

    // ============ Perpetual DEXes ============

    /// @notice Ostium Trading contract
    address internal constant OSTIUM_TRADING = 0x6D0bA1f9996DBD8885827e1b2e8f6593e7702411;

    /// @notice Ostium TradingStorage contract
    address internal constant OSTIUM_STORAGE = 0xcCd5891083A8acD2074690F65d3024E7D13d66E7;

    /// @notice GBP/USD pair index on Ostium (VERIFIED!)
    /// @dev Confirmed from Ostium GraphQL API: pair.id = "3"
    uint16 internal constant GBP_USD_PAIR_INDEX = 3; // ✅ VERIFIED

    // ============ Oracles ============

    /// @notice Chainlink GBP/USD Price Feed on Arbitrum
    /// @dev Feed: https://data.chain.link/feeds/arbitrum/mainnet/gbp-usd
    address internal constant CHAINLINK_GBP_USD = 0x9C4424Fd84C6661F97D8d6b3fc3C1aAc2BeDd137;

    // ============ Vault Configuration ============

    /// @notice Yield allocation (90%)
    uint256 internal constant YIELD_ALLOCATION = 9000;

    /// @notice Perp allocation (10%)
    uint256 internal constant PERP_ALLOCATION = 1000;

    /// @notice Target leverage (10x)
    uint256 internal constant TARGET_LEVERAGE = 10;

    /// @notice Basis points precision
    uint256 internal constant BASIS_POINTS = 10000;
}
