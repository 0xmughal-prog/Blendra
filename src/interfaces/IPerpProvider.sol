// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPerpProvider
 * @notice Interface for perpetual DEX providers (GMX, Avantis, etc.)
 * @dev Abstracted interface to allow swapping between perp providers
 */
interface IPerpProvider {
    /**
     * @notice Increase a perpetual position
     * @param market The market identifier (e.g., GBP/USD)
     * @param collateral Amount of collateral to add
     * @param sizeDelta The size to increase the position by (notional value)
     * @param isLong Whether this is a long position
     */
    function increasePosition(
        bytes32 market,
        uint256 collateral,
        uint256 sizeDelta,
        bool isLong
    ) external;

    /**
     * @notice Decrease a perpetual position
     * @param market The market identifier
     * @param collateralDelta Amount of collateral to remove
     * @param sizeDelta The size to decrease the position by
     * @param isLong Whether this is a long position
     */
    function decreasePosition(
        bytes32 market,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong
    ) external;

    /**
     * @notice Get the current position's profit and loss
     * @param market The market identifier
     * @param account The account holding the position
     * @return pnl The unrealized profit/loss (can be negative)
     */
    function getPositionPnL(bytes32 market, address account) external view returns (int256 pnl);

    /**
     * @notice Get the current position size
     * @param market The market identifier
     * @param account The account holding the position
     * @return size The current position size (notional value)
     */
    function getPositionSize(bytes32 market, address account) external view returns (uint256 size);

    /**
     * @notice Get the current collateral in the position
     * @param market The market identifier
     * @param account The account holding the position
     * @return collateral The current collateral amount
     */
    function getPositionCollateral(bytes32 market, address account) external view returns (uint256 collateral);
}
