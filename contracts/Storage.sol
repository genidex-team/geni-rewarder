// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./Helper.sol";

abstract contract Storage {
    struct Epoch {
        uint256 startTime;
        uint256 totalUnlockable;
        uint256 distributedTokens;
    }

    uint256 public constant BASE_UNIT = 10 ** 8;
    uint256 internal constant TEN_POW_10 = 10 ** 10;

    mapping(uint256 => Epoch) public epochs;
    mapping(address => uint256) public totalClaimedTokens;
    mapping(address => uint256) public referralPoints;

    IERC20 public geniToken;
    IGeniDex public geniDex;

    uint256 public constant EPOCH_DURATION = 730 days;
    uint256 public constant UNLOCK_INTERVAL = 60;

    uint256 public currentEpoch;

    uint256 public totalUnclaimedRefPoints;
}