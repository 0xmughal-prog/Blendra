import minterABI from './contracts/GBPbMinterABI.json';
import erc20ABI from './contracts/IERC20ABI.json';

// Contract addresses on Arbitrum Mainnet (GAS FIX DEPLOYMENT)
export const CONTRACTS = {
  vault: '0x2339b63D3b9e9E246f8c8485Db90EABb88f44c61' as const, // GBPbMinter (WITH GAS FIX)
  usdc: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831' as const, // USDC Arbitrum mainnet
  morphoStrategy: '0x6d2e4C3B491C8DCCC79C5049087533B46187227F' as const,
  perpManager: '0xEc791A81F5D54c89749313D256Dd7289C62A8B7E' as const, // PerpPositionManager (WITH GAS FIX)
  oracle: '0x85731548499ce2A9c771606cE736EDEd1CA9b136' as const,
  gbpb: '0xf04e200541c6E9Ec4499757653cD2f166Faf8F91' as const,
  sGBPb: '0xFeb31be5dB6A49d67Cd131e56C98d1ABcE52aED3' as const, // New sGBPb with rescue function & 100% max fee
  ostiumProvider: '0xfD08f1C84deF1997521aF79AB653fF368322b269' as const, // OstiumPerpProvider (WITH GAS FIX)
};

export const VAULT_ABI = minterABI;
export const ERC20_ABI = erc20ABI;

// Chain ID for Arbitrum Mainnet
export const ARBITRUM_MAINNET_CHAIN_ID = 42161;
