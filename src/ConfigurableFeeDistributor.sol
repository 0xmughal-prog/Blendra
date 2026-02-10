// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ConfigurableFeeDistributor
 * @notice Distributes vault fee shares with adjustable revenue split
 * @dev Owner can update treasury/reserve split percentages
 *
 * Features:
 * - Configurable revenue split (default: 90% treasury, 10% reserve)
 * - Owner can change split anytime
 * - Pull payment model (recipients must claim)
 * - Based on OpenZeppelin patterns
 */
contract ConfigurableFeeDistributor is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The vault shares token (ERC20)
    IERC20 public immutable vaultToken;

    /// @notice Treasury address (receives treasury share of fees)
    address public treasury;

    /// @notice Reserve buffer address (receives reserve share of fees)
    address public reserveBuffer;

    /// @notice Treasury share percentage (in basis points, e.g., 9000 = 90%)
    uint256 public treasuryShareBps;

    /// @notice Reserve share percentage (in basis points, e.g., 1000 = 10%)
    uint256 public reserveShareBps;

    /// @notice Total basis points (10000 = 100%)
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
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Emitted when reserve buffer address is updated
    event ReserveBufferUpdated(address indexed oldBuffer, address indexed newBuffer);

    error ZeroAddress();
    error NoPaymentDue();
    error InvalidSplit();

    /**
     * @notice Constructor
     * @param _vaultToken Address of the vault shares token
     * @param _treasury Address to receive treasury share of fees
     * @param _reserveBuffer Address to receive reserve share of fees
     * @param _treasuryBps Initial treasury share in basis points (e.g., 9000 = 90%)
     * @param _reserveBps Initial reserve share in basis points (e.g., 1000 = 10%)
     * @param _owner Initial owner address
     */
    constructor(
        address _vaultToken,
        address _treasury,
        address _reserveBuffer,
        uint256 _treasuryBps,
        uint256 _reserveBps,
        address _owner
    ) Ownable(_owner) {
        if (_vaultToken == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_reserveBuffer == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();
        if (_treasuryBps + _reserveBps != TOTAL_BPS) revert InvalidSplit();

        vaultToken = IERC20(_vaultToken);
        treasury = _treasury;
        reserveBuffer = _reserveBuffer;
        treasuryShareBps = _treasuryBps;
        reserveShareBps = _reserveBps;
    }

    /**
     * @notice Update revenue split percentages
     * @param _treasuryBps New treasury share in basis points
     * @param _reserveBps New reserve share in basis points
     * @dev Must sum to 10000 (100%)
     */
    function setRevenueSplit(uint256 _treasuryBps, uint256 _reserveBps) external onlyOwner {
        if (_treasuryBps + _reserveBps != TOTAL_BPS) revert InvalidSplit();

        treasuryShareBps = _treasuryBps;
        reserveShareBps = _reserveBps;

        emit RevenueSplitUpdated(_treasuryBps, _reserveBps);
    }

    /**
     * @notice Update treasury address
     * @param _newTreasury New treasury address
     */
    function setTreasury(address _newTreasury) external onlyOwner {
        if (_newTreasury == address(0)) revert ZeroAddress();

        address oldTreasury = treasury;
        treasury = _newTreasury;

        emit TreasuryUpdated(oldTreasury, _newTreasury);
    }

    /**
     * @notice Update reserve buffer address
     * @param _newBuffer New reserve buffer address
     */
    function setReserveBuffer(address _newBuffer) external onlyOwner {
        if (_newBuffer == address(0)) revert ZeroAddress();

        address oldBuffer = reserveBuffer;
        reserveBuffer = _newBuffer;

        emit ReserveBufferUpdated(oldBuffer, _newBuffer);
    }

    /**
     * @notice Release vault shares to treasury
     * @dev Can be called by anyone (pull payment model)
     */
    function releaseTreasury() external nonReentrant {
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
        uint256 payment = _releasable(reserveBuffer);
        if (payment == 0) revert NoPaymentDue();

        _releasedReserve += payment;
        vaultToken.safeTransfer(reserveBuffer, payment);

        emit PaymentReleased(reserveBuffer, payment);
    }

    /**
     * @notice Calculate releasable amount for an account
     * @param account Address to check
     * @return Releasable amount
     */
    function releasable(address account) external view returns (uint256) {
        return _releasable(account);
    }

    /**
     * @notice Get current balance of vault tokens in this contract
     * @return Current balance
     */
    function totalReceived() external view returns (uint256) {
        return _totalReceived;
    }

    /**
     * @notice Get total released to treasury
     * @return Total released amount
     */
    function releasedTreasury() external view returns (uint256) {
        return _releasedTreasury;
    }

    /**
     * @notice Get total released to reserve
     * @return Total released amount
     */
    function releasedReserve() external view returns (uint256) {
        return _releasedReserve;
    }

    /**
     * @notice Internal function to calculate releasable amount
     * @param account Address to check
     * @return Releasable amount based on current split
     */
    function _releasable(address account) private view returns (uint256) {
        uint256 totalBalance = vaultToken.balanceOf(address(this));
        uint256 totalReceivedNow = totalBalance + _releasedTreasury + _releasedReserve;

        if (account == treasury) {
            uint256 entitledAmount = (totalReceivedNow * treasuryShareBps) / TOTAL_BPS;
            return entitledAmount - _releasedTreasury;
        } else if (account == reserveBuffer) {
            uint256 entitledAmount = (totalReceivedNow * reserveShareBps) / TOTAL_BPS;
            return entitledAmount - _releasedReserve;
        }

        return 0;
    }

    /**
     * @notice Receive function to track incoming tokens
     */
    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }
}
