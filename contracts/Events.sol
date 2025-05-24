// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

abstract contract Events {
    event Claimed(address indexed user, uint256 epoch, uint256 reward, uint256 pointsUsed, uint256 pointsPerGENI);
    event Contributed(address indexed from, uint256 amount);
    event EpochStarted(uint256 epoch, uint256 startTime);
    event EpochEnded(uint256 epoch);
}