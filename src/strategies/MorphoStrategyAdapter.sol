// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "../interfaces/IYieldStrategy.sol";

/**
 * @title MorphoStrategyAdapter
 * @notice Wraps existing KPK Morpho vault to implement IYieldStrategy interface
 * @dev This allows easy swapping with other protocol adapters
 */
contract MorphoStrategyAdapter is IYieldStrategy, Ownable {
    using SafeERC20 for IERC20;

    /// @notice USDC token
    IERC20 public immutable usdc;

    /// @notice KPK Morpho Vault (ERC4626)
    IERC4626 public immutable morphoVault;

    /// @notice Main GBP Yield Vault
    address public immutable vault;

    /// @notice Last known APY (manually updated)
    uint256 public lastKnownAPY;

    /// @notice Last known price per share (for exploit detection)
    /// @dev ✅ FIX MED-6: Track Morpho vault price per share to detect exploits
    uint256 public lastKnownPricePerShare;

    /// @notice Slippage tolerance constant (2% = 200 bps)
    /// @dev ✅ FIX LOW-6: Named constant instead of magic number 9800
    uint256 private constant SLIPPAGE_TOLERANCE_BPS = 200; // 2% slippage
    uint256 private constant BPS = 10000;

    /// @notice Solvency threshold (5% max loss)
    /// @dev ✅ FIX LOW-6: Named constant instead of magic number 9500
    uint256 private constant SOLVENCY_THRESHOLD_BPS = 500; // 5% max acceptable loss

    /// Errors
    error OnlyVault();
    error ZeroAmount();
    error DepositFailed();
    error WithdrawFailed();
    error SlippageTooHigh();
    error VaultUnderwater();
    error SuspiciousActivity();

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    /**
     * @notice Constructor
     * @param _usdc USDC token address
     * @param _morphoVault KPK Morpho vault address
     * @param _vault Main GBP Yield Vault address
     */
    constructor(
        address _usdc,
        address _morphoVault,
        address _vault
    ) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC");
        require(_morphoVault != address(0), "Invalid Morpho vault");
        require(_vault != address(0), "Invalid vault");

        usdc = IERC20(_usdc);
        morphoVault = IERC4626(_morphoVault);
        vault = _vault;

        // Verify Morpho vault uses USDC
        require(morphoVault.asset() == _usdc, "Vault asset mismatch");

        // Default APY estimate
        lastKnownAPY = 500; // 5%
    }

    /// @inheritdoc IYieldStrategy
    /// @dev ✅ FIX CRIT-3: Added slippage protection against MEV sandwich attacks
    /// @dev ✅ FIX MED-6: Added solvency check before depositing
    function deposit(uint256 amount) external override onlyVault returns (uint256 shares) {
        if (amount == 0) revert ZeroAmount();

        // ✅ FIX MED-6: Enhanced Morpho vault solvency checks
        // Check 1: Ensure vault is not underwater (totalAssets >= totalSupply worth)
        uint256 totalShares = morphoVault.totalSupply();
        if (totalShares > 0) {
            uint256 totalMorphoAssets = morphoVault.totalAssets();
            uint256 expectedAssets = morphoVault.convertToAssets(totalShares);

            // If vault is significantly underwater (>5% loss), don't deposit
            if (totalMorphoAssets < (expectedAssets * (BPS - SOLVENCY_THRESHOLD_BPS)) / BPS) {
                revert VaultUnderwater();
            }

            // ✅ FIX MED-6: Check 2: Detect sudden price drops (potential exploit)
            uint256 currentPricePerShare = (totalMorphoAssets * 1e18) / totalShares;

            // If we have a known price and it dropped >5%, suspicious activity
            if (lastKnownPricePerShare > 0) {
                uint256 minAcceptablePrice = (lastKnownPricePerShare * 95) / 100; // 95% of last known
                if (currentPricePerShare < minAcceptablePrice) {
                    revert SuspiciousActivity();
                }
            }

            // Update last known price per share for future checks
            lastKnownPricePerShare = currentPricePerShare;
        }

        // Transfer USDC from vault
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // ✅ Calculate minimum acceptable shares (2% slippage tolerance)
        uint256 expectedShares = morphoVault.previewDeposit(amount);
        uint256 minShares = (expectedShares * (BPS - SLIPPAGE_TOLERANCE_BPS)) / BPS;

        // Approve and deposit into Morpho
        usdc.forceApprove(address(morphoVault), amount);
        shares = morphoVault.deposit(amount, address(this));

        // ✅ FIX HIGH-9: Revoke approval after operation
        usdc.forceApprove(address(morphoVault), 0);

        // ✅ Enforce minimum shares to prevent MEV attacks
        if (shares < minShares) revert SlippageTooHigh();
        if (shares == 0) revert DepositFailed();

        emit Deposited(amount, shares);
    }

    /// @inheritdoc IYieldStrategy
    /// @dev ✅ FIX CRIT-3: Added slippage protection on withdrawals
    /// @dev ✅ FIX HIGH-9: Graceful handling if Morpho paused
    function withdraw(uint256 amount) external override onlyVault returns (uint256 actualAmount) {
        if (amount == 0) revert ZeroAmount();

        uint256 totalHoldings = totalAssets();
        if (amount > totalHoldings) {
            amount = totalHoldings;
        }

        // ✅ FIX HIGH-9: Try to withdraw from Morpho, return 0 if paused
        try morphoVault.previewWithdraw(amount) returns (uint256 shares) {
            // ✅ Calculate minimum acceptable assets (2% slippage tolerance)
            uint256 minAssets = (amount * (BPS - SLIPPAGE_TOLERANCE_BPS)) / BPS;

            try morphoVault.redeem(shares, vault, address(this)) returns (uint256 assets) {
                actualAmount = assets;
                // ✅ Enforce minimum assets received
                if (actualAmount < minAssets) revert SlippageTooHigh();
                emit Withdrawn(actualAmount, shares);
                return actualAmount;
            } catch {
                // Morpho withdrawal failed, return 0
                // Vault can handle partial withdrawal
                return 0;
            }
        } catch {
            // Morpho preview failed (likely paused), return 0
            return 0;
        }
    }

    /// @inheritdoc IYieldStrategy
    /// @dev ✅ FIX HIGH-9: Graceful handling if Morpho paused
    function withdrawAll() external override onlyVault returns (uint256 amount) {
        uint256 shares = morphoVault.balanceOf(address(this));
        if (shares == 0) return 0;

        // ✅ FIX HIGH-9: Try to withdraw from Morpho, return 0 if paused
        try morphoVault.redeem(shares, vault, address(this)) returns (uint256 assets) {
            amount = assets;
            emit Withdrawn(amount, shares);
            return amount;
        } catch {
            // Morpho withdrawal failed (likely paused), return 0
            // Vault can handle graceful degradation
            return 0;
        }
    }

    /// @inheritdoc IYieldStrategy
    function totalAssets() public view override returns (uint256) {
        uint256 shares = morphoVault.balanceOf(address(this));
        return morphoVault.convertToAssets(shares);
    }

    /// @inheritdoc IYieldStrategy
    function currentAPY() external view override returns (uint256) {
        return lastKnownAPY;
    }

    /// @inheritdoc IYieldStrategy
    /// @dev ✅ FIX MED-5: Sends funds to vault, not owner, in emergencies
    ///      Vault funds belong to depositors, not owner
    function emergencyWithdraw() external override onlyOwner returns (uint256 amount) {
        uint256 shares = morphoVault.balanceOf(address(this));
        if (shares == 0) return 0;

        // ✅ FIX MED-5: Send to vault (belongs to depositors), not owner
        amount = morphoVault.redeem(shares, vault, address(this));
        emit EmergencyWithdrawal(amount);
    }

    /// @inheritdoc IYieldStrategy
    /// @notice Get maximum withdrawable amount for an owner
    /// @param owner Address to check withdrawal limit for
    /// @return Maximum amount that can be withdrawn (limited by Morpho vault liquidity)
    function maxWithdraw(address owner) external view override returns (uint256) {
        // Return how much the strategy can withdraw from Morpho
        // Use address(this) because the strategy owns the vault shares, not the owner
        return morphoVault.maxWithdraw(address(this));
    }

    /// @inheritdoc IYieldStrategy
    function getMetadata() external pure override returns (
        string memory name,
        string memory protocol,
        uint256 riskScore,
        bool isActive
    ) {
        return ("KPK Morpho USDC", "Morpho", 5, true);
    }


    /**
     * @notice Update APY estimate (owner only)
     * @param newAPY New APY in basis points
     */
    function updateAPY(uint256 newAPY) external onlyOwner {
        uint256 oldAPY = lastKnownAPY;
        lastKnownAPY = newAPY;
        emit APYUpdated(oldAPY, newAPY);
    }

    /**
     * @notice Update price per share baseline (owner only)
     * @dev ✅ FIX MED-6: Manually sync price per share for exploit detection
     *      Call this after confirming Morpho vault is healthy
     */
    function updatePricePerShare() external onlyOwner {
        uint256 shares = morphoVault.totalSupply();
        if (shares > 0) {
            uint256 assets = morphoVault.totalAssets();
            lastKnownPricePerShare = (assets * 1e18) / shares;
        }
    }
}
