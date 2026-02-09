'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';
import Link from 'next/link';
import { useSGBPbAPY } from '@/lib/hooks/useSGBPbAPY';
import { useVaultMetrics } from '@/lib/hooks/useVaultMetrics';
import { TrendingUp, DollarSign } from 'lucide-react';

interface HeaderProps {
  activePage?: 'mint' | 'staking' | 'analytics';
}

export function Header({ activePage }: HeaderProps) {
  const { apy, isLoading } = useSGBPbAPY();
  const { gbpUsdPrice, isLoading: isPriceLoading } = useVaultMetrics();

  // Calculate GBPb price in USD (1 GBPb = 1/GBP_USD rate)
  const gbpbPriceUSD = gbpUsdPrice > 0 ? 1 / gbpUsdPrice : 0;

  return (
    <>
      {/* Desktop Header */}
      <header className="hidden md:block relative z-10 border-b border-white/10 bg-white/5 backdrop-blur-sm">
        <div className="container mx-auto flex items-center justify-between px-6 py-4">
          {/* Left: Navigation */}
          <nav className="flex items-center gap-8">
            <Link
              href="/"
              className={`transition-colors font-medium ${
                activePage === 'mint' ? 'text-white/90' : 'text-white/70 hover:text-white/90'
              }`}
            >
              Mint/Redeem
            </Link>
            <Link
              href="/staking"
              className={`transition-colors font-medium ${
                activePage === 'staking' ? 'text-white/90' : 'text-white/70 hover:text-white/90'
              }`}
            >
              Stake
            </Link>
            <Link
              href="/analytics"
              className={`transition-colors font-medium ${
                activePage === 'analytics' ? 'text-white/90' : 'text-white/70 hover:text-white/90'
              }`}
            >
              Analytics
            </Link>
          </nav>

          {/* Right: Metrics + Wallet */}
          <div className="flex items-center gap-4">
            {/* sGBPb APY */}
            <div className="flex items-center gap-2 bg-white/10 backdrop-blur-md px-4 py-2 rounded-full border border-white/20">
              <TrendingUp className="h-4 w-4 text-green-400" />
              <div className="flex items-baseline gap-1.5">
                <span className="text-white/70 text-sm font-medium">sGBPb:</span>
                <span className="text-white text-base font-bold">
                  {isLoading ? '...' : `${apy.toFixed(1)}%`}
                </span>
              </div>
            </div>

            {/* GBPb Price */}
            <div className="flex items-center gap-2 bg-white/10 backdrop-blur-md px-4 py-2 rounded-full border border-white/20">
              <DollarSign className="h-4 w-4 text-blue-400" />
              <div className="flex items-baseline gap-1.5">
                <span className="text-white/70 text-sm font-medium">1 GBPb =</span>
                <span className="text-white text-base font-bold">
                  {isPriceLoading ? '...' : `$${gbpbPriceUSD.toFixed(4)}`}
                </span>
              </div>
            </div>

            {/* Wallet Connect */}
            <ConnectButton />
          </div>
        </div>
      </header>

      {/* Mobile Header */}
      <header className="md:hidden relative z-10 border-b border-white/10 bg-white/5 backdrop-blur-sm">
        <div className="flex items-center justify-between px-4 py-3">
          {/* Metrics */}
          <div className="flex items-center gap-2">
            {/* sGBPb APY */}
            <div className="flex items-center gap-1.5 bg-white/10 backdrop-blur-md px-3 py-1.5 rounded-full border border-white/20">
              <TrendingUp className="h-3 w-3 text-green-400" />
              <span className="text-white text-xs font-bold">
                {isLoading ? '...' : `${apy.toFixed(1)}%`}
              </span>
            </div>

            {/* GBPb Price */}
            <div className="flex items-center gap-1.5 bg-white/10 backdrop-blur-md px-3 py-1.5 rounded-full border border-white/20">
              <DollarSign className="h-3 w-3 text-blue-400" />
              <span className="text-white text-xs font-bold">
                {isPriceLoading ? '...' : `$${gbpbPriceUSD.toFixed(3)}`}
              </span>
            </div>
          </div>

          {/* Wallet Connect */}
          <ConnectButton />
        </div>
      </header>
    </>
  );
}
