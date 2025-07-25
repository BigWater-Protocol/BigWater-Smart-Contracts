const hre = require("hardhat");
const { ethers } = hre;
const { Wallet } = require("ethers");

async function main() {
  const [deployer, user1, user2, user3, user4, user5] = await ethers.getSigners();
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Users:`, user1.address, user2.address, user3.address, user4.address, user5.address);

  const Token = await ethers.getContractFactory("BigWaterToken");
  const cap = ethers.parseEther("110000");
  const initialSupply = ethers.parseEther("11000");
  const token = await Token.deploy(deployer.address, initialSupply, cap);
  await token.waitForDeployment();

  const NFT = await ethers.getContractFactory("BigWaterDeviceNFT");
  const nft = await NFT.deploy();
  await nft.waitForDeployment();

  const Registry = await ethers.getContractFactory("DeviceRegistry");
  const registry = await Registry.deploy(await nft.getAddress());
  await registry.waitForDeployment();
  await nft.transferOwnership(await registry.getAddress());

  const Rewards = await ethers.getContractFactory("RewardDistribution");
  const rewards = await Rewards.deploy(await token.getAddress(), await registry.getAddress());
  await rewards.waitForDeployment();

  const Staking = await ethers.getContractFactory("DePINStaking");
  const staking = await Staking.deploy(await token.getAddress(), await rewards.getAddress());
  await staking.waitForDeployment();

  await token.transfer(await rewards.getAddress(), ethers.parseEther("1000"));
  await token.approve(await staking.getAddress(), ethers.parseEther("100"));

  await registry.registerDevice(user1.address, "device1", "bigw://1");
  await registry.registerDevice(user2.address, "device2", "bigw://2");
  await registry.registerDevice(user3.address, "device3", "bigw://3");
  await registry.registerDevice(user4.address, "device4", "bigw://4");
  await registry.registerDevice(user5.address, "device5", "bigw://5");

  await rewards.submitScore("device1", 50);
  await rewards.submitScore("device2", 20);
  await rewards.submitScore("device3", 10);
  await rewards.submitScore("device4", 10);
  await rewards.submitScore("device5", 10);

  const MAX = 200000;
  const fakeBase = Wallet.createRandom();
  const registeredAddrs = [];

  console.log("⛔ Generating and registering participants up to max cap...");
  for (let i = 0; i < MAX - 5; i++) {
    const fakeWallet = Wallet.fromMnemonic(fakeBase.mnemonic.phrase, `m/44'/60'/0'/0/${i}`);
    const deviceId = `mass-device-${i}`;
    const uri = `bigw://mass-${i}`;

    await nft.connect(deployer).mint(fakeWallet.address, deviceId, uri);
    await registry.registerDevice(fakeWallet.address, deviceId, uri);
    await rewards.submitScore(deviceId, 1);

    registeredAddrs.push(fakeWallet.address);
    if (i % 10000 === 0) console.log(`  → ${i + 5} participants registered`);
  }

  console.log("⛔ Testing enforcement of cap on 200001st participant...");
  const overflowWallet = Wallet.createRandom();
  try {
    const deviceId = "overflow-device";
    const uri = "bigw://overflow";

    await nft.connect(deployer).mint(overflowWallet.address, deviceId, uri);
    await registry.registerDevice(overflowWallet.address, deviceId, uri);
    await rewards.submitScore(deviceId, 10);

    throw new Error("❌ Cap breach allowed");
  } catch (err) {
    const msg = err?.reason || err?.message || err;
    if (msg.includes("Max participants reached")) {
      console.log("✅ Max participant cap correctly enforced");
    } else {
      console.error("❌ Unexpected error while testing cap:", msg);
    }
  }

  // Remove 2 participants
  const toRemove = registeredAddrs.slice(0, 2);
  for (const addr of toRemove) {
    await rewards.removeParticipant(addr);
    console.log(`✅ Removed participant: ${addr}`);
  }

  // Add 1 new participant (should succeed)
  const readdWallet = Wallet.createRandom();
  const readdDevice = "readd-device";
  const readdURI = "bigw://readd";
  await nft.connect(deployer).mint(readdWallet.address, readdDevice, readdURI);
  await registry.registerDevice(readdWallet.address, readdDevice, readdURI);
  await rewards.submitScore(readdDevice, 42);
  console.log(`✅ Successfully re-added participant after removals: ${readdWallet.address}`);
}

main().catch((err) => {
  console.error("❌ Script Error:", err);
  process.exit(1);
});
