'use client';

import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { arbitrum } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'Blendra Admin',
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'f57feadbcac85c350d63cc74b796a7a3', // Temporary fallback
  chains: [arbitrum],
  ssr: true,
});
