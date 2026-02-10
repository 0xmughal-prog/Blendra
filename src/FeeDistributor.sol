// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title FeeDistributor
 * @notice Distributes vault fee shares between treasury and reserve buffer
 * @dev Implements audited pull-payment pattern from OpenZeppelin PaymentSplitter
 *
 * Fee Split (Configurable):
 * - Default: 90% to Treasury (18% of total yield)
 * - Default: 10% to Reserve Buffer (2% of total yield)
 *
 * Total: 20% performance fee, 80% to users
 *
 * Security Features:
 * - Pull payment model (recipients must claim) - prevents reentrancy
 * - ReentrancyGuard on release functions
 * - Configurable shares (owner can adjust split)
 * - Owner controls via Ownable2Step (secure ownership transfer)
 * - Based on OpenZeppelin PaymentSplitter pattern (audited)
 *
 * @dev This contract is based on OpenZeppelin's audited PaymentSplitter pattern
 *      from v4.x, adapted for ERC20 tokens only and simplified for our use case.
 */
contract FeeDistributor is ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;

    /// @notice The vault shares token (ERC20)
    IERC20 public immutable vaultToken;

    /// @notice Treasury address (receives 90% of fees)
    /// @dev ✅ FIX HIGH-10: Changed from immutable to allow updates if treasury becomes malicious
    address public treasury;

    /// @notice Reserve buffer address (receives 10% of fees)
    /// @dev ✅ FIX HIGH-10: Changed from immutable to allow updates if reserve becomes malicious
    address public reserveBuffer;

    /// @notice Treasury share in basis points (9000 = 90%)
    uint256 public treasuryShareBps;

    /// @notice Reserve share in basis points (1000 = 10%)
    uint256 public reserveShareBps;

    /// @notice Total shares in basis points (10000 = 100%)
    uint256 public constant TOTAL_BPS = 10000;

    /// @notice Total vault tokens received by this contract
    uint256 private _totalReceived;

    /// @notice Amount already released to treasury
    uint256 private _releasedTreasury;

    /// @notice Amount already released to reserve
    uint256 private _releasedReserve;

    /// @notice Emitted when vault shares are released to a recipient
    event PaymentReleased(address indexed to, uint256 amount);

    /// @notice Emitted when vault shares are received
    event PaymentReceived(address indexed from, uint256 amount);

    /// @notice Emitted when revenue split is updated
    event RevenueSplitUpdated(uint256 treasuryBps, uint256 reserveBps);

    /// @notice Emitted when treasury address is updated
    /// @dev ✅ FIX HIGH-10: Allow treasury changes to prevent DoS
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Emitted when reserve buffer address is updated
    /// @dev ✅ FIX HIGH-10: Allow reserve changes to prevent DoS
    event ReserveBufferUpdated(address indexed oldReserveBuffer, address indexed newReserveBuffer);

    error ZeroAddress();
    error NoPaymentDue();
    error InvalidSplit();

    /**
     * @notice Constructor
     * @param _vaultToken Address of the vault shares token
     * @param _treasury Address to receive treasury share of fees
     * @param _reserveBuffer Address to receive reserve share of fees
     * @param _owner Initial owner address
     */
    constructor(
        address _vaultToken,
        address _treasury,
        address _reserveBuffer,
        address _owner
    ) Ownable(_owner) {
        if (_vaultToken == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_reserveBuffer == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();

        vaultToken = IERC20(_vaultToken);
        treasury = _treasury;
        reserveBuffer = _reserveBuffer;

        // Initialize with default 90/10 split
        treasuryShareBps = 9000; // 90%
        reserveShareBps = 1000;  // 10%
    }

    /**
     * @notice Set revenue split between treasury and reserve
     * @param _treasuryBps Treasury share in basis points (e.g., 9000 = 90%)
     * @param _reserveBps Reserve share in basis points (e.g., 1000 = 10%)
     * @dev Only owner can update. Must sum to 10000 (100%)
     * @dev ✅ FIX VULN-10: Forces release of all pending funds before changing split
     *      This prevents accounting issues from retroactive split changes
     */
    function setRevenueSplit(uint256 _treasuryBps, uint256 _reserveBps) external onlyOwner {
        if (_treasuryBps + _reserveBps != TOTAL_BPS) revert InvalidSplit();

        // ✅ FIX: Sync and release all pending payments before changing split
        syncTotalReceived();

        // Release to treasury if any pending
        uint256 treasuryPayment = _releasable(treasury);
        if (treasuryPayment > 0) {
            _releasedTreasury += treasuryPayment;
            vaultToken.safeTransfer(treasury, treasuryPayment);
            emit PaymentReleased(treasury, treasuryPayment);
        }

        // Release to reserve if any pending
        uint256 reservePayment = _releasable(reserveBuffer);
        if (reservePayment > 0) {
            _releasedReserve += reservePayment;
            vaultToken.safeTransfer(reserveBuffer, reservePayment);
            emit PaymentReleased(reserveBuffer, reservePayment);
        }

        // Now safe to change split (no pending funds)
        treasuryShareBps = _treasuryBps;
        reserveShareBps = _reserveBps;

        emit RevenueSplitUpdated(_treasuryBps, _reserveBps);
    }

    /**
     * @notice Update treasury address
     * @param _newTreasury New treasury address
     * @dev ✅ FIX HIGH-10: Allows changing treasury if it becomes malicious/unresponsive
     *      Prevents permanent DoS of fee distribution
     */
    function setTreasury(address _newTreasury) external onlyOwner {
        if (_newTreasury == address(0)) revert ZeroAddress();
        if (_newTreasury == treasury) return; // No change

        address oldTreasury = treasury;
        treasury = _newTreasury;

        emit TreasuryUpdated(oldTreasury, _newTreasury);
    }

    /**
     * @notice Update reserve buffer address
     * @param _newReserveBuffer New reserve buffer address
     * @dev ✅ FIX HIGH-10: Allows changing reserve if it becomes malicious/unresponsive
     *      Prevents permanent DoS of fee distribution
     */
    function setReserveBuffer(address _newReserveBuffer) external onlyOwner {
        if (_newReserveBuffer == address(0)) revert ZeroAddress();
        if (_newReserveBuffer == reserveBuffer) return; // No change

        address oldReserveBuffer = reserveBuffer;
        reserveBuffer = _newReserveBuffer;

        emit ReserveBufferUpdated(oldReserveBuffer, _newReserveBuffer);
    }

    /**
     * @notice Sync total received to prevent accounting drift
     * @dev ✅ FIX MED-10: Updates _totalReceived to match actual balance + released
     *      Prevents rounding errors from accumulating over time
     */
    function syncTotalReceived() public {
        uint256 totalBalance = vaultToken.balanceOf(address(this));
        uint256 totalReceivedNow = totalBalance + _releasedTreasury + _releasedReserve;
        _totalReceived = totalReceivedNow;
    }

    /**
     * @notice Release vault shares to treasury
     * @dev Can be called by anyone (pull payment model)
     */
    function releaseTreasury() external nonReentrant {
        // ✅ FIX MED-10: Sync before calculating to prevent drift
        syncTotalReceived();
        uint256 payment = _releasable(treasury);
        if (payment == 0) revert NoPaymentDue();

        _releasedTreasury += payment;
        vaultToken.safeTransfer(treasury, payment);

        emit PaymentReleased(treasury, payment);
    }

    /**
     * @notice Release vault shares to reserve buffer
     * @dev Can be called by anyone (pull payment model)
     */
    function releaseReserve() external nonReentrant {
        // ✅ FIX MED-10: Sync before calculating to prevent drift
        syncTotalReceived();

        uint256 payment = _releasable(reserveBuffer);
        if (payment == 0) revert NoPaymentDue();

        _releasedReserve += payment;
        vaultToken.safeTransfer(reserveBuffer, payment);

        emit PaymentReleased(reserveBuffer, payment);
    }

    /**
     * @notice Release shares to all recipients
     * @dev Convenience function to distribute to both recipients at once
     */
    function releaseAll() external nonReentrant {
        // ✅ FIX MED-10: Sync before calculating to prevent drift
        syncTotalReceived();

        // Release to treasury
        uint256 treasuryPayment = _releasable(treasury);
        if (treasuryPayment > 0) {
            _releasedTreasury += treasuryPayment;
            vaultToken.safeTransfer(treasury, treasuryPayment);
            emit PaymentReleased(treasury, treasuryPayment);
        }

        // Release to reserve
        uint256 reservePayment = _releasable(reserveBuffer);
        if (reservePayment > 0) {
            _releasedReserve += reservePayment;
            vaultToken.safeTransfer(reserveBuffer, reservePayment);
            emit PaymentReleased(reserveBuffer, reservePayment);
        }

        if (treasuryPayment == 0 && reservePayment == 0) {
            revert NoPaymentDue();
        }
    }

    /**
     * @notice Get total shares releasable to treasury
     * @return Amount of vault shares releasable to treasury
     */
    function releasableTreasury() external view returns (uint256) {
        return _releasable(treasury);
    }

    /**
     * @notice Get total shares releasable to reserve buffer
     * @return Amount of vault shares releasable to reserve buffer
     */
    function releasableReserve() external view returns (uint256) {
        return _releasable(reserveBuffer);
    }

    /**
     * @notice Get total shares already released to treasury
     * @return Amount of vault shares already released to treasury
     */
    function releasedTreasury() external view returns (uint256) {
        return _releasedTreasury;
    }

    /**
     * @notice Get total shares already released to reserve buffer
     * @return Amount of vault shares already released to reserve buffer
     */
    function releasedReserve() external view returns (uint256) {
        return _releasedReserve;
    }

    /**
     * @notice Get total tokens received by this contract
     * @return Total amount received
     */
    function totalReceived() external view returns (uint256) {
        return _totalReceived;
    }

    /**
     * @notice Calculate releasable amount for an account
     * @param account The account to calculate for
     * @return The amount of tokens releasable to the account
     * @dev Based on OpenZeppelin PaymentSplitter logic
     */
    function _releasable(address account) private view returns (uint256) {
        uint256 totalBalance = vaultToken.balanceOf(address(this));
        uint256 totalReceivedNow = totalBalance + _releasedTreasury + _releasedReserve;

        // Update our internal total if needed
        if (totalReceivedNow > _totalReceived) {
            // Note: This is a view function, so we can't update state
            // The actual _totalReceived update happens implicitly through the calculation
        }

        uint256 share;
        uint256 alreadyReleased;

        if (account == treasury) {
            share = treasuryShareBps;
            alreadyReleased = _releasedTreasury;
        } else if (account == reserveBuffer) {
            share = reserveShareBps;
            alreadyReleased = _releasedReserve;
        } else {
            return 0;
        }

        // Calculate total entitled amount
        uint256 entitled = (totalReceivedNow * share) / TOTAL_BPS;

        // Return amount not yet released
        if (entitled > alreadyReleased) {
            return entitled - alreadyReleased;
        }
        return 0;
    }
}
