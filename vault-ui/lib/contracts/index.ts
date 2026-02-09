import vaultABI from './GBPYieldVaultV2SecureABI.json';
import erc20ABI from './IERC20ABI.json';

// Contract addresses on Arbitrum Sepolia (from DEPLOYMENT_V2_SECURE.md)
export const CONTRACTS = {
  vault: '0x3224854163Ded9b939EEe85d0c9f3130e8fA2569' as const, // GBPbMinter
  usdc: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831' as const, // USDC Arbitrum mainnet
  morphoStrategy: '0x6d2e4C3B491C8DCCC79C5049087533B46187227F' as const,
  eulerStrategy: '0x79418578752113451bf543DE5a3ACd0EB7F62Ea8' as const, // Not used on mainnet
  perpManager: '0x555a6f93634F7B379B317Cccea47133f268947Eb' as const,
  oracle: '0x85731548499ce2A9c771606cE736EDEd1CA9b136' as const,
};

export const VAULT_ABI = vaultABI;
export const ERC20_ABI = erc20ABI;

// Chain ID for Arbitrum Mainnet
export const ARBITRUM_MAINNET_CHAIN_ID = 42161;
