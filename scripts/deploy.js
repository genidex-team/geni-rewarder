const { ethers, upgrades, network } = require("hardhat");
const hre = require("hardhat");
const data = require("../../geni_data/index");

async function main() {
  const [deployer] = await ethers.getSigners();

  const geniDexAddress = data.getGeniDexAddress(network.name, "GeniDex");
  const tokenAddress = data.getGeniTokenAddress(network.name, "GeniToken");
  console.log(tokenAddress, '====', geniDexAddress);
  if (!geniDexAddress || !tokenAddress ) {
    console.error("❌ Missing token or points contract address in data");
    return;
  }

  const GeniRewarder = await ethers.getContractFactory("GeniRewarder");
  const distributor = await upgrades.deployProxy(
    GeniRewarder,
    [deployer.address, tokenAddress, geniDexAddress],
    { initializer: "initialize", kind: "uups" }
  );

  await distributor.waitForDeployment();
  console.log("✅ GeniRewarder deployed to:", distributor.target);

  data.setGeniRewarder(network.name, distributor.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});