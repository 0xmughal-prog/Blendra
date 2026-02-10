// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IPerpProvider.sol";

/**
 * @title PerpPositionManager
 * @notice Manages perpetual positions for GBP/USD hedging
 * @dev Abstracted to work with any IPerpProvider implementation (GMX, Avantis, etc.)
 * @dev ✅ FIX VULN-24: Uses Ownable2Step for safer ownership transfers
 */
contract PerpPositionManager is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The vault that owns this position manager
    address public immutable vault;

    /// @notice The collateral token (e.g., USDC)
    IERC20 public immutable collateralToken;

    /// @notice The perpetual DEX provider
    IPerpProvider public perpProvider;

    /// @notice The market identifier for GBP/USD
    bytes32 public immutable gbpUsdMarket;

    /// @notice Current total notional position size
    uint256 public currentNotional;

    /// @notice Current total collateral in the position
    uint256 public currentCollateral;

    /// @notice Whether positions are long (true) or short (false)
    bool public constant IS_LONG = true; // We're always long GBP/USD

    /// @notice Minimum collateral ratio (basis points, 2000 = 20% = 5x max leverage)
    /// @dev ✅ FIX HIGH-5: Prevents undercollateralized positions
    /// @dev ✅ SECURITY: More conservative 5x max leverage to protect against FX volatility
    uint256 public constant MIN_COLLATERAL_RATIO_BPS = 2000; // 20% minimum (allows 5x leverage, was 10x)

    /// @notice Liquidation threshold (basis points, 3000 = 30% = warning level)
    /// @dev ✅ FIX HIGH-8: Monitor health factor to prevent liquidations
    uint256 public constant LIQUIDATION_WARNING_THRESHOLD_BPS = 3000; // 30%

    /// @notice Timelock for perp provider changes (24 hours)
    uint256 public constant PERP_PROVIDER_TIMELOCK = 24 hours;

    /// @notice Cooldown period between proposals (12 hours)
    /// @dev ✅ FIX MED-NEW-1: Prevents timelock bypass via proposal cycling
    uint256 public constant PROPOSAL_COOLDOWN = 12 hours;

    /// @notice Pending perp provider (during timelock)
    IPerpProvider public pendingPerpProvider;

    /// @notice Timestamp when pending provider can be activated
    uint256 public perpProviderChangeTimestamp;

    /// @notice Timestamp of last proposal (to enforce cooldown)
    /// @dev ✅ FIX MED-NEW-1: Prevents rapid proposal cycling
    uint256 public lastProposalTimestamp;

    /// @notice Emitted when a position is increased
    event PositionIncreased(uint256 notionalSize, uint256 collateral);

    /// @notice Emitted when a position is decreased
    event PositionDecreased(uint256 shareRatio, uint256 notionalReduced, uint256 collateralReduced);

    /// @notice Emitted when perp provider is updated
    event PerpProviderUpdated(address oldProvider, address newProvider);

    /// @notice Emitted when perp provider change is proposed
    event PerpProviderProposed(address indexed oldProvider, address indexed newProvider, uint256 activationTime);

    /// @notice Emitted when perp provider proposal is cancelled
    event PerpProviderProposalCancelled(address indexed cancelledProvider);

    /// @notice ✅ FIX HIGH-8: Emitted when position approaches liquidation
    event LiquidationWarning(uint256 healthFactor, int256 pnl, uint256 collateral);

    error OnlyVault();
    error ZeroAmount();
    error InvalidProvider();
    error InvalidShareRatio();
    error TimelockNotExpired();
    error NoPendingProvider();
    error ProviderNotChanged();
    error InsufficientCollateralRatio();
    error PositionNearLiquidation();
    error ProposalCooldownActive();
    error DeadlineExpired();

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    /**
     * @notice Constructor
     * @param _vault Address of the vault
     * @param _collateralToken Address of the collateral token
     * @param _perpProvider Address of the initial perp provider
     * @param _gbpUsdMarket Market identifier for GBP/USD
     */
    constructor(
        address _vault,
        address _collateralToken,
        address _perpProvider,
        bytes32 _gbpUsdMarket
    ) Ownable(msg.sender) {
        require(_vault != address(0), "Invalid vault");
        require(_collateralToken != address(0), "Invalid collateral");
        require(_perpProvider != address(0), "Invalid provider");
        require(_gbpUsdMarket != bytes32(0), "Invalid market");

        vault = _vault;
        collateralToken = IERC20(_collateralToken);
        perpProvider = IPerpProvider(_perpProvider);
        gbpUsdMarket = _gbpUsdMarket;
    }

    /**
     * @notice Increase the perpetual position
     * @param notionalSize Total notional size to achieve (e.g., $1000)
     * @param collateral Collateral amount to add (e.g., $200 for 5x leverage)
     * @param deadline Timestamp after which transaction reverts (prevents stale execution)
     * @dev ✅ FIX HIGH-5: Now enforces minimum collateral ratio
     * @dev ✅ FIX HIGH-8: Deadline prevents stale price execution and MEV
     */
    function increasePosition(uint256 notionalSize, uint256 collateral, uint256 deadline) external onlyVault nonReentrant {
        if (notionalSize == 0 || collateral == 0) revert ZeroAmount();

        // ✅ FIX HIGH-8: Prevent stale transaction execution
        if (block.timestamp > deadline) revert DeadlineExpired();

        // ✅ FIX HIGH-5: Enforce minimum collateral ratio
        // Collateral must be at least 20% of notional (for 5x max leverage)
        // collateral / notionalSize >= MIN_COLLATERAL_RATIO_BPS / 10000
        // collateral * 10000 >= notionalSize * MIN_COLLATERAL_RATIO_BPS
        if (collateral * 10000 < notionalSize * MIN_COLLATERAL_RATIO_BPS) {
            revert InsufficientCollateralRatio();
        }

        // Transfer collateral from vault to this contract
        collateralToken.safeTransferFrom(msg.sender, address(this), collateral);

        // Approve perp provider to spend collateral
        collateralToken.forceApprove(address(perpProvider), collateral);

        // Open/increase position on perp DEX
        // ✅ FIX: Forward explicit gas through the call chain
        perpProvider.increasePosition{gas: 3500000}(
            gbpUsdMarket,
            collateral,
            notionalSize,
            IS_LONG
        );

        // ⚠️ FIX CRITICAL: Sync with actual position instead of assuming input values
        // Actual position may differ due to fees, slippage, partial fills
        uint256 actualSize = perpProvider.getPositionSize(gbpUsdMarket, address(this));
        uint256 actualCollateral = perpProvider.getPositionCollateral(gbpUsdMarket, address(this));

        // ⚠️ FIX CRITICAL: Get health before update to compare
        uint256 healthBefore = currentNotional > 0 ? getHealthFactor() : 10000;

        // Update tracking with ACTUAL values from DEX
        currentNotional = actualSize;
        currentCollateral = actualCollateral;

        // ✅ FIX HIGH-8: Check for liquidation risk (allows improving health)
        _checkLiquidationRisk(healthBefore);

        emit PositionIncreased(notionalSize, collateral);
    }

    /**
     * @notice Decrease the perpetual position based on share ratio
     * @param shareRatio The proportion of the position to close (in 1e18 precision)
     * @param deadline Timestamp after which transaction reverts (prevents stale execution)
     * @dev ✅ FIX HIGH-8: Deadline prevents stale price execution and MEV
     */
    function decreasePosition(uint256 shareRatio, uint256 deadline) external onlyVault nonReentrant {
        if (shareRatio == 0) revert ZeroAmount();
        if (shareRatio > 1e18) revert InvalidShareRatio();

        // ✅ FIX HIGH-8: Prevent stale transaction execution
        if (block.timestamp > deadline) revert DeadlineExpired();

        // Calculate position reduction
        uint256 reduceNotional = (currentNotional * shareRatio) / 1e18;
        uint256 reduceCollateral = (currentCollateral * shareRatio) / 1e18;

        if (reduceNotional == 0 || reduceCollateral == 0) revert ZeroAmount();

        // Close proportional position on perp DEX
        perpProvider.decreasePosition(
            gbpUsdMarket,
            reduceCollateral,
            reduceNotional,
            IS_LONG
        );

        // ⚠️ FIX CRITICAL: Sync with actual position after close
        uint256 actualSize = perpProvider.getPositionSize(gbpUsdMarket, address(this));
        uint256 actualCollateral = perpProvider.getPositionCollateral(gbpUsdMarket, address(this));

        // Update with actual remaining position
        currentNotional = actualSize;
        currentCollateral = actualCollateral;

        // Transfer any returned collateral to vault (external call last)
        uint256 balance = collateralToken.balanceOf(address(this));
        if (balance > 0) {
            collateralToken.safeTransfer(vault, balance);
        }

        emit PositionDecreased(shareRatio, reduceNotional, reduceCollateral);
    }

    /**
     * @notice Get the current position's profit and loss
     * @return pnl The unrealized profit/loss (can be negative)
     */
    function getPositionPnL() external view returns (int256 pnl) {
        return perpProvider.getPositionPnL(gbpUsdMarket, address(this));
    }

    /**
     * @notice Get current position details
     * @return notional Current notional size
     * @return collateral Current collateral
     * @return size Position size from provider
     */
    function getPositionDetails() external view returns (
        uint256 notional,
        uint256 collateral,
        uint256 size
    ) {
        notional = currentNotional;
        collateral = currentCollateral;
        size = perpProvider.getPositionSize(gbpUsdMarket, address(this));
    }

    /**
     * @notice Get the total value of the position (collateral + PnL)
     * @return value Total position value in collateral token
     */
    function getPositionValue() external view returns (uint256 value) {
        int256 pnl = perpProvider.getPositionPnL(gbpUsdMarket, address(this));
        int256 totalValue = int256(currentCollateral) + pnl;
        // Return 0 if position is negative (underwater)
        return totalValue > 0 ? uint256(totalValue) : 0;
    }

    /**
     * @notice Get position health factor
     * @return healthFactor Health factor in basis points (10000 = 100% = fully collateralized)
     * @dev ✅ FIX HIGH-8: Monitor position health to prevent liquidations
     *      healthFactor = (collateral + PnL) / (notionalSize / leverage) * 10000
     *      If healthFactor < 3000 (30%), position is at risk of liquidation
     */
    function getHealthFactor() public view returns (uint256 healthFactor) {
        // ⚠️ FIX CRITICAL: Multiple zero checks to prevent division by zero
        if (currentNotional == 0 || currentCollateral == 0) {
            return 10000; // 100% - no position
        }

        int256 pnl = perpProvider.getPositionPnL(gbpUsdMarket, address(this));
        int256 positionValue = int256(currentCollateral) + pnl;

        if (positionValue <= 0) {
            return 0; // Underwater
        }

        // ⚠️ FIX CRITICAL: Additional safety check before division
        if (currentCollateral == 0) {
            return 0; // Prevent division by zero
        }

        // Health factor = position value / collateral * 10000
        healthFactor = (uint256(positionValue) * 10000) / currentCollateral;
    }

    /**
     * @notice Check if position is near liquidation and emit warning
     * @dev ⚠️ FIX CRITICAL: Only prevents positions that WORSEN health
     *      Allows deposits that add collateral and improve health
     * @param healthFactorBefore Health factor before the operation
     */
    function _checkLiquidationRisk(uint256 healthFactorBefore) internal {
        if (currentNotional == 0) return; // No position

        uint256 healthFactorAfter = getHealthFactor();

        // If health factor at or below 30%, emit warning
        if (healthFactorAfter <= LIQUIDATION_WARNING_THRESHOLD_BPS) {
            int256 pnl = perpProvider.getPositionPnL(gbpUsdMarket, address(this));
            emit LiquidationWarning(healthFactorAfter, pnl, currentCollateral);

            // ⚠️ FIX CRITICAL: Only revert if health is critical AND got worse
            // Allow operations that improve health even if still below threshold
            if (healthFactorAfter < MIN_COLLATERAL_RATIO_BPS) {
                // If health improved or stayed same, allow it (user adding collateral)
                if (healthFactorAfter >= healthFactorBefore) {
                    // Health improved or maintained, allow operation
                    return;
                }
                // Health got worse and is below 20%, prevent operation
                revert PositionNearLiquidation();
            }
        }
    }

    /**
     * @notice Decrease position by withdrawing collateral amount
     * @param withdrawAmount Amount of collateral to withdraw
     * @return actualWithdrawn Amount actually returned to vault
     */
    function withdrawCollateral(uint256 withdrawAmount) external onlyVault nonReentrant returns (uint256 actualWithdrawn) {
        if (withdrawAmount == 0) revert ZeroAmount();
        if (currentCollateral == 0) return 0;

        // Calculate share ratio
        uint256 shareRatio = (withdrawAmount * 1e18) / currentCollateral;
        if (shareRatio > 1e18) shareRatio = 1e18; // Cap at 100%

        // Get vault balance before
        uint256 balanceBefore = collateralToken.balanceOf(vault);

        // Close proportional position
        uint256 reduceNotional = (currentNotional * shareRatio) / 1e18;
        uint256 reduceCollateral = (currentCollateral * shareRatio) / 1e18;

        if (reduceNotional > 0 && reduceCollateral > 0) {
            // ✅ FIX CRIT-8: Update state BEFORE external call (CEI pattern)
            currentNotional -= reduceNotional;
            currentCollateral -= reduceCollateral;

            // External call after state update
            perpProvider.decreasePosition(
                gbpUsdMarket,
                reduceCollateral,
                reduceNotional,
                IS_LONG
            );

            // ✅ FIX VULN-9: RESYNC with actual Ostium position after withdrawal
            // This accounts for any PnL realized during the decrease
            uint256 actualSize = perpProvider.getPositionSize(gbpUsdMarket, address(this));
            uint256 actualCollateralNow = perpProvider.getPositionCollateral(gbpUsdMarket, address(this));

            currentNotional = actualSize;
            currentCollateral = actualCollateralNow;

            // Transfer returned collateral to vault (external call last)
            uint256 balance = collateralToken.balanceOf(address(this));
            if (balance > 0) {
                collateralToken.safeTransfer(vault, balance);
            }

            emit PositionDecreased(shareRatio, reduceNotional, reduceCollateral);
        }

        // Return amount transferred to vault
        uint256 balanceAfter = collateralToken.balanceOf(vault);
        actualWithdrawn = balanceAfter - balanceBefore;
    }

    /**
     * @notice Propose a new perp provider (step 1 of 2)
     * @param newProvider Address of the new perp provider
     * @dev ✅ FIX HIGH-1: Added timelock to prevent immediate malicious provider switch
     * @dev ✅ FIX MED-NEW-1: Added cooldown to prevent timelock bypass via proposal cycling
     */
    function proposePerpProviderChange(address newProvider) external onlyOwner {
        if (newProvider == address(0)) revert InvalidProvider();
        if (newProvider == address(perpProvider)) revert ProviderNotChanged();

        // ✅ FIX MED-NEW-1: Enforce cooldown between proposals
        // Prevents bypassing timelock by repeatedly proposing/cancelling
        if (lastProposalTimestamp > 0 && block.timestamp < lastProposalTimestamp + PROPOSAL_COOLDOWN) {
            revert ProposalCooldownActive();
        }

        pendingPerpProvider = IPerpProvider(newProvider);
        perpProviderChangeTimestamp = block.timestamp + PERP_PROVIDER_TIMELOCK;
        lastProposalTimestamp = block.timestamp; // Record proposal time

        emit PerpProviderProposed(
            address(perpProvider),
            newProvider,
            perpProviderChangeTimestamp
        );
    }

    /**
     * @notice Cancel a pending perp provider proposal
     * @dev ✅ FIX HIGH-1: Allow owner to cancel if needed
     */
    function cancelPerpProviderProposal() external onlyOwner {
        if (address(pendingPerpProvider) == address(0)) revert NoPendingProvider();

        address cancelled = address(pendingPerpProvider);
        pendingPerpProvider = IPerpProvider(address(0));
        perpProviderChangeTimestamp = 0;

        emit PerpProviderProposalCancelled(cancelled);
    }

    /**
     * @notice Execute perp provider change (step 2 of 2)
     * @dev ✅ FIX HIGH-1: Only executable after 24-hour timelock
     * @dev ✅ FIX MED-NEW-1: Resets proposal timestamp after successful execution
     */
    function executePerpProviderChange() external onlyOwner {
        if (address(pendingPerpProvider) == address(0)) revert NoPendingProvider();
        if (block.timestamp < perpProviderChangeTimestamp) revert TimelockNotExpired();

        address oldProvider = address(perpProvider);
        perpProvider = pendingPerpProvider;

        // Clear pending state
        pendingPerpProvider = IPerpProvider(address(0));
        perpProviderChangeTimestamp = 0;
        // Note: Keep lastProposalTimestamp to enforce cooldown on next proposal

        emit PerpProviderUpdated(oldProvider, address(perpProvider));
    }

    /**
     * @notice Emergency close all positions
     * @dev ⚠️ FIX CRITICAL: Follows CEI pattern to prevent reentrancy
     */
    function emergencyClosePosition() external onlyOwner nonReentrant {
        if (currentNotional == 0) return;

        // ⚠️ FIX CRITICAL: Save values and reset state FIRST (CEI pattern)
        uint256 _notional = currentNotional;
        uint256 _collateral = currentCollateral;

        // Reset state before external calls
        currentNotional = 0;
        currentCollateral = 0;

        emit PositionDecreased(1e18, _notional, _collateral);

        // External calls AFTER state reset
        perpProvider.decreasePosition(gbpUsdMarket, _collateral, _notional, IS_LONG);

        // Return all collateral to vault
        uint256 balance = collateralToken.balanceOf(address(this));
        if (balance > 0) {
            collateralToken.safeTransfer(vault, balance);
        }
    }
}
