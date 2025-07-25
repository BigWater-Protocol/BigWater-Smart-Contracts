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

  // Deploy BigWaterDeviceNFT
  const NFT = await ethers.getContractFactory("BigWaterDeviceNFT");
  const nft = await NFT.deploy(deployer.address);
  await nft.waitForDeployment();
  console.log(`NFT deployed at: ${await nft.getAddress()}`);

  // Deploy DeviceRegistry
  const Registry = await ethers.getContractFactory("DeviceRegistry");
  const registry = await Registry.deploy(await nft.getAddress(), deployer.address);
  await registry.waitForDeployment();
  console.log(`Registry deployed at: ${await registry.getAddress()}`);

  // Transfer NFT ownership to registry and confirm
  await nft.transferOwnership(await registry.getAddress());
  await registry.acceptNFTContractOwnership(); 
  const newOwner = await nft.owner();
  console.log(`NFT owner address: ${newOwner}`);

  if (newOwner !== (await registry.getAddress())) {
    throw new Error("❌ Ownership transfer to registry failed");
  }
  console.log("✅ NFT ownership transferred to registry");

  // Deploy RewardDistribution
  const Rewards = await ethers.getContractFactory("RewardDistribution");
  const rewards = await Rewards.deploy(await token.getAddress(), await registry.getAddress());
  await rewards.waitForDeployment();
  console.log(`RewardDistribution deployed at: ${await rewards.getAddress()}`);

  // Deploy DePINStaking
  const Staking = await ethers.getContractFactory("DePINStaking");
  const staking = await Staking.deploy(await token.getAddress(), await rewards.getAddress(), deployer.address);
  await staking.waitForDeployment();
  console.log(`DePINStaking deployed at: ${await staking.getAddress()}`);

  // Fund RewardDistribution and approve DePINStaking
  await token.transfer(await rewards.getAddress(), ethers.parseEther("1000"));
  await token.approve(await staking.getAddress(), ethers.parseEther("100"));
  console.log("✅ Funded RewardDistribution and approved Staking");

  //  === Test: Register devices successfully
  await registry.registerDevice(user1.address, "device1", "bigw://1");
  await registry.registerDevice(user2.address, "device2", "bigw://2");
  await registry.registerDevice(user3.address, "device3", "bigw://3");
  await registry.registerDevice(user4.address, "device4", "bigw://4");
  await registry.registerDevice(user5.address, "device5", "bigw://5");
  console.log("✅ Devices registered");

  //  === Test: Submit scores successfully
  await rewards.submitScore("device1", 30);
  await rewards.submitScore("device2", 20);
  await rewards.submitScore("device3", 10);
  await rewards.submitScore("device4", 10);
  await rewards.submitScore("device5", 10);
  console.log("✅ Scores submitted");

  //  === Test: Remove 2 participants successfully
  await rewards.removeParticipant(user4.address);
  await rewards.removeParticipant(user5.address);
  console.log(`✅ Removed participants: ${user1.address}, ${user2.address}`);

  //  === Test: Register new participant and submit score successfully
  const newWallet = ethers.Wallet.createRandom();
  const newDevice = "rejoin-device";
  const newUri = "bigw://rejoin";

  await registry.registerDevice(newWallet.address, newDevice, newUri);
  await rewards.submitScore(newDevice, 42);
  console.log("✅ Re-registered 1 participant after removal");

  // === Test: registerDevice fails with invalid tokenURI ===
  try {
    await registry.registerDevice(user1.address, "deviceX", "ipfs://malicious");
    throw new Error("❌ registerDevice accepted invalid URI (ipfs://...)");
  } catch (err) {
    const reason = err?.error?.reason || err?.reason || err?.message;
    if (reason.includes("URI must start with 'bigw://'")) {
      console.log("✅ registerDevice correctly rejected invalid URI (ipfs://...)");
    } else {
      console.error("❌ Unexpected error during URI validation test:", reason);
      throw err;
    }
  }

  //  === Test: Print actual BIGW scores successfully
  const participants = await rewards.getParticipants();
  for (const addr of participants) {
    const score = await rewards.getScore(addr);
    if (score === 0n) throw new Error(`❌ ${addr} has 0 score.`);
  }

  // === Test: Stake successfully
  const balanceBefore = await token.balanceOf(deployer.address);
  await staking.stake(ethers.parseEther("100"));
  const balanceAfter = await token.balanceOf(deployer.address);
  console.log(`✅ Staked: 100 BIGW`);
  console.log(`Deployer balance before/after stake: ${ethers.formatEther(balanceBefore)} → ${ethers.formatEther(balanceAfter)} BIGW`);

  // === Test: Distribute rewards 
  await staking.distributeRewards();
  console.log(`✅ Rewards distributed, totalStaked: ${ethers.formatEther(await staking.totalStaked())} BIGW`);

  // === Test: Verify each user got > 0 reward
  const users = [user1, user2, user3];
  for (let i = 0; i < users.length; i++) {
    const bal = await token.balanceOf(users[i].address);
    console.log(`User${i + 3} Reward: ${ethers.formatEther(bal)} BIGW`);
    if (bal === 0n) throw new Error(`❌ User${i + 3} (${users[i].address}) received 0 BIGW`);
  }
  console.log("✅ All users received rewards > 0");

  // === Test: Batch Register 3 New Users
  const batchOwners = [user6.address, user7.address, user8.address];
  const batchDeviceIds = ["device6", "device7", "device8"];
  const batchTokenURIs = ["bigw://6", "bigw://7", "bigw://8"];
  await registry.batchRegisterDevices(batchOwners, batchDeviceIds, batchTokenURIs);
  console.log("✅ Batch upload: device6, device7, device8");

  // === Test: Verify devices on state
  for (let i = 0; i < batchOwners.length; i++) {
    const devices = await registry.getDevicesByOwner(batchOwners[i]);
    console.log(`User${i + 6} Devices:`, devices);
    if (!devices.includes(batchDeviceIds[i])) {
      throw new Error(`❌ device ${batchDeviceIds[i]} not found for user${i + 6}`);
    }
  }

  // === Test: Verify owners are recorded
  const allOwners = await registry.getAllRegisteredOwners();
  for (let i = 0; i < batchOwners.length; i++) {
    if (!allOwners.includes(batchOwners[i])) {
      throw new Error(`❌ Batch owner ${batchOwners[i]} not found in registry`);
    }
  }

  // === Test: distributeRewards fails if called by non-owner ===
  try {
    await staking.connect(user1).distributeRewards();
    throw new Error("❌ distributeRewards should fail for non-owner but did not");
  } catch (err) {
    const reason = err?.error?.reason || err?.reason || err?.message;
    if (
      reason.includes("Ownable: caller is not the owner") ||
      reason.includes("caller is not the owner") ||
      reason.includes("OwnableUnauthorizedAccount")
    ) {
      console.log("✅ distributeRewards correctly failed for non-owner caller");
    } else {
      console.error("❌ Unexpected error message for non-owner distributeRewards call:", reason);
      throw err;
    }
  }

  console.log("🎉 All tests completed successfully");
}

main().catch((err) => {
  console.error("❌ Script Error:", err);
  process.exit(1);
});
