'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useTheme } from '@/lib/contexts/ThemeContext';
import { BackgroundWrapper } from '@/components/BackgroundWrapper';
import { ThemeToggle } from '@/components/ThemeToggle';
import { AnimatedNumber } from '@/components/AnimatedNumber';
import { Header } from '@/components/Header';
import { StakeUnstakeForm } from '@/components/StakeUnstakeForm';
import { useSGBPbAPY, useUserSGBPbPosition } from '@/lib/hooks/useSGBPbAPY';
import { useAccount } from 'wagmi';
import { formatNumber } from '@/lib/utils';

export default function StakingPage() {
  const [activeAction, setActiveAction] = useState<'stake' | 'unstake'>('stake');
  const { theme } = useTheme();
  const { address } = useAccount();

  // Real data from contracts
  const { apy, totalStaked } = useSGBPbAPY();
  const userPosition = useUserSGBPbPosition(address);

  return (
    <main className={`relative min-h-screen overflow-hidden ${theme === 'night' ? 'night-mode' : ''}`}>
      {/* Background Image */}
      <BackgroundWrapper />

      {/* Header with sGBPb APY */}
      <Header activePage="staking" />

      {/* Main Content */}
      <div className="relative z-10 flex items-center justify-center min-h-[calc(100vh-80px)] md:min-h-[calc(100vh-80px)] px-4 py-12 pb-24 md:pb-12">
        {/* Glass Morphism Card */}
        <div className="glass-card w-full max-w-md p-6 md:p-8 rounded-3xl relative">
          {/* Theme Toggle */}
          <ThemeToggle />

          {/* Stats Row */}
          <div className="flex justify-between mb-6 mt-4">
            <div>
              <div className="text-white/60 text-sm font-medium">Staking APY</div>
              <div className="text-white text-2xl font-bold">
                <AnimatedNumber value={apy} decimals={1} suffix="%" />
              </div>
            </div>
            <div className="text-right">
              <div className="text-white/60 text-sm font-medium">Total Staked</div>
              <div className="text-white text-2xl font-bold">
                <AnimatedNumber value={totalStaked} decimals={0} />
              </div>
            </div>
          </div>

          {/* Stake/Unstake Buttons */}
          <div className="flex gap-3 mb-8">
            <button
              onClick={() => setActiveAction('stake')}
              className={`flex-1 py-3 px-6 rounded-xl font-semibold transition-all ${
                activeAction === 'stake'
                  ? 'bg-white/20 text-white border-2 border-white/30'
                  : 'bg-white/5 text-white/60 border-2 border-white/10 hover:bg-white/10 hover:text-white/80'
              }`}
            >
              Stake
            </button>
            <button
              onClick={() => setActiveAction('unstake')}
              className={`flex-1 py-3 px-6 rounded-xl font-semibold transition-all ${
                activeAction === 'unstake'
                  ? 'bg-white/20 text-white border-2 border-white/30'
                  : 'bg-white/5 text-white/60 border-2 border-white/10 hover:bg-white/10 hover:text-white/80'
              }`}
            >
              Unstake
            </button>
          </div>

          {/* Functional Form Component */}
          <StakeUnstakeForm activeAction={activeAction} />

          {/* Staking Info */}
          <div className="mt-6 pt-6 border-t border-white/10">
            <div className="text-white/60 text-xs space-y-2">
              <div className="flex justify-between">
                <span>Your sGBPb Balance:</span>
                <span className="text-white font-semibold">
                  {address ? `${formatNumber(userPosition.sGBPbBalance, 2)} sGBPb` : '0.00 sGBPb'}
                </span>
              </div>
              <div className="flex justify-between">
                <span>Underlying Value:</span>
                <span className={`font-semibold ${userPosition.accruedProfit > 0 ? 'text-green-400' : 'text-white'}`}>
                  {address ? `≈ ${formatNumber(userPosition.underlyingGBPbValue, 2)} GBPb` : '0.00 GBPb'}
                </span>
              </div>
              {address && userPosition.accruedProfit > 0 && (
                <div className="flex justify-between">
                  <span>Profit:</span>
                  <span className="text-green-400 font-semibold">
                    +{formatNumber(userPosition.accruedProfit, 2)} GBPb
                  </span>
                </div>
              )}
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

          <Link href="/staking" className="flex flex-col items-center gap-1 text-white/90">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
            <span className="text-xs font-medium">Stake</span>
          </Link>

          <Link href="/analytics" className="flex flex-col items-center gap-1 text-white/60">
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
