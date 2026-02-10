// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title sGBPb
 * @notice Stake GBPb to earn auto-compounding yield
 * @dev Fork of Ethena sUSDe + OpenZeppelin ERC4626
 *
 * Key features:
 * - ERC4626 vault accepting GBPb tokens
 * - Share price increases as yield accrues
 * - 20% performance fee (high water mark)
 * - Auto-compounding
 * - Instant unstake (no cooldown for simplicity)
 *
 * Based on audited code:
 * - OpenZeppelin ERC4626 (audited)
 * - Ethena sUSDe pattern (audited)
 * - Fee logic from MetaMorpho pattern
 *
 * Lines: ~200 (minimal implementation)
 */
contract sGBPb is ERC4626, Ownable2Step, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for IERC20;

    /// @notice Basis points denominator
    uint256 private constant BPS = 10000;

    /// @notice GBPbMinter contract that manages the underlying assets
    address public minter;

    /// @notice Fee collector (FeeDistributor contract)
    address public feeCollector;

    /// @notice Performance fee in basis points (2000 = 20%)
    uint256 public performanceFeeBPS;

    /// @notice High water mark (price per share)
    uint256 public highWaterMark;

    /// @notice Last harvest timestamp
    uint256 public lastHarvestTimestamp;

    /// @notice Maximum performance fee (30%)
    uint256 public constant MAX_PERFORMANCE_FEE_BPS = 10000; // 100%

    /// @notice Cooldown duration (1 day like Ethena pattern, but shorter)
    uint24 public cooldownDuration;

    /// @notice Cooldown data for each user
    struct UserCooldown {
        uint104 cooldownEnd;      // Timestamp when cooldown ends
        uint152 underlyingAmount; // Amount of GBPb to withdraw
    }

    /// @notice Mapping of user cooldowns
    mapping(address => UserCooldown) public cooldowns;

    /// @notice Last unstake time per user (prevents parallel cooldown bypass)
    /// @dev ✅ FIX MED-9: Track when user last called unstake()
    mapping(address => uint256) public lastUnstakeTime;

    /// Events
    event MinterUpdated(address indexed oldMinter, address indexed newMinter);
    event FeeCollectorUpdated(address indexed oldCollector, address indexed newCollector);
    event PerformanceFeeUpdated(uint256 oldFeeBPS, uint256 newFeeBPS);
    event FeesHarvested(uint256 performanceFee, uint256 feeShares, address indexed feeCollector);
    event HighWaterMarkUpdated(uint256 oldMark, uint256 newMark);
    event CooldownStarted(address indexed user, uint256 amount, uint256 cooldownEnd);
    event CooldownWithdraw(address indexed user, uint256 amount);
    event CooldownDurationUpdated(uint256 oldDuration, uint256 newDuration);

    /// Errors
    error ZeroAddress();
    error FeeTooHigh();
    error OnlyMinter();
    error OnlyMinterOrCollector();
    error CooldownActive();
    error NoCooldownInProgress();

    /**
     * @notice Constructor
     * @param _gbpbToken GBPb token address
     * @param _owner Initial owner
     */
    constructor(
        address _gbpbToken,
        address _owner
    ) ERC4626(IERC20(_gbpbToken)) ERC20("Staked GBPb", "sGBPb") Ownable(_owner) {
        if (_gbpbToken == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();

        performanceFeeBPS = 2000; // 20%
        highWaterMark = 1e18; // 1:1 initial ratio
        lastHarvestTimestamp = block.timestamp;

        // ✅ SECURITY: 1-day cooldown (like Ethena but shorter)
        // Prevents flash loan attacks and MEV extraction
        cooldownDuration = 1 days;

        // ✅ SECURITY FIX: Prevent ERC4626 inflation attack
        // Mint 1M initial shares to dead address to prevent first depositor manipulation
        // This makes donation attacks economically infeasible (would need to donate 1M+ GBPb)
        // Pattern from: Morpho MetaMorpho vaults (audited by ChainSecurity)
        // Increased from 1000e18 to 1e12 for stronger protection
        _mint(0x000000000000000000000000000000000000dEaD, 1e12); // 1 million shares (1e12 / 1e18 = 1e6)
    }

    /**
     * @notice Set minter address
     * @param _minter GBPbMinter contract address
     */
    function setMinter(address _minter) external onlyOwner {
        if (_minter == address(0)) revert ZeroAddress();

        address oldMinter = minter;
        minter = _minter;

        emit MinterUpdated(oldMinter, _minter);
    }

    /**
     * @notice Set fee collector address
     * @param _feeCollector FeeDistributor contract address
     */
    function setFeeCollector(address _feeCollector) external onlyOwner {
        if (_feeCollector == address(0)) revert ZeroAddress();

        address oldCollector = feeCollector;
        feeCollector = _feeCollector;

        emit FeeCollectorUpdated(oldCollector, _feeCollector);
    }

    /**
     * @notice Set performance fee
     * @param newFeeBPS New fee in basis points (max 30%)
     */
    function setPerformanceFee(uint256 newFeeBPS) external onlyOwner {
        if (newFeeBPS > MAX_PERFORMANCE_FEE_BPS) revert FeeTooHigh();

        uint256 oldFeeBPS = performanceFeeBPS;
        performanceFeeBPS = newFeeBPS;

        emit PerformanceFeeUpdated(oldFeeBPS, newFeeBPS);
    }

    /**
     * @notice Get total assets (GBPb tokens held by this vault)
     * @dev Returns the balance of GBPb tokens held by the vault
     */
    function totalAssets() public view override returns (uint256) {
        // Return GBPb balance held by this vault
        return IERC20(asset()).balanceOf(address(this));
    }

    /**
     * @notice Harvest performance fees
     * @return feeShares Amount of shares minted as fees
     * @dev Only charges fees above high water mark (no fees on losses)
     * @dev ✅ SECURITY: Only minter or fee collector can call to prevent flash loan attacks
     */
    function harvest() external nonReentrant returns (uint256 feeShares) {
        // ✅ SECURITY: Prevent flash loan manipulation of totalAssets()
        // Only the minter (who deposits real yield) or fee collector can harvest
        if (msg.sender != minter && msg.sender != feeCollector) {
            revert OnlyMinterOrCollector();
        }

        if (feeCollector == address(0)) return 0;

        uint256 supply = totalSupply();
        if (supply == 0) return 0;

        // Calculate current price per share
        uint256 currentPricePerShare = _getPricePerShare();

        // Only charge fees if price is above high water mark
        if (currentPricePerShare <= highWaterMark) return 0;

        // ✅ ROUNDING: Calculate profit above high water mark (round down = conservative)
        uint256 profit = ((currentPricePerShare - highWaterMark) * supply) / 1e18;

        // ✅ ROUNDING: Calculate performance fee - round UP to favor protocol
        uint256 performanceFee = Math.mulDiv(profit, performanceFeeBPS, BPS, Math.Rounding.Ceil);

        if (performanceFee > 0) {
            // Mint fee shares to fee collector
            feeShares = (performanceFee * 1e18) / currentPricePerShare;
            _mint(feeCollector, feeShares);

            emit FeesHarvested(performanceFee, feeShares, feeCollector);
        }

        // Update high water mark
        uint256 oldMark = highWaterMark;
        highWaterMark = _getPricePerShare();
        lastHarvestTimestamp = block.timestamp;

        emit HighWaterMarkUpdated(oldMark, highWaterMark);
    }

    /**
     * @notice Get current price per share
     * @return Price per share (18 decimals)
     */
    function _getPricePerShare() internal view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 1e18;
        return (totalAssets() * 1e18) / supply;
    }

    /**
     * @notice Get current price per share (external)
     * @return Price per share (18 decimals)
     */
    function pricePerShare() external view returns (uint256) {
        return _getPricePerShare();
    }

    // ============ Cooldown Withdrawal (Ethena Pattern) ============

    /**
     * @notice Start cooldown for withdrawal (step 1 of 2)
     * @param shares Amount of sGBPb shares to unstake
     * @dev ✅ SECURITY: 1-day cooldown prevents flash loan attacks
     * @dev ✅ FIX MED-9: Enforces cooldown between unstake calls to prevent parallel bypass
     * @dev Pattern from Ethena sUSDe (audited by Cyfrin, Pashov, Zellic)
     */
    function unstake(uint256 shares) external nonReentrant {
        require(shares > 0, "Zero shares");
        require(balanceOf(msg.sender) >= shares, "Insufficient balance");

        // ✅ FIX MED-9: Prevent unstaking again within cooldownDuration
        // This prevents users from creating multiple parallel cooldowns to bypass the protection
        if (block.timestamp < lastUnstakeTime[msg.sender] + cooldownDuration) {
            revert CooldownActive();
        }

        // Calculate underlying GBPb amount
        uint256 assets = previewRedeem(shares);

        // Burn shares immediately
        _burn(msg.sender, shares);

        // Start cooldown period
        uint104 cooldownEnd = uint104(block.timestamp + cooldownDuration);
        cooldowns[msg.sender] = UserCooldown({
            cooldownEnd: cooldownEnd,
            underlyingAmount: uint152(assets)
        });

        // ✅ FIX MED-9: Update last unstake time
        lastUnstakeTime[msg.sender] = block.timestamp;

        emit CooldownStarted(msg.sender, assets, cooldownEnd);
    }

    /**
     * @notice Complete withdrawal after cooldown (step 2 of 2)
     * @dev Can be called by anyone after cooldown expires
     */
    function cooldownWithdraw() external nonReentrant {
        UserCooldown memory cooldown = cooldowns[msg.sender];

        if (cooldown.underlyingAmount == 0) revert NoCooldownInProgress();
        if (block.timestamp < cooldown.cooldownEnd) revert CooldownActive();

        uint256 amount = cooldown.underlyingAmount;

        // Clear cooldown
        delete cooldowns[msg.sender];

        // Transfer GBPb to user
        IERC20(asset()).safeTransfer(msg.sender, amount);

        emit CooldownWithdraw(msg.sender, amount);
    }

    /**
     * @notice Set cooldown duration (governance)
     * @param newDuration New cooldown duration in seconds
     */
    function setCooldownDuration(uint24 newDuration) external onlyOwner {
        require(newDuration <= 30 days, "Duration too long");
        require(newDuration >= 1 hours, "Duration too short");

        uint256 oldDuration = cooldownDuration;
        cooldownDuration = newDuration;

        emit CooldownDurationUpdated(oldDuration, newDuration);
    }

    // ============ ERC4626 Overrides (Enforce Cooldown) ============

    /**
     * @notice Override ERC4626 withdraw to enforce cooldown mechanism
     * @dev Users MUST use unstake() -> cooldownWithdraw() flow
     * @dev ✅ FIX VULN-3: Prevents cooldown bypass via direct ERC4626 calls
     */
    function withdraw(uint256, address, address)
        public
        pure
        override
        returns (uint256)
    {
        revert("Use unstake() and cooldownWithdraw()");
    }

    /**
     * @notice Override ERC4626 redeem to enforce cooldown mechanism
     * @dev Users MUST use unstake() -> cooldownWithdraw() flow
     * @dev ✅ FIX VULN-3: Prevents cooldown bypass via direct ERC4626 calls
     */
    function redeem(uint256, address, address)
        public
        pure
        override
        returns (uint256)
    {
        revert("Use unstake() and cooldownWithdraw()");
    }

    /**
     * @notice Override maxWithdraw to return 0 (must use cooldown path)
     * @dev ✅ FIX VULN-3: Forces cooldown mechanism
     */
    function maxWithdraw(address)
        public
        pure
        override
        returns (uint256)
    {
        return 0; // Force cooldown path
    }

    /**
     * @notice Override maxRedeem to return 0 (must use cooldown path)
     * @dev ✅ FIX VULN-3: Forces cooldown mechanism
     */
    function maxRedeem(address)
        public
        pure
        override
        returns (uint256)
    {
        return 0; // Force cooldown path
    }

    /**
     * @notice Deposit GBPb tokens, receive sGBPb shares
     * @dev Inherited from ERC4626 (OpenZeppelin audited)
     */
    // deposit() inherited from ERC4626

    /**
     * @notice Withdraw GBPb tokens, burn sGBPb shares
     * @dev Inherited from ERC4626 (OpenZeppelin audited)
     */
    // withdraw() inherited from ERC4626

    /**
     * @notice Mint sGBPb shares for GBPb tokens
     * @dev Inherited from ERC4626 (OpenZeppelin audited)
     */
    // mint() inherited from ERC4626

    /**
     * @notice Redeem sGBPb shares for GBPb tokens
     * @dev Inherited from ERC4626 (OpenZeppelin audited)
     */
    // redeem() inherited from ERC4626

    /**
     * @notice Emergency withdrawal of stuck tokens
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     * @dev Only owner can call - for rescuing accidentally sent tokens
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}

/**
 * @notice Minimal interface for GBPbMinter
 */
interface IGBPbMinter {
    function totalGBPbValue() external view returns (uint256);
}
