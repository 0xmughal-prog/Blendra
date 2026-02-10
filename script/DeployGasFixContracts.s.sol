// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/tokens/GBPbMinter.sol";
import "../src/tokens/GBPb.sol";
import "../src/tokens/sGBPb.sol";
import "../src/PerpPositionManager.sol";
import "../src/providers/OstiumPerpProvider.sol";

/**
 * @title DeployGasFixContracts
 * @notice Deploy updated contracts with gas forwarding fixes
 */
contract DeployGasFixContracts is Script {
    // Existing contract addresses (from arbitrum-mainnet.json)
    address constant GBPB = 0xf04e200541c6E9Ec4499757653cD2f166Faf8F91;
    address constant OLD_MINTER = 0x3224854163Ded9b939EEe85d0c9f3130e8fA2569;
    address constant SGBPB = 0xFeb31be5dB6A49d67Cd131e56C98d1ABcE52aED3;
    address constant ORACLE = 0x85731548499ce2A9c771606cE736EDEd1CA9b136;
    address constant MORPHO_STRATEGY = 0x6d2e4C3B491C8DCCC79C5049087533B46187227F;
    address constant OLD_PERP_MANAGER = 0xBf702F23D0BB9eFD7A3F1488a4a1A7A4b662a1D3;
    address constant OLD_OSTIUM_PROVIDER = 0x05Ab8B473ed6854BcA6Cc0827052989211EfacB7;
    address constant FEE_DISTRIBUTOR = 0x7545c943A2dD2bFc3593810F96dEe4AD7CE9a913;
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant TREASURY = 0x6d0359bB1874ed16eDcdBA8D4718e68A8ff924d5;

    // Ostium contracts
    address constant OSTIUM_TRADING = 0x6D0bA1f9996DBD8885827e1b2e8f6593e7702411;
    address constant OSTIUM_STORAGE = 0xcCd5891083A8acD2074690F65d3024E7D13d66E7;
    uint16 constant GBP_USD_PAIR_INDEX = 3;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== DEPLOYING GAS FIX CONTRACTS ===");
        console.log("Deployer:", deployer);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy new OstiumPerpProvider (with gas forwarding)
        console.log("1. Deploying new OstiumPerpProvider...");
        OstiumPerpProvider newProvider = new OstiumPerpProvider(
            OSTIUM_TRADING,
            OSTIUM_STORAGE,
            USDC,
            GBP_USD_PAIR_INDEX,
            5, // 5x leverage
            ORACLE,
            bytes32("GBP/USD")
        );
        console.log("   New OstiumPerpProvider:", address(newProvider));

        // 2. Deploy new GBPbMinter first (with gas forwarding)
        console.log("");
        console.log("2. Deploying new GBPbMinter...");
        GBPbMinter newMinter = new GBPbMinter(
            USDC,
            GBPB,
            ORACLE,
            deployer
        );
        console.log("   New GBPbMinter:", address(newMinter));

        // 3. Deploy new PerpPositionManager (with gas forwarding)
        console.log("");
        console.log("3. Deploying new PerpPositionManager...");
        PerpPositionManager newPerpManager = new PerpPositionManager(
            address(newMinter), // vault
            USDC, // collateralToken
            address(newProvider), // perpProvider
            bytes32("GBP/USD") // gbpUsdMarket
        );
        console.log("   New PerpPositionManager:", address(newPerpManager));

        // 4. Wire contracts together
        console.log("");
        console.log("4. Wiring contracts...");

        // Set strategy and perp manager on minter
        newMinter.setActiveStrategy(MORPHO_STRATEGY);
        console.log("   Set Morpho strategy on minter");

        newMinter.setPerpManager(address(newPerpManager));
        console.log("   Set perp manager on minter");

        // Set minter on GBPb token
        GBPb(GBPB).setMinter(address(newMinter));
        console.log("   Set minter on GBPb");

        // Set minter on sGBPb
        sGBPb(SGBPB).setMinter(address(newMinter));
        console.log("   Set minter on sGBPb");

        // Set sGBPb vault on new minter
        newMinter.setSGBPbVault(SGBPB);
        console.log("   Set sGBPb vault on minter");

        // Set fee recipient
        newMinter.setFeeRecipient(TREASURY);
        console.log("   Set fee recipient");

        // Set harvest config
        newMinter.setHarvestConfig(12 hours, 10e6); // 12 hours, $10 min
        console.log("   Set harvest config");

        // Set TVL cap (1M USDC)
        newMinter.setTVLCap(1_000_000e6);
        console.log("   Set TVL cap");

        vm.stopBroadcast();

        console.log("");
        console.log("========================================");
        console.log("DEPLOYMENT COMPLETE!");
        console.log("========================================");
        console.log("");
        console.log("New Addresses:");
        console.log("  GBPbMinter:          ", address(newMinter));
        console.log("  PerpPositionManager: ", address(newPerpManager));
        console.log("  OstiumPerpProvider:  ", address(newProvider));
        console.log("");
        console.log("Old Addresses (can ignore):");
        console.log("  Old GBPbMinter:      ", OLD_MINTER);
        console.log("  Old PerpManager:     ", OLD_PERP_MANAGER);
        console.log("  Old Provider:        ", OLD_OSTIUM_PROVIDER);
        console.log("");
        console.log("Next Steps:");
        console.log("1. Update vault-ui/lib/contracts.ts with new minter address");
        console.log("2. Deploy to Vercel");
        console.log("3. Test $125 mint via UI");
        console.log("========================================");
    }
}
