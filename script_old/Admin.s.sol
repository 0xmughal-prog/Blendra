// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/tokens/GBPbMinter.sol";
import "../src/tokens/GBPb.sol";
import "../src/tokens/sGBPb.sol";
import "../src/strategies/MorphoStrategyAdapter.sol";
import "../src/PerpPositionManager.sol";
import "../src/FeeDistributor.sol";
import "../src/ConfigurableFeeDistributor.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Admin Management Script
 * @notice Interactive admin tool for managing GBPb protocol
 * @dev Run with: forge script script/Admin.s.sol:AdminTool --rpc-url $ARBITRUM_RPC --sig "FUNCTION_NAME(args)" --broadcast
 */
contract AdminTool is Script {
    IERC20 constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

    GBPbMinter public minter;
    GBPb public gbpb;
    sGBPb public vault;
    MorphoStrategyAdapter public strategy;
    PerpPositionManager public perpManager;
    ConfigurableFeeDistributor public feeDistributor;

    function setUp() public {
        minter = GBPbMinter(vm.envAddress("MINTER_ADDRESS"));
        gbpb = GBPb(vm.envAddress("GBPB_ADDRESS"));
        vault = sGBPb(vm.envAddress("SGBPB_ADDRESS"));
        strategy = MorphoStrategyAdapter(vm.envAddress("STRATEGY_ADDRESS"));
        perpManager = PerpPositionManager(vm.envAddress("PERP_MANAGER_ADDRESS"));

        // Load FeeDistributor if available (optional for now)
        address feeDistAddr = vm.envOr("FEE_DISTRIBUTOR_ADDRESS", address(0));
        if (feeDistAddr != address(0)) {
            feeDistributor = ConfigurableFeeDistributor(payable(feeDistAddr));
        }
    }

    // ============================================
    // VIEW FUNCTIONS (Read-Only)
    // ============================================

    function viewStatus() public view {
        console.log("=================================================");
        console.log("PROTOCOL STATUS");
        console.log("=================================================");

        console.log("\n[PROTOCOL STATE]");
        console.log("Paused:              ", minter.paused());
        console.log("TVL:                 $", minter.totalAssets() / 1e6);
        console.log("TVL Cap:             $", minter.tvlCap() / 1e6);
        console.log("Reserve Balance:     $", minter.reserveBalance() / 1e6);
        console.log("Min Reserve:         $", minter.minReserveBalance() / 1e6);
        console.log("User Cooldown:       ", minter.userOperationCooldown() / 1 days, "days");

        console.log("\n[PRICES]");
        console.log("GBP/USD Price:       ", minter.oracle().getGBPUSDPrice());
        console.log("Last GBPb Price:     ", minter.lastGBPbPrice());

        console.log("\n[HOLDINGS]");
        console.log("Strategy Holdings:   $", strategy.totalAssets() / 1e6);
        console.log("Perp Collateral:     $", perpManager.currentCollateral() / 1e6);

        if (perpManager.currentCollateral() > 0) {
            console.log("Perp Health Factor:  ", perpManager.getHealthFactor());
        }

        console.log("\n[ADDRESSES]");
        console.log("Owner:               ", minter.owner());
        console.log("Fee Recipient:       ", minter.feeRecipient());
        console.log("Active Strategy:     ", address(minter.activeStrategy()));
        console.log("Perp Manager:        ", address(minter.perpManager()));

        console.log("\n=================================================");
    }

    function viewReserveAccounting() public view {
        console.log("=================================================");
        console.log("RESERVE ACCOUNTING");
        console.log("=================================================");

        (
            uint256 currentReserve,
            uint256 minReserve,
            uint256 openingFeesPaid,
            uint256 redemptionFeesCollected,
            int256 netRevenue,
            uint256 yieldBorrowed,
            uint256 founderOwed,
            uint256 totalOutstanding
        ) = minter.getReserveAccounting();

        console.log("Current Reserve:     $", currentReserve / 1e6);
        console.log("Minimum Required:    $", minReserve / 1e6);
        console.log("Opening Fees Paid:   $", openingFeesPaid / 1e6);
        console.log("Redemption Fees:     $", redemptionFeesCollected / 1e6);

        if (netRevenue >= 0) {
            console.log("Net Revenue:         +$", uint256(netRevenue) / 1e6);
        } else {
            console.log("Net Revenue:         -$", uint256(-netRevenue) / 1e6);
        }

        console.log("Yield Borrowed:      $", yieldBorrowed / 1e6);
        console.log("Founder Owed:        $", founderOwed / 1e6);
        console.log("Total Outstanding:   $", totalOutstanding / 1e6);
        console.log("Reserve Healthy:     ", minter.isReserveHealthy());

        console.log("=================================================");
    }

    // ============================================
    // PROTOCOL MANAGEMENT
    // ============================================

    function pauseProtocol() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("Pausing protocol...");
        vm.startBroadcast(deployerPrivateKey);
        minter.pause();
        vm.stopBroadcast();
        console.log("Protocol PAUSED");
    }

    function unpauseProtocol() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("Unpausing protocol...");
        vm.startBroadcast(deployerPrivateKey);
        minter.unpause();
        vm.stopBroadcast();
        console.log("Protocol ACTIVE");
    }

    function setTVLCap(uint256 newCapUSD) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 newCap = newCapUSD * 1e6; // Convert USD to USDC 6 decimals

        console.log("Setting TVL cap to: $", newCapUSD);
        vm.startBroadcast(deployerPrivateKey);
        minter.setTVLCap(newCap);
        vm.stopBroadcast();
        console.log("TVL cap updated to: $", newCapUSD);
    }

    function setMinReserve(uint256 newMinUSD) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 newMin = newMinUSD * 1e6;

        console.log("Setting min reserve to: $", newMinUSD);
        vm.startBroadcast(deployerPrivateKey);
        minter.setMinReserveBalance(newMin);
        vm.stopBroadcast();
        console.log("Min reserve updated to: $", newMinUSD);
    }

    function setCooldown(uint256 daysCount) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 cooldown = daysCount * 1 days;

        console.log("Setting cooldown to:", daysCount, "days");
        vm.startBroadcast(deployerPrivateKey);
        minter.setUserOperationCooldown(cooldown);
        vm.stopBroadcast();
        console.log("Cooldown updated to:", daysCount, "days");
    }

    function setFeeRecipient(address newRecipient) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("Setting fee recipient to:", newRecipient);
        vm.startBroadcast(deployerPrivateKey);
        minter.setFeeRecipient(newRecipient);
        vm.stopBroadcast();
        console.log("Fee recipient updated");
    }

    // ============================================
    // RESERVE MANAGEMENT
    // ============================================

    function fundReserve(uint256 amountUSD) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 amount = amountUSD * 1e6;
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Funding reserve with: $", amountUSD);
        console.log("From wallet:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Approve
        USDC.approve(address(minter), amount);
        console.log("USDC approved");

        // Fund
        minter.fundReserve(amount);
        console.log("Reserve funded with: $", amountUSD);

        vm.stopBroadcast();

        console.log("New reserve balance: $", minter.reserveBalance() / 1e6);
    }

    // NOTE: GBPbMinter doesn't have withdrawReserve function
    // Reserve can only be topped up, not withdrawn directly
    // Use emergencyWithdrawStrategy() to pull funds from strategy if needed

    // ============================================
    // STRATEGY & PERP MANAGEMENT
    // ============================================

    function rebalancePerp() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("Current perp health:", perpManager.getHealthFactor());
        console.log("Rebalancing perp position...");

        vm.startBroadcast(deployerPrivateKey);
        minter.rebalancePerp();
        vm.stopBroadcast();

        console.log("Perp rebalanced");
        console.log("New perp health:", perpManager.getHealthFactor());
    }

    function emergencyWithdraw() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("EMERGENCY: Withdrawing all funds from strategy...");
        vm.startBroadcast(deployerPrivateKey);
        uint256 withdrawn = minter.emergencyWithdrawStrategy();
        vm.stopBroadcast();
        console.log("Withdrawn: $", withdrawn / 1e6);
        console.log("Funds now in minter contract");
    }

    function updatePrice() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("Updating last price...");
        vm.startBroadcast(deployerPrivateKey);
        minter.updateLastPrice();
        vm.stopBroadcast();
        console.log("Price updated to:", minter.lastGBPbPrice());
    }

    // ============================================
    // REVENUE SHARE MANAGEMENT
    // ============================================

    function viewRevenueSplit() public view {
        console.log("=================================================");
        console.log("REVENUE SHARE CONFIGURATION");
        console.log("=================================================");

        console.log("Treasury Address:    ", feeDistributor.treasury());
        console.log("Reserve Buffer:      ", feeDistributor.reserveBuffer());
        console.log("");

        uint256 treasuryBps = feeDistributor.treasuryShareBps();
        uint256 reserveBps = feeDistributor.reserveShareBps();

        console.log("Treasury Share (bps):", treasuryBps);
        console.log("Reserve Share (bps): ", reserveBps);
        console.log("(10000 bps = 100%)");

        console.log("Released to Treasury: ", feeDistributor.releasedTreasury() / 1e18);
        console.log("Released to Reserve:  ", feeDistributor.releasedReserve() / 1e18);
        console.log("");

        console.log("Pending Treasury:    ", feeDistributor.releasable(feeDistributor.treasury()) / 1e18);
        console.log("Pending Reserve:     ", feeDistributor.releasable(feeDistributor.reserveBuffer()) / 1e18);

        console.log("=================================================");
    }

    function setRevenueSplit(uint256 treasuryPercent, uint256 reservePercent) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        if (treasuryPercent + reservePercent != 100) {
            console.log("ERROR: Treasury + Reserve must equal 100%");
            return;
        }

        uint256 treasuryBps = treasuryPercent * 100;
        uint256 reserveBps = reservePercent * 100;

        console.log("Setting revenue split:");
        console.log("  Treasury:", treasuryPercent, "%");
        console.log("  Reserve: ", reservePercent, "%");

        vm.startBroadcast(deployerPrivateKey);
        feeDistributor.setRevenueSplit(treasuryBps, reserveBps);
        vm.stopBroadcast();

        console.log("Revenue split updated!");
    }

    function setTreasuryAddress(address newTreasury) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("Updating treasury address to:", newTreasury);

        vm.startBroadcast(deployerPrivateKey);
        feeDistributor.setTreasury(newTreasury);
        vm.stopBroadcast();

        console.log("Treasury address updated!");
    }

    function setReserveBufferAddress(address newBuffer) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("Updating reserve buffer address to:", newBuffer);

        vm.startBroadcast(deployerPrivateKey);
        feeDistributor.setReserveBuffer(newBuffer);
        vm.stopBroadcast();

        console.log("Reserve buffer address updated!");
    }

    function claimTreasuryFees() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        uint256 pending = feeDistributor.releasable(feeDistributor.treasury());
        console.log("Claiming treasury fees:", pending / 1e18, "sGBPb");

        vm.startBroadcast(deployerPrivateKey);
        feeDistributor.releaseTreasury();
        vm.stopBroadcast();

        console.log("Treasury fees claimed!");
    }

    function claimReserveFees() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        uint256 pending = feeDistributor.releasable(feeDistributor.reserveBuffer());
        console.log("Claiming reserve fees:", pending / 1e18, "sGBPb");

        vm.startBroadcast(deployerPrivateKey);
        feeDistributor.releaseReserve();
        vm.stopBroadcast();

        console.log("Reserve fees claimed!");
    }

    // ============================================
    // USER SIMULATION (for testing)
    // ============================================

    function testMint(uint256 amountUSD) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 amount = amountUSD * 1e6;
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Test minting $", amountUSD, "worth of GBPb");
        console.log("User:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Approve
        USDC.approve(address(minter), amount);

        // Mint
        uint256 gbpbReceived = minter.mint(amount);

        vm.stopBroadcast();

        console.log("GBPb received:", gbpbReceived / 1e18);
        console.log("New TVL: $", minter.totalAssets() / 1e6);
    }

    function testRedeem(uint256 gbpbAmount) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 amount = gbpbAmount * 1e18;
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Test redeeming", gbpbAmount, "GBPb");
        console.log("User:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Approve
        gbpb.approve(address(minter), amount);

        // Redeem
        uint256 usdcReceived = minter.redeem(amount);

        vm.stopBroadcast();

        console.log("USDC received: $", usdcReceived / 1e6);
        console.log("New TVL: $", minter.totalAssets() / 1e6);
    }
}
