'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount } from 'wagmi';
import { ProtocolStatus } from '@/components/ProtocolStatus';
import { AdminActions } from '@/components/AdminActions';
import { RevenueManagement } from '@/components/RevenueManagement';
import { GovernanceActions } from '@/components/GovernanceActions';

export default function Home() {
  const { isConnected } = useAccount();

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
      {/* Header */}
      <header className="border-b border-gray-700 bg-gray-900/50 backdrop-blur-sm">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-white">Blendra Admin</h1>
            <p className="text-gray-400 text-sm">Protocol Management Dashboard</p>
          </div>
          <ConnectButton />
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-8">
        {!isConnected ? (
          <div className="flex items-center justify-center min-h-[60vh]">
            <div className="text-center">
              <div className="text-6xl mb-4">🔒</div>
              <h2 className="text-2xl font-bold text-white mb-2">
                Connect Your Wallet
              </h2>
              <p className="text-gray-400 mb-6">
                Connect your admin wallet to manage the Blendra Protocol
              </p>
              <ConnectButton />
            </div>
          </div>
        ) : (
          <div className="space-y-8">
            {/* Protocol Status */}
            <ProtocolStatus />

            {/* Admin Actions */}
            <div>
              <h2 className="text-2xl font-bold text-white mb-4">Basic Controls</h2>
              <div className="grid md:grid-cols-2 gap-8">
                <AdminActions />
                <RevenueManagement />
              </div>
            </div>

            {/* Governance Actions */}
            <div>
              <h2 className="text-2xl font-bold text-white mb-4">Advanced Governance</h2>
              <GovernanceActions />
            </div>
          </div>
        )}
      </main>

      {/* Footer */}
      <footer className="border-t border-gray-700 bg-gray-900/50 backdrop-blur-sm mt-16">
        <div className="container mx-auto px-4 py-6 text-center text-gray-400 text-sm">
          <p>Blendra Protocol v1.0.0 • Arbitrum One •
            <a
              href={`https://arbiscan.io/address/${process.env.NEXT_PUBLIC_MINTER_ADDRESS}`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary-400 hover:text-primary-300 ml-1"
            >
              View on Arbiscan
            </a>
          </p>
        </div>
      </footer>
    </div>
  );
}
