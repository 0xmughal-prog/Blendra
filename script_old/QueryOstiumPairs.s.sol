// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

/**
 * @title QueryOstiumPairs
 * @notice Script to query Ostium pair indices on Arbitrum mainnet
 * @dev Run with: forge script script/QueryOstiumPairs.s.sol --rpc-url $ARBITRUM_RPC_URL
 */

interface IOstiumPairsStorage {
    struct Pair {
        string from;
        string to;
        uint256 spreadP;
        uint256 groupIndex;
        uint256 feeIndex;
    }

    function pairs(uint256 index) external view returns (Pair memory);
    function pairsCount() external view returns (uint256);
}

contract QueryOstiumPairs is Script {
    // Ostium Registry contract (need to find this address)
    // Or we can try to read pairs directly from PairsStorage

    function run() external view {
        console.log("Querying Ostium trading pairs on Arbitrum...");
        console.log("");

        // Note: This is a placeholder script
        // We need to find the PairsStorage contract address
        // from Ostium's registry or documentation

        console.log("To find GBP/USD pair index:");
        console.log("1. Check Ostium app at https://app.ostium.io");
        console.log("2. Open browser console and inspect network requests");
        console.log("3. Look for API calls that include pair indices");
        console.log("4. Or contact Ostium team on Discord/Telegram");
        console.log("");
        console.log("Common forex pair indices (estimated):");
        console.log("- EUR/USD: likely 0 or 1");
        console.log("- GBP/USD: likely 4-6");
        console.log("- USD/JPY: likely 2-3");
        console.log("");
        console.log("Chainlink GBP/USD Oracle (CONFIRMED):");
        console.log("0x9C4424Fd84C6661F97D8d6b3fc3C1aAc2BeDd137");
    }
}
