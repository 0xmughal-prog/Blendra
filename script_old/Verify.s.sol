// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/tokens/GBPbMinter.sol";
import "../src/tokens/GBPb.sol";
import "../src/tokens/sGBPb.sol";
import "../src/strategies/MorphoStrategyAdapter.sol";
import "../src/PerpPositionManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Deployment Verification Script
 * @notice Verifies deployment configuration and monitors protocol health
 * @dev Run with: forge script script/Verify.s.sol:VerifyDeployment --rpc-url $ARBITRUM_RPC
 */
contract VerifyDeployment is Script {
    IERC20 constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

    function run() external view {
        // Load deployed addresses from environment or pass as parameters
        address minterAddr = vm.envAddress("MINTER_ADDRESS");
        address gbpbAddr = vm.envAddress("GBPB_ADDRESS");
        address sGBPbAddr = vm.envAddress("SGBPB_ADDRESS");
        address strategyAddr = vm.envAddress("STRATEGY_ADDRESS");
        address perpManagerAddr = vm.envAddress("PERP_MANAGER_ADDRESS");

        GBPbMinter minter = GBPbMinter(minterAddr);
        GBPb gbpb = GBPb(gbpbAddr);
        sGBPb vault = sGBPb(sGBPbAddr);
        MorphoStrategyAdapter strategy = MorphoStrategyAdapter(strategyAddr);
        PerpPositionManager perpManager = PerpPositionManager(perpManagerAddr);

        console.log("=================================================");
        console.log("DEPLOYMENT VERIFICATION");
        console.log("=================================================");

        verifyConfiguration(minter, gbpb, vault, strategy, perpManager);
        verifySafetyParameters(minter);
        checkProtocolHealth(minter, strategy, perpManager);
        checkReserveStatus(minter);
        checkBalances(address(minter), strategyAddr, perpManagerAddr);

        console.log("\n=================================================");
        console.log("VERIFICATION COMPLETE");
        console.log("=================================================");
    }

    function verifyConfiguration(
        GBPbMinter minter,
        GBPb gbpb,
        sGBPb vault,
        MorphoStrategyAdapter strategy,
        PerpPositionManager perpManager
    ) internal view {
        console.log("\n1. Configuration Verification");
        console.log("   ---------------------------------");

        // Check minter setup
        require(gbpb.minter() == address(minter), "GBPb minter not set correctly");
        console.log("   \u2713 GBPb minter configured");

        require(vault.minter() == address(minter), "sGBPb minter not set correctly");
        console.log("   \u2713 sGBPb minter configured");

        require(address(minter.activeStrategy()) == address(strategy), "Strategy not set");
        console.log("   \u2713 Active strategy configured");

        require(address(minter.perpManager()) == address(perpManager), "PerpManager not set");
        console.log("   \u2713 Perp manager configured");

        require(strategy.owner() == address(minter), "Strategy owner incorrect");
        console.log("   \u2713 Strategy ownership transferred");
    }

    function verifySafetyParameters(GBPbMinter minter) internal view {
        console.log("\n2. Safety Parameters");
        console.log("   ---------------------------------");

        uint256 tvlCap = minter.tvlCap();
        console.log("   TVL Cap:              $", tvlCap / 1e6);
        require(tvlCap == 5_000 * 1e6, "TVL cap not set to $5,000");
        console.log("   \u2713 TVL cap correct");

        uint256 minReserve = minter.minReserveBalance();
        console.log("   Min Reserve:          $", minReserve / 1e6);
        require(minReserve == 100 * 1e6, "Min reserve not set to $100");
        console.log("   \u2713 Min reserve correct");

        uint256 cooldown = minter.userOperationCooldown();
        console.log("   User Cooldown:        ", cooldown / 1 days, "days");
        require(cooldown == 1 days, "Cooldown not set to 1 day");
        console.log("   \u2713 Cooldown correct");

        uint256 minHold = minter.MIN_HOLD_TIME();
        console.log("   Min Hold Time:        ", minHold / 1 hours, "hours");
        require(minHold == 24 hours, "Min hold time not 24 hours");
        console.log("   \u2713 Min hold time correct");

        uint256 redeemFee = minter.REDEEM_FEE_BPS();
        console.log("   Redeem Fee:            0.20%");
        require(redeemFee == 20, "Redeem fee not 0.20%");
        console.log("   \u2713 Redeem fee correct");
    }

    function checkProtocolHealth(
        GBPbMinter minter,
        MorphoStrategyAdapter strategy,
        PerpPositionManager perpManager
    ) internal view {
        console.log("\n3. Protocol Health");
        console.log("   ---------------------------------");

        // Check if paused
        bool isPaused = minter.paused();
        console.log("   Status:              ", isPaused ? "PAUSED" : "ACTIVE");

        // Check TVL
        uint256 tvl = minter.totalAssets();
        console.log("   Current TVL:          $", tvl / 1e6);

        // Check lending allocation
        uint256 lendingAssets = strategy.totalAssets();
        console.log("   Morpho Holdings:      $", lendingAssets / 1e6);

        // Check perp position
        uint256 perpCollateral = perpManager.currentCollateral();
        console.log("   Perp Collateral:      $", perpCollateral / 1e6);

        // Check perp health
        if (perpCollateral > 0) {
            uint256 healthFactor = perpManager.getHealthFactor();
            console.log("   Perp Health Factor:   ", healthFactor);
            console.log("   (10000 = 100%, 5000 = 50%)");

            if (healthFactor < 5000) {
                console.log("   \u26A0 WARNING: Perp health below 50%! Consider rebalancing.");
            } else {
                console.log("   \u2713 Perp position healthy");
            }
        } else {
            console.log("   Perp Health:          N/A (no position)");
        }

        // Check GBP price
        uint256 gbpPrice = minter.oracle().getGBPUSDPrice();
        console.log("   GBP/USD Price:        ", gbpPrice);
        console.log("   (Price in 8 decimals, ~127000000 = $1.27)");
    }

    function checkReserveStatus(GBPbMinter minter) internal view {
        console.log("\n4. Reserve Fund Status");
        console.log("   ---------------------------------");

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

        console.log("   Current Reserve:      $", currentReserve / 1e6);
        console.log("   Minimum Required:     $", minReserve / 1e6);
        console.log("   Opening Fees Paid:    $", openingFeesPaid / 1e6);
        console.log("   Redemption Fees:      $", redemptionFeesCollected / 1e6);

        if (netRevenue >= 0) {
            console.log("   Net Revenue:          +$", uint256(netRevenue) / 1e6);
        } else {
            console.log("   Net Revenue:          -$", uint256(-netRevenue) / 1e6);
        }

        console.log("   Yield Borrowed:       $", yieldBorrowed / 1e6);
        console.log("   Founder Owed:         $", founderOwed / 1e6);
        console.log("   Total Outstanding:    $", totalOutstanding / 1e6);

        bool isHealthy = minter.isReserveHealthy();
        console.log("   Health Status:        ", isHealthy ? "HEALTHY" : "NEEDS FUNDING");

        if (!isHealthy) {
            console.log("   \u26A0 WARNING: Reserve below minimum! Fund immediately.");
        } else {
            console.log("   \u2713 Reserve adequately funded");
        }
    }

    function checkBalances(
        address minterAddr,
        address strategyAddr,
        address perpManagerAddr
    ) internal view {
        console.log("\n5. USDC Balances");
        console.log("   ---------------------------------");

        uint256 minterBalance = USDC.balanceOf(minterAddr);
        console.log("   Minter:               $", minterBalance / 1e6);

        uint256 strategyBalance = USDC.balanceOf(strategyAddr);
        console.log("   Strategy:             $", strategyBalance / 1e6);

        uint256 perpBalance = USDC.balanceOf(perpManagerAddr);
        console.log("   PerpManager:          $", perpBalance / 1e6);

        uint256 totalBalance = minterBalance + strategyBalance + perpBalance;
        console.log("   Total (direct):       $", totalBalance / 1e6);
    }
}
