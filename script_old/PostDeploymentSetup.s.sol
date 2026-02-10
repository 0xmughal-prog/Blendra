// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GBPbMinter} from "../src/tokens/GBPbMinter.sol";
import {sGBPb} from "../src/tokens/sGBPb.sol";

/**
 * @title PostDeploymentSetup
 * @notice Post-deployment configuration and initial funding
 * @dev Run this AFTER Deploy2TokenModel.s.sol to set up the protocol
 */
contract PostDeploymentSetup is Script {
    // Update these with deployed contract addresses
    address constant USDC = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d; // Arbitrum Sepolia
    address constant MINTER = address(0); // TODO: Add deployed minter address
    address constant SGBPB = address(0); // TODO: Add deployed sGBPb address

    // Configuration parameters
    uint256 constant RESERVE_FUND_AMOUNT = 500e6; // $500 USDC
    uint256 constant TVL_CAP = 10_000_000e6; // $10M USDC
    uint256 constant MIN_HARVEST_INTERVAL = 12 hours;
    uint256 constant MIN_HARVEST_AMOUNT = 10e6; // $10 USDC

    function run() external {
        require(MINTER != address(0), "Set MINTER address first");
        require(SGBPB != address(0), "Set SGBPB address first");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("===============================================");
        console.log("Post-Deployment Setup");
        console.log("===============================================");
        console.log("Admin:", deployer);
        console.log("Minter:", MINTER);
        console.log("sGBPb:", SGBPB);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        GBPbMinter minter = GBPbMinter(MINTER);
        sGBPb sGBPbToken = sGBPb(SGBPB);
        IERC20 usdc = IERC20(USDC);

        // Step 1: Fund reserve
        console.log("1. Funding reserve with", RESERVE_FUND_AMOUNT / 1e6, "USDC...");
        uint256 balance = usdc.balanceOf(deployer);
        require(balance >= RESERVE_FUND_AMOUNT, "Insufficient USDC balance");

        usdc.approve(MINTER, RESERVE_FUND_AMOUNT);
        minter.fundReserve(RESERVE_FUND_AMOUNT);
        console.log("   Reserve funded: $", RESERVE_FUND_AMOUNT / 1e6);

        // Step 2: Set TVL cap
        console.log("2. Setting TVL cap...");
        minter.setTVLCap(TVL_CAP);
        console.log("   TVL Cap set: $", TVL_CAP / 1e6);

        // Step 3: Set harvest configuration
        console.log("3. Setting harvest configuration...");
        minter.setHarvestConfig(MIN_HARVEST_INTERVAL, MIN_HARVEST_AMOUNT);
        console.log("   Min interval:", MIN_HARVEST_INTERVAL / 3600, "hours");
        console.log("   Min amount: $", MIN_HARVEST_AMOUNT / 1e6);

        // Step 4: Set min reserve balance
        console.log("4. Setting minimum reserve balance...");
        minter.setMinReserveBalance(100e6); // $100 minimum
        console.log("   Min reserve: $100");

        vm.stopBroadcast();

        // Display summary
        console.log("");
        console.log("===============================================");
        console.log("Setup Complete!");
        console.log("===============================================");
        console.log("");
        console.log("Protocol Configuration:");
        console.log("  Reserve Balance:  $", minter.reserveBalance() / 1e6);
        console.log("  Min Reserve:      $", minter.minReserveBalance() / 1e6);
        console.log("  TVL Cap:          $", minter.tvlCap() / 1e6);
        console.log("  Target Leverage:  ", minter.targetLeverage(), "x");
        console.log("");
        console.log("Next Steps:");
        console.log("1. Verify all contracts on Arbiscan");
        console.log("2. Update admin UI with contract addresses");
        console.log("3. Test user flow (mint -> stake -> harvest)");
        console.log("4. Monitor for 24-48 hours before announcing");
        console.log("===============================================");
    }
}
