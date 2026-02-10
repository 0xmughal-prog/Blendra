'use client';

import { useState } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import { CONTRACTS } from '@/lib/config';
import { MINTER_ABI } from '@/abi/minter';
import { parseUnits } from 'viem';

export function GovernanceActions() {
  const [proposedLeverage, setProposedLeverage] = useState('');
  const [minHarvestInterval, setMinHarvestInterval] = useState('');
  const [minHarvestAmount, setMinHarvestAmount] = useState('');

  // Read current governance state
  const { data: currentLeverage } = useReadContract({
    address: CONTRACTS.MINTER,
    abi: MINTER_ABI,
    functionName: 'targetLeverage',
  });

  const { data: pendingLeverage } = useReadContract({
    address: CONTRACTS.MINTER,
    abi: MINTER_ABI,
    functionName: 'proposedLeverage',
  });

  const { data: leverageTimestamp } = useReadContract({
    address: CONTRACTS.MINTER,
    abi: MINTER_ABI,
    functionName: 'leverageChangeTimestamp',
  });

  const { data: canHarvestData } = useReadContract({
    address: CONTRACTS.MINTER,
    abi: MINTER_ABI,
    functionName: 'canHarvest',
  });

  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // Leverage Governance
  const handleProposeLeverage = () => {
    if (!proposedLeverage) return;
    writeContract({
      address: CONTRACTS.MINTER,
      abi: MINTER_ABI,
      functionName: 'proposeLeverageChange',
      args: [BigInt(proposedLeverage)],
    });
  };

  const handleExecuteLeverage = () => {
    writeContract({
      address: CONTRACTS.MINTER,
      abi: MINTER_ABI,
      functionName: 'executeLeverageChange',
    });
  };

  const handleCancelLeverage = () => {
    writeContract({
      address: CONTRACTS.MINTER,
      abi: MINTER_ABI,
      functionName: 'cancelLeverageProposal',
    });
  };

  // Harvest Management
  const handleHarvestYield = () => {
    writeContract({
      address: CONTRACTS.MINTER,
      abi: MINTER_ABI,
      functionName: 'harvestYield',
    });
  };

  const handleSetHarvestConfig = () => {
    if (!minHarvestInterval || !minHarvestAmount) return;

    // Convert interval to seconds (user inputs hours)
    const intervalSeconds = BigInt(Number(minHarvestInterval) * 3600);
    const minAmount = parseUnits(minHarvestAmount, 6);

    writeContract({
      address: CONTRACTS.MINTER,
      abi: MINTER_ABI,
      functionName: 'setHarvestConfig',
      args: [intervalSeconds, minAmount],
    });
  };

  // Price Management
  const handleUpdatePrice = () => {
    writeContract({
      address: CONTRACTS.MINTER,
      abi: MINTER_ABI,
      functionName: 'updateLastPrice',
    });
  };

  // Emergency Functions
  const handleEmergencyWithdraw = () => {
    const confirmed = confirm(
      '⚠️ EMERGENCY: This will withdraw all funds from the lending strategy.\n\nOnly use in extreme emergencies. Continue?'
    );
    if (!confirmed) return;

    writeContract({
      address: CONTRACTS.MINTER,
      abi: MINTER_ABI,
      functionName: 'emergencyWithdrawStrategy',
    });
  };

  const formatTimestamp = (ts: bigint) => {
    if (!ts || ts === BigInt(0)) return 'None';
    const date = new Date(Number(ts) * 1000);
    return date.toLocaleString();
  };

  const getTimeRemaining = (ts: bigint) => {
    if (!ts || ts === BigInt(0)) return null;
    const now = Math.floor(Date.now() / 1000);
    const remaining = Number(ts) - now;
    if (remaining <= 0) return 'Ready to execute';
    const hours = Math.floor(remaining / 3600);
    const mins = Math.floor((remaining % 3600) / 60);
    return `${hours}h ${mins}m remaining`;
  };

  return (
    <div className="space-y-6">
      {/* Leverage Governance */}
      <div className="bg-gray-800/50 backdrop-blur-sm rounded-xl p-6 border border-gray-700">
        <h3 className="text-xl font-bold text-white mb-4">Leverage Governance (48h Timelock)</h3>

        <div className="bg-gray-700/50 rounded-lg p-4 mb-4">
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span className="text-gray-400">Current Leverage:</span>
              <span className="ml-2 font-bold text-white">{currentLeverage?.toString()}x</span>
            </div>
            <div>
              <span className="text-gray-400">Proposed:</span>
              <span className="ml-2 font-bold text-yellow-400">
                {pendingLeverage && Number(pendingLeverage) > 0
                  ? `${pendingLeverage.toString()}x`
                  : 'None'}
              </span>
            </div>
          </div>
          {leverageTimestamp && Number(leverageTimestamp) > 0 && (
            <div className="mt-2 text-xs text-gray-400">
              Execute after: {formatTimestamp(leverageTimestamp)}
              <br />
              {getTimeRemaining(leverageTimestamp)}
            </div>
          )}
        </div>

        <div className="space-y-3">
          {/* Propose */}
          <div>
            <label className="text-sm text-gray-400 mb-2 block">Propose New Leverage (2x-10x)</label>
            <div className="flex gap-2">
              <input
                type="number"
                min="2"
                max="10"
                value={proposedLeverage}
                onChange={(e) => setProposedLeverage(e.target.value)}
                placeholder="5"
                className="flex-1 px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
              <button
                onClick={handleProposeLeverage}
                disabled={!proposedLeverage || isPending || isConfirming}
                className="px-6 py-2 bg-yellow-600 hover:bg-yellow-700 text-white rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Propose
              </button>
            </div>
          </div>

          {/* Execute/Cancel */}
          {pendingLeverage && Number(pendingLeverage) > 0 && (
            <div className="flex gap-2">
              <button
                onClick={handleExecuteLeverage}
                disabled={isPending || isConfirming}
                className="flex-1 px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Execute Change
              </button>
              <button
                onClick={handleCancelLeverage}
                disabled={isPending || isConfirming}
                className="flex-1 px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Cancel Proposal
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Yield Harvesting */}
      <div className="bg-gray-800/50 backdrop-blur-sm rounded-xl p-6 border border-gray-700">
        <h3 className="text-xl font-bold text-white mb-4">Yield Harvesting</h3>

        {canHarvestData && (
          <div className="bg-gray-700/50 rounded-lg p-4 mb-4">
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span className="text-gray-400">Can Harvest:</span>
                <span className={`ml-2 font-bold ${canHarvestData[0] ? 'text-green-400' : 'text-red-400'}`}>
                  {canHarvestData[0] ? '✓ Yes' : '✗ No'}
                </span>
              </div>
              <div>
                <span className="text-gray-400">Net Yield:</span>
                <span className="ml-2 font-bold text-white">
                  ${(Number(canHarvestData[1]) / 1e6).toFixed(2)}
                </span>
              </div>
              <div className="col-span-2">
                <span className="text-gray-400">Time Until Next:</span>
                <span className="ml-2 font-bold text-yellow-400">
                  {Number(canHarvestData[2]) === 0
                    ? 'Ready'
                    : `${Math.floor(Number(canHarvestData[2]) / 3600)}h ${Math.floor((Number(canHarvestData[2]) % 3600) / 60)}m`}
                </span>
              </div>
            </div>
          </div>
        )}

        <div className="space-y-3">
          {/* Harvest Button */}
          <button
            onClick={handleHarvestYield}
            disabled={isPending || isConfirming || (canHarvestData && !canHarvestData[0])}
            className="w-full px-4 py-3 bg-green-600 hover:bg-green-700 text-white rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isPending || isConfirming ? 'Processing...' : '🌾 Harvest Yield Now'}
          </button>

          {/* Update Harvest Config */}
          <div>
            <label className="text-sm text-gray-400 mb-2 block">Update Harvest Config</label>
            <div className="grid grid-cols-2 gap-2 mb-2">
              <input
                type="number"
                value={minHarvestInterval}
                onChange={(e) => setMinHarvestInterval(e.target.value)}
                placeholder="Min interval (hours)"
                className="px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
              <input
                type="number"
                value={minHarvestAmount}
                onChange={(e) => setMinHarvestAmount(e.target.value)}
                placeholder="Min amount (USD)"
                className="px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
            </div>
            <button
              onClick={handleSetHarvestConfig}
              disabled={!minHarvestInterval || !minHarvestAmount || isPending || isConfirming}
              className="w-full px-4 py-2 bg-primary-600 hover:bg-primary-700 text-white rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Update Config
            </button>
          </div>
        </div>
      </div>

      {/* Oracle & Price Management */}
      <div className="bg-gray-800/50 backdrop-blur-sm rounded-xl p-6 border border-gray-700">
        <h3 className="text-xl font-bold text-white mb-4">Oracle & Price Management</h3>

        <div className="space-y-3">
          <button
            onClick={handleUpdatePrice}
            disabled={isPending || isConfirming}
            className="w-full px-4 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isPending || isConfirming ? 'Processing...' : '📊 Update Last Price'}
          </button>
          <p className="text-xs text-gray-500">
            Updates the last known GBP/USD price. Use after confirming price movements are real.
          </p>
        </div>
      </div>

      {/* Emergency Functions */}
      <div className="bg-red-900/20 backdrop-blur-sm rounded-xl p-6 border border-red-500/50">
        <h3 className="text-xl font-bold text-red-400 mb-4">⚠️ Emergency Functions</h3>

        <div className="space-y-3">
          <button
            onClick={handleEmergencyWithdraw}
            disabled={isPending || isConfirming}
            className="w-full px-4 py-3 bg-red-600 hover:bg-red-700 text-white rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isPending || isConfirming ? 'Processing...' : '🚨 Emergency Withdraw Strategy'}
          </button>
          <p className="text-xs text-red-300">
            Only use in extreme emergencies. Withdraws all funds from lending strategy.
          </p>
        </div>
      </div>

      {/* Transaction Status */}
      {(isPending || isConfirming || isSuccess) && (
        <div className="bg-gray-800/50 backdrop-blur-sm rounded-xl p-4 border border-gray-700">
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
  );
}
