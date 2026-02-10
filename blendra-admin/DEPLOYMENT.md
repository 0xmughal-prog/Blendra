# 🚀 Blendra Admin - Vercel Deployment Guide

## Quick Deploy (2 Minutes)

### Step 1: Get WalletConnect Project ID

1. Go to https://cloud.walletconnect.com/
2. Sign in or create account
3. Click "Create Project"
4. Copy your Project ID

### Step 2: Deploy to Vercel

**Method A: Vercel CLI (Fastest)**

```bash
# Install Vercel CLI globally
npm i -g vercel

# Navigate to project
cd blendra-admin

# Deploy
vercel

# Follow prompts:
# - Set up and deploy: Yes
# - Which scope: Your account
# - Link to existing project: No
# - Project name: blendra-admin
# - Directory: ./
# - Override settings: No

# Add environment variable
vercel env add NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID production

# Paste your WalletConnect Project ID when prompted

# Deploy to production
vercel --prod
```

**Method B: Vercel Dashboard**

1. Go to https://vercel.com/new
2. Click "Add New Project"
3. Select "Import Third-Party Git Repository" or drag folder
4. Configure:
   - Project Name: `blendra-admin`
   - Framework Preset: Next.js
   - Root Directory: `./`
5. Add Environment Variable:
   - Key: `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`
   - Value: Your WalletConnect Project ID
6. Click "Deploy"

### Step 3: Access Your Dashboard

Once deployed, you'll get a URL like:
```
https://blendra-admin.vercel.app
```

Visit the URL and connect your admin wallet!

## 🔧 Post-Deployment

### Update Domain (Optional)

1. Go to Vercel Dashboard → Your Project → Settings → Domains
2. Add custom domain: `admin.blendra.xyz` (or your preference)
3. Follow DNS configuration instructions

### Environment Variables

If you need to update your WalletConnect Project ID:

```bash
vercel env add NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID production
```

Or in Vercel Dashboard:
- Settings → Environment Variables → Edit

### Redeploy

```bash
vercel --prod
```

## ✅ Verification Checklist

- [ ] Dashboard loads at Vercel URL
- [ ] Can connect wallet with MetaMask
- [ ] Protocol status displays correctly
- [ ] Admin functions work (pause/unpause)
- [ ] Revenue management displays
- [ ] Transactions submit to Arbitrum

## 🐛 Troubleshooting

**Issue: "Invalid Project ID"**
- Solution: Check NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID in environment variables

**Issue: "Cannot read properties of undefined"**
- Solution: Ensure you're connected to Arbitrum network in MetaMask

**Issue: "Transaction reverted"**
- Solution: Ensure connected wallet is the protocol owner

**Issue: Build fails**
- Solution: Run `npm run build` locally to check for errors

## 📱 Mobile Responsive

The dashboard is mobile-responsive and works on phones/tablets!

## 🔐 Security

- Only protocol owner can execute admin functions (enforced on-chain)
- All transactions require wallet signatures
- Dashboard is read-only for non-owners

---

**Need Help?** Open an issue or contact the team.
