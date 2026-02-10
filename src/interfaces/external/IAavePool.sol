// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAavePool
 * @notice Interface for Aave V3 Pool
 * @dev Simplified interface with only the functions we need
 */
interface IAavePool {
    /**
     * @notice Supplies an amount of underlying asset into the reserve
     * @param asset The address of the underlying asset to supply
     * @param amount The amount to be supplied
     * @param onBehalfOf The address that will receive the aTokens
     * @param referralCode Code used to register the integrator
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    /**
     * @notice Withdraws an amount of underlying asset from the reserve
     * @param asset The address of the underlying asset to withdraw
     * @param amount The underlying amount to be withdrawn (use type(uint256).max for full withdrawal)
     * @param to The address that will receive the underlying
     * @return The final amount withdrawn
     */
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

/**
 * @title IAToken
 * @notice Interface for Aave aTokens
 */
interface IAToken {
    /**
     * @notice Returns the amount of tokens owned by account
     * @param account The address to query
     * @return The balance
     */
    function balanceOf(address account) external view returns (uint256);
}
