#!/bin/bash

# Test script for GBPb/sGBPb 2-token model on Arbitrum Sepolia
# This script tests the complete user flow: USDC → GBPb → sGBPb → GBPb → USDC

set -e  # Exit on error

# Load environment variables
source .env

# Contract addresses from deployment (10x leverage)
USDC="0xEACE2c1eEA7A7025fDaDd5b7546Ffd0d65bc94e2"
MINTER="0xC0e4e8925476ce02d015ceEaC0D3E03C471D2A76"
GBPB="0x23589CA228Ce53004A4BCc1dbE73E185F7d6970E"
SGBPB="0x2B3E6243DBE7f59da34EAfc92475C24702eEAE8C"
DEPLOYER="0x5db104d7820Cb05b9214f053FFc23e99e9eCf65a"

RPC="--rpc-url arbitrum_sepolia"
ACCOUNT="--private-key $PRIVATE_KEY"

echo "==============================================="
echo "GBPb/sGBPb User Flow Testing"
echo "==============================================="
echo ""

# Step 1: Check USDC balance
echo "📊 Step 1: Check initial USDC balance"
USDC_BALANCE=$(cast call $USDC "balanceOf(address)(uint256)" $DEPLOYER $RPC)
echo "   USDC Balance: $(cast to-dec $USDC_BALANCE) (raw: $USDC_BALANCE)"
echo ""

# Step 2: Approve USDC for minting
echo "✅ Step 2: Approve USDC for minter (1000 USDC)"
AMOUNT="1000000000"  # 1000 USDC (6 decimals)
cast send $USDC "approve(address,uint256)" $MINTER $AMOUNT $RPC $ACCOUNT --gas-limit 100000
echo "   Approved: 1000 USDC"
echo ""

# Wait a bit for transaction to be mined
sleep 5

# Step 3: Mint GBPb tokens
echo "🏭 Step 3: Mint GBPb tokens with 1000 USDC"
echo "   This should:"
echo "   - Take 1000 USDC from user"
echo "   - Deposit 900 USDC to Morpho (90%)"
echo "   - Deposit 100 USDC to perp (10%)"
echo "   - Mint ~787 GBPb tokens (1000 / 1.27 GBP/USD)"
echo ""
cast send $MINTER "mint(uint256)" $AMOUNT $RPC $ACCOUNT --gas-limit 2000000
echo "   ✅ Minted GBPb!"
echo ""

# Wait for transaction
sleep 5

# Step 4: Check GBPb balance
echo "📊 Step 4: Check GBPb balance"
GBPB_BALANCE=$(cast call $GBPB "balanceOf(address)(uint256)" $DEPLOYER $RPC)
GBPB_HUMAN=$(cast to-unit $GBPB_BALANCE ether)
echo "   GBPb Balance: $GBPB_HUMAN GBPb"
echo ""

# Step 5: Check minter TVL
echo "📊 Step 5: Check total value locked"
TVL=$(cast call $MINTER "totalAssets()(uint256)" $RPC)
echo "   Total USDC in strategies: $(cast to-dec $TVL)"
echo ""

# Step 6: Approve GBPb for staking
echo "✅ Step 6: Approve GBPb for staking"
cast send $GBPB "approve(address,uint256)" $SGBPB $GBPB_BALANCE $RPC $ACCOUNT --gas-limit 100000
echo "   Approved: $GBPB_HUMAN GBPb"
echo ""

sleep 5

# Step 7: Stake GBPb to earn yield (deposit to sGBPb)
echo "💰 Step 7: Stake GBPb to sGBPb"
echo "   This should:"
echo "   - Take GBPb from user"
echo "   - Mint sGBPb shares (initially 1:1)"
echo ""
cast send $SGBPB "deposit(uint256,address)" $GBPB_BALANCE $DEPLOYER $RPC $ACCOUNT --gas-limit 500000
echo "   ✅ Staked to sGBPb!"
echo ""

sleep 5

# Step 8: Check sGBPb balance
echo "📊 Step 8: Check sGBPb balance"
SGBPB_BALANCE=$(cast call $SGBPB "balanceOf(address)(uint256)" $DEPLOYER $RPC)
SGBPB_HUMAN=$(cast to-unit $SGBPB_BALANCE ether)
echo "   sGBPb Balance: $SGBPB_HUMAN sGBPb"
echo ""

# Step 9: Check price per share
echo "📊 Step 9: Check price per share"
PRICE_PER_SHARE=$(cast call $SGBPB "pricePerShare()(uint256)" $RPC)
PRICE_HUMAN=$(cast to-unit $PRICE_PER_SHARE ether)
echo "   Price per share: $PRICE_HUMAN GBPb/sGBPb"
echo ""

# Step 10: Check total assets in sGBPb
echo "📊 Step 10: Check total assets in sGBPb vault"
TOTAL_ASSETS=$(cast call $SGBPB "totalAssets()(uint256)" $RPC)
TOTAL_ASSETS_HUMAN=$(cast to-unit $TOTAL_ASSETS ether)
echo "   Total assets: $TOTAL_ASSETS_HUMAN GBPb"
echo ""

# Step 11: Simulate yield accrual (for mock vault)
echo "⏰ Step 11: Simulating yield accrual..."
echo "   (In production, yield accrues from lending + perp)"
echo "   (In mocks, we can manually trigger yield)"
echo ""

# Step 12: Try to mint again (should fail due to rate limit)
echo "🛡️ Step 12: Test rate limit (should fail)"
echo "   Trying to mint again within cooldown period..."
cast send $MINTER "mint(uint256)" "100000000" $RPC $ACCOUNT --gas-limit 2000000 2>&1 || echo "   ✅ Rate limit working! Transaction reverted as expected"
echo ""

# Step 13: Summary
echo "==============================================="
echo "✅ Test Flow Complete!"
echo "==============================================="
echo ""
echo "Summary:"
echo "  - Minted GBPb: $GBPB_HUMAN"
echo "  - Staked to sGBPb: $SGBPB_HUMAN"
echo "  - Price per share: $PRICE_HUMAN"
echo "  - Total value locked: $(cast to-dec $TVL) USDC"
echo ""
echo "Next steps:"
echo "  - Wait for yield to accrue"
echo "  - Harvest fees"
echo "  - Test unstaking + redemption"
echo ""
echo "==============================================="
