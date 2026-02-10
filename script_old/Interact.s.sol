// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GBPYieldVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title InteractWithVault
 * @notice Helper scripts for interacting with the deployed GBP Yield Vault
 * @dev Run with: forge script script/Interact.s.sol:FunctionName --rpc-url $RPC_URL --broadcast
 */
contract DepositToVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        uint256 depositAmount = vm.envUint("DEPOSIT_AMOUNT"); // in USDC (6 decimals)

        vm.startBroadcast(deployerPrivateKey);

        GBPYieldVault vault = GBPYieldVault(vaultAddress);
        IERC20 usdc = IERC20(vault.asset());

        // Approve vault to spend USDC
        usdc.approve(vaultAddress, depositAmount);
        console.log("Approved vault to spend", depositAmount, "USDC");

        // Deposit to vault
        uint256 shares = vault.deposit(depositAmount, msg.sender);
        console.log("Deposited", depositAmount, "USDC");
        console.log("Received", shares, "shares");

        vm.stopBroadcast();
    }
}

contract WithdrawFromVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        uint256 sharesToRedeem = vm.envUint("SHARES_AMOUNT");

        vm.startBroadcast(deployerPrivateKey);

        GBPYieldVault vault = GBPYieldVault(vaultAddress);

        // Redeem shares
        uint256 assetsReturned = vault.redeem(sharesToRedeem, msg.sender, msg.sender);
        console.log("Redeemed", sharesToRedeem, "shares");
        console.log("Received", assetsReturned, "USDC");

        vm.stopBroadcast();
    }
}

contract CheckVaultStatus is Script {
    function run() external view {
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        GBPYieldVault vault = GBPYieldVault(vaultAddress);

        console.log("=== Vault Status ===");
        console.log("Total Assets (USD):", vault.totalAssets());
        console.log("Total Assets (GBP):", vault.totalAssetsGBP());
        console.log("Total Shares:", vault.totalSupply());
        console.log("Share Price (GBP):", vault.sharePriceGBP());
        console.log("Yield Allocation:", vault.yieldAllocation(), "bps");
        console.log("Perp Allocation:", vault.perpAllocation(), "bps");
        console.log("Target Leverage:", vault.targetLeverage(), "x");
        console.log("Paused:", vault.paused());
        console.log("====================");
    }
}

contract CheckUserBalance is Script {
    function run() external view {
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address userAddress = vm.envAddress("USER_ADDRESS");

        GBPYieldVault vault = GBPYieldVault(vaultAddress);
        IERC20 usdc = IERC20(vault.asset());

        uint256 shares = vault.balanceOf(userAddress);
        uint256 usdcBalance = usdc.balanceOf(userAddress);

        console.log("=== User Balance ===");
        console.log("User:", userAddress);
        console.log("Vault Shares:", shares);
        console.log("USDC Balance:", usdcBalance);

        if (shares > 0) {
            uint256 assetsValue = vault.previewRedeem(shares);
            console.log("Shares Value (USD):", assetsValue);

            uint256 gbpValue = vault.totalAssetsGBP() * shares / vault.totalSupply();
            console.log("Shares Value (GBP):", gbpValue);
        }
        console.log("====================");
    }
}

contract EmergencyPause is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        GBPYieldVault vault = GBPYieldVault(vaultAddress);
        vault.pause();

        console.log("Vault paused successfully");

        vm.stopBroadcast();
    }
}

contract EmergencyUnpause is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        GBPYieldVault vault = GBPYieldVault(vaultAddress);
        vault.unpause();

        console.log("Vault unpaused successfully");

        vm.stopBroadcast();
    }
}

contract UpdateAllocations is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        uint256 yieldAlloc = vm.envUint("YIELD_ALLOCATION"); // basis points
        uint256 perpAlloc = vm.envUint("PERP_ALLOCATION");   // basis points

        vm.startBroadcast(deployerPrivateKey);

        GBPYieldVault vault = GBPYieldVault(vaultAddress);
        vault.setAllocations(yieldAlloc, perpAlloc);

        console.log("Updated allocations:");
        console.log("Yield:", yieldAlloc, "bps");
        console.log("Perp:", perpAlloc, "bps");

        vm.stopBroadcast();
    }
}
