'use client';

import { useState, useEffect, useRef } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';
import { CONTRACTS, VAULT_ABI } from '@/lib/contracts';
import { formatNumber } from '@/lib/utils';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits } from 'viem';
import { ArrowUpCircle, Loader2, AlertCircle, CheckCircle2, ExternalLink, Info } from 'lucide-react';

export function WithdrawForm() {
  const { address } = useAccount();
  const [shares, setShares] = useState('');
  const [error, setError] = useState<string>('');
  const [validationError, setValidationError] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState(false); // FIX #1: Prevent double submissions

  // FIX #3: Focus management refs
  const successMessageRef = useRef<HTMLDivElement>(null);
  const errorMessageRef = useRef<HTMLDivElement>(null);

  // Read user's share balance
  const { data: userShares, refetch: refetchShares } = useReadContract({
    address: CONTRACTS.vault,
    abi: VAULT_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });

  // Read how much USDC the shares are worth
  const { data: previewRedeem } = useReadContract({
    address: CONTRACTS.vault,
    abi: VAULT_ABI,
    functionName: 'previewRedeem',
    args: shares && Number(shares) > 0 ? [parseUnits(shares, 18)] : undefined,
    query: {
      enabled: !!shares && Number(shares) > 0,
    },
  });

  // Withdraw (redeem shares)
  const {
    writeContract: redeem,
    data: redeemHash,
    isPending: isRedeemPending,
    error: redeemError,
    reset: resetRedeem,
  } = useWriteContract();

  // Wait for redeem transaction
  const {
    isLoading: isRedeemLoading,
    isSuccess: isRedeemSuccess,
    error: redeemReceiptError,
  } = useWaitForTransactionReceipt({
    hash: redeemHash,
  });

  // Handle redeem success
  useEffect(() => {
    if (isRedeemSuccess) {
      setShares('');
      setError('');
      setIsSubmitting(false); // FIX #1: Reset submission flag
      refetchShares();

      // FIX #3: Focus on success message
      setTimeout(() => {
        successMessageRef.current?.focus();
      }, 100);

      // Reset after 5 seconds
      setTimeout(() => {
        resetRedeem();
      }, 5000);
    }
  }, [isRedeemSuccess, refetchShares, resetRedeem]);

  // Handle errors
  useEffect(() => {
    if (redeemError) {
      setError(redeemError.message.includes('User rejected')
        ? 'Transaction rejected'
        : 'Withdrawal failed: ' + redeemError.message);
      setIsSubmitting(false); // FIX #1: Reset on error

      // FIX #3: Focus on error message
      setTimeout(() => errorMessageRef.current?.focus(), 100);
    } else if (redeemReceiptError) {
      setError('Withdrawal transaction failed on-chain');
      setIsSubmitting(false);
      setTimeout(() => errorMessageRef.current?.focus(), 100);
    }
  }, [redeemError, redeemReceiptError]);

  // Validate input
  const validateShares = (value: string): string => {
    if (!value) return '';

    // Remove whitespace
    value = value.trim();

    // Check for valid number format
    if (!/^\d*\.?\d*$/.test(value)) {
      return 'Please enter a valid number';
    }

    const numValue = Number(value);

    // Check for zero or negative
    if (numValue <= 0) {
      return 'Amount must be greater than zero';
    }

    // Check against share balance
    if (userShares && numValue > Number(userShares) / 1e18) {
      return 'Amount exceeds your share balance';
    }

    // Check decimal places (shares have 18 decimals but limit to reasonable amount)
    const decimals = value.split('.')[1];
    if (decimals && decimals.length > 18) {
      return 'Maximum 18 decimal places allowed';
    }

    return '';
  };

  const handleSharesChange = (value: string) => {
    setShares(value);
    const error = validateShares(value);
    setValidationError(error);
    if (error) setError('');
  };

  const handleRedeem = () => {
    if (!shares || !address || isSubmitting) return; // FIX #1: Check submission flag

    const validationError = validateShares(shares);
    if (validationError) {
      setError(validationError);
      return;
    }

    try {
      const sharesInWei = parseUnits(shares, 18);
      setError('');
      setIsSubmitting(true); // FIX #1: Set submission flag
      redeem({
        address: CONTRACTS.vault,
        abi: VAULT_ABI,
        functionName: 'redeem',
        args: [sharesInWei, address, address],
      });
    } catch (e) {
      setError('Invalid shares amount format');
      setIsSubmitting(false); // FIX #1: Reset on error
    }
  };

  const handleMaxClick = () => {
    if (userShares) {
      // Format to avoid precision loss
      const sharesStr = (Number(userShares) / 1e18).toFixed(18).replace(/\.?0+$/, '');
      setShares(sharesStr);
      setValidationError('');
    }
  };

  const handleRetry = () => {
    setError('');
    setIsSubmitting(false); // FIX #1: Reset submission flag
    resetRedeem();
  };

  const isLoading = isRedeemPending || isRedeemLoading || isSubmitting;
  const hasError = !!error;
  const canProceed = shares && !validationError && !isLoading;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <ArrowUpCircle className="h-5 w-5" />
          Withdraw USDC
        </CardTitle>
        <CardDescription>
          Redeem your vault shares to receive USDC back
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="withdraw-shares">
            Shares to Redeem
            <span className="text-destructive ml-1" aria-label="required">*</span>
          </Label>
          <div className="flex gap-2">
            <Input
              id="withdraw-shares"
              type="text"
              placeholder="0.00"
              value={shares}
              onChange={(e) => handleSharesChange(e.target.value)}
              disabled={!address || isLoading}
              aria-required="true"
              aria-invalid={!!validationError}
              aria-describedby={validationError ? "shares-error" : "shares-help"}
            />
            <Button
              variant="outline"
              onClick={handleMaxClick}
              disabled={!address || isLoading}
              aria-label="Set shares to maximum available balance"
            >
              Max
            </Button>
          </div>
          {userShares ? (
            <p id="shares-help" className="text-xs text-muted-foreground">
              Your shares: {formatNumber(Number(userShares) / 1e18, 2)}
            </p>
          ) : null}
          {validationError ? (
            <p id="shares-error" className="text-xs text-destructive flex items-center gap-1">
              <AlertCircle className="h-3 w-3" />
              {validationError}
            </p>
          ) : null}
        </div>

        {/* FIX #2: aria-live region for status announcements */}
        <div aria-live="polite" aria-atomic="true" className="sr-only">
          {isRedeemLoading && 'Withdrawal transaction confirming'}
          {isRedeemSuccess && 'Withdrawal successful'}
          {hasError && error}
        </div>

        {/* Preview Withdrawal Amount */}
        {previewRedeem && !hasError && !validationError ? (
          <div className="rounded-md bg-muted p-3 border">
            <p className="text-sm font-medium mb-1">You will receive (estimated):</p>
            <p className="text-lg font-bold">
              {formatNumber(Number(previewRedeem) / 1e6, 2)} USDC
            </p>
            <p className="text-xs text-muted-foreground mt-1 flex items-center gap-1">
              <Info className="h-3 w-3" />
              Final amount may vary slightly based on share price at execution
            </p>
          </div>
        ) : null}

        {/* Error Display */}
        {hasError ? (
          <div
            ref={errorMessageRef}
            tabIndex={-1}
            className="rounded-md bg-destructive/10 p-3 border border-destructive/20"
            role="alert"
          >
            <p className="text-sm text-destructive flex items-center gap-2">
              <AlertCircle className="h-4 w-4" />
              {error}
            </p>
            <Button
              variant="outline"
              size="sm"
              onClick={handleRetry}
              className="mt-2"
            >
              Try Again
            </Button>
          </div>
        ) : null}

        {/* Success Display */}
        {isRedeemSuccess ? (
          <div
            ref={successMessageRef}
            tabIndex={-1}
            className="rounded-md bg-green-500/10 p-3 border border-green-500/20"
            role="status"
          >
            <p className="text-sm text-green-600 flex items-center gap-2 font-medium">
              <CheckCircle2 className="h-4 w-4" />
              Withdrawal successful! USDC has been sent to your wallet.
            </p>
            {redeemHash ? (
              <a
                href={`https://sepolia.arbiscan.io/tx/${redeemHash}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-green-600 hover:underline flex items-center gap-1 mt-1"
              >
                View transaction <ExternalLink className="h-3 w-3" />
              </a>
            ) : null}
          </div>
        ) : null}

        {/* Transaction in progress */}
        {isRedeemLoading && redeemHash ? (
          <div className="rounded-md bg-blue-500/10 p-3 border border-blue-500/20" role="status">
            <p className="text-sm text-blue-600 flex items-center gap-2">
              <Loader2 className="h-4 w-4 animate-spin" />
              Transaction submitted, waiting for confirmation...
            </p>
            <a
              href={`https://sepolia.arbiscan.io/tx/${redeemHash}`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs text-blue-600 hover:underline flex items-center gap-1 mt-1"
            >
              View transaction <ExternalLink className="h-3 w-3" />
            </a>
          </div>
        ) : null}

        {/* Action Button */}
        {!address ? (
          <div className="space-y-2">
            <Button className="w-full" disabled>
              Connect Wallet to Withdraw
            </Button>
            <p className="text-xs text-muted-foreground text-center">
              Please connect your wallet using the button above
            </p>
          </div>
        ) : (
          <Button
            className="w-full"
            onClick={handleRedeem}
            disabled={!canProceed}
          >
            {isRedeemPending || isRedeemLoading ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                {isRedeemLoading ? 'Confirming...' : 'Withdrawing...'}
              </>
            ) : (
              'Withdraw USDC'
            )}
          </Button>
        )}
      </CardContent>
    </Card>
  );
}
