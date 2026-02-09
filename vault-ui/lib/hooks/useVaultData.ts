import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS, VAULT_ABI, ERC20_ABI } from '../contracts';
import { parseUnits, formatUnits } from 'viem';

// Hook to read vault TVL
export function useVaultTVL() {
  const { data, isLoading, error } = useReadContract({
    address: CONTRACTS.vault,
    abi: VAULT_ABI,
    functionName: 'totalAssets',
  });

  return {
    tvl: data ? formatUnits(data as bigint, 6) : '0', // USDC has 6 decimals
    isLoading,
    error,
  };
}

// Hook to read current APY
export function useVaultAPY() {
  const { data, isLoading, error } = useReadContract({
    address: CONTRACTS.vault,
    abi: VAULT_ABI,
    functionName: 'getCurrentAPY',
  });

  return {
    apy: data ? (Number(data) / 100).toString() : '0', // Assuming APY is returned as basis points
    isLoading,
    error,
  };
}

// Hook to read user's USDC balance
export function useUSDCBalance(address?: `0x${string}`) {
  const { data, isLoading, error } = useReadContract({
    address: CONTRACTS.usdc,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  return {
    balance: data ? formatUnits(data as bigint, 6) : '0',
    isLoading,
    error,
  };
}

// Hook to read user's GBPb balance
export function useGBPbBalance(address?: `0x${string}`) {
  const { data, isLoading, error } = useReadContract({
    address: CONTRACTS.gbpb,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  return {
    balance: data ? formatUnits(data as bigint, 18) : '0', // GBPb has 18 decimals
    isLoading,
    error,
  };
}

// Hook to deposit USDC
export function useDeposit() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const deposit = (amount: string) => {
    const amountInWei = parseUnits(amount, 6); // USDC has 6 decimals

    writeContract({
      address: CONTRACTS.vault,
      abi: VAULT_ABI,
      functionName: 'deposit',
      args: [amountInWei],
    });
  };

  return {
    deposit,
    isPending,
    isConfirming,
    isSuccess,
    error,
    hash,
  };
}

// Hook to approve USDC spending
export function useApproveUSDC() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();

  const approve = (amount: string) => {
    const amountInWei = parseUnits(amount, 6);

    writeContract({
      address: CONTRACTS.usdc,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [CONTRACTS.vault, amountInWei],
    });
  };

  return {
    approve,
    isPending,
    error,
    hash,
  };
}
