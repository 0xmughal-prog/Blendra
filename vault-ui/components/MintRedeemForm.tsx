'use client';

import { useState, useEffect } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import { CONTRACTS, VAULT_ABI, ERC20_ABI } from '@/lib/contracts';
import { useVaultMetrics } from '@/lib/hooks/useVaultMetrics';
import { formatNumber } from '@/lib/utils';
import { Loader2, AlertCircle, CheckCircle2, ExternalLink } from 'lucide-react';

interface MintRedeemFormProps {
  activeAction: 'mint' | 'redeem';
}

export function MintRedeemForm({ activeAction }: MintRedeemFormProps) {
  const { address } = useAccount();
  const [amount, setAmount] = useState('');
  const [error, setError] = useState('');
  const vaultMetrics = useVaultMetrics();

  // Read USDC balance
  const { data: usdcBalance, refetch: refetchUsdcBalance } = useReadContract({
    address: CONTRACTS.usdc,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  // Read GBPb balance
  const { data: gbpbBalance, refetch: refetchGbpbBalance } = useReadContract({
    address: CONTRACTS.gbpb,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  // Read USDC allowance for vault
  const { data: usdcAllowance, refetch: refetchAllowance } = useReadContract({
    address: CONTRACTS.usdc,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address ? [address, CONTRACTS.vault] : undefined,
    query: { enabled: !!address && activeAction === 'mint' },
  });

  // Approve USDC
  const {
    writeContract: approve,
    data: approveHash,
    isPending: isApprovePending,
    error: approveError,
    reset: resetApprove,
  } = useWriteContract();

  // Mint (deposit)
  const {
    writeContract: mint,
    data: mintHash,
    isPending: isMintPending,
    error: mintError,
    reset: resetMint,
  } = useWriteContract();

  // Redeem
  const {
    writeContract: redeem,
    data: redeemHash,
    isPending: isRedeemPending,
    error: redeemError,
    reset: resetRedeem,
  } = useWriteContract();

  // Wait for transactions
  const { isLoading: isApproveLoading, isSuccess: isApproveSuccess } = useWaitForTransactionReceipt({
    hash: approveHash,
  });

  const { isLoading: isMintLoading, isSuccess: isMintSuccess } = useWaitForTransactionReceipt({
    hash: mintHash,
  });

  const { isLoading: isRedeemLoading, isSuccess: isRedeemSuccess } = useWaitForTransactionReceipt({
    hash: redeemHash,
  });

  // Calculate GBPb preview when minting
  const gbpbPreview = () => {
    if (!amount || activeAction !== 'mint' || vaultMetrics.gbpUsdPrice === 0) return 0;
    try {
      const usdcAmount = parseFloat(amount);
      // USDC (USD) / GBP_USD_rate = GBPb amount
      return usdcAmount / vaultMetrics.gbpUsdPrice;
    } catch {
      return 0;
    }
  };

  // Calculate USDC preview when redeeming (after 0.2% fee)
  const usdcPreview = () => {
    if (!amount || activeAction !== 'redeem' || vaultMetrics.gbpUsdPrice === 0) return 0;
    try {
      const gbpbAmount = parseFloat(amount);
      // GBPb * GBP_USD_rate = USDC value
      const usdcBeforeFee = gbpbAmount * vaultMetrics.gbpUsdPrice;
      // Apply 0.2% redemption fee
      return usdcBeforeFee * 0.998;
    } catch {
      return 0;
    }
  };

  // Check if approval needed
  const needsApproval = () => {
    if (activeAction !== 'mint' || !amount || !usdcAllowance) return true;
    try {
      const amountInWei = parseUnits(amount, 6);
      return amountInWei > (usdcAllowance as bigint);
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

  // Handle mint success
  useEffect(() => {
    if (isMintSuccess) {
      setAmount('');
      setError('');
      refetchUsdcBalance();
      refetchGbpbBalance();
      refetchAllowance();
      setTimeout(() => resetMint(), 5000);
    }
  }, [isMintSuccess, refetchUsdcBalance, refetchGbpbBalance, refetchAllowance, resetMint]);

  // Handle redeem success
  useEffect(() => {
    if (isRedeemSuccess) {
      setAmount('');
      setError('');
      refetchUsdcBalance();
      refetchGbpbBalance();
      setTimeout(() => resetRedeem(), 5000);
    }
  }, [isRedeemSuccess, refetchUsdcBalance, refetchGbpbBalance, resetRedeem]);

  // Handle errors
  useEffect(() => {
    const errors = [approveError, mintError, redeemError];
    const error = errors.find(e => e);
    if (error) {
      setError(error.message.includes('User rejected') ? 'Transaction rejected' : error.message);
    }
  }, [approveError, mintError, redeemError]);

  const handleApprove = () => {
    if (!amount || !address) return;
    try {
      const amountInWei = parseUnits(amount, 6);
      setError('');
      approve({
        address: CONTRACTS.usdc,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [CONTRACTS.vault, amountInWei],
      });
    } catch (e) {
      setError('Invalid amount format');
    }
  };

  const handleMint = () => {
    if (!amount || !address) return;
    try {
      const amountInWei = parseUnits(amount, 6);
      // Calculate expected GBPb amount with 1% slippage tolerance
      const expectedGBPb = gbpbPreview();
      const minGbpAmount = parseUnits((expectedGBPb * 0.99).toFixed(18), 18);
      setError('');
      mint({
        address: CONTRACTS.vault,
        abi: VAULT_ABI,
        functionName: 'mint',
        args: [amountInWei, minGbpAmount],
      });
    } catch (e) {
      setError('Invalid amount format');
    }
  };

  const handleRedeem = () => {
    if (!amount || !address) return;
    try {
      const amountInWei = parseUnits(amount, 18); // GBPb has 18 decimals
      setError('');
      redeem({
        address: CONTRACTS.vault,
        abi: VAULT_ABI,
        functionName: 'redeem',
        args: [amountInWei],
      });
    } catch (e) {
      setError('Invalid amount format');
    }
  };

  const handleMaxClick = () => {
    if (activeAction === 'mint' && usdcBalance) {
      const balanceStr = (Number(usdcBalance) / 1e6).toFixed(6);
      setAmount(balanceStr);
    } else if (activeAction === 'redeem' && gbpbBalance) {
      const balanceStr = formatUnits(gbpbBalance as bigint, 18);
      setAmount(balanceStr);
    }
  };

  const isLoading = isApprovePending || isApproveLoading || isMintPending || isMintLoading || isRedeemPending || isRedeemLoading;
  const showApproveButton = activeAction === 'mint' && needsApproval();
  const showSuccess = isMintSuccess || isRedeemSuccess;
  const txHash = mintHash || redeemHash || approveHash;

  return (
    <div className="space-y-4">
      {/* Amount Input */}
      <div>
        <label className="text-white/70 text-sm font-medium mb-2 block">
          {activeAction === 'mint' ? 'Amount to Mint' : 'Amount to Redeem'}
        </label>
        <div className="relative">
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.00"
            disabled={!address || isLoading}
            className="w-full bg-white/10 border-2 border-white/20 rounded-xl px-4 py-4 pr-32 text-white text-lg font-semibold placeholder:text-white/30 focus:outline-none focus:border-white/40 transition-colors [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
          />
          <div className="absolute right-20 top-1/2 -translate-y-1/2 text-white/60 font-medium text-sm">
            {activeAction === 'mint' ? 'USDC' : 'GBPb'}
          </div>
          <button
            onClick={handleMaxClick}
            disabled={!address || isLoading}
            className="absolute right-4 top-1/2 -translate-y-1/2 px-2 py-1 bg-blue-500/20 border border-blue-400/30 rounded-lg text-blue-400 text-xs font-semibold hover:bg-blue-500/30 hover:text-blue-300 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
          >
            MAX
          </button>
        </div>

        {/* Balance */}
        <p className="text-xs text-white/60 mt-1">
          Balance: {address
            ? activeAction === 'mint'
              ? `${formatNumber(Number(usdcBalance || 0n) / 1e6, 2)} USDC`
              : `${formatNumber(Number(gbpbBalance || 0n) / 1e18, 2)} GBPb`
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
                {activeAction === 'mint'
                  ? `≈ ${formatNumber(gbpbPreview(), 2)} GBPb`
                  : `≈ ${formatNumber(usdcPreview(), 2)} USDC`
                }
              </div>
              {activeAction === 'redeem' && (
                <div className="text-white/50 text-xs">After 0.2% fee</div>
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
            {activeAction === 'mint' ? 'Mint successful!' : 'Redemption successful!'}
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
      {(isApproveLoading || isMintLoading || isRedeemLoading) && txHash && (
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
              'Step 1: Approve USDC'
            )}
          </button>
          {isApproveSuccess && (
            <p className="text-xs text-green-400 text-center">
              ✓ Approval successful! Click "Mint GBPb" below.
            </p>
          )}
        </>
      ) : (
        <button
          onClick={activeAction === 'mint' ? handleMint : handleRedeem}
          disabled={!amount || parseFloat(amount) <= 0 || isLoading}
          className={`w-full border-2 text-white font-bold py-4 px-6 rounded-xl transition-all ${
            !amount || parseFloat(amount) <= 0 || isLoading
              ? 'bg-white/10 border-white/20 text-white/40 cursor-not-allowed'
              : 'bg-white/20 hover:bg-white/30 border-white/30 hover:scale-[1.02] active:scale-[0.98]'
          }`}
        >
          {(isMintPending || isMintLoading || isRedeemPending || isRedeemLoading) ? (
            <span className="flex items-center justify-center gap-2">
              <Loader2 className="h-4 w-4 animate-spin" />
              {(isMintLoading || isRedeemLoading) ? 'Confirming...' : 'Processing...'}
            </span>
          ) : activeAction === 'mint' ? (
            showApproveButton ? 'Step 2: Mint GBPb' : 'Mint GBPb'
          ) : (
            'Redeem USDC'
          )}
        </button>
      )}

      {/* Fee Information */}
      <div className="text-center mt-3">
        <p className="text-white/70 text-sm font-medium">
          {activeAction === 'mint' ? '0% mint fee' : '0.2% redemption fee'}
        </p>
      </div>

      {/* Info Text */}
      <p className="text-white/50 text-xs text-center mt-2">
        {activeAction === 'mint'
          ? 'Deposit USDC to receive GBPb tokens'
          : 'Redeem your GBPb tokens back to USDC'}
      </p>
    </div>
  );
}
