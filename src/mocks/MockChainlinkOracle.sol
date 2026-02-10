// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockChainlinkOracle
 * @notice Mock Chainlink Aggregator for testing
 */
contract MockChainlinkOracle {
    int256 public price;
    uint8 public immutable decimals;
    uint80 private roundId;

    constructor(int256 initialPrice, uint8 _decimals) {
        price = initialPrice;
        decimals = _decimals;
        roundId = 1;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (
            roundId,
            price,
            block.timestamp,
            block.timestamp,
            roundId
        );
    }

    function setPrice(int256 newPrice) external {
        price = newPrice;
        roundId++;
    }

    function updateRoundData(
        int256 _answer,
        uint256 _startedAt,
        uint256 _updatedAt,
        uint80 _answeredInRound
    ) external {
        price = _answer;
        roundId++;
    }

    /**
     * @notice Get the latest GBP/USD price (mock version)
     * @return price The latest GBP/USD price (8 decimals)
     * @dev Simplified mock version without validation for testing
     */
    function getGBPUSDPrice() external view returns (uint256) {
        require(price > 0, "Invalid price");
        return uint256(price);
    }
}
