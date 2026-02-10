// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/providers/OstiumPerpProvider.sol";
import "../src/PerpPositionManager.sol";
import "../src/tokens/GBPbMinter.sol";

/**
 * @title UpgradeOstiumFix
 * @notice Deploy fixed OstiumPerpProvider and PerpPositionManager, then update GBPbMinter
 */
contract UpgradeOstiumFix is Script {
    // Existing contracts
    address constant GBPB_MINTER = 0x3224854163Ded9b939EEe85d0c9f3130e8fA2569;
    address constant ORACLE = 0x85731548499ce2A9c771606cE736EDEd1CA9b136;
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    // Ostium contracts
    address constant OSTIUM_TRADING = 0x6D0bA1f9996DBD8885827e1b2e8f6593e7702411;
    address constant OSTIUM_TRADING_STORAGE = 0xcCd5891083A8acD2074690F65d3024E7D13d66E7;

    // Configuration
    uint16 constant GBP_USD_PAIR_INDEX = 3;
    uint256 constant TARGET_LEVERAGE = 5;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying fixed Ostium integration...");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new OstiumPerpProvider with openPrice fix
        console.log("\n=== Deploying Fixed OstiumPerpProvider ===");
        OstiumPerpProvider newProvider = new OstiumPerpProvider(
            OSTIUM_TRADING,
            OSTIUM_TRADING_STORAGE,
            USDC,
            GBP_USD_PAIR_INDEX,
            TARGET_LEVERAGE,
            ORACLE,
            bytes32("GBP/USD")
        );
        console.log("New OstiumPerpProvider deployed at:", address(newProvider));

        // Deploy new PerpPositionManager with new provider
        console.log("\n=== Deploying New PerpPositionManager ===");
        PerpPositionManager newPerpManager = new PerpPositionManager(
            GBPB_MINTER,
            USDC,
            address(newProvider),
            bytes32("GBP/USD")
        );
        console.log("New PerpPositionManager deployed at:", address(newPerpManager));

        // Update GBPbMinter to use new PerpPositionManager
        console.log("\n=== Updating GBPbMinter ===");
        GBPbMinter minter = GBPbMinter(GBPB_MINTER);
        minter.setPerpManager(address(newPerpManager));
        console.log("GBPbMinter updated to use new PerpPositionManager");

        vm.stopBroadcast();

        console.log("\n========================================");
        console.log("UPGRADE COMPLETE!");
        console.log("========================================");
        console.log("New OstiumPerpProvider:  ", address(newProvider));
        console.log("New PerpPositionManager: ", address(newPerpManager));
        console.log("GBPbMinter (updated):    ", GBPB_MINTER);
        console.log("\nFix applied: openPrice now uses oracle price instead of 0");
        console.log("========================================");
    }
}
