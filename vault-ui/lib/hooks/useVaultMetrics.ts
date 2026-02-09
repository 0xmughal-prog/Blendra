'use client';

import { useReadContract } from 'wagmi';
import { CONTRACTS, VAULT_ABI, ERC20_ABI } from '../contracts';
import { formatUnits } from 'viem';

/**
 * Hook to fetch comprehensive vault metrics
 */
export function useVaultMetrics() {
  // Total TVL in USDC
  const { data: totalAssets, isLoading: isLoadingTVL } = useReadContract({
    address: CONTRACTS.vault,
    abi: VAULT_ABI,
    functionName: 'totalAssets',
  });

  // Total GBPb supply
  const { data: totalGBPbSupply } = useReadContract({
    address: CONTRACTS.gbpb,
    abi: ERC20_ABI,
    functionName: 'totalSupply',
  });

  // Morpho strategy balance
  const { data: morphoBalance } = useReadContract({
    address: CONTRACTS.morphoStrategy,
    abi: [
      {
        inputs: [],
        name: 'totalAssets',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
      },
    ] as const,
    functionName: 'totalAssets',
  });

  // Morpho strategy APY (manually set)
  const { data: morphoAPY } = useReadContract({
    address: CONTRACTS.morphoStrategy,
    abi: [
      {
        inputs: [],
        name: 'currentAPY',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
      },
    ] as const,
    functionName: 'currentAPY',
  });

  // Perp manager collateral
  const { data: perpCollateral } = useReadContract({
    address: CONTRACTS.perpManager,
    abi: [
      {
        inputs: [],
        name: 'currentCollateral',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
      },
    ] as const,
    functionName: 'currentCollateral',
  });

  // GBP/USD exchange rate
  const { data: gbpUsdRate } = useReadContract({
    address: CONTRACTS.oracle,
    abi: [
      {
        inputs: [],
        name: 'getGBPUSDPrice',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
      },
    ] as const,
    functionName: 'getGBPUSDPrice',
  });

  // Calculate metrics
  const tvlUSD = totalAssets ? Number(formatUnits(totalAssets as bigint, 6)) : 0;
  const morphoBalanceUSD = morphoBalance ? Number(formatUnits(morphoBalance as bigint, 6)) : 0;
  const perpCollateralUSD = perpCollateral ? Number(formatUnits(perpCollateral as bigint, 6)) : 0;

  // Allocation percentages
  const morphoAllocation = tvlUSD > 0 ? (morphoBalanceUSD / tvlUSD) * 100 : 0;
  const perpAllocation = tvlUSD > 0 ? (perpCollateralUSD / tvlUSD) * 100 : 0;

  // Estimated net APY calculation
  // Morpho APY is in basis points (500 = 5%)
  // Assume perp funding cost ~5-15% annualized (conservative estimate)
  const morphoAPYPercent = morphoAPY ? Number(morphoAPY) / 100 : 5; // Default 5%
  const estimatedPerpFundingCost = 10; // 10% funding cost estimate

  // Net APY = (Morpho APY * Morpho allocation) - (Funding cost * Perp allocation)
  const netAPY = (morphoAPYPercent * morphoAllocation / 100) - (estimatedPerpFundingCost * perpAllocation / 100);

  // GBP/USD rate (8 decimals from Chainlink)
  const gbpUsdPrice = gbpUsdRate ? Number(gbpUsdRate) / 1e8 : 1.30;

  // Total GBPb in circulation
  const totalGBPb = totalGBPbSupply ? Number(formatUnits(totalGBPbSupply as bigint, 18)) : 0;

  // TVL in GBP terms
  const tvlGBP = tvlUSD / gbpUsdPrice;

  return {
    // TVL metrics
    tvlUSD,
    tvlGBP,
    morphoBalanceUSD,
    perpCollateralUSD,

    // Allocations
    morphoAllocation,
    perpAllocation,

    // APY
    netAPY,
    morphoAPYPercent,

    // Exchange rate
    gbpUsdPrice,

    // Supply
    totalGBPb,

    // Loading state
    isLoading: isLoadingTVL,
  };
}

/**
 * Hook to fetch user-specific vault data
 */
export function useUserVaultData(userAddress?: `0x${string}`) {
  // User's GBPb balance
  const { data: gbpbBalance } = useReadContract({
    address: CONTRACTS.gbpb,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress,
    },
  });

  // User's USDC balance
  const { data: usdcBalance } = useReadContract({
    address: CONTRACTS.usdc,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress,
    },
  });

  // User's sGBPb (staked) balance
  const { data: sGBPbBalance } = useReadContract({
    address: CONTRACTS.sGBPb,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress,
    },
  });

  const gbpb = gbpbBalance ? Number(formatUnits(gbpbBalance as bigint, 18)) : 0;
  const usdc = usdcBalance ? Number(formatUnits(usdcBalance as bigint, 6)) : 0;
  const sGBPb = sGBPbBalance ? Number(formatUnits(sGBPbBalance as bigint, 18)) : 0;

  return {
    gbpbBalance: gbpb,
    usdcBalance: usdc,
    sGBPbBalance: sGBPb,
    totalGBPbHoldings: gbpb + sGBPb,
  };
}
