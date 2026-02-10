// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {GBPb} from "../src/tokens/GBPb.sol";
import {sGBPb} from "../src/tokens/sGBPb.sol";
import {GBPbMinter} from "../src/tokens/GBPbMinter.sol";
import "../src/FeeDistributor.sol";
import "../src/strategies/MorphoStrategyAdapter.sol";
import "../src/PerpPositionManager.sol";
import "../src/providers/OstiumPerpProvider.sol";
import "../src/ChainlinkOracle.sol";

/**
 * @title Deploy2TokenModel
 * @notice Deployment script for GBP 2-token model (GBP + sGBP)
 * @dev Deploys and wires together all contracts for the 2-token system
 */
contract Deploy2TokenModel is Script {
    // Arbitrum Sepolia addresses
    address constant USDC = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
    address constant MORPHO_VAULT = 0x0000000000000000000000000000000000000000; // TODO: Add actual Morpho vault
    address constant OSTIUM_TRADING = 0xaaF3C61367A3878E7866F21C2CE6bB21Cd99a6E0;
    address constant OSTIUM_STORAGE = 0x1BE29D05DD6B6E38f34e6Cb8C372fa34D57Ebf73;
    address constant CHAINLINK_GBP_USD = 0x0000000000000000000000000000000000000000; // TODO: Add actual feed

    // Deployment parameters
    uint16 constant GBP_USD_PAIR_INDEX = 3;
    uint256 constant TARGET_LEVERAGE = 10; // 10x leverage
    uint256 constant MAX_PRICE_AGE = 1 hours;

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
        console.log("GBP 2-Token Model Deployment");
        console.log("===============================================");
        console.log("Deployer:", deployer);
        console.log("Network:", block.chainid);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ChainlinkOracle
        console.log("1. Deploying ChainlinkOracle...");
        oracle = new ChainlinkOracle(CHAINLINK_GBP_USD, MAX_PRICE_AGE, deployer);
        console.log("   Oracle:", address(oracle));

        // 2. Deploy GBPb (base token)
        console.log("2. Deploying GBPb...");
        gbpbToken = new GBPb(deployer);
        console.log("   GBP Token:", address(gbpbToken));

        // 3. Deploy GBPbMinter
        console.log("3. Deploying GBPbMinter...");
        minter = new GBPbMinter(
            USDC,
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
            reserveBuffer,
            deployer // owner
        );
        console.log("   FeeDistributor:", address(feeDistributor));

        // 6. Deploy MorphoStrategyAdapter
        console.log("6. Deploying MorphoStrategyAdapter...");
        morphoStrategy = new MorphoStrategyAdapter(
            USDC,
            MORPHO_VAULT,
            address(minter)
        );
        console.log("   Morpho Strategy:", address(morphoStrategy));

        // 7. Deploy OstiumPerpProvider
        console.log("7. Deploying OstiumPerpProvider...");
        ostiumProvider = new OstiumPerpProvider(
            OSTIUM_TRADING,
            OSTIUM_STORAGE,
            USDC,
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
            USDC,
            address(ostiumProvider),
            bytes32("GBP/USD")
        );
        console.log("   Perp Manager:", address(perpManager));

        // 9. Wire everything together
        console.log("9. Wiring contracts...");

        // Set minter on GBPb
        gbpbToken.setMinter(address(minter));
        console.log("   - GBPb.minter = GBPMinter");

        // Set minter and fee collector on StakedGBP
        sGBPbToken.setMinter(address(minter));
        sGBPbToken.setFeeCollector(address(feeDistributor));
        console.log("   - StakedGBP.minter = GBPMinter");
        console.log("   - StakedGBP.feeCollector = FeeDistributor");

        // Set strategies on Minter
        minter.setActiveStrategy(address(morphoStrategy));
        minter.setPerpManager(address(perpManager));
        console.log("   - Minter.activeStrategy = MorphoStrategy");
        console.log("   - Minter.perpManager = PerpManager");

        // ✅ FIX: Set sGBPb vault on Minter (critical for yield distribution!)
        minter.setSGBPbVault(address(sGBPbToken));
        console.log("   - Minter.sGBPbVault = sGBPb");

        vm.stopBroadcast();

        // Display deployment summary
        console.log("");
        console.log("===============================================");
        console.log("Deployment Complete!");
        console.log("===============================================");
        console.log("");
        console.log("Token Contracts:");
        console.log("  GBP Token:    ", address(gbpbToken));
        console.log("  Staked GBP:   ", address(sGBPbToken));
        console.log("");
        console.log("Core Contracts:");
        console.log("  GBP Minter:   ", address(minter));
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
        console.log("");
        console.log("===============================================");
        console.log("User Flow:");
        console.log("===============================================");
        console.log("1. Mint GBP:  minter.mint(USDC amount)");
        console.log("2. Stake GBP: sGBPbToken.deposit(GBP amount)");
        console.log("3. Unstake:   sGBPbToken.redeem(sGBP shares)");
        console.log("4. Redeem:    minter.redeem(GBP amount)");
        console.log("");
        console.log("Owner Functions:");
        console.log("  Harvest fees: sGBPbToken.harvest()");
        console.log("  Update price: minter.updateLastPrice()");
        console.log("  Pause:        minter.pause()");
        console.log("===============================================");
        console.log("");
        console.log("===============================================");
        console.log("POST-DEPLOYMENT CHECKLIST:");
        console.log("===============================================");
        console.log("1. Fund reserve:");
        console.log("   - Approve USDC: usdc.approve(minter, amount)");
        console.log("   - Call: minter.fundReserve(amount)");
        console.log("   - Recommended: At least $100-500 to start");
        console.log("");
        console.log("2. Set initial parameters:");
        console.log("   - TVL Cap: minter.setTVLCap(amount)");
        console.log("   - Harvest config: minter.setHarvestConfig(interval, minAmount)");
        console.log("");
        console.log("3. Verify contracts on Arbiscan");
        console.log("");
        console.log("4. Update admin UI config:");
        console.log("   - Add contract addresses to lib/config.ts");
        console.log("   - Update ABIs if needed");
        console.log("");
        console.log("5. Test user flow:");
        console.log("   - Approve USDC for minter");
        console.log("   - Mint GBPb");
        console.log("   - Approve GBPb for sGBPb");
        console.log("   - Stake in sGBPb");
        console.log("   - Wait for yield");
        console.log("   - Harvest");
        console.log("   - Unstake (1-day cooldown)");
        console.log("===============================================");
    }
}

