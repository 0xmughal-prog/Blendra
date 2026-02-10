# ⚡ Blendra Admin - 5 Minute Deployment

## 🎯 What You're Deploying

A beautiful web admin dashboard for managing your Blendra Protocol on Arbitrum.

**Features:**
- ✅ Real-time protocol metrics
- ✅ One-click pause/unpause
- ✅ TVL cap management
- ✅ Reserve funding
- ✅ Revenue split configuration
- ✅ Fee claiming

## 🚀 Deploy Now (3 Steps)

### Step 1: Get WalletConnect ID (1 min)

1. Visit: https://cloud.walletconnect.com/
2. Create free account
3. Create new project
4. Copy Project ID

### Step 2: Install Vercel CLI (30 sec)

```bash
npm i -g vercel
```

### Step 3: Deploy! (1 min)

```bash
cd blendra-admin
vercel
```

When prompted:
- **Set up and deploy?** Yes
- **Which scope?** Your account
- **Link to project?** No
- **Project name?** blendra-admin
- **Directory?** ./
- **Override settings?** No

Then add your WalletConnect ID:

```bash
vercel env add NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID production
```

Paste your Project ID when prompted.

Finally, deploy to production:

```bash
vercel --prod
```

### Done! 🎉

Your dashboard is live at: `https://blendra-admin-xxx.vercel.app`

## 🎨 What It Looks Like

```
┌─────────────────────────────────────────┐
│  Blendra Admin     [Connect Wallet]     │
├─────────────────────────────────────────┤
│  📊 Protocol Status                     │
│  ┌────────┐ ┌────────┐ ┌────────┐     │
│  │ ACTIVE │ │ TVL $0 │ │ $5 Res │     │
│  └────────┘ └────────┘ └────────┘     │
│                                         │
│  ⚙️ Admin Actions   💰 Revenue         │
│  ┌────────────┐    ┌─────────────┐   │
│  │ Pause      │    │ 90% Treasury│   │
│  │ Set TVL    │    │ 10% Reserve │   │
│  │ Fund Res   │    │ Update Split│   │
│  └────────────┘    └─────────────┘   │
└─────────────────────────────────────────┘
```

## 📱 Access It

- **Desktop:** Works great on Chrome, Firefox, Safari
- **Mobile:** Fully responsive, use MetaMask mobile app

## 🔐 Security

- Only your admin wallet can execute functions
- All actions require your signature
- Smart contracts enforce permissions

## 💡 Tips

1. **Bookmark it** - Add to favorites for easy access
2. **Share with team** - Read-only for non-admins
3. **Use on mobile** - Manage protocol on-the-go
4. **Check daily** - Monitor reserve and TVL

## 🆘 Need Help?

**Can't connect wallet?**
- Make sure you're on Arbitrum network
- Try MetaMask mobile browser

**Transactions failing?**
- Ensure you're the protocol owner
- Check you have ETH for gas

**Dashboard not loading?**
- Check WalletConnect Project ID is set
- Try clearing browser cache

## 🎯 Next Steps

1. Connect your admin wallet
2. Check protocol status
3. Test pause/unpause (optional)
4. Manage as needed!

---

**Congratulations!** 🎉 You now have a professional admin dashboard for Blendra Protocol!
