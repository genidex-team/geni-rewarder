const { ethers, upgrades } = require("hardhat");
const data = require("geni_data");

async function main() {
  const network = hre.network.name;
  const proxyAddress = data.getGeniRewarder(network);

  console.log(`Upgrading GeniRewarder on network: ${network}`);
  console.log("Proxy address:", proxyAddress);
  console.log("Old implementation address:", await upgrades.erc1967.getImplementationAddress(proxyAddress));

  const GeniRewarderV2 = await ethers.getContractFactory("GeniRewarder"); 
  const upgraded = await upgrades.upgradeProxy(
    proxyAddress,
    GeniRewarderV2,
    {kind: "uups"}
  );

  console.log("✅ Upgrade successful!");
  console.log("New implementation address:", await upgrades.erc1967.getImplementationAddress(proxyAddress));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});