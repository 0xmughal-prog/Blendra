import minterABI from './contracts/GBPbMinterABI.json';
import erc20ABI from './contracts/IERC20ABI.json';

// Contract addresses on Arbitrum Mainnet (from DEPLOYMENT_COMPLETE.md)
export const CONTRACTS = {
  vault: '0x3224854163Ded9b939EEe85d0c9f3130e8fA2569' as const, // GBPbMinter
  usdc: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831' as const, // USDC Arbitrum mainnet
  morphoStrategy: '0x6d2e4C3B491C8DCCC79C5049087533B46187227F' as const,
  perpManager: '0xBf702F23D0BB9eFD7A3F1488a4a1A7A4b662a1D3' as const, // FIXED: Updated to new PerpPositionManager
  oracle: '0x85731548499ce2A9c771606cE736EDEd1CA9b136' as const,
  gbpb: '0xf04e200541c6E9Ec4499757653cD2f166Faf8F91' as const,
  sGBPb: '0xFeb31be5dB6A49d67Cd131e56C98d1ABcE52aED3' as const, // FIXED: New sGBPb with rescue function & 100% max fee
};

export const VAULT_ABI = minterABI;
export const ERC20_ABI = erc20ABI;

// Chain ID for Arbitrum Mainnet
export const ARBITRUM_MAINNET_CHAIN_ID = 42161;
