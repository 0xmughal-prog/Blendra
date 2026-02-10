// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/external/IAavePool.sol";
import "./MockERC20.sol";

/**
 * @title MockAavePool
 * @notice Mock Aave V3 Pool for testing
 */
contract MockAavePool is IAavePool {
    using SafeERC20 for IERC20;

    /// @notice Interest rate per supply call (in basis points)
    uint256 public interestRate = 500; // 5% per supply

    /// @notice Mapping of asset => aToken
    mapping(address => address) public aTokens;

    /// @notice Mapping of user => asset => supplied amount
    mapping(address => mapping(address => uint256)) public suppliedAmounts;

    event Supply(address indexed asset, uint256 amount, address indexed onBehalfOf);
    event Withdraw(address indexed asset, uint256 amount, address indexed to);

    /**
     * @notice Set the aToken for an asset
     */
    function setAToken(address asset, address aToken) external {
        aTokens[asset] = aToken;
    }

    /**
     * @notice Supply assets to the pool
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external override {
        require(amount > 0, "Zero amount");
        require(aTokens[asset] != address(0), "No aToken set");

        // Transfer underlying from sender
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Mint aTokens to onBehalfOf
        MockERC20(aTokens[asset]).mint(onBehalfOf, amount);

        // Track supplied amount
        suppliedAmounts[onBehalfOf][asset] += amount;

        emit Supply(asset, amount, onBehalfOf);
    }

    /**
     * @notice Withdraw assets from the pool
     */
    function withdraw(address asset, uint256 amount, address to) external override returns (uint256) {
        require(amount > 0, "Zero amount");
        require(aTokens[asset] != address(0), "No aToken set");

        address aToken = aTokens[asset];
        uint256 aTokenBalance = IERC20(aToken).balanceOf(msg.sender);

        // If amount is max uint, withdraw everything
        uint256 withdrawAmount = amount == type(uint256).max ? aTokenBalance : amount;
        require(withdrawAmount <= aTokenBalance, "Insufficient aTokens");

        // Burn aTokens from sender
        MockERC20(aToken).burn(msg.sender, withdrawAmount);

        // Simulate interest accrual (add small percentage)
        uint256 interest = (withdrawAmount * interestRate) / 10000;
        uint256 totalReturn = withdrawAmount + interest;

        // Transfer underlying to recipient
        // Mint additional underlying to simulate interest
        if (interest > 0) {
            MockERC20(asset).mint(address(this), interest);
        }

        IERC20(asset).safeTransfer(to, totalReturn);

        emit Withdraw(asset, withdrawAmount, to);

        return totalReturn;
    }

    /**
     * @notice Set interest rate for testing
     */
    function setInterestRate(uint256 newRate) external {
        interestRate = newRate;
    }
}
