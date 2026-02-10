// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "../interfaces/IYieldStrategy.sol";

/**
 * @title EulerStrategy
 * @notice Yield strategy adapter for Euler v2 (ERC4626 compliant)
 * @dev Euler v2 uses isolated lending markets with risk tiers
 *
 * Euler Features:
 * - Isolated markets (each market independent)
 * - Risk tiers (collateral/isolation/cross)
 * - ERC4626 compliant vaults
 * - Permissionless market creation
 *
 * Risk Considerations:
 * - Oracle risk (price manipulation)
 * - Isolated market risk (less liquidity)
 * - Tier-specific risks
 */
contract EulerStrategy is IYieldStrategy, Ownable {
    using SafeERC20 for IERC20;

    /// @notice USDC token
    IERC20 public immutable usdc;

    /// @notice Euler v2 vault (ERC4626)
    IERC4626 public immutable eulerVault;

    /// @notice Main GBP Yield Vault
    address public immutable vault;

    /// @notice Euler market/tier identifier
    uint256 public immutable marketTier;

    /// @notice Risk score (1-10, where 10 is highest risk)
    uint256 public immutable riskScore;

    /// @notice Last known APY (updated periodically)
    uint256 public lastKnownAPY;

    /// Events
    event APYUpdated(uint256 oldAPY, uint256 newAPY, uint256 timestamp);

    /// Errors
    error OnlyVault();
    error InsufficientAssets();
    error DepositFailed();
    error WithdrawFailed();

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    /**
     * @notice Constructor
     * @param _usdc USDC token address
     * @param _eulerVault Euler v2 vault address (ERC4626)
     * @param _vault Main GBP Yield Vault address
     * @param _marketTier Euler market tier (1=collateral, 2=isolation, 3=cross)
     * @param _riskScore Risk score 1-10
     */
    constructor(
        address _usdc,
        address _eulerVault,
        address _vault,
        uint256 _marketTier,
        uint256 _riskScore
    ) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC");
        require(_eulerVault != address(0), "Invalid Euler vault");
        require(_vault != address(0), "Invalid vault");
        require(_marketTier >= 1 && _marketTier <= 3, "Invalid tier");
        require(_riskScore >= 1 && _riskScore <= 10, "Invalid risk score");

        usdc = IERC20(_usdc);
        eulerVault = IERC4626(_eulerVault);
        vault = _vault;
        marketTier = _marketTier;
        riskScore = _riskScore;

        // Verify Euler vault uses USDC as asset
        require(eulerVault.asset() == _usdc, "Vault asset mismatch");
    }

    /**
     * @notice Deposit USDC into Euler vault
     * @param amount Amount of USDC to deposit
     * @return shares Amount of Euler vault shares received
     */
    function deposit(uint256 amount) external override onlyVault returns (uint256 shares) {
        if (amount == 0) revert DepositFailed();

        // Transfer USDC from vault
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Approve Euler vault
        usdc.forceApprove(address(eulerVault), amount);

        // Deposit into Euler (ERC4626)
        shares = eulerVault.deposit(amount, address(this));

        if (shares == 0) revert DepositFailed();

        emit Deposited(amount, shares);
    }

    /**
     * @notice Withdraw USDC from Euler vault
     * @param amount Amount of USDC to withdraw
     * @return actualAmount Actual USDC withdrawn
     */
    function withdraw(uint256 amount) external override onlyVault returns (uint256 actualAmount) {
        if (amount == 0) revert WithdrawFailed();

        uint256 totalHoldings = totalAssets();
        if (amount > totalHoldings) {
            amount = totalHoldings; // Withdraw max available
        }

        // Calculate shares needed for withdrawal
        uint256 shares = eulerVault.previewWithdraw(amount);

        // Withdraw from Euler (burns shares, returns USDC)
        actualAmount = eulerVault.redeem(shares, vault, address(this));

        emit Withdrawn(actualAmount, shares);
    }

    /**
     * @notice Withdraw all USDC from strategy
     * @return amount Total USDC withdrawn
     */
    function withdrawAll() external override onlyVault returns (uint256 amount) {
        uint256 shares = eulerVault.balanceOf(address(this));
        if (shares == 0) return 0;

        // Redeem all shares
        amount = eulerVault.redeem(shares, vault, address(this));

        emit Withdrawn(amount, shares);
    }

    /**
     * @notice Get total USDC value in Euler vault
     * @return Total assets in USDC (6 decimals)
     */
    function totalAssets() public view override returns (uint256) {
        uint256 shares = eulerVault.balanceOf(address(this));
        return eulerVault.convertToAssets(shares);
    }

    /**
     * @notice Get maximum withdrawable amount from Euler vault
     * @param owner Address to check (ignored, checks this contract's balance)
     * @return Maximum USDC that can be withdrawn
     * @dev ✅ FIX VULN-2: Added to check Euler liquidity before harvest
     */
    function maxWithdraw(address owner) external view override returns (uint256) {
        // Euler is ERC4626 compliant, use its maxWithdraw
        return eulerVault.maxWithdraw(address(this));
    }

    /**
     * @notice Get current APY estimate
     * @return APY in basis points (e.g., 500 = 5%)
     * @dev For production, fetch from Euler's analytics or calculate from rate model
     */
    function currentAPY() external view override returns (uint256) {
        // In production, calculate from:
        // 1. Euler's interest rate model
        // 2. Current utilization rate
        // 3. Historical returns

        // For now, return last known APY
        return lastKnownAPY;
    }

    /**
     * @notice Emergency withdraw - bypasses normal checks
     * @return amount Amount recovered
     */
    function emergencyWithdraw() external override onlyOwner returns (uint256 amount) {
        uint256 shares = eulerVault.balanceOf(address(this));
        if (shares == 0) return 0;

        // Emergency redeem all
        amount = eulerVault.redeem(shares, owner(), address(this));

        emit EmergencyWithdrawal(amount);
    }

    /**
     * @notice Get strategy metadata
     */
    function getMetadata() external view override returns (
        string memory name,
        string memory protocol,
        uint256 risk,
        bool isActive
    ) {
        // Tier names
        string memory tierName;
        if (marketTier == 1) tierName = "Collateral";
        else if (marketTier == 2) tierName = "Isolation";
        else tierName = "Cross";

        name = string(abi.encodePacked("Euler USDC ", tierName));
        protocol = "Euler v2";
        risk = riskScore;
        isActive = true;
    }


    /**
     * @notice Update APY estimate (owner/keeper only)
     * @param newAPY New APY in basis points
     */
    function updateAPY(uint256 newAPY) external onlyOwner {
        uint256 oldAPY = lastKnownAPY;
        lastKnownAPY = newAPY;

        emit APYUpdated(oldAPY, newAPY, block.timestamp);
    }

    /**
     * @notice Get Euler vault info
     * @return asset Underlying asset (USDC)
     * @return vaultTotalAssets Total USDC in Euler vault
     * @return totalSupply Total Euler vault shares
     * @return sharePrice Price per share
     */
    function getEulerVaultInfo() external view returns (
        address asset,
        uint256 vaultTotalAssets,
        uint256 totalSupply,
        uint256 sharePrice
    ) {
        asset = eulerVault.asset();
        vaultTotalAssets = eulerVault.totalAssets();
        totalSupply = eulerVault.totalSupply();
        sharePrice = totalSupply > 0
            ? (vaultTotalAssets * 1e18) / totalSupply
            : 1e18;
    }
}
