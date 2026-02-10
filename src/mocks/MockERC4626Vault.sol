// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MockERC20.sol";

/**
 * @title MockERC4626Vault
 * @notice Mock ERC4626 vault for testing KPK Morpho strategy
 * @dev Simulates a simple yield-bearing vault like KPK
 */
contract MockERC4626Vault is ERC4626 {
    uint256 public yieldRate; // Yield rate per block in basis points
    uint256 public lastYieldBlock;
    uint256 public accumulatedYield; // Track accumulated yield

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset) ERC20(_name, _symbol) {
        yieldRate = 10; // 0.1% per block (for testing)
        lastYieldBlock = block.number;
    }

    /**
     * @notice Simulate yield accrual by minting real tokens
     */
    function accrueYield() external {
        uint256 blocksSinceLastYield = block.number - lastYieldBlock;
        if (blocksSinceLastYield > 0) {
            uint256 currentAssets = IERC20(asset()).balanceOf(address(this));
            uint256 yieldAmount = (currentAssets * yieldRate * blocksSinceLastYield) / 10000;

            if (yieldAmount > 0) {
                // Mint real tokens to simulate yield (only works with MockERC20)
                MockERC20(asset()).mint(address(this), yieldAmount);
                accumulatedYield += yieldAmount;
            }

            lastYieldBlock = block.number;
        }
    }

    /**
     * @notice Set yield rate for testing
     * @param newRate New yield rate in basis points per block
     */
    function setYieldRate(uint256 newRate) external {
        yieldRate = newRate;
    }

    /**
     * @notice Add yield directly (for testing)
     * @param amount Amount of yield to add
     */
    function addYield(uint256 amount) external {
        if (amount > 0) {
            MockERC20(asset()).mint(address(this), amount);
            accumulatedYield += amount;
        }
    }

    /**
     * @notice Total assets including accrued yield
     * @dev Since we mint real tokens in accrueYield, just return the balance
     */
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    /**
     * @notice Override deposit to ensure it works correctly
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        require(assets > 0, "Cannot deposit 0");

        // Transfer assets from sender first
        IERC20(asset()).transferFrom(msg.sender, address(this), assets);

        // Calculate shares - handle first deposit case
        uint256 supply = totalSupply();
        if (supply == 0) {
            shares = assets; // 1:1 for first deposit
        } else {
            // Calculate shares based on totalAssets BEFORE this deposit
            // Since we already transferred, subtract the new assets to get old total
            shares = (assets * supply) / (totalAssets() - assets);
        }

        require(shares > 0, "Zero shares");

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        return shares;
    }

    /**
     * @notice Override redeem to ensure it works correctly
     */
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        require(shares > 0, "Cannot redeem 0");

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        // Calculate assets - do this before burning
        uint256 supply = totalSupply();
        uint256 totalAssetsBefore = totalAssets();
        assets = (shares * totalAssetsBefore) / supply;
        require(assets > 0, "Zero assets");

        // Burn shares
        _burn(owner, shares);

        // Transfer assets to receiver (now real tokens after minting)
        IERC20(asset()).transfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return assets;
    }
}
