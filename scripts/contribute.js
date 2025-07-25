const { ethers, network } = require("hardhat");
const data = require('geni_data');

async function main() {
    const [deployer] = await ethers.getSigners();
    const tokenAddress = data.getGeniTokenAddress(network.name);
    const geniRewarderAddress = data.getGeniRewarder(network.name);
    const rawAmount = ethers.parseUnits("750000000", 18);
    const normAmount = ethers.parseUnits("21024000", 8);

    // approved
    const ERC20_ABI = [
        "function approve(address spender, uint256 amount) external returns (bool)"
    ];
    const geniToken = await ethers.getContractAt(ERC20_ABI, tokenAddress, deployer);
    const tx = await geniToken.approve(geniRewarderAddress, rawAmount);
    await tx.wait();
    console.log(`✅ Approved ${rawAmount} GENI to ${geniRewarderAddress}`);


    // contribute
    const rewarder = await ethers.getContractAt('GeniRewarder', geniRewarderAddress, deployer);
    const tx2 = await rewarder.contribute(normAmount)
    console.log(`Contributed ${normAmount} GENI to the rewarder contract ${geniRewarderAddress}`);
    console.log("Tx hash:", tx.hash);
    await tx2.wait();
    console.log("✅ Transfer confirmed.");
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});