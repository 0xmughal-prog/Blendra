'use client';

import { useState } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import { CONTRACTS } from '@/lib/config';
import { MINTER_ABI } from '@/abi/minter';
import { parseUnits } from 'viem';

export function AdminActions() {
  const [tvlCapInput, setTvlCapInput] = useState('');
  const [minReserveInput, setMinReserveInput] = useState('');
  const [fundAmount, setFundAmount] = useState('');
  const [minTVLAfterRebalance, setMinTVLAfterRebalance] = useState('');
  const [showRebalanceModal, setShowRebalanceModal] = useState(false);

  const { data: paused } = useReadContract({
    address: CONTRACTS.MINTER,
    abi: MINTER_ABI,
    functionName: 'paused',
  });

  // Fetch health status for rebalance modal
  const { data: healthStatus } = useReadContract({
    address: CONTRACTS.MINTER,
    abi: MINTER_ABI,
    functionName: 'getHealthStatus',
  });

  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const handlePause = () => {
    writeContract({
      address: CONTRACTS.MINTER,
      abi: MINTER_ABI,
      functionName: 'pause',
    });
  };

  const handleUnpause = () => {
    writeContract({
      address: CONTRACTS.MINTER,
      abi: MINTER_ABI,
      functionName: 'unpause',
    });
  };

  const handleSetTVLCap = () => {
    if (!tvlCapInput) return;
    const amount = parseUnits(tvlCapInput, 6);
    writeContract({
      address: CONTRACTS.MINTER,
      abi: MINTER_ABI,
      functionName: 'setTVLCap',
      args: [amount],
    });
  };

  const handleSetMinReserve = () => {
    if (!minReserveInput) return;
    const amount = parseUnits(minReserveInput, 6);
    writeContract({
      address: CONTRACTS.MINTER,
      abi: MINTER_ABI,
      functionName: 'setMinReserveBalance',
      args: [amount],
    });
  };

  const handleFundReserve = () => {
    if (!fundAmount) return;
    const amount = parseUnits(fundAmount, 6);
    writeContract({
      address: CONTRACTS.MINTER,
      abi: MINTER_ABI,
      functionName: 'fundReserve',
      args: [amount],
    });
  };

  const handleRebalancePerp = () => {
    setShowRebalanceModal(true);
  };

  const confirmRebalance = () => {
    const minTVL = minTVLAfterRebalance ? parseUnits(minTVLAfterRebalance, 6) : BigInt(0);

    writeContract({
      address: CONTRACTS.MINTER,
      abi: MINTER_ABI,
      functionName: 'rebalancePerp',
      args: [minTVL],
    });

    setShowRebalanceModal(false);
  };

  const formatUSDC = (value: bigint) => {
    return (Number(value) / 1e6).toFixed(2);
  };

  const formatBPS = (bps: bigint) => {
    return (Number(bps) / 100).toFixed(1);
  };

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm rounded-xl p-6 border border-gray-700">
      <h3 className="text-xl font-bold text-white mb-4">Admin Actions</h3>

      <div className="space-y-4">
        {/* Pause/Unpause */}
        <div>
          <label className="text-sm text-gray-400 mb-2 block">Protocol Control</label>
          <button
            onClick={paused ? handleUnpause : handlePause}
            disabled={isPending || isConfirming}
            className={`w-full px-4 py-3 rounded-lg font-bold transition-colors ${
              paused
                ? 'bg-green-600 hover:bg-green-700 text-white'
                : 'bg-red-600 hover:bg-red-700 text-white'
            } disabled:opacity-50 disabled:cursor-not-allowed`}
          >
            {isPending || isConfirming
              ? 'Processing...'
              : paused
              ? '▶️ Unpause Protocol'
              : '⏸ Pause Protocol'}
          </button>
        </div>

        {/* Set TVL Cap */}
        <div>
          <label className="text-sm text-gray-400 mb-2 block">Set TVL Cap (USD)</label>
          <div className="flex gap-2">
            <input
              type="number"
              value={tvlCapInput}
              onChange={(e) => setTvlCapInput(e.target.value)}
              placeholder="5000"
              className="flex-1 px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
            />
            <button
              onClick={handleSetTVLCap}
              disabled={!tvlCapInput || isPending || isConfirming}
              className="px-6 py-2 bg-primary-600 hover:bg-primary-700 text-white rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Set
            </button>
          </div>
        </div>

        {/* Set Min Reserve */}
        <div>
          <label className="text-sm text-gray-400 mb-2 block">Set Min Reserve (USD)</label>
          <div className="flex gap-2">
            <input
              type="number"
              value={minReserveInput}
              onChange={(e) => setMinReserveInput(e.target.value)}
              placeholder="100"
              className="flex-1 px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
            />
            <button
              onClick={handleSetMinReserve}
              disabled={!minReserveInput || isPending || isConfirming}
              className="px-6 py-2 bg-primary-600 hover:bg-primary-700 text-white rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Set
            </button>
          </div>
        </div>

        {/* Fund Reserve */}
        <div>
          <label className="text-sm text-gray-400 mb-2 block">Fund Reserve (USDC)</label>
          <div className="flex gap-2">
            <input
              type="number"
              value={fundAmount}
              onChange={(e) => setFundAmount(e.target.value)}
              placeholder="500"
              className="flex-1 px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
            />
            <button
              onClick={handleFundReserve}
              disabled={!fundAmount || isPending || isConfirming}
              className="px-6 py-2 bg-primary-600 hover:bg-primary-700 text-white rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Fund
            </button>
          </div>
          <p className="text-xs text-gray-500 mt-1">
            Note: Approve USDC first if needed
          </p>
        </div>

        {/* Rebalance Perp */}
        <div>
          <label className="text-sm text-gray-400 mb-2 block">Perp Management</label>
          <button
            onClick={handleRebalancePerp}
            disabled={isPending || isConfirming}
            className="w-full px-4 py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-lg font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isPending || isConfirming ? 'Processing...' : '🔄 Rebalance Perp Position'}
          </button>
          {healthStatus && (
            <div className="mt-2 text-xs text-gray-400">
              Health: {formatBPS(healthStatus[0] as bigint)}% |
              Estimated Loss: ${formatUSDC(healthStatus[3] as bigint)}
            </div>
          )}
        </div>

        {/* Rebalance Modal */}
        {showRebalanceModal && (
          <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50">
            <div className="bg-gray-800 rounded-xl p-6 max-w-md w-full mx-4 border border-red-500/50">
              <h3 className="text-xl font-bold text-red-400 mb-4">⚠️ Rebalance Warning</h3>

              <div className="bg-red-900/20 border border-red-500/30 rounded-lg p-4 mb-4">
                <p className="text-sm text-red-300 mb-3">
                  This action will:
                </p>
                <ul className="text-xs text-gray-300 space-y-1 list-disc list-inside">
                  <li>Close the entire perp position (realizes any losses)</li>
                  <li>Withdraw from all strategies</li>
                  <li>Rebalance with new 80/20 split</li>
                </ul>
              </div>

              {healthStatus && (
                <div className="bg-gray-700/50 rounded-lg p-4 mb-4 space-y-2">
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-400">Current Health:</span>
                    <span className={`font-bold ${Number(healthStatus[0]) < 5000 ? 'text-red-400' : 'text-yellow-400'}`}>
                      {formatBPS(healthStatus[0] as bigint)}%
                    </span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-400">Perp PnL:</span>
                    <span className={`font-bold ${Number(healthStatus[2]) < 0 ? 'text-red-400' : 'text-green-400'}`}>
                      ${formatUSDC(BigInt(Math.abs(Number(healthStatus[2]))))}
                      {Number(healthStatus[2]) < 0 ? ' (Loss)' : ' (Profit)'}
                    </span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-400">Estimated Loss:</span>
                    <span className="font-bold text-red-400">
                      ${formatUSDC(healthStatus[3] as bigint)}
                    </span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-400">Current TVL:</span>
                    <span className="font-bold text-white">
                      ${formatUSDC(healthStatus[4] as bigint)}
                    </span>
                  </div>
                </div>
              )}

              <div className="mb-4">
                <label className="text-sm text-gray-400 mb-2 block">
                  Min TVL After Rebalance (Slippage Protection)
                </label>
                <input
                  type="number"
                  value={minTVLAfterRebalance}
                  onChange={(e) => setMinTVLAfterRebalance(e.target.value)}
                  placeholder="0 (no protection)"
                  className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
                <p className="text-xs text-gray-500 mt-1">
                  Set to 0 to disable slippage check (not recommended)
                </p>
              </div>

              <div className="bg-yellow-900/20 border border-yellow-500/30 rounded-lg p-3 mb-4">
                <p className="text-xs text-yellow-300">
                  ⚠️ This action is <strong>IRREVERSIBLE</strong>. Losses will be realized immediately.
                </p>
              </div>

              <div className="flex gap-3">
                <button
                  onClick={() => setShowRebalanceModal(false)}
                  className="flex-1 px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-bold transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={confirmRebalance}
                  className="flex-1 px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-bold transition-colors"
                >
                  Confirm Rebalance
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Transaction Status */}
        {(isPending || isConfirming || isSuccess) && (
          <div className="mt-4 p-3 rounded-lg bg-gray-700/50 border border-gray-600">
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
