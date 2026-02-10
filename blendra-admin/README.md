# 🎛️ Blendra Admin Dashboard

Web-based admin dashboard for managing the Blendra Protocol on Arbitrum.

## 🚀 Features

- **Real-time Protocol Status** - Monitor TVL, reserve, pause status
- **Protocol Management** - Pause/unpause, set TVL caps, manage reserves
- **Revenue Management** - Adjust treasury/reserve splits, claim fees
- **Web3 Integration** - Connect with MetaMask via RainbowKit
- **Beautiful UI** - Dark theme with TailwindCSS

## 📦 Tech Stack

- **Next.js 14** - React framework with App Router
- **TypeScript** - Type safety
- **TailwindCSS** - Styling
- **Wagmi + Viem** - Web3 interactions
- **RainbowKit** - Wallet connection

## 🛠️ Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment

Create `.env.local`:

```bash
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id_here
```

Get your WalletConnect Project ID from: https://cloud.walletconnect.com/

### 3. Run Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

## 🌐 Deploy to Vercel

### Option 1: Vercel CLI (Recommended)

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel
```

### Option 2: GitHub Integration

1. Push code to GitHub
2. Go to [vercel.com](https://vercel.com)
3. Click "New Project"
4. Import your GitHub repository
5. Add environment variable:
   - `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`
6. Deploy!

### Option 3: Vercel Dashboard

1. Go to [vercel.com](https://vercel.com)
2. Click "Add New Project"
3. Upload the `blendra-admin` folder
4. Add environment variables
5. Deploy

## 🔐 Security

- **Admin Only:** Only the protocol owner can execute admin functions
- **Web3 Secured:** All transactions require wallet signatures
- **On-chain Validation:** Smart contracts enforce permissions

## 📝 Contract Addresses (Arbitrum)

- **Minter:** `0x680A5F9d86accdcfd0aaCdaf533896A5B6c0F11d`
- **GBPb Token:** `0x59a7A23c1246713352B663690C3ac6D280a40176`
- **sGBPb Vault:** `0x0D9Fdc66E774FDa67607D02c498d8dc3AD4F6683`
- **Fee Distributor:** `0xD4A33F34E17C57587297C86b38049bd2B11b2964`

## 🎯 Usage

1. **Connect Wallet** - Click "Connect" and select your wallet
2. **View Status** - Monitor protocol metrics in real-time
3. **Admin Actions** - Execute protocol management functions
4. **Revenue Management** - Adjust splits and claim fees

## 📖 Documentation

See the main protocol documentation in the parent directory.

## 🐛 Issues

Report issues on GitHub or contact the development team.

---

Built with ❤️ for Blendra Protocol
