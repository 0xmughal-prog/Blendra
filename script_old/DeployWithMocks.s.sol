// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GBPb} from "../src/tokens/GBPb.sol";
import {sGBPb} from "../src/tokens/sGBPb.sol";
import {GBPbMinter} from "../src/tokens/GBPbMinter.sol";
import {FeeDistributor} from "../src/FeeDistributor.sol";
import {MorphoStrategyAdapter} from "../src/strategies/MorphoStrategyAdapter.sol";
import {PerpPositionManager} from "../src/PerpPositionManager.sol";
import {OstiumPerpProvider} from "../src/providers/OstiumPerpProvider.sol";
import {ChainlinkOracle} from "../src/ChainlinkOracle.sol";

// Mocks
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockERC4626Vault} from "../src/mocks/MockERC4626Vault.sol";
import {MockV3Aggregator} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {MockOstiumTrading} from "../src/mocks/MockOstiumTrading.sol";
import {MockOstiumTradingStorage} from "../src/mocks/MockOstiumTradingStorage.sol";

/**
 * @title DeployWithMocks
 * @notice Deployment script for testing with mock contracts
 */
contract DeployWithMocks is Script {
    // Mock contracts
    MockERC20 public usdc;
    MockERC4626Vault public morphoVault;
    MockV3Aggregator public gbpUsdFeed;
    MockOstiumTrading public ostiumTrading;
    MockOstiumTradingStorage public ostiumStorage;

    // Deployment parameters
    uint16 constant GBP_USD_PAIR_INDEX = 3;
    uint256 constant TARGET_LEVERAGE = 10; // 10x leverage
    uint256 constant MAX_PRICE_AGE = 1 hours;

    // Initial GBP/USD price: 1.27 USD per GBP (8 decimals)
    int256 constant INITIAL_GBP_USD_PRICE = 127_000_000; // 1.27 * 1e8

    // Deployed contracts
    GBPb public gbpbToken;
    sGBPb public sGBPbToken;
    GBPbMinter public minter;
    FeeDistributor public feeDistributor;
    MorphoStrategyAdapter public morphoStrategy;
    PerpPositionManager public perpManager;
    OstiumPerpProvider public ostiumProvider;
    ChainlinkOracle public oracle;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("===============================================");
        console.log("GBP 2-Token Model Deployment (WITH MOCKS)");
        console.log("===============================================");
        console.log("Deployer:", deployer);
        console.log("Network:", block.chainid);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Mocks
        console.log("Deploying Mock Contracts...");

        // 1. Deploy Mock USDC
        usdc = new MockERC20("USD Coin", "USDC", 6);
        console.log("   Mock USDC:", address(usdc));

        // 2. Deploy Mock Ostium Storage (needs to be before Trading)
        ostiumStorage = new MockOstiumTradingStorage(address(usdc));
        console.log("   Mock Ostium Storage:", address(ostiumStorage));

        // 3. Deploy Mock Ostium Trading
        ostiumTrading = new MockOstiumTrading(address(ostiumStorage));
        console.log("   Mock Ostium Trading:", address(ostiumTrading));

        // 4. Deploy Mock Morpho Vault
        morphoVault = new MockERC4626Vault(IERC20(address(usdc)), "Mock Morpho Vault", "mMorpho");
        console.log("   Mock Morpho Vault:", address(morphoVault));

        // 5. Deploy Mock Chainlink Price Feed
        gbpUsdFeed = new MockV3Aggregator(8, INITIAL_GBP_USD_PRICE);
        console.log("   Mock GBP/USD Feed:", address(gbpUsdFeed));

        console.log("");

        // Deploy Real Contracts
        console.log("Deploying Protocol Contracts...");

        // 1. Deploy ChainlinkOracle
        console.log("1. Deploying ChainlinkOracle...");
        oracle = new ChainlinkOracle(address(gbpUsdFeed), MAX_PRICE_AGE);
        console.log("   Oracle:", address(oracle));

        // 2. Deploy GBPb (base token)
        console.log("2. Deploying GBPb...");
        gbpbToken = new GBPb(deployer);
        console.log("   GBPb Token:", address(gbpbToken));

        // 3. Deploy GBPbMinter
        console.log("3. Deploying GBPbMinter...");
        minter = new GBPbMinter(
            address(usdc),
            address(gbpbToken),
            address(oracle),
            deployer
        );
        console.log("   Minter:", address(minter));

        // 4. Deploy sGBPb (sGBP - yield token)
        console.log("4. Deploying sGBPb...");
        sGBPbToken = new sGBPb(address(gbpbToken), deployer);
        console.log("   Staked GBPb:", address(sGBPbToken));

        // 5. Deploy FeeDistributor
        console.log("5. Deploying FeeDistributor...");
        address treasury = deployer; // TODO: Replace with multisig for mainnet
        address reserveBuffer = deployer; // TODO: Replace with reserve contract
        feeDistributor = new FeeDistributor(
            address(sGBPbToken),
            treasury,
            reserveBuffer
        );
        console.log("   FeeDistributor:", address(feeDistributor));

        // 6. Deploy MorphoStrategyAdapter
        console.log("6. Deploying MorphoStrategyAdapter...");
        morphoStrategy = new MorphoStrategyAdapter(
            address(usdc),
            address(morphoVault),
            address(minter)
        );
        console.log("   Morpho Strategy:", address(morphoStrategy));

        // 7. Deploy OstiumPerpProvider
        console.log("7. Deploying OstiumPerpProvider...");
        ostiumProvider = new OstiumPerpProvider(
            address(ostiumTrading),
            address(ostiumStorage),
            address(usdc),
            GBP_USD_PAIR_INDEX,
            TARGET_LEVERAGE,
            address(oracle),
            bytes32("GBP/USD")
        );
        console.log("   Ostium Provider:", address(ostiumProvider));

        // 8. Deploy PerpPositionManager
        console.log("8. Deploying PerpPositionManager...");
        perpManager = new PerpPositionManager(
            address(minter),
            address(usdc),
            address(ostiumProvider),
            bytes32("GBP/USD")
        );
        console.log("   Perp Manager:", address(perpManager));

        // 9. Wire everything together
        console.log("9. Wiring contracts...");

        // Set minter on GBPb
        gbpbToken.setMinter(address(minter));
        console.log("   - GBPb.minter = GBPbMinter");

        // Set minter and fee collector on sGBPb
        sGBPbToken.setMinter(address(minter));
        sGBPbToken.setFeeCollector(address(feeDistributor));
        console.log("   - sGBPb.minter = GBPbMinter");
        console.log("   - sGBPb.feeCollector = FeeDistributor");

        // Set strategies on Minter
        minter.setActiveStrategy(address(morphoStrategy));
        minter.setPerpManager(address(perpManager));
        console.log("   - Minter.activeStrategy = MorphoStrategy");
        console.log("   - Minter.perpManager = PerpManager");

        // Initialize price
        minter.updateLastPrice();
        console.log("   - Minter.lastPrice initialized");

        // Mint test USDC to deployer
        usdc.mint(deployer, 100_000 * 1e6); // 100k USDC for testing
        console.log("   - Minted 100,000 USDC to deployer");

        vm.stopBroadcast();

        // Display deployment summary
        console.log("");
        console.log("===============================================");
        console.log("Deployment Complete!");
        console.log("===============================================");
        console.log("");
        console.log("Mock Contracts:");
        console.log("  USDC:         ", address(usdc));
        console.log("  Morpho Vault: ", address(morphoVault));
        console.log("  GBP/USD Feed: ", address(gbpUsdFeed));
        console.log("  Ostium Trade: ", address(ostiumTrading));
        console.log("  Ostium Store: ", address(ostiumStorage));
        console.log("");
        console.log("Token Contracts:");
        console.log("  GBPb Token:   ", address(gbpbToken));
        console.log("  Staked GBPb:  ", address(sGBPbToken));
        console.log("");
        console.log("Core Contracts:");
        console.log("  GBPb Minter:  ", address(minter));
        console.log("  Fee Dist:     ", address(feeDistributor));
        console.log("");
        console.log("Strategies:");
        console.log("  Morpho:       ", address(morphoStrategy));
        console.log("  Perp Manager: ", address(perpManager));
        console.log("  Ostium Prov:  ", address(ostiumProvider));
        console.log("");
        console.log("Oracles:");
        console.log("  Chainlink:    ", address(oracle));
        console.log("");
        console.log("Configuration:");
        console.log("  Treasury:     ", treasury);
        console.log("  Reserve:      ", reserveBuffer);
        console.log("  TVL Cap:      ", minter.tvlCap() / 1e6, "USDC");
        console.log("  Perf Fee:     ", sGBPbToken.performanceFeeBPS() / 100, "%");
        console.log("  GBP/USD:      ", uint256(INITIAL_GBP_USD_PRICE) / 1e6, "(1e8 decimals)");
        console.log("");
        console.log("===============================================");
        console.log("Testing Commands:");
        console.log("===============================================");
        console.log("USDC:", address(usdc));
        console.log("Minter:", address(minter));
        console.log("GBPb:", address(gbpbToken));
        console.log("sGBPb:", address(sGBPbToken));
        console.log("===============================================");
    }
}
