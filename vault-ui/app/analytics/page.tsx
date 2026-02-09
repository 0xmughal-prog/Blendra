'use client';

import Link from 'next/link';
import { useTheme } from '@/lib/contexts/ThemeContext';
import { BackgroundWrapper } from '@/components/BackgroundWrapper';
import { AnimatedNumber } from '@/components/AnimatedNumber';
import { Header } from '@/components/Header';
import { VaultStats } from '@/components/VaultStats';
import { useVaultMetrics } from '@/lib/hooks/useVaultMetrics';
import { useSGBPbAPY } from '@/lib/hooks/useSGBPbAPY';
import { useReadContract } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { formatNumber } from '@/lib/utils';

export default function AnalyticsPage() {
  const { theme } = useTheme();

  // Real-time data from contracts
  const vaultMetrics = useVaultMetrics();
  const { apy: sGBPbAPY } = useSGBPbAPY();

  // Fetch GBPb backing ratio
  const { data: totalGBPbSupply } = useReadContract({
    address: CONTRACTS.gbpb,
    abi: [
      {
        inputs: [],
        name: 'totalSupply',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
      },
    ] as const,
    functionName: 'totalSupply',
  });

  // Calculate backing ratio (USDC backing vs GBPb supply)
  const gbpbSupply = totalGBPbSupply ? Number(totalGBPbSupply) / 1e18 : 0;
  const gbpbValueInUSD = gbpbSupply * vaultMetrics.gbpUsdPrice;
  const backingRatio = gbpbValueInUSD > 0 ? (vaultMetrics.tvlUSD / gbpbValueInUSD) * 100 : 0;

  // Utilization: how much of deposited capital is actually deployed
  const deployedCapital = vaultMetrics.morphoBalanceUSD + vaultMetrics.perpCollateralUSD;
  const utilizationRate = vaultMetrics.tvlUSD > 0 ? (deployedCapital / vaultMetrics.tvlUSD) * 100 : 0;

  return (
    <main className={`relative min-h-screen overflow-hidden ${theme === 'night' ? 'night-mode' : ''}`}>
      {/* Background Image */}
      <BackgroundWrapper />

      {/* Header with sGBPb APY */}
      <Header activePage="analytics" />

      {/* Main Content */}
      <div className="relative z-10 container mx-auto px-4 py-12 pb-24 md:pb-12 space-y-6">
        {/* VaultStats Component - Main metrics grid */}
        <div className="max-w-5xl mx-auto">
          <VaultStats />
        </div>

        {/* Capital Allocation */}
        <div className="glass-card p-8 rounded-3xl max-w-5xl mx-auto">
          <h3 className="text-white text-xl font-bold mb-6">Capital Allocation</h3>

          <div className="grid md:grid-cols-2 gap-6">
            {/* Morpho */}
            <div className="glass-toggle p-6 rounded-2xl">
              <div className="flex items-center gap-2 mb-4">
                <div className="w-3 h-3 rounded-full bg-blue-400"></div>
                <div className="text-white/90 text-sm font-semibold">Morpho Vault</div>
              </div>
              <div className="text-white text-3xl font-bold mb-2">
                ${vaultMetrics.isLoading ? '...' : <AnimatedNumber value={vaultMetrics.morphoBalanceUSD} decimals={2} />}
              </div>
              <div className="text-white/60 text-sm mb-3">
                <AnimatedNumber value={vaultMetrics.morphoAllocation} decimals={1} suffix="%" /> of total capital
              </div>
              <div className="text-blue-400 text-sm font-semibold">
                <AnimatedNumber value={vaultMetrics.morphoAPYPercent} decimals={1} suffix="%" /> APY earning
              </div>
            </div>

            {/* Ostium */}
            <div className="glass-toggle p-6 rounded-2xl">
              <div className="flex items-center gap-2 mb-4">
                <div className="w-3 h-3 rounded-full bg-purple-400"></div>
                <div className="text-white/90 text-sm font-semibold">Ostium Perpetuals</div>
              </div>
              <div className="text-white text-3xl font-bold mb-2">
                ${vaultMetrics.isLoading ? '...' : <AnimatedNumber value={vaultMetrics.perpCollateralUSD} decimals={2} />}
              </div>
              <div className="text-white/60 text-sm mb-3">
                <AnimatedNumber value={vaultMetrics.perpAllocation} decimals={1} suffix="%" /> of total capital
              </div>
              <div className="text-purple-400 text-sm font-semibold">
                5x GBP/USD long position
              </div>
            </div>
          </div>
        </div>

        {/* Protocol Health */}
        <div className="glass-card p-8 rounded-3xl max-w-5xl mx-auto">
          <h3 className="text-white text-xl font-bold mb-6">Protocol Health</h3>

          <div className="space-y-4">
            <div>
              <div className="flex justify-between text-sm mb-2">
                <span className="text-white/70">GBPb Backing Ratio</span>
                <span className={`font-semibold ${backingRatio >= 100 ? 'text-green-400' : 'text-orange-400'}`}>
                  {vaultMetrics.isLoading ? '...' : `${formatNumber(backingRatio, 1)}%`}
                </span>
              </div>
              <div className="w-full bg-white/10 rounded-full h-2">
                <div
                  className={`h-2 rounded-full ${backingRatio >= 100 ? 'bg-gradient-to-r from-green-400 to-green-300' : 'bg-gradient-to-r from-orange-400 to-orange-300'}`}
                  style={{ width: `${Math.min(backingRatio, 100)}%` }}
                />
              </div>
              <p className="text-xs text-white/50 mt-1">
                {backingRatio >= 100 ? '✅ Fully backed' : '⚠️ Undercollateralized'}
              </p>
            </div>

            <div>
              <div className="flex justify-between text-sm mb-2">
                <span className="text-white/70">Capital Utilization</span>
                <span className="text-white font-semibold">
                  {vaultMetrics.isLoading ? '...' : `${formatNumber(utilizationRate, 1)}%`}
                </span>
              </div>
              <div className="w-full bg-white/10 rounded-full h-2">
                <div
                  className="bg-gradient-to-r from-blue-400 to-blue-300 h-2 rounded-full"
                  style={{ width: `${utilizationRate}%` }}
                />
              </div>
              <p className="text-xs text-white/50 mt-1">
                ${formatNumber(deployedCapital, 2)} of ${formatNumber(vaultMetrics.tvlUSD, 2)} deployed
              </p>
            </div>

            <div>
              <div className="flex justify-between text-sm mb-2">
                <span className="text-white/70">Total GBPb Supply</span>
                <span className="text-white font-semibold">
                  {formatNumber(gbpbSupply, 0)} GBPb
                </span>
              </div>
              <div className="w-full bg-white/10 rounded-full h-2">
                <div
                  className="bg-gradient-to-r from-white/40 to-white/20 h-2 rounded-full"
                  style={{ width: gbpbSupply > 0 ? '100%' : '0%' }}
                />
              </div>
              <p className="text-xs text-white/50 mt-1">
                ≈ ${formatNumber(gbpbValueInUSD, 2)} at current GBP/USD rate
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Mobile Bottom Navigation */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 z-20 border-t border-white/10 bg-white/5 backdrop-blur-lg">
        <div className="flex items-center justify-around px-4 py-3">
          <Link href="/" className="flex flex-col items-center gap-1 text-white/60">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span className="text-xs font-medium">Mint</span>
          </Link>

          <Link href="/staking" className="flex flex-col items-center gap-1 text-white/60">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
            <span className="text-xs font-medium">Stake</span>
          </Link>

          <Link href="/analytics" className="flex flex-col items-center gap-1 text-white/90">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
            </svg>
            <span className="text-xs font-medium">Analytics</span>
          </Link>
        </div>
      </nav>
    </main>
  );
}
