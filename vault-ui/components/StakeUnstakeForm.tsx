'use client';

import { useState, useEffect } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import { CONTRACTS, ERC20_ABI } from '@/lib/contracts';
import { useUserSGBPbPosition } from '@/lib/hooks/useSGBPbAPY';
import { formatNumber } from '@/lib/utils';
import { Loader2, AlertCircle, CheckCircle2, ExternalLink } from 'lucide-react';

interface StakeUnstakeFormProps {
  activeAction: 'stake' | 'unstake';
}

const SGBPB_ABI = [
  {
    inputs: [{ name: 'assets', type: 'uint256' }],
    name: 'deposit',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ name: 'shares', type: 'uint256' }],
    name: 'redeem',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ name: 'shares', type: 'uint256' }],
    name: 'previewRedeem',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

export function StakeUnstakeForm({ activeAction }: StakeUnstakeFormProps) {
  const { address } = useAccount();
  const [amount, setAmount] = useState('');
  const [error, setError] = useState('');
  const userPosition = useUserSGBPbPosition(address);

  // Read GBPb balance
  const { data: gbpbBalance, refetch: refetchGbpbBalance } = useReadContract({
    address: CONTRACTS.gbpb,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  // Read sGBPb balance
  const { data: sGbpbBalance, refetch: refetchSGbpbBalance } = useReadContract({
    address: CONTRACTS.sGBPb,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  // Read GBPb allowance for sGBPb
  const { data: gbpbAllowance, refetch: refetchAllowance } = useReadContract({
    address: CONTRACTS.gbpb,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address ? [address, CONTRACTS.sGBPb] : undefined,
    query: { enabled: !!address && activeAction === 'stake' },
  });

  // Preview unstake amount
  const { data: unstakePreview } = useReadContract({
    address: CONTRACTS.sGBPb,
    abi: SGBPB_ABI,
    functionName: 'previewRedeem',
    args: amount && parseFloat(amount) > 0 ? [parseUnits(amount, 18)] : undefined,
    query: { enabled: activeAction === 'unstake' && !!amount && parseFloat(amount) > 0 },
  });

  // Approve GBPb
  const {
    writeContract: approve,
    data: approveHash,
    isPending: isApprovePending,
    error: approveError,
    reset: resetApprove,
  } = useWriteContract();

  // Stake (deposit to sGBPb)
  const {
    writeContract: stake,
    data: stakeHash,
    isPending: isStakePending,
    error: stakeError,
    reset: resetStake,
  } = useWriteContract();

  // Unstake (redeem from sGBPb)
  const {
    writeContract: unstake,
    data: unstakeHash,
    isPending: isUnstakePending,
    error: unstakeError,
    reset: resetUnstake,
  } = useWriteContract();

  // Wait for transactions
  const { isLoading: isApproveLoading, isSuccess: isApproveSuccess } = useWaitForTransactionReceipt({
    hash: approveHash,
  });

  const { isLoading: isStakeLoading, isSuccess: isStakeSuccess } = useWaitForTransactionReceipt({
    hash: stakeHash,
  });

  const { isLoading: isUnstakeLoading, isSuccess: isUnstakeSuccess } = useWaitForTransactionReceipt({
    hash: unstakeHash,
  });

  // Calculate sGBPb preview when staking (1:1 on first stake, then based on share price)
  const sGbpbPreview = () => {
    if (!amount || activeAction !== 'stake') return 0;
    try {
      // For staking, it's approximately 1:1 initially, but share price increases over time
      // We show approximate amount - actual will be slightly less as you get proportional shares
      return parseFloat(amount);
    } catch {
      return 0;
    }
  };

  // Calculate GBPb preview when unstaking
  const gbpbPreviewValue = () => {
    if (!unstakePreview || activeAction !== 'unstake') return 0;
    return Number(formatUnits(unstakePreview as bigint, 18));
  };

  // Check if approval needed
  const needsApproval = () => {
    if (activeAction !== 'stake' || !amount || !gbpbAllowance) return true;
    try {
      const amountInWei = parseUnits(amount, 18);
      return amountInWei > (gbpbAllowance as bigint);
    } catch {
      return true;
    }
  };

  // Handle approve success
  useEffect(() => {
    if (isApproveSuccess) {
      setError('');
      refetchAllowance();
    }
  }, [isApproveSuccess, refetchAllowance]);

  // Handle stake success
  useEffect(() => {
    if (isStakeSuccess) {
      setAmount('');
      setError('');
      refetchGbpbBalance();
      refetchSGbpbBalance();
      refetchAllowance();
      setTimeout(() => resetStake(), 5000);
    }
  }, [isStakeSuccess, refetchGbpbBalance, refetchSGbpbBalance, refetchAllowance, resetStake]);

  // Handle unstake success
  useEffect(() => {
    if (isUnstakeSuccess) {
      setAmount('');
      setError('');
      refetchGbpbBalance();
      refetchSGbpbBalance();
      setTimeout(() => resetUnstake(), 5000);
    }
  }, [isUnstakeSuccess, refetchGbpbBalance, refetchSGbpbBalance, resetUnstake]);

  // Handle errors
  useEffect(() => {
    const errors = [approveError, stakeError, unstakeError];
    const error = errors.find(e => e);
    if (error) {
      setError(error.message.includes('User rejected') ? 'Transaction rejected' : error.message);
    }
  }, [approveError, stakeError, unstakeError]);

  const handleApprove = () => {
    if (!amount || !address) return;
    try {
      const amountInWei = parseUnits(amount, 18);
      setError('');
      approve({
        address: CONTRACTS.gbpb,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [CONTRACTS.sGBPb, amountInWei],
      });
    } catch (e) {
      setError('Invalid amount format');
    }
  };

  const handleStake = () => {
    if (!amount || !address) return;
    try {
      const amountInWei = parseUnits(amount, 18);
      setError('');
      stake({
        address: CONTRACTS.sGBPb,
        abi: SGBPB_ABI,
        functionName: 'deposit',
        args: [amountInWei],
      });
    } catch (e) {
      setError('Invalid amount format');
    }
  };

  const handleUnstake = () => {
    if (!amount || !address) return;
    try {
      const amountInWei = parseUnits(amount, 18);
      setError('');
      unstake({
        address: CONTRACTS.sGBPb,
        abi: SGBPB_ABI,
        functionName: 'redeem',
        args: [amountInWei],
      });
    } catch (e) {
      setError('Invalid amount format');
    }
  };

  const handleMaxClick = () => {
    if (activeAction === 'stake' && gbpbBalance) {
      const balanceStr = formatUnits(gbpbBalance as bigint, 18);
      setAmount(balanceStr);
    } else if (activeAction === 'unstake' && sGbpbBalance) {
      const balanceStr = formatUnits(sGbpbBalance as bigint, 18);
      setAmount(balanceStr);
    }
  };

  const isLoading = isApprovePending || isApproveLoading || isStakePending || isStakeLoading || isUnstakePending || isUnstakeLoading;
  const showApproveButton = activeAction === 'stake' && needsApproval();
  const showSuccess = isStakeSuccess || isUnstakeSuccess;
  const txHash = stakeHash || unstakeHash || approveHash;

  return (
    <div className="space-y-4">
      {/* Amount Input */}
      <div>
        <label className="text-white/70 text-sm font-medium mb-2 block">
          {activeAction === 'stake' ? 'Amount to Stake' : 'Amount to Unstake'}
        </label>
        <div className="relative">
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.00"
            disabled={!address || isLoading}
            className="w-full bg-white/10 border-2 border-white/20 rounded-xl px-4 py-4 text-white text-lg font-semibold placeholder:text-white/30 focus:outline-none focus:border-white/40 transition-colors"
          />
          <div className="absolute right-16 top-1/2 -translate-y-1/2 text-white/60 font-medium">
            {activeAction === 'stake' ? 'GBPb' : 'sGBPb'}
          </div>
          <button
            onClick={handleMaxClick}
            disabled={!address || isLoading}
            className="absolute right-4 top-1/2 -translate-y-1/2 text-blue-400 text-sm font-semibold hover:text-blue-300 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            MAX
          </button>
        </div>

        {/* Balance */}
        <p className="text-xs text-white/60 mt-1">
          Available: {address
            ? activeAction === 'stake'
              ? `${formatNumber(Number(gbpbBalance || 0n) / 1e18, 2)} GBPb`
              : `${formatNumber(Number(sGbpbBalance || 0n) / 1e18, 2)} sGBPb`
            : '0.00'}
        </p>
      </div>

      {/* Preview */}
      {amount && parseFloat(amount) > 0 && (
        <div className="bg-white/5 border border-white/10 rounded-xl p-4">
          <div className="flex justify-between items-center">
            <span className="text-white/70 text-sm">You will receive:</span>
            <div className="text-right">
              <div className="text-white text-lg font-bold">
                {activeAction === 'stake'
                  ? `≈ ${formatNumber(sGbpbPreview(), 2)} sGBPb`
                  : `≈ ${formatNumber(gbpbPreviewValue(), 2)} GBPb`
                }
              </div>
              {activeAction === 'stake' && (
                <div className="text-white/50 text-xs">Earning yield immediately</div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Error Display */}
      {error && (
        <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-3">
          <p className="text-sm text-red-400 flex items-center gap-2">
            <AlertCircle className="h-4 w-4" />
            {error}
          </p>
        </div>
      )}

      {/* Success Display */}
      {showSuccess && (
        <div className="bg-green-500/10 border border-green-500/30 rounded-xl p-3">
          <p className="text-sm text-green-400 flex items-center gap-2 font-medium">
            <CheckCircle2 className="h-4 w-4" />
            {activeAction === 'stake' ? 'Staking successful!' : 'Unstake successful!'}
          </p>
          {txHash && (
            <a
              href={`https://arbiscan.io/tx/${txHash}`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs text-green-400 hover:underline flex items-center gap-1 mt-1"
            >
              View transaction <ExternalLink className="h-3 w-3" />
            </a>
          )}
        </div>
      )}

      {/* Transaction in progress */}
      {(isApproveLoading || isStakeLoading || isUnstakeLoading) && txHash && (
        <div className="bg-blue-500/10 border border-blue-500/30 rounded-xl p-3">
          <p className="text-sm text-blue-400 flex items-center gap-2">
            <Loader2 className="h-4 w-4 animate-spin" />
            {isApproveLoading ? 'Approving...' : 'Transaction confirming...'}
          </p>
          <a
            href={`https://arbiscan.io/tx/${txHash}`}
            target="_blank"
            rel="noopener noreferrer"
            className="text-xs text-blue-400 hover:underline flex items-center gap-1 mt-1"
          >
            View transaction <ExternalLink className="h-3 w-3" />
          </a>
        </div>
      )}

      {/* Withdrawal Period Warning for Unstaking */}
      {activeAction === 'unstake' && (
        <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-xl p-4">
          <div className="flex items-start gap-2">
            <div className="text-yellow-400 text-lg">⏱️</div>
            <div>
              <div className="text-yellow-400 font-semibold text-sm">Instant Unstaking</div>
              <p className="text-white/70 text-xs mt-1">
                Unstaking is instant - you'll receive your GBPb immediately (including accrued yield).
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Action Buttons */}
      {!address ? (
        <button
          disabled
          className="w-full bg-white/10 border-2 border-white/20 text-white/40 font-bold py-4 px-6 rounded-xl cursor-not-allowed"
        >
          Connect Wallet
        </button>
      ) : showApproveButton ? (
        <>
          <button
            onClick={handleApprove}
            disabled={!amount || parseFloat(amount) <= 0 || isLoading}
            className={`w-full border-2 text-white font-bold py-4 px-6 rounded-xl transition-all ${
              !amount || parseFloat(amount) <= 0 || isLoading
                ? 'bg-white/10 border-white/20 text-white/40 cursor-not-allowed'
                : 'bg-white/20 hover:bg-white/30 border-white/30 hover:scale-[1.02] active:scale-[0.98]'
            }`}
          >
            {isApprovePending || isApproveLoading ? (
              <span className="flex items-center justify-center gap-2">
                <Loader2 className="h-4 w-4 animate-spin" />
                {isApproveLoading ? 'Confirming...' : 'Approving...'}
              </span>
            ) : (
              'Step 1: Approve GBPb'
            )}
          </button>
          {isApproveSuccess && (
            <p className="text-xs text-green-400 text-center">
              ✓ Approval successful! Click "Stake GBPb" below.
            </p>
          )}
        </>
      ) : (
        <button
          onClick={activeAction === 'stake' ? handleStake : handleUnstake}
          disabled={!amount || parseFloat(amount) <= 0 || isLoading}
          className={`w-full border-2 text-white font-bold py-4 px-6 rounded-xl transition-all ${
            !amount || parseFloat(amount) <= 0 || isLoading
              ? 'bg-white/10 border-white/20 text-white/40 cursor-not-allowed'
              : 'bg-white/20 hover:bg-white/30 border-white/30 hover:scale-[1.02] active:scale-[0.98]'
          }`}
        >
          {(isStakePending || isStakeLoading || isUnstakePending || isUnstakeLoading) ? (
            <span className="flex items-center justify-center gap-2">
              <Loader2 className="h-4 w-4 animate-spin" />
              {(isStakeLoading || isUnstakeLoading) ? 'Confirming...' : 'Processing...'}
            </span>
          ) : activeAction === 'stake' ? (
            'Stake GBPb → sGBPb'
          ) : (
            'Unstake sGBPb'
          )}
        </button>
      )}

      {/* Info Text */}
      <p className="text-white/50 text-xs text-center mt-2">
        {activeAction === 'stake'
          ? 'Stake your GBPb tokens to receive sGBPb and earn yield'
          : 'Unstake your sGBPb to receive GBPb back (including accrued yield)'}
      </p>
    </div>
  );
}
