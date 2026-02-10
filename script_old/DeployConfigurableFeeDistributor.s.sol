// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ConfigurableFeeDistributor.sol";

/**
 * @title Deploy Configurable Fee Distributor
 * @notice Deploys a new ConfigurableFeeDistributor with custom revenue split
 * @dev Run with: forge script script/DeployConfigurableFeeDistributor.s.sol:DeployConfigurableFeeDistributor --rpc-url $ARBITRUM_RPC --broadcast
 */
contract DeployConfigurableFeeDistributor is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load addresses from environment
        address sGBPbAddress = vm.envAddress("SGBPB_ADDRESS");
        address treasury = vm.envOr("TREASURY_ADDRESS", deployer);
        address reserveRecipient = vm.envOr("RESERVE_RECIPIENT", deployer);

        // Default split: 90% Treasury, 10% Reserve (9000 bps, 1000 bps)
        // You can customize these values:
        uint256 treasuryBps = vm.envOr("TREASURY_BPS", uint256(9000)); // 90%
        uint256 reserveBps = vm.envOr("RESERVE_BPS", uint256(1000));   // 10%

        console.log("=================================================");
        console.log("Deploying Configurable Fee Distributor");
        console.log("=================================================");
        console.log("Deployer:        ", deployer);
        console.log("sGBPb Vault:     ", sGBPbAddress);
        console.log("Treasury:        ", treasury);
        console.log("Reserve Buffer:  ", reserveRecipient);
        console.log("Treasury Share:  ", treasuryBps / 100, "%");
        console.log("Reserve Share:   ", reserveBps / 100, "%");
        console.log("=================================================");

        vm.startBroadcast(deployerPrivateKey);

        ConfigurableFeeDistributor feeDistributor = new ConfigurableFeeDistributor(
            sGBPbAddress,
            treasury,
            reserveRecipient,
            treasuryBps,
            reserveBps,
            deployer
        );

        vm.stopBroadcast();

        console.log("\n=================================================");
        console.log("DEPLOYMENT COMPLETE");
        console.log("=================================================");
        console.log("ConfigurableFeeDistributor:", address(feeDistributor));
        console.log("=================================================");

        console.log("\n=================================================");
        console.log("NEXT STEPS");
        console.log("=================================================");
        console.log("1. Add to your .env file:");
        console.log("   FEE_DISTRIBUTOR_ADDRESS=", address(feeDistributor));
        console.log("");
        console.log("2. Update sGBPb vault fee collector to:");
        console.log("   Address:", address(feeDistributor));
        console.log("   Use cast send command with setFeeCollector");
        console.log("");
        console.log("3. Test with viewRevenueSplit() in Admin tool");
        console.log("=================================================");
    }
}
