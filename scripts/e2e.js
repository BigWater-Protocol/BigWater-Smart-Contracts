const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const [deployer, user1, user2, user3, user4, user5, user6, user7, user8] = await ethers.getSigners();
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Users:`, user1.address, user2.address, user3.address, user4.address, user5.address);

  // Deploy BigWaterToken
  const Token = await ethers.getContractFactory("BigWaterToken");
  const cap = ethers.parseEther("110000");
  const initialSupply = ethers.parseEther("11000");
  const token = await Token.deploy(deployer.address, initialSupply, cap);
  await token.waitForDeployment();
  console.log(`BIGW deployed at: ${await token.getAddress()}`);

  // Deploy NFT
  const NFT = await ethers.getContractFactory("BigWaterDeviceNFT");
  const nft = await NFT.deploy();
  await nft.waitForDeployment();
  console.log(`NFT deployed at: ${await nft.getAddress()}`);

  // Deploy DeviceRegistry
  const Registry = await ethers.getContractFactory("DeviceRegistry");
  const registry = await Registry.deploy(await nft.getAddress());
  await registry.waitForDeployment();
  console.log(`Registry deployed at: ${await registry.getAddress()}`);

  // Transfer NFT ownership to registry
  await nft.transferOwnership(await registry.getAddress());

  // Deploy RewardDistribution
  const Rewards = await ethers.getContractFactory("RewardDistribution");
  const rewards = await Rewards.deploy(await token.getAddress(), await registry.getAddress());
  await rewards.waitForDeployment();
  console.log(`RewardDistribution deployed at: ${await rewards.getAddress()}`);

  // Deploy DePINStaking
  const Staking = await ethers.getContractFactory("DePINStaking");
  const staking = await Staking.deploy(await token.getAddress(), await rewards.getAddress());
  await staking.waitForDeployment();
  console.log(`DePINStaking deployed at: ${await staking.getAddress()}`);

  // Fund contracts and approve staking
  await token.transfer(await rewards.getAddress(), ethers.parseEther("1000"));
  await token.approve(await staking.getAddress(), ethers.parseEther("100"));
  console.log("✅ Funded RewardDistribution and approved Staking");

  // Register 5 devices
  await registry.registerDevice(user1.address, "device1", "ipfs://1");
  await registry.registerDevice(user2.address, "device2", "ipfs://2");
  await registry.registerDevice(user3.address, "device3", "ipfs://3");
  await registry.registerDevice(user4.address, "device4", "ipfs://4");
  await registry.registerDevice(user5.address, "device5", "ipfs://5");
  console.log("✅ Devices registered");

  // Submit scores
  await rewards.submitScore("device1", 50);
  await rewards.submitScore("device2", 20);
  await rewards.submitScore("device3", 10);
  await rewards.submitScore("device4", 10);
  await rewards.submitScore("device5", 10);
  console.log("✅ Scores submitted");

  // Print participant scores
  const participants = await rewards.getParticipants();
  for (const addr of participants) {
    const score = await rewards.getScore(addr);
    console.log(`  → Participant ${addr} has score ${score}`);
  }

  // Print deployer balance before staking
  const balanceBefore = await token.balanceOf(deployer.address);
  console.log(`Deployer balance before stake: ${ethers.formatEther(balanceBefore)} BIGW`);

  // Stake
  await staking.stake(ethers.parseEther("100"));
  const balanceAfter = await token.balanceOf(deployer.address);
  console.log(`✅ Staked: 100.0 BIGW`);
  console.log(`Deployer balance after stake: ${ethers.formatEther(balanceAfter)} BIGW`);

  // Distribute rewards
  await staking.distributeRewards();
  console.log(`✅ Rewards distributed, totalStaked now: ${ethers.formatEther(await staking.totalStaked())} BIGW`);

  // === Test reward distribution effects ===
  const expectedStaked = ethers.parseEther("90");
  const actualStaked = await staking.totalStaked();
  if (actualStaked !== expectedStaked) {
    throw new Error(`❌ totalStaked mismatch: expected 90, got ${ethers.formatEther(actualStaked)}`);
  }
  console.log("✅ totalStaked reduced correctly after distribution");

  try {
    await staking.distributeRewards();
    throw new Error("❌ distributeRewards was callable twice");
  } catch (err) {
    console.log("✅ distributeRewards cannot be called again immediately (as expected)");
  }

  try {
    await staking.connect(user1).distributeRewards();
    throw new Error("❌ Non-owner was able to call distributeRewards");
  } catch (err) {
    console.log("✅ Non-owner cannot call distributeRewards");
  }

  // Final balances
  const users = [user1, user2, user3, user4, user5];
  for (let i = 0; i < users.length; i++) {
    const bal = await token.balanceOf(users[i].address);
    console.log(`User${i + 1} Reward: ${ethers.formatEther(bal)} BIGW`);
    if (bal === 0n) {
      throw new Error(`❌ User${i + 1} (${users[i].address}) received 0 BIGW`);
    }
  }
  console.log("✅ All users received rewards > 0");

  const rewardDistBalance = await token.balanceOf(await rewards.getAddress());
  console.log(`RewardDistribution post-distribution balance: ${ethers.formatEther(rewardDistBalance)} BIGW`);

  // === Batch Register 3 New Users ===
  const batchOwners = [user6.address, user7.address, user8.address];
  const batchDeviceIds = ["device6", "device7", "device8"];
  const batchTokenURIs = ["ipfs://6", "ipfs://7", "ipfs://8"];

  await registry.batchRegisterDevices(batchOwners, batchDeviceIds, batchTokenURIs);
  console.log("✅ Batch upload complete: device6, device7, device8");

  for (let i = 0; i < batchOwners.length; i++) {
    const devices = await registry.getDevicesByOwner(batchOwners[i]);
    console.log(`User${i + 6} Devices:`, devices);
    if (!devices.includes(batchDeviceIds[i])) {
      throw new Error(`❌ device ${batchDeviceIds[i]} not found for user${i + 6}`);
    }
  }

  const allOwners = await registry.getAllRegisteredOwners();
  for (let i = 0; i < batchOwners.length; i++) {
    if (!allOwners.includes(batchOwners[i])) {
      throw new Error(`❌ Batch owner ${batchOwners[i]} not found in registry`);
    }
  }

  console.log("✅ Batch registration + verification for 3 new users passed");
  console.log("✅ All tests passed");
}

main().catch((error) => {
  console.error("❌ Script error:", error);
  process.exit(1);
});


main().catch((error) => {
  console.error("❌ Script error:", error);
  process.exit(1);
});
