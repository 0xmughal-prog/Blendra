// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/tokens/GBPbMinter.sol";
import "../src/tokens/GBPb.sol";
import "../src/tokens/sGBPb.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockChainlinkOracle.sol";
import "../src/mocks/MockERC4626Vault.sol";
import "../src/strategies/MorphoStrategyAdapter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CriticalTest
 * @notice Tests for the most critical vulnerabilities
 */
contract CriticalTest is Test {
    GBPbMinter public minter;
    GBPb public gbpb;
    sGBPb public sGBPbVault;
    MockChainlinkOracle public oracle;
    MockERC20 public usdc;
    MockERC4626Vault public morphoVault;
    MorphoStrategyAdapter public morphoStrategy;
    MockPerpManager public perpManager;

    address public owner = address(this);
    address public user1 = address(0x1);

    function setUp() public {
        // Warp to a future timestamp to avoid rate limit issues
        vm.warp(1000000);

        // Deploy tokens
        usdc = new MockERC20("USDC", "USDC", 6);
        oracle = new MockChainlinkOracle(130000000, 8); // 1.30 GBP/USD

        // Deploy GBPb
        gbpb = new GBPb(owner);

        // Deploy minter
        minter = new GBPbMinter(
            address(usdc),
            address(gbpb),
            address(oracle),
            owner
        );

        // Deploy Morpho vault and strategy
        morphoVault = new MockERC4626Vault(
            IERC20(address(usdc)),
            "Morpho KPK",
            "mKPK"
        );
        morphoStrategy = new MorphoStrategyAdapter(
            address(usdc),
            address(morphoVault),
            address(minter)
        );

        // Deploy sGBPb
        sGBPbVault = new sGBPb(address(gbpb), owner);
        sGBPbVault.setMinter(address(minter));
        sGBPbVault.setFeeCollector(owner);

        // Deploy mock perp manager
        perpManager = new MockPerpManager();

        // Wire up
        gbpb.setMinter(address(minter));
        minter.setActiveStrategy(address(morphoStrategy));
        minter.setSGBPbVault(address(sGBPbVault));
        minter.setPerpManager(address(perpManager));

        // Disable weekend check for most tests (except testWeekendProtection)
        minter.setWeekendCheckEnabled(false);

        // Fund user
        usdc.mint(user1, 1000000e6);
        vm.prank(user1);
        usdc.approve(address(minter), type(uint256).max);
    }

    function testMintAndRedeem() public {
        console.log(">> Test: Mint and Redeem >>");

        vm.startPrank(user1);

        // Mint (minGbpAmount ~70 GBP for 100 USDC at 1.30 rate)
        uint256 gbpbAmount = minter.mint(100e6, 70e18);
        console.log("Minted GBPb:", gbpbAmount);
        assertGt(gbpbAmount, 0, "Should mint GBPb");

        // Check backing
        (bool isBackedProperly, uint256 backingRatioBPS,,) = minter.verifyGBPbBacking();
        console.log("Backing ratio (BPS):", backingRatioBPS);
        assertTrue(isBackedProperly, "Should be backed");
        assertGe(backingRatioBPS, 10000, "Should be >= 100%");

        // Wait for hold time
        skip(1 days + 1);

        // Redeem
        gbpb.approve(address(minter), gbpbAmount);
        uint256 usdcReceived = minter.redeem(gbpbAmount);
        console.log("Redeemed USDC:", usdcReceived);
        assertGt(usdcReceived, 0, "Should receive USDC");

        vm.stopPrank();

        console.log("[OK] Mint and Redeem works!\n");
    }

    function testCooldownEnforcement() public {
        console.log(">> Test: Cooldown Enforcement >>");

        vm.startPrank(user1);

        // Mint and stake
        uint256 gbpbAmount = minter.mint(100e6, 70e18);
        gbpb.approve(address(sGBPbVault), gbpbAmount);
        uint256 shares = sGBPbVault.deposit(gbpbAmount, user1);
        console.log("Staked, received shares:", shares);

        // Try to bypass via withdraw - should revert
        vm.expectRevert("Use unstake() and cooldownWithdraw()");
        sGBPbVault.withdraw(gbpbAmount, user1, user1);
        console.log("[OK] Withdraw() blocked");

        // Try to bypass via redeem - should revert
        vm.expectRevert("Use unstake() and cooldownWithdraw()");
        sGBPbVault.redeem(shares, user1, user1);
        console.log("[OK] Redeem() blocked");

        // maxWithdraw should return 0
        uint256 maxWithdraw = sGBPbVault.maxWithdraw(user1);
        assertEq(maxWithdraw, 0, "maxWithdraw should be 0");
        console.log("[OK] maxWithdraw returns 0");

        // Start unstake
        sGBPbVault.unstake(shares);
        console.log("[OK] Unstake initiated");

        // Try to withdraw immediately - should fail
        vm.expectRevert();
        sGBPbVault.cooldownWithdraw();
        console.log("[OK] Immediate withdrawal blocked");

        // Wait 1 day
        skip(1 days);

        // Now should work
        sGBPbVault.cooldownWithdraw();
        console.log("[OK] Withdrawal after cooldown works");

        assertGt(gbpb.balanceOf(user1), 0, "Should have GBPb");

        vm.stopPrank();

        console.log("[OK] Cooldown enforcement works!\n");
    }

    function testYieldDistribution() public {
        console.log(">> Test: Yield Distribution >>");

        // Mint and stake
        vm.startPrank(user1);
        uint256 gbpbAmount = minter.mint(100e6, 70e18);
        gbpb.approve(address(sGBPbVault), gbpbAmount);
        sGBPbVault.deposit(gbpbAmount, user1);
        vm.stopPrank();

        uint256 priceBefore = sGBPbVault.pricePerShare();
        console.log("Price before harvest:", priceBefore);

        // Simulate yield
        morphoVault.addYield(10e6);
        skip(13 hours);

        // Harvest
        minter.harvestYield();

        uint256 priceAfter = sGBPbVault.pricePerShare();
        console.log("Price after harvest:", priceAfter);

        assertGt(priceAfter, priceBefore, "Share price should increase");

        console.log("[OK] Yield distribution works!\n");
    }

    function testWeekendProtection() public {
        console.log(">> Test: Weekend Protection >>");

        // Re-enable weekend check for this test
        minter.setWeekendCheckEnabled(true);

        // Friday 11pm UTC - should block (Feb 9, 2024 11pm UTC)
        uint256 fridayEvening = 1707516000;
        vm.warp(fridayEvening);

        vm.prank(user1);
        vm.expectRevert(GBPbMinter.OstiumMarketClosed.selector);
        minter.mint(100e6, 70e18);

        console.log("[OK] Friday evening blocked");

        // Disable weekend check to test that minting works when enabled
        minter.setWeekendCheckEnabled(false);

        vm.prank(user1);
        uint256 gbpbReceived = minter.mint(100e6, 70e18);
        assertGt(gbpbReceived, 0, "Should mint when weekend check disabled");

        console.log("[OK] Minting works when weekend check disabled");
        console.log("[OK] Weekend protection works!\n");
    }

    function testMintTimeNotUpdatedOnTransfer() public {
        console.log(">> Test: MintTime Transfer Protection >>");

        vm.startPrank(user1);

        uint256 gbpbAmount = minter.mint(100e6, 70e18);
        uint256 mintTimeBefore = gbpb.mintTime(user1);
        console.log("Mint time before transfer:", mintTimeBefore);

        skip(1 hours);

        // Transfer to user2
        address user2 = address(0x2);
        gbpb.transfer(user2, gbpbAmount / 2);

        uint256 mintTimeAfter = gbpb.mintTime(user1);
        console.log("Mint time after transfer:", mintTimeAfter);

        assertEq(mintTimeBefore, mintTimeAfter, "Mint time should not change");

        console.log("[OK] MintTime protection works!\n");

        vm.stopPrank();
    }

    function testCompleteUserJourney() public {
        console.log(">> Test: Complete User Journey >>");

        vm.startPrank(user1);

        // 1. Mint GBPb
        console.log("Step 1: Minting GBPb...");
        uint256 gbpbAmount = minter.mint(100e6, 70e18);
        console.log("  Minted:", gbpbAmount);

        // 2. Stake
        console.log("Step 2: Staking GBPb...");
        gbpb.approve(address(sGBPbVault), gbpbAmount);
        uint256 shares = sGBPbVault.deposit(gbpbAmount, user1);
        console.log("  Received shares:", shares);

        vm.stopPrank();

        // 3. Simulate yield + harvest
        console.log("Step 3: Simulating yield...");
        morphoVault.addYield(5e6);
        skip(13 hours);
        minter.harvestYield();
        console.log("  Harvested yield");

        // 4. Unstake
        console.log("Step 4: Unstaking...");
        vm.startPrank(user1);
        sGBPbVault.unstake(shares);
        skip(1 days);
        sGBPbVault.cooldownWithdraw();
        console.log("  Unstaked successfully");

        uint256 gbpbAfter = gbpb.balanceOf(user1);
        console.log("  Final GBPb balance:", gbpbAfter);

        // Should have earned yield
        assertGt(gbpbAfter, gbpbAmount, "Should earn yield");

        vm.stopPrank();

        console.log("[OK] Complete user journey works!\n");
    }
}

// Mock Perp Manager
contract MockPerpManager {
    uint256 public collateral;

    function increasePosition(uint256, uint256 collateralAmount, uint256) external {
        collateral += collateralAmount;
    }

    function decreasePosition(uint256, uint256) external {
        collateral = collateral * 99 / 100;
    }

    function withdrawCollateral(uint256 amount) external returns (uint256) {
        if (amount > collateral) amount = collateral;
        collateral -= amount;
        return amount;
    }

    function getHealthFactor() external pure returns (uint256) {
        return 10000;
    }

    function getPositionValue() external view returns (uint256) {
        return collateral;
    }

    function getPositionPnL() external pure returns (int256) {
        return 0;
    }

    function currentCollateral() external view returns (uint256) {
        return collateral;
    }
}
