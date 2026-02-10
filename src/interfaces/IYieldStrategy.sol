// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IYieldStrategy
 * @notice Standard interface for all yield-generating strategies
 * @dev Implement this interface for any protocol adapter (Morpho, Euler, Dolomite, Curvance, etc.)
 */
interface IYieldStrategy {
    /// @notice Deposit USDC into the underlying protocol
    /// @param amount Amount of USDC to deposit
    /// @return shares Amount of strategy shares/tokens received
    function deposit(uint256 amount) external returns (uint256 shares);

    /// @notice Withdraw USDC from the underlying protocol
    /// @param amount Amount of USDC to withdraw
    /// @return actualAmount Actual USDC withdrawn (may differ due to fees/slippage)
    function withdraw(uint256 amount) external returns (uint256 actualAmount);

    /// @notice Withdraw all funds from strategy
    /// @return amount Total USDC withdrawn
    function withdrawAll() external returns (uint256 amount);

    /// @notice Get maximum withdrawable amount for an owner
    /// @param owner Address to check withdrawal limit for
    /// @return Maximum amount that can be withdrawn
    function maxWithdraw(address owner) external view returns (uint256);

    /// @notice Get total USDC value held by this strategy
    /// @return Total assets in USDC (6 decimals)
    function totalAssets() external view returns (uint256);

    /// @notice Get current APY of the strategy
    /// @return APY in basis points (e.g., 500 = 5.00%)
    function currentAPY() external view returns (uint256);

    /// @notice Emergency withdraw - bypasses normal checks
    /// @return amount Amount of USDC recovered
    function emergencyWithdraw() external returns (uint256 amount);

    /// @notice Get strategy metadata
    /// @return name Human-readable strategy name
    /// @return protocol Protocol name (e.g., "Morpho", "Euler")
    /// @return riskScore Risk score 1-10 (10 = highest risk)
    /// @return isActive Whether strategy is currently operational
    function getMetadata() external view returns (
        string memory name,
        string memory protocol,
        uint256 riskScore,
        bool isActive
    );

    /// Events
    event Deposited(uint256 amount, uint256 shares);
    event Withdrawn(uint256 amount, uint256 shares);
    event EmergencyWithdrawal(uint256 amount);
    event APYUpdated(uint256 oldAPY, uint256 newAPY);
}
