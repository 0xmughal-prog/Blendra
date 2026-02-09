'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatNumber } from '@/lib/utils';
import { useAccount } from 'wagmi';
import { TrendingUp, Wallet, PiggyBank, DollarSign, Activity, Percent } from 'lucide-react';
import { useVaultMetrics, useUserVaultData } from '@/lib/hooks/useVaultMetrics';

export function VaultStats() {
  const { address } = useAccount();
  const vaultMetrics = useVaultMetrics();
  const userData = useUserVaultData(address);

  // User's total holdings value in USD
  const userValueUSD = userData.totalGBPbHoldings * vaultMetrics.gbpUsdPrice;

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
      {/* Total Value Locked */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Total Value Locked</CardTitle>
          <PiggyBank className="h-4 w-4 text-white/60" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            ${vaultMetrics.isLoading ? '...' : formatNumber(vaultMetrics.tvlUSD, 2)}
          </div>
          <p className="text-xs text-white/60">
            ≈ £{formatNumber(vaultMetrics.tvlGBP, 2)}
          </p>
        </CardContent>
      </Card>

      {/* Net APY */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Estimated Net APY</CardTitle>
          <TrendingUp className="h-4 w-4 text-white/60" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {vaultMetrics.isLoading ? '...' : `${formatNumber(vaultMetrics.netAPY, 1)}%`}
          </div>
          <p className="text-xs text-white/60">
            Morpho {formatNumber(vaultMetrics.morphoAPYPercent, 1)}% - Funding ~10%
          </p>
        </CardContent>
      </Card>

      {/* Your Holdings */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Your GBPb Holdings</CardTitle>
          <Wallet className="h-4 w-4 text-white/60" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {address ? formatNumber(userData.totalGBPbHoldings, 2) : '0.00'}
          </div>
          <p className="text-xs text-white/60">
            ≈ ${formatNumber(userValueUSD, 2)}
          </p>
        </CardContent>
      </Card>

      {/* GBP/USD Rate */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">GBP/USD Rate</CardTitle>
          <Activity className="h-4 w-4 text-white/60" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            ${formatNumber(vaultMetrics.gbpUsdPrice, 4)}
          </div>
          <p className="text-xs text-white/60">Live Chainlink oracle</p>
        </CardContent>
      </Card>

      {/* Total GBPb Supply */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Total GBPb Supply</CardTitle>
          <DollarSign className="h-4 w-4 text-white/60" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {formatNumber(vaultMetrics.totalGBPb, 0)}
          </div>
          <p className="text-xs text-white/60">GBPb tokens in circulation</p>
        </CardContent>
      </Card>

      {/* Asset Allocation */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Asset Allocation</CardTitle>
          <Percent className="h-4 w-4 text-white/60" />
        </CardHeader>
        <CardContent>
          <div className="space-y-1">
            <div className="flex justify-between text-sm">
              <span className="text-white/60">Morpho:</span>
              <span className="font-semibold">{formatNumber(vaultMetrics.morphoAllocation, 1)}%</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-white/60">Perp:</span>
              <span className="font-semibold">{formatNumber(vaultMetrics.perpAllocation, 1)}%</span>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
