'use client';

import { useReadContract } from 'wagmi';
import { CONTRACTS } from '../contracts';

// Hyperithm Morpho Vault ABI for APY calculation
const MORPHO_VAULT_ABI = [
  {
    inputs: [],
    name: 'totalAssets',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'shares', type: 'uint256' }],
    name: 'convertToAssets',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

const HYPERITHM_VAULT = '0x4B6F1C9E5d470b97181786b26da0d0945A7cf027' as const;

/**
 * Hook to fetch real sGBPb APY from Morpho strategy
 * sGBPb earns the Morpho vault APY (from Hyperithm)
 */
export function useSGBPbAPY() {
  // Get the APY from MorphoStrategyAdapter (manually set by operator)
  const { data: strategyAPY, isLoading } = useReadContract({
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

  // Also fetch total staked in sGBPb vault
  const { data: totalStaked } = useReadContract({
    address: CONTRACTS.sGBPb,
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

  // Convert APY from basis points to percentage
  // 500 basis points = 5%
  const apyPercent = strategyAPY ? Number(strategyAPY) / 100 : 0;

  // Total staked in GBPb (18 decimals)
  const totalStakedGBPb = totalStaked ? Number(totalStaked) / 1e18 : 0;

  return {
    apy: apyPercent,
    totalStaked: totalStakedGBPb,
    isLoading,
    formattedAPY: `${apyPercent.toFixed(1)}%`,
  };
}

/**
 * Hook to fetch user's sGBPb position details
 */
export function useUserSGBPbPosition(userAddress?: `0x${string}`) {
  // User's sGBPb balance
  const { data: sGBPbBalance } = useReadContract({
    address: CONTRACTS.sGBPb,
    abi: [
      {
        inputs: [{ name: 'account', type: 'address' }],
        name: 'balanceOf',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
      },
    ] as const,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress,
    },
  });

  // Convert sGBPb to underlying GBPb value
  const { data: underlyingValue } = useReadContract({
    address: CONTRACTS.sGBPb,
    abi: [
      {
        inputs: [{ name: 'shares', type: 'uint256' }],
        name: 'convertToAssets',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
      },
    ] as const,
    functionName: 'convertToAssets',
    args: sGBPbBalance ? [sGBPbBalance as bigint] : undefined,
    query: {
      enabled: !!sGBPbBalance,
    },
  });

  const sGBPb = sGBPbBalance ? Number(sGBPbBalance) / 1e18 : 0;
  const gbpbValue = underlyingValue ? Number(underlyingValue) / 1e18 : 0;
  const accruedValue = gbpbValue - sGBPb; // Profit from staking

  return {
    sGBPbBalance: sGBPb,
    underlyingGBPbValue: gbpbValue,
    accruedProfit: accruedValue,
  };
}
