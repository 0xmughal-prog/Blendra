'use client';

import { useState } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import { CONTRACTS } from '@/lib/config';
import { FEE_DISTRIBUTOR_ABI } from '@/abi/feeDistributor';

export function RevenueManagement() {
  const [treasuryPercent, setTreasuryPercent] = useState('90');
  const [reservePercent, setReservePercent] = useState('10');

  const { data: treasuryBps } = useReadContract({
    address: CONTRACTS.FEE_DISTRIBUTOR,
    abi: FEE_DISTRIBUTOR_ABI,
    functionName: 'treasuryShareBps',
  });

  const { data: reserveBps } = useReadContract({
    address: CONTRACTS.FEE_DISTRIBUTOR,
    abi: FEE_DISTRIBUTOR_ABI,
    functionName: 'reserveShareBps',
  });

  const { data: treasury } = useReadContract({
    address: CONTRACTS.FEE_DISTRIBUTOR,
    abi: FEE_DISTRIBUTOR_ABI,
    functionName: 'treasury',
  });

  const { data: reserveBuffer } = useReadContract({
    address: CONTRACTS.FEE_DISTRIBUTOR,
    abi: FEE_DISTRIBUTOR_ABI,
    functionName: 'reserveBuffer',
  });

  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const handleSetRevenueSplit = () => {
    const treasuryBpsValue = BigInt(Number(treasuryPercent) * 100);
    const reserveBpsValue = BigInt(Number(reservePercent) * 100);

    if (Number(treasuryPercent) + Number(reservePercent) !== 100) {
      alert('Treasury % + Reserve % must equal 100%');
      return;
    }

    writeContract({
      address: CONTRACTS.FEE_DISTRIBUTOR,
      abi: FEE_DISTRIBUTOR_ABI,
      functionName: 'setRevenueSplit',
      args: [treasuryBpsValue, reserveBpsValue],
    });
  };

  const handleReleaseTreasury = () => {
    writeContract({
      address: CONTRACTS.FEE_DISTRIBUTOR,
      abi: FEE_DISTRIBUTOR_ABI,
      functionName: 'releaseTreasury',
    });
  };

  const handleReleaseReserve = () => {
    writeContract({
      address: CONTRACTS.FEE_DISTRIBUTOR,
      abi: FEE_DISTRIBUTOR_ABI,
      functionName: 'releaseReserve',
    });
  };

  const formatPercent = (bps: bigint | undefined) => {
    if (!bps) return '0';
    return (Number(bps) / 100).toFixed(1);
  };

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm rounded-xl p-6 border border-gray-700">
      <h3 className="text-xl font-bold text-white mb-4">Revenue Management</h3>

      <div className="space-y-4">
        {/* Current Split */}
        <div className="bg-gray-700/50 rounded-lg p-4">
          <div className="text-sm text-gray-400 mb-2">Current Revenue Split</div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <div className="text-2xl font-bold text-white">
                {formatPercent(treasuryBps)}%
              </div>
              <div className="text-xs text-gray-500">Treasury</div>
            </div>
            <div>
              <div className="text-2xl font-bold text-white">
                {formatPercent(reserveBps)}%
              </div>
              <div className="text-xs text-gray-500">Reserve</div>
            </div>
          </div>
        </div>

        {/* Update Split */}
        <div>
          <label className="text-sm text-gray-400 mb-2 block">Update Revenue Split</label>
          <div className="grid grid-cols-2 gap-2 mb-2">
            <div>
              <input
                type="number"
                value={treasuryPercent}
                onChange={(e) => {
                  setTreasuryPercent(e.target.value);
                  setReservePercent((100 - Number(e.target.value)).toString());
                }}
                placeholder="90"
                className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
              <div className="text-xs text-gray-500 mt-1">Treasury %</div>
            </div>
            <div>
              <input
                type="number"
                value={reservePercent}
                onChange={(e) => {
                  setReservePercent(e.target.value);
                  setTreasuryPercent((100 - Number(e.target.value)).toString());
                }}
                placeholder="10"
                className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
              <div className="text-xs text-gray-500 mt-1">Reserve %</div>
            </div>
          </div>
          <button
            onClick={handleSetRevenueSplit}
            disabled={isPending || isConfirming}
            className="w-full px-4 py-2 bg-primary-600 hover:bg-primary-700 text-white rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isPending || isConfirming ? 'Processing...' : 'Update Split'}
          </button>
        </div>

        {/* Quick Presets */}
        <div>
          <div className="text-sm text-gray-400 mb-2">Quick Presets</div>
          <div className="grid grid-cols-3 gap-2">
            <button
              onClick={() => {
                setTreasuryPercent('90');
                setReservePercent('10');
              }}
              className="px-3 py-2 bg-gray-700 hover:bg-gray-600 text-white text-sm rounded-lg transition-colors"
            >
              90/10
            </button>
            <button
              onClick={() => {
                setTreasuryPercent('80');
                setReservePercent('20');
              }}
              className="px-3 py-2 bg-gray-700 hover:bg-gray-600 text-white text-sm rounded-lg transition-colors"
            >
              80/20
            </button>
            <button
              onClick={() => {
                setTreasuryPercent('70');
                setReservePercent('30');
              }}
              className="px-3 py-2 bg-gray-700 hover:bg-gray-600 text-white text-sm rounded-lg transition-colors"
            >
              70/30
            </button>
          </div>
        </div>

        {/* Claim Fees */}
        <div className="border-t border-gray-700 pt-4">
          <div className="text-sm text-gray-400 mb-2">Claim Accumulated Fees</div>
          <div className="grid grid-cols-2 gap-2">
            <button
              onClick={handleReleaseTreasury}
              disabled={isPending || isConfirming}
              className="px-4 py-2 bg-green-600 hover:bg-green-700 text-white text-sm rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Claim Treasury
            </button>
            <button
              onClick={handleReleaseReserve}
              disabled={isPending || isConfirming}
              className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Claim Reserve
            </button>
          </div>
        </div>

        {/* Addresses */}
        <div className="bg-gray-700/50 rounded-lg p-3 text-xs">
          <div className="flex justify-between mb-1">
            <span className="text-gray-500">Treasury:</span>
            <span className="text-gray-300 font-mono">
              {treasury ? `${treasury.slice(0, 6)}...${treasury.slice(-4)}` : '-'}
            </span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-500">Reserve:</span>
            <span className="text-gray-300 font-mono">
              {reserveBuffer ? `${reserveBuffer.slice(0, 6)}...${reserveBuffer.slice(-4)}` : '-'}
            </span>
          </div>
        </div>

        {/* Transaction Status */}
        {(isPending || isConfirming || isSuccess) && (
          <div className="p-3 rounded-lg bg-gray-700/50 border border-gray-600">
            {isPending && (
              <p className="text-sm text-yellow-400">⏳ Waiting for wallet confirmation...</p>
            )}
            {isConfirming && (
              <p className="text-sm text-blue-400">⏳ Transaction confirming...</p>
            )}
            {isSuccess && (
              <p className="text-sm text-green-400">✅ Transaction confirmed!</p>
            )}
            {hash && (
              <a
                href={`https://arbiscan.io/tx/${hash}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-primary-400 hover:text-primary-300 block mt-1"
              >
                View on Arbiscan →
              </a>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
