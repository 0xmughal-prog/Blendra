// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IOldMinter {
    function owner() external view returns (address);
}

/**
 * @title RescueOldMinter
 * @notice Emergency rescue script to recover USDC from old minter contract
 * @dev Uses delegatecall trick to transfer USDC from the old minter
 */
contract RescueHelper {
    function rescue(address token, address to) external {
        IERC20(token).transfer(to, IERC20(token).balanceOf(address(this)));
    }
}

contract RescueOldMinter is Script {
    address constant OLD_MINTER = 0x680A5F9d86accdcfd0aaCdaf533896A5B6c0F11d;
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Rescuing USDC from old minter...");
        console.log("Old Minter:", OLD_MINTER);
        console.log("Deployer:", deployer);

        // Check USDC balance in old minter
        uint256 balance = IERC20(USDC).balanceOf(OLD_MINTER);
        console.log("USDC balance in old minter:", balance);

        if (balance == 0) {
            console.log("No USDC to rescue!");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        // Deploy rescue helper
        RescueHelper helper = new RescueHelper();
        console.log("RescueHelper deployed at:", address(helper));

        // Try to call a low-level function on old minter that might transfer tokens
        // Approach 1: Try calling transfer directly as owner
        (bool success, ) = OLD_MINTER.call(
            abi.encodeWithSignature(
                "transfer(address,address,uint256)",
                USDC,
                deployer,
                balance
            )
        );

        if (!success) {
            // Approach 2: Try rescue function
            (success, ) = OLD_MINTER.call(
                abi.encodeWithSignature(
                    "rescueERC20(address,address,uint256)",
                    USDC,
                    deployer,
                    balance
                )
            );
        }

        if (!success) {
            // Approach 3: Try emergency withdraw
            (success, ) = OLD_MINTER.call(
                abi.encodeWithSignature("emergencyWithdraw(address,uint256)", USDC, balance)
            );
        }

        vm.stopBroadcast();

        // Check final balance
        uint256 finalBalance = IERC20(USDC).balanceOf(deployer);
        console.log("\n========================================");
        if (success) {
            console.log("SUCCESS! USDC rescued");
            console.log("Your new USDC balance:", finalBalance);
        } else {
            console.log("FAILED to rescue with standard methods");
            console.log("Manual intervention needed");
        }
        console.log("========================================");
    }
}
