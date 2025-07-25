const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  const [deployer, user1, user2, user3, user4, user5] = await ethers.getSigners();
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

  await token.transfer(await rewards.getAddress(), ethers.parseEther("1000"));
  await token.approve(await staking.getAddress(), ethers.parseEther("100"));
  console.log("✅ Funded RewardDistribution and approved Staking");

  // Register 5 initial devices
  await registry.registerDevice(user1.address, "device1", "bigw://1");
  await registry.registerDevice(user2.address, "device2", "bigw://2");
  await registry.registerDevice(user3.address, "device3", "bigw://3");
  await registry.registerDevice(user4.address, "device4", "bigw://4");
  await registry.registerDevice(user5.address, "device5", "bigw://5");
  console.log("✅ Devices registered");

  await rewards.submitScore("device1", 50);
  await rewards.submitScore("device2", 20);
  await rewards.submitScore("device3", 10);
  await rewards.submitScore("device4", 10);
  await rewards.submitScore("device5", 10);

  // === Remove 2 participants
  const remove1 = user1.address;
  const remove2 = user2.address;
  await rewards.removeParticipant(remove1);
  await rewards.removeParticipant(remove2);
  console.log(`✅ Removed participants: ${remove1}, ${remove2}`);

  // === Add 1 more participant after removal
  const newWallet = ethers.Wallet.createRandom();
  const newDevice = "rejoin-device";
  const newUri = "bigw://rejoin";
  await registry.registerDevice(newWallet.address, newDevice, newUri);
  await rewards.submitScore(newDevice, 42);
  console.log("✅ Re-registered 1 participant after removal");

  console.log("🎉 All tests completed successfully");
}

main().catch((err) => {
  console.error("❌ Script Error:", err);
  process.exit(1);
});
