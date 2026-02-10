// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IPerpProvider.sol";

/**
 * @title MockPerpProvider
 * @notice Mock perpetual DEX provider for testing
 * @dev Simulates perp trading without actual DEX integration
 */
contract MockPerpProvider is IPerpProvider {
    using SafeERC20 for IERC20;

    struct Position {
        uint256 size;           // Notional size
        uint256 collateral;     // Collateral amount
        int256 pnl;             // Simulated P&L
        bool isLong;            // Position direction
    }

    /// @notice Mapping of market => account => position
    mapping(bytes32 => mapping(address => Position)) public positions;

    /// @notice The collateral token
    IERC20 public immutable collateralToken;

    /// @notice Simulated funding rate per update (can be positive or negative)
    int256 public fundingRate;

    /// @notice Simulated price impact on entry/exit
    uint256 public priceImpact;

    event PositionIncreased(bytes32 indexed market, address indexed account, uint256 collateral, uint256 sizeDelta);
    event PositionDecreased(bytes32 indexed market, address indexed account, uint256 collateralDelta, uint256 sizeDelta);
    event PnLUpdated(bytes32 indexed market, address indexed account, int256 pnl);
    event FundingRateUpdated(int256 newRate);

    constructor(address _collateralToken) {
        require(_collateralToken != address(0), "Invalid collateral token");
        collateralToken = IERC20(_collateralToken);
        fundingRate = -10; // Start with small negative funding (longs pay shorts)
        priceImpact = 50; // 0.5% impact in basis points
    }

    /**
     * @notice Increase a perpetual position
     */
    function increasePosition(
        bytes32 market,
        uint256 collateral,
        uint256 sizeDelta,
        bool isLong
    ) external override {
        require(collateral > 0, "Zero collateral");
        require(sizeDelta > 0, "Zero size");

        // Transfer collateral from sender
        collateralToken.safeTransferFrom(msg.sender, address(this), collateral);

        Position storage pos = positions[market][msg.sender];

        // Initialize or update position
        pos.size += sizeDelta;
        pos.collateral += collateral;
        pos.isLong = isLong;

        // Simulate entry price impact (small loss)
        uint256 impactLoss = (collateral * priceImpact) / 10000;
        pos.pnl -= int256(impactLoss);

        emit PositionIncreased(market, msg.sender, collateral, sizeDelta);
    }

    /**
     * @notice Decrease a perpetual position
     */
    function decreasePosition(
        bytes32 market,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong
    ) external override {
        Position storage pos = positions[market][msg.sender];

        require(pos.size >= sizeDelta, "Size too large");
        require(pos.collateral >= collateralDelta, "Collateral too large");

        // Update position
        pos.size -= sizeDelta;
        pos.collateral -= collateralDelta;

        // Simulate exit price impact
        uint256 impactLoss = (collateralDelta * priceImpact) / 10000;
        pos.pnl -= int256(impactLoss);

        // Calculate total to return: collateral + pnl
        int256 totalReturn = int256(collateralDelta) + pos.pnl;

        // Proportionally reduce pnl
        if (pos.size > 0) {
            pos.pnl = (pos.pnl * int256(pos.size)) / int256(pos.size + sizeDelta);
        } else {
            pos.pnl = 0; // Position fully closed
        }

        // Return collateral (and profits if any)
        if (totalReturn > 0) {
            collateralToken.safeTransfer(msg.sender, uint256(totalReturn));
        } else {
            // In a real scenario, this would liquidate or require more collateral
            // For mock, just return remaining collateral
            if (collateralDelta > 0) {
                uint256 remainingCollateral = uint256(int256(collateralDelta) + totalReturn);
                if (remainingCollateral > 0) {
                    collateralToken.safeTransfer(msg.sender, remainingCollateral);
                }
            }
        }

        emit PositionDecreased(market, msg.sender, collateralDelta, sizeDelta);
    }

    /**
     * @notice Get position P&L
     */
    function getPositionPnL(bytes32 market, address account) external view override returns (int256 pnl) {
        return positions[market][account].pnl;
    }

    /**
     * @notice Get position size
     */
    function getPositionSize(bytes32 market, address account) external view override returns (uint256 size) {
        return positions[market][account].size;
    }

    /**
     * @notice Get position collateral
     */
    function getPositionCollateral(bytes32 market, address account)
        external
        view
        override
        returns (uint256 collateral)
    {
        return positions[market][account].collateral;
    }

    /**
     * @notice Simulate price movement (for testing)
     * @param market The market identifier
     * @param account The account
     * @param pnlChange Change in P&L (can be positive or negative)
     */
    function simulatePriceMovement(bytes32 market, address account, int256 pnlChange) external {
        positions[market][account].pnl += pnlChange;
        emit PnLUpdated(market, account, positions[market][account].pnl);
    }

    /**
     * @notice Update simulated funding rate
     * @param newRate New funding rate (positive means shorts pay longs, negative means longs pay shorts)
     */
    function setFundingRate(int256 newRate) external {
        fundingRate = newRate;
        emit FundingRateUpdated(newRate);
    }

    /**
     * @notice Apply funding to a position
     * @param market The market identifier
     * @param account The account
     */
    function applyFunding(bytes32 market, address account) external {
        Position storage pos = positions[market][account];
        if (pos.size == 0) return;

        // Calculate funding based on position size
        // If long and funding negative, reduce pnl
        int256 fundingAmount = (int256(pos.size) * fundingRate) / 10000;

        if (pos.isLong) {
            pos.pnl -= fundingAmount;
        } else {
            pos.pnl += fundingAmount;
        }

        emit PnLUpdated(market, account, pos.pnl);
    }

    /**
     * @notice Set price impact
     * @param newImpact New price impact in basis points
     */
    function setPriceImpact(uint256 newImpact) external {
        require(newImpact <= 1000, "Impact too high"); // Max 10%
        priceImpact = newImpact;
    }
}
