'use client';

import { useEffect, useState } from 'react';
import { AlertTriangle, CheckCircle, XCircle } from 'lucide-react';
import { verifyAllContracts, type VerificationResult } from '@/lib/contractVerification';

export function ContractVerificationBanner() {
  const [status, setStatus] = useState<{
    vault: VerificationResult | null;
    usdc: VerificationResult | null;
    isLoading: boolean;
  }>({
    vault: null,
    usdc: null,
    isLoading: true,
  });

  useEffect(() => {
    async function verify() {
      const results = await verifyAllContracts();
      setStatus({
        vault: results.vault,
        usdc: results.usdc,
        isLoading: false,
      });
    }

    verify();
  }, []);

  if (status.isLoading) {
    return null; // Don't show anything while loading
  }

  const hasErrors = !status.vault?.isValid || !status.usdc?.isValid;

  if (!hasErrors) {
    // Contracts verified successfully - show subtle success indicator
    return (
      <div className="bg-green-500/10 border border-green-500/20 rounded-md p-2 mb-4">
        <div className="flex items-center gap-2 text-sm text-green-600">
          <CheckCircle className="h-4 w-4" />
          <span>Contracts verified</span>
        </div>
      </div>
    );
  }

  // Show error banner if verification failed
  return (
    <div className="bg-destructive/10 border border-destructive/20 rounded-md p-4 mb-4" role="alert">
      <div className="flex items-start gap-3">
        <XCircle className="h-5 w-5 text-destructive mt-0.5" />
        <div className="flex-1">
          <h3 className="font-semibold text-destructive mb-2">Contract Verification Failed</h3>

          {!status.vault?.isValid && (
            <div className="text-sm text-destructive/90 mb-2">
              <p className="font-medium">Vault Contract:</p>
              <p className="text-xs">{status.vault?.error || 'Unknown error'}</p>
            </div>
          )}

          {!status.usdc?.isValid && (
            <div className="text-sm text-destructive/90 mb-2">
              <p className="font-medium">USDC Contract:</p>
              <p className="text-xs">{status.usdc?.error || 'Unknown error'}</p>
            </div>
          )}

          <p className="text-sm text-destructive/80 mt-3">
            ⚠️ <strong>Do not deposit funds.</strong> The contracts at the configured addresses do not match the expected interfaces. This could indicate:
          </p>
          <ul className="text-xs text-destructive/80 list-disc list-inside mt-1 space-y-1">
            <li>Wrong network (check you're on Arbitrum Sepolia)</li>
            <li>Incorrect contract addresses in configuration</li>
            <li>Contracts not deployed or upgraded</li>
            <li>Network connection issues</li>
          </ul>
        </div>
      </div>
    </div>
  );
}
