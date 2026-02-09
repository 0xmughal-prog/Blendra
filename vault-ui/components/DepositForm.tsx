'use client';

import { useState, useEffect, useRef } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';
import { CONTRACTS, VAULT_ABI, ERC20_ABI } from '@/lib/contracts';
import { formatUSDC } from '@/lib/utils';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits } from 'viem';
import { ArrowDownCircle, Loader2, AlertCircle, CheckCircle2, ExternalLink } from 'lucide-react';

export function DepositForm() {
  const { address } = useAccount();
  const [amount, setAmount] = useState('');
  const [step, setStep] = useState<'approve' | 'deposit'>('approve');
  const [error, setError] = useState<string>('');
  const [validationError, setValidationError] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState(false); // FIX #1: Prevent double submissions

  // FIX #3: Focus management refs
  const successMessageRef = useRef<HTMLDivElement>(null);
  const errorMessageRef = useRef<HTMLDivElement>(null);
  const depositButtonRef = useRef<HTMLButtonElement>(null);

  // Read user's USDC balance
  const { data: usdcBalance, refetch: refetchBalance } = useReadContract({
    address: CONTRACTS.usdc,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });

  // Read current allowance
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: CONTRACTS.usdc,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address ? [address, CONTRACTS.vault] : undefined,
    query: {
      enabled: !!address,
    },
  });

  // Approve USDC
  const {
    writeContract: approve,
    data: approveHash,
    isPending: isApprovePending,
    error: approveError,
    reset: resetApprove,
  } = useWriteContract();

  // Deposit to vault
  const {
    writeContract: deposit,
    data: depositHash,
    isPending: isDepositPending,
    error: depositError,
    reset: resetDeposit,
  } = useWriteContract();

  // Wait for approve transaction
  const {
    isLoading: isApproveLoading,
    isSuccess: isApproveSuccess,
    error: approveReceiptError,
  } = useWaitForTransactionReceipt({
    hash: approveHash,
  });

  // Wait for deposit transaction
  const {
    isLoading: isDepositLoading,
    isSuccess: isDepositSuccess,
    error: depositReceiptError,
  } = useWaitForTransactionReceipt({
    hash: depositHash,
  });

  // Handle approve success
  useEffect(() => {
    if (isApproveSuccess && step === 'approve') {
      setStep('deposit');
      setError('');
      setIsSubmitting(false); // FIX #1: Reset submission flag
      refetchAllowance();

      // FIX #3: Focus on deposit button after approval
      setTimeout(() => {
        depositButtonRef.current?.focus();
      }, 100);
    }
  }, [isApproveSuccess, step, refetchAllowance]);

  // Handle deposit success
  useEffect(() => {
    if (isDepositSuccess) {
      setAmount('');
      setStep('approve');
      setError('');
      setIsSubmitting(false); // FIX #1: Reset submission flag
      refetchBalance();
      refetchAllowance();

      // FIX #3: Focus on success message
      setTimeout(() => {
        successMessageRef.current?.focus();
      }, 100);

      // Reset after 5 seconds
      setTimeout(() => {
        resetDeposit();
      }, 5000);
    }
  }, [isDepositSuccess, refetchBalance, refetchAllowance, resetDeposit]);

  // Handle errors
  useEffect(() => {
    if (approveError) {
      setError(approveError.message.includes('User rejected')
        ? 'Transaction rejected'
        : 'Approval failed: ' + approveError.message);
      setIsSubmitting(false); // FIX #1: Reset on error

      // FIX #3: Focus on error message
      setTimeout(() => errorMessageRef.current?.focus(), 100);
    } else if (depositError) {
      setError(depositError.message.includes('User rejected')
        ? 'Transaction rejected'
        : 'Deposit failed: ' + depositError.message);
      setIsSubmitting(false); // FIX #1: Reset on error

      // FIX #3: Focus on error message
      setTimeout(() => errorMessageRef.current?.focus(), 100);
    } else if (approveReceiptError) {
      setError('Approval transaction failed on-chain');
      setIsSubmitting(false);
      setTimeout(() => errorMessageRef.current?.focus(), 100);
    } else if (depositReceiptError) {
      setError('Deposit transaction failed on-chain');
      setIsSubmitting(false);
      setTimeout(() => errorMessageRef.current?.focus(), 100);
    }
  }, [approveError, depositError, approveReceiptError, depositReceiptError]);

  // Validate input
  const validateAmount = (value: string): string => {
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

    // Check minimum deposit
    if (numValue < 100) {
      return 'Minimum deposit is 100 USDC';
    }

    // Check against balance
    if (usdcBalance && numValue > Number(usdcBalance) / 1e6) {
      return 'Amount exceeds your balance';
    }

    // Check decimal places (USDC has 6 decimals)
    const decimals = value.split('.')[1];
    if (decimals && decimals.length > 6) {
      return 'Maximum 6 decimal places allowed';
    }

    return '';
  };

  const handleAmountChange = (value: string) => {
    setAmount(value);
    const error = validateAmount(value);
    setValidationError(error);
    if (error) setError('');
  };

  const handleApprove = () => {
    if (!amount || !address || isSubmitting) return; // FIX #1: Check submission flag

    const validationError = validateAmount(amount);
    if (validationError) {
      setError(validationError);
      return;
    }

    try {
      const amountInWei = parseUnits(amount, 6);
      setError('');
      setIsSubmitting(true); // FIX #1: Set submission flag
      approve({
        address: CONTRACTS.usdc,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [CONTRACTS.vault, amountInWei],
      });
    } catch (e) {
      setError('Invalid amount format');
      setIsSubmitting(false); // FIX #1: Reset on error
    }
  };

  const handleDeposit = () => {
    if (!amount || !address || isSubmitting) return; // FIX #1: Check submission flag

    const validationError = validateAmount(amount);
    if (validationError) {
      setError(validationError);
      return;
    }

    try {
      const amountInWei = parseUnits(amount, 6);
      setError('');
      setIsSubmitting(true); // FIX #1: Set submission flag
      deposit({
        address: CONTRACTS.vault,
        abi: VAULT_ABI,
        functionName: 'deposit',
        args: [amountInWei, address],
      });
    } catch (e) {
      setError('Invalid amount format');
      setIsSubmitting(false); // FIX #1: Reset on error
    }
  };

  const handleMaxClick = () => {
    if (usdcBalance) {
      // Format to avoid precision loss
      const balanceStr = (Number(usdcBalance) / 1e6).toFixed(6);
      setAmount(balanceStr);
      setValidationError('');
    }
  };

  const handleRetry = () => {
    setError('');
    setStep('approve');
    setIsSubmitting(false); // FIX #1: Reset submission flag
    resetApprove();
    resetDeposit();
  };

  // Check if we need approval - handle undefined allowance properly
  const needsApproval = () => {
    if (!amount || !allowance) return true;
    try {
      const amountInWei = parseUnits(amount, 6);
      return amountInWei > (allowance as bigint);
    } catch {
      return true;
    }
  };

  const isLoading = isApprovePending || isApproveLoading || isDepositPending || isDepositLoading || isSubmitting;
  const hasError = !!error;
  const canProceed = amount && !validationError && !isLoading;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <ArrowDownCircle className="h-5 w-5" />
          Deposit USDC
        </CardTitle>
        <CardDescription>
          Deposit USDC to receive GBP-denominated vault shares earning 6-10% APY
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="deposit-amount">
            Amount (USDC)
            <span className="text-destructive ml-1" aria-label="required">*</span>
          </Label>
          <div className="flex gap-2">
            <Input
              id="deposit-amount"
              type="text"
              placeholder="100.00"
              value={amount}
              onChange={(e) => handleAmountChange(e.target.value)}
              disabled={!address || isLoading}
              aria-required="true"
              aria-invalid={!!validationError}
              aria-describedby={validationError ? "amount-error" : "amount-help"}
            />
            <Button
              variant="outline"
              onClick={handleMaxClick}
              disabled={!address || isLoading}
              aria-label="Set amount to maximum available balance"
            >
              Max
            </Button>
          </div>
          {usdcBalance ? (
            <p id="amount-help" className="text-xs text-muted-foreground">
              Balance: {formatUSDC(usdcBalance as bigint)} USDC
            </p>
          ) : null}
          {validationError ? (
            <p id="amount-error" className="text-xs text-destructive flex items-center gap-1">
              <AlertCircle className="h-3 w-3" />
              {validationError}
            </p>
          ) : null}
        </div>

        {/* FIX #2: aria-live region for status announcements */}
        <div aria-live="polite" aria-atomic="true" className="sr-only">
          {isApproveLoading && 'Approval transaction confirming'}
          {isDepositLoading && 'Deposit transaction confirming'}
          {isApproveSuccess && step === 'deposit' && 'Approval successful, ready to deposit'}
          {isDepositSuccess && 'Deposit successful'}
          {hasError && error}
        </div>

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
        {isDepositSuccess ? (
          <div
            ref={successMessageRef}
            tabIndex={-1}
            className="rounded-md bg-green-500/10 p-3 border border-green-500/20"
            role="status"
          >
            <p className="text-sm text-green-600 flex items-center gap-2 font-medium">
              <CheckCircle2 className="h-4 w-4" />
              Deposit successful! Your shares have been minted.
            </p>
            {depositHash ? (
              <a
                href={`https://arbiscan.io/tx/${depositHash}`}
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
        {(isApproveLoading || isDepositLoading) && (approveHash || depositHash) ? (
          <div className="rounded-md bg-blue-500/10 p-3 border border-blue-500/20" role="status">
            <p className="text-sm text-blue-600 flex items-center gap-2">
              <Loader2 className="h-4 w-4 animate-spin" />
              Transaction submitted, waiting for confirmation...
            </p>
            {(approveHash || depositHash) ? (
              <a
                href={`https://arbiscan.io/tx/${approveHash || depositHash}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-blue-600 hover:underline flex items-center gap-1 mt-1"
              >
                View transaction <ExternalLink className="h-3 w-3" />
              </a>
            ) : null}
          </div>
        ) : null}

        {/* Action Button */}
        {!address ? (
          <div className="space-y-2">
            <Button className="w-full" disabled>
              Connect Wallet to Deposit
            </Button>
            <p className="text-xs text-muted-foreground text-center">
              Please connect your wallet using the button above
            </p>
          </div>
        ) : needsApproval() && step === 'approve' ? (
          <Button
            className="w-full"
            onClick={handleApprove}
            disabled={!canProceed}
          >
            {isApprovePending || isApproveLoading ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                {isApproveLoading ? 'Confirming...' : 'Approving...'}
              </>
            ) : (
              'Step 1: Approve USDC'
            )}
          </Button>
        ) : (
          <Button
            ref={depositButtonRef}
            className="w-full"
            onClick={handleDeposit}
            disabled={!canProceed}
          >
            {isDepositPending || isDepositLoading ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                {isDepositLoading ? 'Confirming...' : 'Depositing...'}
              </>
            ) : (
              'Step 2: Deposit to Vault'
            )}
          </Button>
        )}

        {step === 'deposit' && !hasError ? (
          <p className="text-xs text-muted-foreground text-center">
            Approval complete. Click above to deposit.
          </p>
        ) : null}
      </CardContent>
    </Card>
  );
}
