 ``` 
  [User]                                [Contracts]
     │
     │ ① registerDevice(deviceId, tokenURI)
     ├─────────────────────────────────▶ DRC (DeviceRegistry)
     │                                  └──→ mints NFT via NFT contract
     │
     │
     │ ② oracle → submitScore(deviceId, score)
     ├─────────────────────────────────▶ RDC (RewardDistribution)
     │
     │ ③ user calls claimRewards()
     ├─────────────────────────────────▶ RDC transfers BIGW base reward
     │
     │ ④ protocol calls approve() + stake(amount)
     ├─────────────────────────────────▶ Staking
     │
     │
     │ ⑤ ⏱ every epoch, user calls claimStakingYield()
     ├─────────────────────────────────▶ Staking:
     │                                     └─ fetches score from RDC
     │                                     └─ applies stake multiplier
     │                                     └─ sends boosted BIGW
```
