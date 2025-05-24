// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IGeniDex {
    function getUserPoints(address user) external view returns (uint256);
    function getTotalUnclaimedPoints() external view returns (uint256);
    function getReferrer(address referee) external view returns (address);
    function deductUserPoints(address user, uint256 pointsToDeduct) external;
}

library Helper {


}