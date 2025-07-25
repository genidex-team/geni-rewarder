require('@genidex/logger');
require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

const data = require('geni_data');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.27",
  networks: data.getNetworkConfig(),
  etherscan: data.getEtherscanConfig()
};
