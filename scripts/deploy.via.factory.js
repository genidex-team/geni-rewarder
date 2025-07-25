

const { ethers, network } = require("hardhat");
const data = require('geni_data');
const {factory} = require('geni_helper');

let proxySalt;

const tokenAddress = data.getGeniTokenAddress(network.name);
const geniDexAddress = data.getGeniDexAddress(network.name);

// if(data.isDevnet(network.name)){
//     // proxySalt = data.getTokenSalt();
//     proxySalt = data.randomBytes32();
// }else{
    proxySalt = data.getRewarderSalt();
// }

async function main() {

    const [deployer] = await ethers.getSigners();
    const initialOwner = deployer.address;
    console.log(`\nNetwork : ${network.name}`);
    console.log(`Deployer: ${deployer.address}`);
    console.log({initialOwner, tokenAddress, geniDexAddress})
    let initArgs = [initialOwner, tokenAddress, geniDexAddress];
    const proxyAddress = await factory.deploy('GeniRewarder', proxySalt, initArgs, 'uups');
    data.setGeniRewarder(network.name, proxyAddress)

}

main()
    .then(() => process.exit(0))
    .catch((e) => { console.error(e); process.exit(1); });
