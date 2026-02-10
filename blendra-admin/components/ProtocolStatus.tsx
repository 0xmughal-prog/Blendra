'use client';

import { useReadContract } from 'wagmi';
import { CONTRACTS } from '@/lib/config';
import { MINTER_ABI } from '@/abi/minter';
import { formatUnits } from 'viem';

export function ProtocolStatus() {
  const { data: paused } = useReadContract({
    address: CONTRACTS.MINTER,
    abi: MINTER_ABI,
    functionName: 'paused',
  });

  const { data: tvl } = useReadContract({
    address: CONTRACTS.MINTER,
    abi: MINTER_ABI,
    functionName: 'totalAssets',
  });

  const { data: tvlCap } = useReadContract({
    address: CONTRACTS.MINTER,
    abi: MINTER_ABI,
    functionName: 'tvlCap',
  });

  const { data: reserve } = useReadContract({
    address: CONTRACTS.MINTER,
    abi: MINTER_ABI,
    functionName: 'reserveBalance',
  });

  const { data: minReserve } = useReadContract({
    address: CONTRACTS.MINTER,
    abi: MINTER_ABI,
    functionName: 'minReserveBalance',
  });

  const { data: cooldown } = useReadContract({
    address: CONTRACTS.MINTER,
    abi: MINTER_ABI,
    functionName: 'userOperationCooldown',
  });

  const formatUSDC = (value: bigint | undefined) => {
    if (!value) return '0';
    return formatUnits(value, 6);
  };

  const formatDays = (seconds: bigint | undefined) => {
    if (!seconds) return '0';
    return (Number(seconds) / 86400).toFixed(1);
  };

  return (
    <div>
      <h2 className="text-2xl font-bold text-white mb-4">Protocol Status</h2>
      <div className="grid md:grid-cols-3 gap-4">
        {/* Status Card */}
        <div className="bg-gray-800/50 backdrop-blur-sm rounded-xl p-6 border border-gray-700">
          <div className="flex items-center justify-between mb-2">
            <span className="text-gray-400 text-sm">Status</span>
            <div
              className={`px-3 py-1 rounded-full text-xs font-bold ${
                paused
                  ? 'bg-red-500/20 text-red-400'
                  : 'bg-green-500/20 text-green-400'
              }`}
            >
              {paused ? '⏸ PAUSED' : '✓ ACTIVE'}
            </div>
          </div>
          <div className="text-2xl font-bold text-white">
            {paused ? 'Protocol Paused' : 'All Systems Go'}
          </div>
        </div>

        {/* TVL Card */}
        <div className="bg-gray-800/50 backdrop-blur-sm rounded-xl p-6 border border-gray-700">
          <div className="text-gray-400 text-sm mb-2">Total Value Locked</div>
          <div className="text-3xl font-bold text-white mb-1">
            ${formatUSDC(tvl)}
          </div>
          <div className="text-sm text-gray-500">
            Cap: ${formatUSDC(tvlCap)}
          </div>
          {tvl && tvlCap && (
            <div className="mt-2">
              <div className="bg-gray-700 rounded-full h-2 overflow-hidden">
                <div
                  className="bg-primary-500 h-full transition-all"
                  style={{
                    width: `${Math.min((Number(tvl) / Number(tvlCap)) * 100, 100)}%`,
                  }}
                />
              </div>
            </div>
          )}
        </div>

        {/* Reserve Card */}
        <div className="bg-gray-800/50 backdrop-blur-sm rounded-xl p-6 border border-gray-700">
          <div className="text-gray-400 text-sm mb-2">Reserve Balance</div>
          <div className="text-3xl font-bold text-white mb-1">
            ${formatUSDC(reserve)}
          </div>
          <div className="text-sm text-gray-500">
            Min: ${formatUSDC(minReserve)}
          </div>
          {reserve && minReserve && Number(reserve) < Number(minReserve) && (
            <div className="mt-2 text-xs text-yellow-400 flex items-center">
              ⚠️ Below minimum
            </div>
          )}
        </div>

        {/* Cooldown Card */}
        <div className="bg-gray-800/50 backdrop-blur-sm rounded-xl p-6 border border-gray-700">
          <div className="text-gray-400 text-sm mb-2">User Cooldown</div>
          <div className="text-3xl font-bold text-white">
            {formatDays(cooldown)} days
          </div>
        </div>

        {/* Contract Addresses */}
        <div className="bg-gray-800/50 backdrop-blur-sm rounded-xl p-6 border border-gray-700 md:col-span-2">
          <div className="text-gray-400 text-sm mb-3">Contract Addresses</div>
          <div className="space-y-2 text-xs">
            <div className="flex justify-between">
              <span className="text-gray-500">Minter:</span>
              <a
                href={`https://arbiscan.io/address/${CONTRACTS.MINTER}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-primary-400 hover:text-primary-300 font-mono"
              >
                {CONTRACTS.MINTER.slice(0, 6)}...{CONTRACTS.MINTER.slice(-4)}
              </a>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">GBPb Token:</span>
              <a
                href={`https://arbiscan.io/address/${CONTRACTS.GBPB_TOKEN}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-primary-400 hover:text-primary-300 font-mono"
              >
                {CONTRACTS.GBPB_TOKEN.slice(0, 6)}...{CONTRACTS.GBPB_TOKEN.slice(-4)}
              </a>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">Fee Distributor:</span>
              <a
                href={`https://arbiscan.io/address/${CONTRACTS.FEE_DISTRIBUTOR}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-primary-400 hover:text-primary-300 font-mono"
              >
                {CONTRACTS.FEE_DISTRIBUTOR.slice(0, 6)}...{CONTRACTS.FEE_DISTRIBUTOR.slice(-4)}
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
