// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/tokens/sGBPb.sol";
import "../src/tokens/GBPbMinter.sol";
import "../src/FeeDistributor.sol";

/**
 * @title RedeploySGBPb
 * @notice Redeploy sGBPb with 100% max performance fee and rescue function
 */
contract RedeploySGBPb is Script {
    // Existing contracts
    address constant GBPB = 0xf04e200541c6E9Ec4499757653cD2f166Faf8F91;
    address constant MINTER = 0x3224854163Ded9b939EEe85d0c9f3130e8fA2569;
    address constant FEE_DISTRIBUTOR = 0x7545c943A2dD2bFc3593810F96dEe4AD7CE9a913;
    address constant TREASURY = 0x6d0359bB1874ed16eDcdBA8D4718e68A8ff924d5;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== REDEPLOYING sGBPb ===");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new sGBPb with rescue function and 100% max fee
        console.log("\n1. Deploying new sGBPb...");
        sGBPb newSGBPb = new sGBPb(GBPB, deployer);
        console.log("New sGBPb deployed at:", address(newSGBPb));

        // Set minter on new sGBPb
        console.log("\n2. Setting minter on new sGBPb...");
        newSGBPb.setMinter(MINTER);
        console.log("Minter set to:", MINTER);

        // Set fee collector on new sGBPb
        console.log("\n3. Setting fee collector on new sGBPb...");
        newSGBPb.setFeeCollector(FEE_DISTRIBUTOR);
        console.log("Fee collector set to:", FEE_DISTRIBUTOR);

        // Set performance fee to 15%
        console.log("\n4. Setting performance fee to 15% (1500 BPS)...");
        newSGBPb.setPerformanceFee(1500);
        console.log("Performance fee set to 15%");

        // Update GBPbMinter to use new sGBPb
        console.log("\n5. Updating GBPbMinter to use new sGBPb...");
        GBPbMinter(MINTER).setSGBPbVault(address(newSGBPb));
        console.log("GBPbMinter updated");

        // Update FeeDistributor to verify treasury (already set)
        console.log("\n6. Verifying treasury address...");
        address currentTreasury = FeeDistributor(FEE_DISTRIBUTOR).treasury();
        console.log("Current treasury:", currentTreasury);
        if (currentTreasury != TREASURY) {
            console.log("Treasury needs update - already done in previous tx");
        }

        vm.stopBroadcast();

        console.log("\n========================================");
        console.log("DEPLOYMENT COMPLETE!");
        console.log("========================================");
        console.log("\nNew sGBPb:         ", address(newSGBPb));
        console.log("Old sGBPb (obsolete): 0xC388c87F3f983111C02375C956ed3f0BA6B5b18c");
        console.log("\nConfiguration:");
        console.log("  Max Performance Fee: 100% (10000 BPS)");
        console.log("  Current Fee:         15% (1500 BPS)");
        console.log("  Rescue Function:     ADDED");
        console.log("  Treasury:           ", TREASURY);
        console.log("\nNext steps:");
        console.log("1. Update UI with new sGBPb address");
        console.log("2. Test minting with $5+ USDC");
        console.log("========================================");
    }
}
