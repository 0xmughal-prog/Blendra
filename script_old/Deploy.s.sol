// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/tokens/GBPb.sol";
import "../src/tokens/sGBPb.sol";
import "../src/tokens/GBPbMinter.sol";
import "../src/FeeDistributor.sol";
import "../src/strategies/MorphoStrategyAdapter.sol";
import "../src/PerpPositionManager.sol";
import "../src/providers/OstiumPerpProvider.sol";
import "../src/ChainlinkOracle.sol";

/**
 * @title Mainnet Deployment Script with Safety Parameters
 * @notice Deploys GBPb protocol to Arbitrum mainnet with conservative limits
 * @dev Run with: forge script script/Deploy.s.sol:DeployGBPb --rpc-url $ARBITRUM_RPC --broadcast --verify
 */
contract DeployGBPb is Script {
    // ============ Configuration ============

    // Arbitrum Mainnet Addresses
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Arbitrum USDC
    address constant MORPHO_VAULT = 0x4B6F1C9E5d470b97181786b26da0d0945A7cf027; // Hyperithm Morpho USDC Vault
    address constant GBP_USD_FEED = 0x9C4424Fd84C6661F97D8d6b3fc3C1aAc2BeDd137; // Chainlink GBP/USD

    // Ostium Addresses (Arbitrum Mainnet)
    address constant OSTIUM_TRADING_STORAGE = 0xcCd5891083A8acD2074690F65d3024E7D13d66E7;
    address constant OSTIUM_TRADING = 0x6D0bA1f9996DBD8885827e1b2e8f6593e7702411;

    // Safety Parameters
    uint256 constant INITIAL_TVL_CAP = 5_000 * 1e6;        // $5,000 max TVL
    uint256 constant MIN_RESERVE_BALANCE = 100 * 1e6;      // $100 minimum reserve
    uint256 constant INITIAL_RESERVE_FUNDING = 500 * 1e6;  // $500 initial reserve
    uint256 constant MAX_PRICE_AGE = 1 hours;               // Oracle staleness
    uint256 constant USER_COOLDOWN = 1 days;                // Rate limiting

    // Ostium Parameters
    uint16 constant GBP_USD_PAIR_INDEX = 3;
    uint256 constant TARGET_LEVERAGE = 10; // 10x leverage
    bytes32 constant GBP_USD_MARKET = bytes32("GBP/USD");

    // ============ State Variables ============

    address public deployer;
    address public treasury;
    address public reserveRecipient;

    GBPb public gbpb;
    sGBPb public sGBPbVault;
    GBPbMinter public minter;
    FeeDistributor public feeDistributor;
    ChainlinkOracle public oracle;
    MorphoStrategyAdapter public morphoStrategy;
    OstiumPerpProvider public ostiumProvider;
    PerpPositionManager public perpManager;

    // ============ Deployment ============

    function run() external {
        // Load deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        // Set treasury and reserve recipients (can be updated later)
        treasury = vm.envOr("TREASURY_ADDRESS", deployer);
        reserveRecipient = vm.envOr("RESERVE_RECIPIENT", deployer);

        console.log("=================================================");
        console.log("GBPb Protocol Mainnet Deployment");
        console.log("=================================================");
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);
        console.log("Network: Arbitrum One");
        console.log("=================================================");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Oracle
        console.log("\n1. Deploying ChainlinkOracle...");
        oracle = new ChainlinkOracle(GBP_USD_FEED, MAX_PRICE_AGE);
        console.log("   Oracle deployed at:", address(oracle));

        // 2. Deploy GBPb Token
        console.log("\n2. Deploying GBPb Token...");
        gbpb = new GBPb(deployer);
        console.log("   GBPb deployed at:", address(gbpb));

        // 3. Deploy GBPbMinter
        console.log("\n3. Deploying GBPbMinter...");
        minter = new GBPbMinter(
            USDC,
            address(gbpb),
            address(oracle),
            deployer
        );
        console.log("   GBPbMinter deployed at:", address(minter));

        // 4. Deploy sGBPb Vault
        console.log("\n4. Deploying sGBPb Vault...");
        sGBPbVault = new sGBPb(address(gbpb), deployer);
        console.log("   sGBPb deployed at:", address(sGBPbVault));

        // 5. Deploy FeeDistributor
        console.log("\n5. Deploying FeeDistributor...");
        feeDistributor = new FeeDistributor(
            address(sGBPbVault),
            treasury,
            reserveRecipient
        );
        console.log("   FeeDistributor deployed at:", address(feeDistributor));

        // 6. Deploy MorphoStrategyAdapter
        console.log("\n6. Deploying MorphoStrategyAdapter...");
        morphoStrategy = new MorphoStrategyAdapter(
            USDC,
            MORPHO_VAULT,
            address(minter)
        );
        console.log("   MorphoStrategy deployed at:", address(morphoStrategy));

        // 7. Deploy OstiumPerpProvider
        console.log("\n7. Deploying OstiumPerpProvider...");
        ostiumProvider = new OstiumPerpProvider(
            OSTIUM_TRADING,
            OSTIUM_TRADING_STORAGE,
            USDC,
            GBP_USD_PAIR_INDEX,
            TARGET_LEVERAGE,
            address(oracle),
            GBP_USD_MARKET
        );
        console.log("   OstiumProvider deployed at:", address(ostiumProvider));

        // 8. Deploy PerpPositionManager
        console.log("\n8. Deploying PerpPositionManager...");
        perpManager = new PerpPositionManager(
            address(minter),
            USDC,
            address(ostiumProvider),
            GBP_USD_MARKET
        );
        console.log("   PerpPositionManager deployed at:", address(perpManager));

        // 9. Wire contracts together
        console.log("\n9. Wiring contracts...");

        gbpb.setMinter(address(minter));
        console.log("   GBPb minter set");

        sGBPbVault.setMinter(address(minter));
        console.log("   sGBPb minter set");

        sGBPbVault.setFeeCollector(address(feeDistributor));
        console.log("   sGBPb fee collector set");

        minter.setActiveStrategy(address(morphoStrategy));
        console.log("   Minter strategy set");

        minter.setPerpManager(address(perpManager));
        console.log("   Minter perp manager set");

        morphoStrategy.transferOwnership(address(minter));
        console.log("   MorphoStrategy ownership transferred to minter");

        ostiumProvider.transferOwnership(address(perpManager));
        console.log("   OstiumProvider ownership transferred to perpManager");

        minter.updateLastPrice();
        console.log("   Initial price updated");

        // 10. Configure safety parameters
        console.log("\n10. Configuring safety parameters...");

        minter.setTVLCap(INITIAL_TVL_CAP);
        console.log("   TVL cap set to: $5,000");

        minter.setMinReserveBalance(MIN_RESERVE_BALANCE);
        console.log("   Min reserve balance set to: $100");

        minter.setUserOperationCooldown(USER_COOLDOWN);
        console.log("   User cooldown set to: 1 day");

        minter.setFeeRecipient(treasury);
        console.log("   Fee recipient set to:", treasury);

        // 11. Pause initially (will unpause after funding reserve)
        minter.pause();
        console.log("   Protocol PAUSED (unpause after funding reserve)");

        vm.stopBroadcast();

        // 12. Print deployment summary
        printDeploymentSummary();

        // 13. Print next steps
        printNextSteps();
    }

    function printDeploymentSummary() internal view {
        console.log("\n=================================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("=================================================");
        console.log("ChainlinkOracle:        ", address(oracle));
        console.log("GBPb Token:             ", address(gbpb));
        console.log("sGBPb Vault:            ", address(sGBPbVault));
        console.log("GBPbMinter:             ", address(minter));
        console.log("FeeDistributor:         ", address(feeDistributor));
        console.log("MorphoStrategyAdapter:  ", address(morphoStrategy));
        console.log("OstiumPerpProvider:     ", address(ostiumProvider));
        console.log("PerpPositionManager:    ", address(perpManager));
        console.log("=================================================");
        console.log("Owner:                  ", deployer);
        console.log("Treasury:               ", treasury);
        console.log("=================================================");
        console.log("TVL Cap:                $5,000");
        console.log("Min Reserve:            $100");
        console.log("Status:                 PAUSED");
        console.log("=================================================");
    }

    function printNextSteps() internal view {
        console.log("\n=================================================");
        console.log("NEXT STEPS");
        console.log("=================================================");
        console.log("1. Verify contracts on Arbiscan");
        console.log("   forge verify-contract <address> <contract> --chain-id 42161");
        console.log("");
        console.log("2. Fund reserve with $500 USDC:");
        console.log("   a. Approve USDC (0xaf88...831) to minter:");
        console.log("      Minter address:", address(minter));
        console.log("   b. Fund reserve with 500000000 (500 USDC)");
        console.log("");
        console.log("3. Unpause protocol:");
        console.log("   Call unpause() on minter:", address(minter));
        console.log("");
        console.log("4. Test mint with small amount (e.g., $100)");
        console.log("");
        console.log("5. Monitor deployment using Verify.s.sol script");
        console.log("=================================================");
        console.log("");
        console.log("IMPORTANT: Protocol is PAUSED until reserve is funded!");
        console.log("=================================================");
    }
}
