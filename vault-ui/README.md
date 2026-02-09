# GBP Yield Vault UI

A modern Next.js 14 web application for interacting with the GBP Yield Vault on Arbitrum Sepolia.

## Features

- 💼 **Wallet Connection**: Connect with MetaMask, WalletConnect, and more via RainbowKit
- 📊 **Live Stats**: Real-time vault metrics (TVL, APY, share price, your position)
- 💰 **Deposit**: Approve USDC and deposit to earn GBP-denominated yields
- 🏦 **Withdraw**: Redeem your vault shares for USDC
- 🎨 **Modern UI**: Built with shadcn/ui and Tailwind CSS
- ⚡ **Fast**: Next.js 14 with App Router and React Server Components

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Web3**: RainbowKit + wagmi + viem
- **UI**: shadcn/ui + Tailwind CSS
- **Language**: TypeScript
- **Network**: Arbitrum Sepolia (Testnet)

## Getting Started

### 1. Install Dependencies

```bash
npm install
```

### 2. Set Up Environment Variables

Create a `.env.local` file:

```bash
cp .env.example .env.local
```

Then edit `.env.local` and add your WalletConnect Project ID:

- Get a free project ID from [WalletConnect Cloud](https://cloud.walletconnect.com)
- Add it to `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`

### 3. Run Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Contract Addresses (Arbitrum Sepolia)

```
Vault:           0x34E196b1C1ACBF1e3D89F49AEbEC3E1AF9C40244
Mock USDC:       0x5Ee6Ac8bEe69F471dcadc6AbaC31840909Aa93c9
Morpho Strategy: 0x9F218D3D5e5801A6953d8AA58B734f7f0772945D
Perp Manager:    0x2f04124F1129E9763C5170D47341B3C786fda331
```

## Testing on Testnet

1. **Switch to Arbitrum Sepolia** in your wallet
2. **Get Testnet ETH**: [Arbitrum Sepolia Faucet](https://faucet.quicknode.com/arbitrum/sepolia)
3. **Get Mock USDC**: The vault deployer can send you testnet USDC
4. **Deposit & Earn**: Try depositing 100+ USDC to test the vault

## Project Structure

```
vault-ui/
├── app/
│   ├── layout.tsx       # Root layout with Web3 providers
│   ├── page.tsx         # Main vault interface
│   ├── providers.tsx    # RainbowKit & wagmi setup
│   └── globals.css      # Global styles & Tailwind
├── components/
│   ├── ui/              # shadcn/ui components
│   ├── VaultStats.tsx   # Vault statistics dashboard
│   ├── DepositForm.tsx  # Deposit functionality
│   └── WithdrawForm.tsx # Withdrawal functionality
└── lib/
    ├── contracts/       # ABIs and addresses
    ├── wagmi.ts         # wagmi configuration
    └── utils.ts         # Helper functions
```

## Features Explained

### Deposit Flow

1. Enter amount of USDC to deposit (minimum 100 USDC)
2. Click "Approve USDC" and confirm the transaction
3. Click "Deposit to Vault" and confirm the transaction
4. Receive vault shares representing your GBP-denominated position

### Withdraw Flow

1. Enter number of shares to redeem (or click "Max")
2. See preview of how much USDC you'll receive
3. Click "Withdraw USDC" and confirm the transaction
4. Receive USDC back to your wallet

### Vault Stats

- **Total Value Locked**: Total USDC in the vault
- **Share Price (GBP)**: Current price per share in British Pounds
- **Your Shares**: Your vault share balance and GBP value
- **Est. APY**: Expected annual percentage yield (6-10%)

## Build for Production

```bash
npm run build
npm start
```

## Learn More

- [Vault Smart Contracts](../src)
- [Deployment Documentation](../DEPLOYMENT_V2_SECURE.md)
- [Security Analysis](../docs/SECURITY_ANALYSIS_VAULT_EXPLOITS.md)
- [Next.js Documentation](https://nextjs.org/docs)
- [RainbowKit Documentation](https://www.rainbowkit.com)
- [wagmi Documentation](https://wagmi.sh)

## Troubleshooting

**Wallet won't connect?**
- Make sure you have a WalletConnect Project ID in `.env.local`
- Switch your wallet to Arbitrum Sepolia network

**Transactions failing?**
- Ensure you have enough ETH for gas on Arbitrum Sepolia
- Check that you have approved USDC before depositing
- Verify minimum deposit is at least 100 USDC

**Can't see your balance?**
- Refresh the page or reconnect your wallet
- Verify you're on the correct network (Arbitrum Sepolia)

## Security Notes

⚠️ **This is a testnet deployment**
- Smart contracts are unaudited
- Use only testnet funds
- Do not use on mainnet without professional audit

## License

MIT
