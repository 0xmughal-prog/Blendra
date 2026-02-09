'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { useTheme } from '@/lib/contexts/ThemeContext';
import { BackgroundWrapper } from '@/components/BackgroundWrapper';
import { ThemeToggle } from '@/components/ThemeToggle';
import { Header } from '@/components/Header';
import { MintRedeemForm } from '@/components/MintRedeemForm';

export default function Home() {
  const [activeAction, setActiveAction] = useState<'mint' | 'redeem'>('mint');
  const { theme } = useTheme();

  // Check if forex markets are closed (weekends)
  const isMarketClosed = () => {
    const now = new Date();
    const day = now.getUTCDay(); // 0 = Sunday, 6 = Saturday
    const hour = now.getUTCHours();

    // Markets closed: Friday 22:00 UTC to Sunday 22:00 UTC
    if (day === 6) return true; // Saturday - all day closed
    if (day === 0 && hour < 22) return true; // Sunday before 22:00 UTC
    if (day === 5 && hour >= 22) return true; // Friday after 22:00 UTC

    return false;
  };

  const [marketClosed, setMarketClosed] = useState(isMarketClosed());

  // Update market status every minute
  useEffect(() => {
    const interval = setInterval(() => {
      setMarketClosed(isMarketClosed());
    }, 60000); // Check every minute

    return () => clearInterval(interval);
  }, []);

  return (
    <main className={`relative min-h-screen overflow-hidden ${theme === 'night' ? 'night-mode' : ''}`}>
      {/* Background Image */}
      <BackgroundWrapper />

      {/* Header with sGBPb APY */}
      <Header activePage="mint" />

      {/* Main Content */}
      <div className="relative z-10 flex items-center justify-center min-h-[calc(100vh-80px)] md:min-h-[calc(100vh-80px)] px-4 py-12 pb-24 md:pb-12">
        {/* Glass Morphism Card */}
        <div className="glass-card w-full max-w-md p-6 md:p-8 rounded-3xl relative">
          {/* Theme Toggle */}
          <ThemeToggle />

          {/* Market Closed Warning */}
          {marketClosed && (
            <div className="mb-6 p-4 bg-orange-500/10 border border-orange-500/30 rounded-xl">
              <div className="flex items-start gap-3">
                <div className="text-orange-400 text-xl flex-shrink-0">⚠️</div>
                <div>
                  <div className="text-orange-400 font-semibold text-sm mb-1">Markets Closed</div>
                  <p className="text-white/80 text-xs leading-relaxed">
                    Forex markets are currently closed for the weekend. Minting and redemptions are unavailable until markets reopen on Sunday at 22:00 UTC.
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Mint/Redeem Buttons */}
          <div className="flex gap-3 mb-8">
            <button
              onClick={() => setActiveAction('mint')}
              className={`flex-1 py-3 px-6 rounded-xl font-semibold transition-all ${
                activeAction === 'mint'
                  ? 'bg-white/20 text-white border-2 border-white/30'
                  : 'bg-white/5 text-white/60 border-2 border-white/10 hover:bg-white/10 hover:text-white/80'
              }`}
            >
              Mint
            </button>
            <button
              onClick={() => setActiveAction('redeem')}
              className={`flex-1 py-3 px-6 rounded-xl font-semibold transition-all ${
                activeAction === 'redeem'
                  ? 'bg-white/20 text-white border-2 border-white/30'
                  : 'bg-white/5 text-white/60 border-2 border-white/10 hover:bg-white/10 hover:text-white/80'
              }`}
            >
              Redeem
            </button>
          </div>

          {/* Functional Form Component */}
          <MintRedeemForm activeAction={activeAction} />
        </div>
      </div>

      {/* Mobile Bottom Navigation */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 z-20 border-t border-white/10 bg-white/5 backdrop-blur-lg">
        <div className="flex items-center justify-around px-4 py-3">
          <Link href="/" className="flex flex-col items-center gap-1 text-white/90">
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
