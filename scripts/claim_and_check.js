const hre = require("hardhat");
const ethers = hre.ethers;
const data = require("../../geni_data");

async function printUserInfo(rewarder, user, label = "") {
    const info = await rewarder.getUserRewardInfo(user.address);
    console.log(`${label}User points     : ${ethers.formatUnits(info.userPoints, 6)}`);
    console.log(`${label}Est. reward     : ${ethers.formatEther(info.estimatedReward)} GENI`);
    console.log(`${label}Claimed (total) : ${ethers.formatEther(info.totalClaimed)} GENI\n`);
}

async function printRewardSystemInfo(rewarder) {
    const system = await rewarder.getRewardSystemInfo();
    console.log("📊 System reward info:");
    console.log(`Epoch            : ${system.epoch}`);
    console.log(`Start time       : ${system.startTime} (${new Date(Number(system.startTime) * 1000).toISOString()})`);
    console.log(`Total unlockable : ${ethers.formatEther(system.totalUnlockable)} GENI`);
    console.log(`Unlocked tokens  : ${ethers.formatEther(system.unlockedTokens)} GENI`);
    console.log(`Distributed      : ${ethers.formatEther(system.distributedTokens)} GENI`);
    console.log(`Available tokens : ${ethers.formatEther(system.availableTokens)} GENI`);
    console.log(`Unclaimed points : ${ethers.formatUnits(system.unclaimedPoints, 6)}`);
    console.log(`Token/point rate : ${ethers.formatEther(system.tokenPerPoint)} GENI/point\n`);
}

async function main() {
    const [deployer, trader1] = await ethers.getSigners();
    const network = hre.network.name;

    const geniRewarderAddress = data.getGeniRewarder(network);

    const GeniRewarder = await ethers.getContractFactory("GeniRewarder");
    const rewarder = await GeniRewarder.attach(geniRewarderAddress);

    console.log(`📌 Checking reward info before claim for: ${trader1.address}`);
    await printRewardSystemInfo(rewarder);
    await printUserInfo(rewarder, trader1);

    // const info = await rewarder.getUserRewardInfo(trader1.address);
    // const pointsToClaim = info.userPoints / 10n;
    const pointsToClaim = ethers.parseUnits('1', 6);

    if (pointsToClaim > 0) {
        console.log(`🚀 Claiming ${ethers.formatUnits(pointsToClaim, 6)} points...`);
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