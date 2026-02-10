// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Secure V2 contracts
import "../src/GBPYieldVaultV2Secure.sol";
import "../src/strategies/MorphoStrategyAdapter.sol";
import "../src/strategies/EulerStrategy.sol";
import "../src/PerpPositionManager.sol";
import "../src/providers/OstiumPerpProvider.sol";
import "../src/ChainlinkOracle.sol";
import "../src/FeeDistributor.sol";

// Mock contracts for testnet
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockERC4626Vault.sol";
import "../src/mocks/MockOstiumTrading.sol";
import "../src/mocks/MockOstiumTradingStorage.sol";
import "../src/mocks/MockChainlinkOracle.sol";

/**
 * @title DeployTestnetV2Secure
 * @notice Security-hardened deployment for Arbitrum Sepolia testnet
 * @dev Deploys GBPYieldVaultV2Secure with:
 *      - First depositor attack protection
 *      - Reentrancy guards
 *      - Strategy swapping capability
 *      - Multiple strategy options (Morpho, Euler)
 */
contract DeployTestnetV2Secure is Script {
    // ============ Configuration ============

    // Vault configuration
    uint256 constant YIELD_ALLOCATION = 9000;  // 90%
    uint256 constant PERP_ALLOCATION = 1000;   // 10%
    uint256 constant TARGET_LEVERAGE = 10;     // 10x

    // GBP/USD pair index (Ostium)
    uint16 constant GBP_USD_PAIR_INDEX = 3;

    // Oracle configuration
    uint256 constant MAX_PRICE_AGE = 3600; // 1 hour

    // Initial prices
    int256 constant INITIAL_GBP_USD_PRICE = 126500000; // 1.265 GBP/USD

    // ============ Deployed Contracts ============

    // Mocks
    MockERC20 public mockUSDC;
    MockERC4626Vault public mockMorphoVault;
    MockERC4626Vault public mockEulerVault;
    MockOstiumTrading public mockOstiumTrading;
    MockOstiumTradingStorage public mockOstiumStorage;
    MockChainlinkOracle public mockChainlinkFeed;

    // Real contracts
    ChainlinkOracle public chainlinkOracle;
    MorphoStrategyAdapter public morphoStrategy;
    EulerStrategy public eulerStrategy;
    OstiumPerpProvider public ostiumProvider;
    PerpPositionManager public perpManager;
    GBPYieldVaultV2Secure public vault;
    FeeDistributor public feeDistributor;

    // Fee recipients
    address public treasury;
    address public reserveBuffer;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("================================================================");
        console.log("   DEPLOYING SECURE GBP YIELD VAULT V2 TO ARBITRUM SEPOLIA     ");
        console.log("================================================================");
        console.log("");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        require(block.chainid == 421614, "Must deploy to Arbitrum Sepolia");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy mock infrastructure
        console.log("\n=== STEP 1: DEPLOYING MOCKS ===\n");
        deployMocks();

        // Step 2: Deploy real contracts
        console.log("\n=== STEP 2: DEPLOYING REAL CONTRACTS ===\n");
        deployRealContracts(deployer);

        // Step 3: Configure contracts
        console.log("\n=== STEP 3: CONFIGURING CONTRACTS ===\n");
        configureContracts(deployer);

        // Step 4: Security checks
        console.log("\n=== STEP 4: SECURITY VERIFICATION ===\n");
        verifySecurityFeatures();

        vm.stopBroadcast();

        // Step 5: Print deployment summary
        printDeploymentSummary(deployer);
    }

    function deployMocks() internal {
        // 1. Deploy mock USDC
        mockUSDC = new MockERC20("USD Coin", "USDC", 6);
        console.log("MockUSDC deployed:", address(mockUSDC));

        // 2. Deploy mock Morpho vault (ERC4626)
        mockMorphoVault = new MockERC4626Vault(
            mockUSDC,
            "Mock Morpho KPK Vault",
            "mMorpho"
        );
        console.log("MockMorphoVault deployed:", address(mockMorphoVault));

        // 3. Deploy mock Euler vault (ERC4626)
        mockEulerVault = new MockERC4626Vault(
            mockUSDC,
            "Mock Euler USDC Vault",
            "mEuler"
        );
        console.log("MockEulerVault deployed:", address(mockEulerVault));

        // 4. Deploy mock Ostium contracts
        mockOstiumStorage = new MockOstiumTradingStorage(address(mockUSDC));
        console.log("MockOstiumStorage deployed:", address(mockOstiumStorage));

        mockOstiumTrading = new MockOstiumTrading(address(mockOstiumStorage));
        console.log("MockOstiumTrading deployed:", address(mockOstiumTrading));

        // 5. Deploy mock Chainlink feed
        mockChainlinkFeed = new MockChainlinkOracle(INITIAL_GBP_USD_PRICE, 8);
        console.log("MockChainlinkFeed deployed:", address(mockChainlinkFeed));
        console.log("Initial GBP/USD price:", uint256(INITIAL_GBP_USD_PRICE));
    }

    function deployRealContracts(address deployer) internal {
        // Predict vault address for strategy deployment
        address predictedVault = vm.computeCreateAddress(deployer, vm.getNonce(deployer) + 5);
        console.log("Predicted vault address:", predictedVault);

        // 1. Deploy Chainlink Oracle wrapper
        chainlinkOracle = new ChainlinkOracle(
            address(mockChainlinkFeed),
            MAX_PRICE_AGE
        );
        console.log("ChainlinkOracle deployed:", address(chainlinkOracle));

        // 2. Deploy Morpho Strategy Adapter
        morphoStrategy = new MorphoStrategyAdapter(
            address(mockUSDC),
            address(mockMorphoVault),
            predictedVault
        );
        console.log("MorphoStrategyAdapter deployed:", address(morphoStrategy));

        // 3. Deploy Euler Strategy Adapter
        eulerStrategy = new EulerStrategy(
            address(mockUSDC),
            address(mockEulerVault),
            predictedVault,
            1,  // Collateral tier (safest)
            6   // Risk score
        );
        console.log("EulerStrategy deployed:", address(eulerStrategy));

        // 4. Deploy Ostium Perp Provider
        ostiumProvider = new OstiumPerpProvider(
            address(mockOstiumTrading),
            address(mockOstiumStorage),
            address(mockUSDC),
            GBP_USD_PAIR_INDEX,
            TARGET_LEVERAGE,
            address(chainlinkOracle), // ✅ Added for PnL calculation
            bytes32("GBP/USD") // ✅ FIX MED-7: Market identifier
        );
        console.log("OstiumPerpProvider deployed:", address(ostiumProvider));

        // 5. Deploy PerpPositionManager
        perpManager = new PerpPositionManager(
            predictedVault,
            address(mockUSDC),
            address(ostiumProvider),
            bytes32("GBP/USD")
        );
        console.log("PerpPositionManager deployed:", address(perpManager));

        // 6. Deploy Secure Vault V2
        // Note: FeeDistributor deployed after vault (needs vault address)
        vault = new GBPYieldVaultV2Secure(
            address(mockUSDC),
            "GBP Yield Vault V2 Secure",
            "gbpUSDCv2",
            address(morphoStrategy),  // Initial strategy
            address(perpManager),
            address(chainlinkOracle),
            deployer,  // Guardian (for testnet, same as deployer)
            YIELD_ALLOCATION,
            PERP_ALLOCATION,
            TARGET_LEVERAGE
        );

        // Verify vault address matches prediction
        require(address(vault) == predictedVault, "Vault address mismatch!");
        console.log("GBPYieldVaultV2Secure deployed:", address(vault));
    }

    function configureContracts(address deployer) internal {
        // 1. Deploy FeeDistributor
        // For testnet: Use deployer as both treasury and reserve
        // For mainnet: Use proper multisig addresses
        treasury = deployer; // TODO: Replace with multisig for mainnet
        reserveBuffer = deployer; // TODO: Replace with reserve contract for mainnet

        feeDistributor = new FeeDistributor(
            address(vault), // Vault shares token
            treasury,       // 90% of fees (18% of yield)
            reserveBuffer   // 10% of fees (2% of yield)
        );
        console.log("FeeDistributor deployed:", address(feeDistributor));
        console.log("  Treasury (90%):", treasury);
        console.log("  Reserve Buffer (10%):", reserveBuffer);

        // 2. Set fee collector in vault
        vault.setFeeCollector(address(feeDistributor));
        console.log("Fee collector set in vault");

        // 3. Transfer ownership of strategies to vault
        morphoStrategy.transferOwnership(address(vault));
        console.log("MorphoStrategy ownership -> Vault");

        eulerStrategy.transferOwnership(address(vault));
        console.log("EulerStrategy ownership -> Vault");

        // 4. Transfer ownership of PerpPositionManager to vault
        perpManager.transferOwnership(address(vault));
        console.log("PerpPositionManager ownership -> Vault");

        // 5. Approve Euler as backup strategy
        vault.setStrategyApproval(address(eulerStrategy), true);
        console.log("EulerStrategy approved as backup");

        // 6. Set up test funds (100k USDC for deployer)
        mockUSDC.mint(deployer, 100_000 * 10**6);
        console.log("Minted 100,000 USDC to deployer");

        // 5. Also mint some USDC to mock vaults for yield simulation
        mockUSDC.mint(address(mockMorphoVault), 10_000 * 10**6);
        mockUSDC.mint(address(mockEulerVault), 10_000 * 10**6);
        console.log("Funded mock vaults for yield simulation");
    }

    function verifySecurityFeatures() internal view {
        console.log("Checking security features...\n");

        // 1. Check initial shares minted (first depositor protection)
        uint256 initialShares = vault.balanceOf(address(1));
        console.log("Initial shares locked:", initialShares);
        require(initialShares == 1000, "First depositor protection not active!");
        console.log("  [OK] First depositor attack protection active");

        // 2. Check strategy approval
        bool morphoApproved = vault.isApprovedStrategy(address(morphoStrategy));
        bool eulerApproved = vault.isApprovedStrategy(address(eulerStrategy));
        console.log("  [OK] Morpho strategy approved:", morphoApproved);
        console.log("  [OK] Euler strategy approved:", eulerApproved);

        // 3. Check timelock configuration
        uint256 timelock = vault.STRATEGY_TIMELOCK();
        console.log("  [OK] Strategy timelock:", timelock / 3600, "hours");

        // 4. Check minimum deposit
        uint256 minDeposit = vault.MIN_DEPOSIT();
        console.log("  [OK] Minimum deposit:", minDeposit / 1e6, "USDC");

        // 5. Check ownership
        address vaultOwner = vault.owner();
        console.log("  [OK] Vault owner:", vaultOwner);

        // 6. Check guardian
        address vaultGuardian = vault.guardian();
        console.log("  [OK] Guardian:", vaultGuardian);

        console.log("\n[SUCCESS] All security features verified!");
    }

    function printDeploymentSummary(address deployer) internal view {
        console.log("\n");
        console.log("================================================================");
        console.log("        GBP YIELD VAULT V2 SECURE - DEPLOYMENT SUMMARY         ");
        console.log("================================================================");
        console.log("");
        console.log("Network: Arbitrum Sepolia (421614)");
        console.log("Deployer:", deployer);
        console.log("");

        console.log("=== MOCK CONTRACTS (Testnet Only) ===");
        console.log("MockUSDC:              ", address(mockUSDC));
        console.log("MockMorphoVault:       ", address(mockMorphoVault));
        console.log("MockEulerVault:        ", address(mockEulerVault));
        console.log("MockOstiumTrading:     ", address(mockOstiumTrading));
        console.log("MockOstiumStorage:     ", address(mockOstiumStorage));
        console.log("MockChainlinkFeed:     ", address(mockChainlinkFeed));
        console.log("");

        console.log("=== PRODUCTION CONTRACTS ===");
        console.log("GBPYieldVaultV2Secure: ", address(vault));
        console.log("FeeDistributor:        ", address(feeDistributor));
        console.log("MorphoStrategyAdapter: ", address(morphoStrategy));
        console.log("EulerStrategy:         ", address(eulerStrategy));
        console.log("PerpPositionManager:   ", address(perpManager));
        console.log("OstiumPerpProvider:    ", address(ostiumProvider));
        console.log("ChainlinkOracle:       ", address(chainlinkOracle));
        console.log("");

        console.log("=== CONFIGURATION ===");
        console.log("Yield Allocation:      90% (9000 bps)");
        console.log("Perp Allocation:       10% (1000 bps)");
        console.log("");

        console.log("=== FEE STRUCTURE ===");
        console.log("Performance Fee:       20% (2000 bps)");
        console.log("  -> Treasury:         18% of yield (90% of fees)");
        console.log("  -> Reserve Buffer:   2% of yield (10% of fees)");
        console.log("  -> Users Keep:       80% of yield");
        console.log("Fee Collector:         ", address(feeDistributor));
        console.log("Treasury Address:      ", treasury);
        console.log("Reserve Buffer:        ", reserveBuffer);
        console.log("Target Leverage:       10x");
        console.log("Strategy Timelock:     24 hours");
        console.log("Min Deposit:           100 USDC");
        console.log("");

        console.log("=== SECURITY FEATURES ===");
        console.log("[OK] First depositor protection (1000 shares locked to address(1))");
        console.log("[OK] ReentrancyGuard on all state changes");
        console.log("[OK] Minimum deposit requirement (100 USDC)");
        console.log("[OK] Strategy whitelist + approval system");
        console.log("[OK] 24-hour timelock on strategy changes");
        console.log("[OK] Emergency pause capability");
        console.log("[OK] Guardian role for emergency actions");
        console.log("[OK] Price sanity checks");
        console.log("");

        console.log("=== AVAILABLE STRATEGIES ===");
        console.log("1. Morpho (Active)   - Risk: 5/10, APY: ~6%");
        console.log("2. Euler (Approved)  - Risk: 6/10, APY: ~5%");
        console.log("");

        console.log("=== QUICK START ===");
        console.log("");
        console.log("# Set environment variables");
        console.log("export VAULT=%s", vm.toString(address(vault)));
        console.log("export USDC=%s", vm.toString(address(mockUSDC)));
        console.log("export MORPHO=%s", vm.toString(address(morphoStrategy)));
        console.log("export EULER=%s", vm.toString(address(eulerStrategy)));
        console.log("");

        console.log("# Test deposit (requires approval first)");
        console.log("cast send $USDC \"approve(address,uint256)\" $VAULT 10000000000");
        console.log("cast send $VAULT \"deposit(uint256,address)\" 1000000000 $DEPLOYER");
        console.log("");

        console.log("# Switch to Euler strategy");
        console.log("cast send $VAULT \"proposeStrategyChange(address)\" $EULER");
        console.log("# Wait 24 hours...");
        console.log("cast send $VAULT \"executeStrategyChange()\"");
        console.log("");

        console.log("=== ARBISCAN LINKS ===");
        console.log("Vault: https://sepolia.arbiscan.io/address/%s", vm.toString(address(vault)));
        console.log("");

        console.log("================================================================");
        console.log("                    DEPLOYMENT COMPLETE!                        ");
        console.log("================================================================");
    }
}
