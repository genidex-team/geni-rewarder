const {ethers, upgrades} = require("hardhat");
const data = require("geni_data");

async function printUserInfo(rewarder, user) {
    const info = await rewarder.getUserRewardInfo(user.address);
    console.log(`User points     : ${ethers.formatEther(info.userPoints)}`);
    console.log(`Points Per GENI : ${ethers.formatEther(info.pointsPerGENI)} points/GENI`);
    console.log(`Est. reward     : ${ethers.formatEther(info.estimatedReward)} GENI`);
    console.log(`Claimed (total) : ${ethers.formatEther(info.totalClaimed)} GENI\n`);
}

async function printRewardSystemInfo(rewarder) {
    const system = await rewarder.getRewardSystemInfo();
    console.log("📊 System reward info:");
    console.log(`Epoch            : ${system.epoch}`);
    console.log(`Epoch Start time       : ${system.startTime} (${new Date(Number(system.startTime) * 1000).toISOString()})`);
    console.log(`Epoch Total unlockable : ${ethers.formatEther(system.totalUnlockable)} GENI`);
    console.log(`Epoch Unlocked tokens  : ${ethers.formatEther(system.unlockedTokens)} GENI`);
    console.log(`Epoch Distributed      : ${ethers.formatEther(system.distributedTokens)} GENI`);
    console.log(`Total Distributed      : ${ethers.formatEther(system.totalDistributed)} GENI`);
    console.log(`Epoch Available tokens : ${ethers.formatEther(system.availableTokens)} GENI`);
    console.log(`Unclaimed points       : ${ethers.formatEther(system.unclaimedPoints)}`);
    console.log(`Points Per GENI        : ${ethers.formatEther(system.pointsPerGENI)} points/GENI`);
    console.log(`Geni Balance           : ${ethers.formatEther(system.geniBalance)} GENI\n`);
}

async function main() {
    const [deployer, user, trader1] = await ethers.getSigners();
    const network = hre.network.name;

    const geniRewarderAddress = data.getGeniRewarder(network);

    const GeniRewarder = await ethers.getContractFactory("GeniRewarder");
    const rewarder = await upgrades.upgradeProxy(
        geniRewarderAddress,
        GeniRewarder,
        {kind: "uups"}
    );

    // const GeniRewarder = await ethers.getContractFactory("GeniRewarder");
    // const rewarder = await GeniRewarder.attach(geniRewarderAddress);

    console.log(`📌 Checking reward info before claim for: ${trader1.address}`);
    await printRewardSystemInfo(rewarder);
    await printUserInfo(rewarder, trader1);

    // const info = await rewarder.getUserRewardInfo(trader1.address);
    // const pointsToClaim = info.userPoints / 10n;
    const pointsToClaim = ethers.parseEther('100.0001');

    if (pointsToClaim > 0) {
        console.log(`🚀 Claiming ${ethers.formatEther(pointsToClaim)} points...`);
        const tx = await rewarder.connect(trader1).claim(pointsToClaim);
        await tx.wait();
        console.log("✅ Claim successful!");
    } else {
        console.log("⚠️  No points available to claim.\n");
        return;
    }

    console.log("\n📌 Checking reward info AFTER claim...");
    await printRewardSystemInfo(rewarder);
    await printUserInfo(rewarder, trader1);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});