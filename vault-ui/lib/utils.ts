import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatNumber(value: number | bigint, decimals: number = 2): string {
  const num = typeof value === 'bigint' ? Number(value) : value
  return new Intl.NumberFormat('en-US', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(num)
}

export function formatUSDC(value: bigint): string {
  // USDC has 6 decimals
  return formatNumber(Number(value) / 1e6, 2)
}

export function formatPercentage(value: number): string {
  return `${formatNumber(value, 2)}%`
}

export function shortenAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`
}
