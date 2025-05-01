## DePIN contracts for BigWater Protocol

```
+-------------------+      (1) registerDevice      +--------------------+
|     User Wallet   | ───────────────────────────▶ |  DeviceRegistry    |
|                   |                              |  - Stores device   |
+-------------------+                              |  - Mints NFT       |
        ^                                          +---------┬----------+
        │ (NFT minted)                                       │
        |                                                    ▼
+-------------------+        (mint)                 +--------------------+
| BigWaterDeviceNFT | ◀──────────────────────────── | DeviceRegistry     |
| - tokenURI mapped |                               |                    |
+-------------------+                               +--------------------+
        
                     (2) Oracle submits quality score      
+-------------------+        (submitScore)         +--------------------+
|    Oracle Node    | ────────────────────────────▶| RewardDistribution |
|                   |                              | - Stores scores    |
+-------------------+                              | - Calculates base  |
                                                   +--------------------+
                                                              │
                 (3) claimRewards()                           │
        +─────────────────────────────────────────────────────+---------
        │                                                              ^
        ▼                                                              |
+-------------------+                            (BWTR transfer)       |
|     User Wallet   | ◀────────────────────────────────────────────┐   |
+-------------------+                                              │   |
        ^                                                          ▼   ▼  
        │   (4) approve + stake()                        +------------------+
        ├──────────────────────────────────────────────▶ |     Staking      |
        │  (BWTR with multiplier)                        | - Holds stake    |
        │                                                | - Computes yield |
        │                                                +--------┬---------+                                                     
(5) every epoch: claimStakingYield()                             │
        ├────────────────────────────────────────────────────────+


```
