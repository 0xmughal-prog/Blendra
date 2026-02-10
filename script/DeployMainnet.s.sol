// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/tokens/GBPb.sol";
import "../src/tokens/GBPbMinter.sol";
import "../src/tokens/sGBPb.sol";
import "../src/strategies/MorphoStrategyAdapter.sol";
import "../src/PerpPositionManager.sol";
import "../src/FeeDistributor.sol";
import "../src/providers/OstiumPerpProvider.sol";
import "../src/ChainlinkOracle.sol";

/**
 * @title DeployMainnet
 * @notice Deployment script for Arbitrum mainnet with REAL Ostium integration
 * @dev This deploys the complete GBP Yield Vault system
 */
contract DeployMainnet is Script {
    // ========== ARBITRUM MAINNET ADDRESSES ==========

    // USDC on Arbitrum
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    // Chainlink GBP/USD aggregator on Arbitrum (raw feed)
    address constant CHAINLINK_GBP_USD_FEED = 0x9C4424Fd84C6661F97D8d6b3fc3C1aAc2BeDd137;

    // Ostium contracts on Arbitrum (checksummed addresses)
    address constant OSTIUM_TRADING = 0x6D0bA1f9996DBD8885827e1b2e8f6593e7702411;
    address constant OSTIUM_TRADING_STORAGE = 0xcCd5891083A8acD2074690F65d3024E7D13d66E7;

    // Morpho Hyperithm USDC Vault on Arbitrum (VERIFIED)
    // Hyperithm USDC vault - https://app.morpho.org/arbitrum/vault/0x4B6F1C9E5d470b97181786b26da0d0945A7cf027
    address constant MORPHO_KPK_VAULT = 0x4B6F1C9E5d470b97181786b26da0d0945A7cf027;

    // ========== CONFIGURATION ==========

    // GBP/USD pair index on Ostium
    uint16 constant GBP_USD_PAIR_INDEX = 3;

    // Target leverage for perp positions
    uint256 constant TARGET_LEVERAGE = 5; // 5x leverage

    // Maximum price age for oracle (1 hour)
    uint256 constant MAX_PRICE_AGE = 1 hours;

    function run() external {
        // Get deployer from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying to Arbitrum Mainnet...");
        console.log("Deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);

        require(deployer.balance > 0.01 ether, "Insufficient ETH for deployment");

        vm.startBroadcast(deployerPrivateKey);

        // ========== STEP 1: Deploy Core Tokens ==========
        console.log("\n=== STEP 1: Deploying Core Tokens ===");

        GBPb gbpb = new GBPb(deployer);
        console.log("GBPb deployed at:", address(gbpb));

        // ========== STEP 2: Deploy Chainlink Oracle Wrapper ==========
        console.log("\n=== STEP 2: Deploying Chainlink Oracle Wrapper ===");

        ChainlinkOracle oracle = new ChainlinkOracle(
            CHAINLINK_GBP_USD_FEED,
            MAX_PRICE_AGE,
            deployer
        );
        console.log("ChainlinkOracle wrapper deployed at:", address(oracle));
        console.log("Using Chainlink feed:", CHAINLINK_GBP_USD_FEED);

        // ========== STEP 3: Deploy GBPbMinter ==========
        console.log("\n=== STEP 3: Deploying GBPbMinter ===");

        GBPbMinter minter = new GBPbMinter(
            USDC,
            address(gbpb),
            address(oracle),
            deployer
        );
        console.log("GBPbMinter deployed at:", address(minter));

        // ========== STEP 4: Deploy Morpho Strategy ==========
        console.log("\n=== STEP 4: Deploying Morpho Strategy ===");

        MorphoStrategyAdapter morphoStrategy = new MorphoStrategyAdapter(
            USDC,
            MORPHO_KPK_VAULT,
            address(minter)
        );
        console.log("MorphoStrategyAdapter deployed at:", address(morphoStrategy));

        // ========== STEP 5: Deploy sGBPb Vault ==========
        console.log("\n=== STEP 5: Deploying sGBPb Vault ===");

        sGBPb sGBPbVault = new sGBPb(
            address(gbpb),
            deployer
        );
        console.log("sGBPb deployed at:", address(sGBPbVault));

        // ========== STEP 6: Deploy FeeDistributor ==========
        console.log("\n=== STEP 6: Deploying FeeDistributor ===");

        FeeDistributor feeDistributor = new FeeDistributor(
            USDC,
            address(sGBPbVault),
            deployer,
            deployer // Protocol fee recipient
        );
        console.log("FeeDistributor deployed at:", address(feeDistributor));

        // ========== STEP 7: Deploy Ostium Perp Provider ==========
        console.log("\n=== STEP 7: Deploying Ostium Perp Provider (REAL INTEGRATION) ===");

        OstiumPerpProvider ostiumProvider = new OstiumPerpProvider(
            OSTIUM_TRADING,
            OSTIUM_TRADING_STORAGE,
            USDC,
            GBP_USD_PAIR_INDEX,
            TARGET_LEVERAGE,
            address(oracle),
            bytes32("GBP/USD")
        );
        console.log("OstiumPerpProvider deployed at:", address(ostiumProvider));

        // ========== STEP 8: Deploy PerpPositionManager ==========
        console.log("\n=== STEP 8: Deploying PerpPositionManager ===");

        PerpPositionManager perpManager = new PerpPositionManager(
            address(minter), // vault
            USDC, // collateralToken
            address(ostiumProvider), // perpProvider
            bytes32("GBP/USD") // gbpUsdMarket
        );
        console.log("PerpPositionManager deployed at:", address(perpManager));

        // ========== STEP 9: Wire Everything Together ==========
        console.log("\n=== STEP 9: Wiring Contracts Together ===");

        // Set minter on GBPb
        gbpb.setMinter(address(minter));
        console.log("GBPb minter set");

        // Set minter on sGBPb
        sGBPbVault.setMinter(address(minter));
        console.log("sGBPb minter set");

        // Set fee collector on sGBPb
        sGBPbVault.setFeeCollector(address(feeDistributor));
        console.log("sGBPb fee collector set");

        // Set active strategy on minter
        minter.setActiveStrategy(address(morphoStrategy));
        console.log("Minter active strategy set");

        // Set sGBPb vault on minter
        minter.setSGBPbVault(address(sGBPbVault));
        console.log("Minter sGBPb vault set");

        // Set perp manager on minter
        minter.setPerpManager(address(perpManager));
        console.log("Minter perp manager set");

        // ========== STEP 10: Initial Configuration ==========
        console.log("\n=== STEP 10: Initial Configuration ===");

        // Disable weekend check initially (can be enabled later after testing)
        minter.setWeekendCheckEnabled(false);
        console.log("Weekend check disabled (enable after testing)");

        // Set reasonable fee distributor splits (80% to treasury, 20% to reserve)
        feeDistributor.setRevenueSplit(8000, 2000);
        console.log("Fee split set: 80% treasury, 20% reserve");

        vm.stopBroadcast();

        // ========== DEPLOYMENT SUMMARY ==========
        console.log("\n========================================");
        console.log("DEPLOYMENT COMPLETE!");
        console.log("========================================");
        console.log("");
        console.log("Core Contracts:");
        console.log("  GBPb:              ", address(gbpb));
        console.log("  GBPbMinter:        ", address(minter));
        console.log("  sGBPb:             ", address(sGBPbVault));
        console.log("");
        console.log("Strategies:");
        console.log("  MorphoStrategy:    ", address(morphoStrategy));
        console.log("");
        console.log("Perp Integration:");
        console.log("  OstiumProvider:    ", address(ostiumProvider));
        console.log("  PerpManager:       ", address(perpManager));
        console.log("");
        console.log("Fee Management:");
        console.log("  FeeDistributor:    ", address(feeDistributor));
        console.log("");
        console.log("Oracle:");
        console.log("  ChainlinkOracle:   ", address(oracle));
        console.log("");
        console.log("External Contracts:");
        console.log("  USDC:              ", USDC);
        console.log("  Chainlink Feed:    ", CHAINLINK_GBP_USD_FEED);
        console.log("  Ostium Trading:    ", OSTIUM_TRADING);
        console.log("  Ostium Storage:    ", OSTIUM_TRADING_STORAGE);
        console.log("  Morpho Vault:      ", MORPHO_KPK_VAULT);
        console.log("");
        console.log("Configuration:");
        console.log("  GBP/USD Pair Index:", GBP_USD_PAIR_INDEX);
        console.log("  Target Leverage:   ", TARGET_LEVERAGE, "x");
        console.log("  Weekend Check:     ", "DISABLED");
        console.log("");
        console.log("========================================");
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Verify contracts on Arbiscan");
        console.log("2. Test with small amounts");
        console.log("3. Enable weekend check after testing");
        console.log("4. Update UI with contract addresses");
        console.log("5. Deploy UI to Vercel");
        console.log("========================================");

        // Save addresses to file for UI
        string memory addresses = string(abi.encodePacked(
            "{\n",
            '  "gbpb": "', vm.toString(address(gbpb)), '",\n',
            '  "minter": "', vm.toString(address(minter)), '",\n',
            '  "sGBPb": "', vm.toString(address(sGBPbVault)), '",\n',
            '  "oracle": "', vm.toString(address(oracle)), '",\n',
            '  "morphoStrategy": "', vm.toString(address(morphoStrategy)), '",\n',
            '  "ostiumProvider": "', vm.toString(address(ostiumProvider)), '",\n',
            '  "perpManager": "', vm.toString(address(perpManager)), '",\n',
            '  "feeDistributor": "', vm.toString(address(feeDistributor)), '",\n',
            '  "chainId": 42161\n',
            "}\n"
        ));

        vm.writeFile("deployments/arbitrum-mainnet.json", addresses);
        console.log("Contract addresses saved to deployments/arbitrum-mainnet.json");
    }
}
