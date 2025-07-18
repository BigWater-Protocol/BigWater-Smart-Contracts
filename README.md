# DePIN Contracts Deployment

This repository contains a full stack of smart contracts to simulate a DePIN reward flow, including:

- `BigWaterToken` (Capped ERC20 token)
- `BigWaterDeviceNFT` (ERC721 NFT)
- `DeviceRegistry` (Manages device ownership)
- `RewardDistribution` (Tracks scores and manages participant rewards)
- `DePINStaking` (Staking + reward payout logic)

---

## 🛠 Requirements

- Node.js >= 20.x
- Hardhat (installed locally)
- Dependencies installed by:-

```bash
npm install
```

---

## 🚀 Running the Script

To deploy and run the full e2e test locally:

```bash
npx hardhat run scripts/e2e.js
```

The script will:

1. Deploy all contracts
2. Register 5 test devices (assigned to separate accounts)
3. Submit mock scores
4. Stake BIGW tokens from the deployer
5. Distribute rewards based on the scores
6. Check pre- and post-stake balances

---

## ✅ Expected Output

Look for:

- ✅ Funded RewardDistribution and approved Staking  
- ✅ Devices registered  
- ✅ Scores submitted  
- ✅ Staked: xx BIGW  
- ✅ Rewards distributed  
- ✅ All tests passed 🎉

Final token balances of user accounts will be printed as:

```
User1 Reward: 2.0 BIGW
User2 Reward: 1.0 BIGW
...
```
---

## 🔁 Reset & Retry

To re-run from a clean state (local Hardhat network), simply run:

```bash
npx hardhat run scripts/deploy.js
```