import vaultABI from './contracts/GBPYieldVaultV2SecureABI.json';
import erc20ABI from './contracts/IERC20ABI.json';

// Contract addresses on Arbitrum Mainnet (from DEPLOYMENT_COMPLETE.md)
export const CONTRACTS = {
  vault: '0x3224854163Ded9b939EEe85d0c9f3130e8fA2569' as const, // GBPbMinter
  usdc: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831' as const, // USDC Arbitrum mainnet
  morphoStrategy: '0x6d2e4C3B491C8DCCC79C5049087533B46187227F' as const,
  perpManager: '0x555a6f93634F7B379B317Cccea47133f268947Eb' as const,
  oracle: '0x85731548499ce2A9c771606cE736EDEd1CA9b136' as const,
  gbpb: '0xf04e200541c6E9Ec4499757653cD2f166Faf8F91' as const,
  sGBPb: '0xC388c87F3f983111C02375C956ed3f0BA6B5b18c' as const,
};

export const VAULT_ABI = vaultABI;
export const ERC20_ABI = erc20ABI;

// Chain ID for Arbitrum Mainnet
export const ARBITRUM_MAINNET_CHAIN_ID = 42161;
