// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./Helper.sol";
import "./Events.sol";
import "./Storage.sol";

contract GeniRewarder is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    Storage,
    Events {

    function initialize(address initialOwner, address _token, address _geniDex) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        geniToken = IERC20(_token);
        geniDex = IGeniDex(_geniDex);

        currentEpoch = 0;
        epochs[0].startTime = block.timestamp;
        epochs[0].totalUnlockable = 0;
        epochs[0].distributedTokens = 0;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _initEpochIfNeeded() internal {
        if (block.timestamp >= epochs[currentEpoch].startTime + EPOCH_DURATION) {
            emit EpochEnded(currentEpoch);
            currentEpoch += 1;
            uint256 currentBalance = geniToken.balanceOf(address(this));
            epochs[currentEpoch].startTime = block.timestamp;
            epochs[currentEpoch].totalUnlockable = currentBalance / (2 * TEN_POW_10);
            epochs[currentEpoch].distributedTokens = 0;

            emit EpochStarted(currentEpoch, block.timestamp);
        }
    }

    function _getUnlockedTokens(uint256 epochId) internal view returns (uint256) {
        Epoch memory epoch = epochs[epochId];

        uint256 elapsed = block.timestamp - epoch.startTime;
        if (elapsed >= EPOCH_DURATION) return epoch.totalUnlockable;

        uint256 totalMinutes = EPOCH_DURATION / UNLOCK_INTERVAL;
        return (epoch.totalUnlockable * (elapsed / UNLOCK_INTERVAL)) / totalMinutes;
    }

    function contribute(uint256 normAmount) external {
        require(normAmount > 0, "Zero points");
        uint256 rawAmount = normAmount * TEN_POW_10;
        require(geniToken.transferFrom(msg.sender, address(this), rawAmount), "Transfer failed");
        epochs[currentEpoch].totalUnlockable += normAmount / 2;
        emit Contributed(msg.sender, normAmount);
    }

    function claimTradingReward(uint256 points) external {
        require(points > 0, "Zero points");

        uint256 userPoints = geniDex.getUserPoints(msg.sender);
        require(userPoints >= points, "Not enough user points");

        uint256 totalUnclaimedPoints = totalUnclaimedRefPoints + geniDex.getTotalUnclaimedPoints();
        require(totalUnclaimedPoints >= points, "Not enough unclaimed points");

        _initEpochIfNeeded();
        Epoch storage epoch = epochs[currentEpoch];

        uint256 unlocked = _getUnlockedTokens(currentEpoch);
        require(unlocked > epoch.distributedTokens, "No tokens available");

        uint256 available = unlocked - epoch.distributedTokens;
        uint256 pointsPerGENI = BASE_UNIT * totalUnclaimedPoints / available;
        // uint256 reward = points / pointsPerGENI;
        uint256 reward = available * points / totalUnclaimedPoints;

        require(reward > 0, "Reward = 0");

        epoch.distributedTokens += reward;
        totalClaimedTokens[msg.sender] += reward;

        geniDex.deductUserPoints(msg.sender, points);
        geniToken.transfer(msg.sender, reward*TEN_POW_10);
        _addReferralPoints(points);

        emit Claimed(msg.sender, currentEpoch, reward, points, pointsPerGENI);
    }

    function claimReferralReward(uint256 points) external {
        require(points > 0, "Zero points");

        uint256 userPoints = referralPoints[msg.sender];
        require(userPoints >= points, "Not enough user points");

        uint256 totalUnclaimedPoints = totalUnclaimedRefPoints + geniDex.getTotalUnclaimedPoints();
        require(totalUnclaimedPoints >= points, "Not enough unclaimed points");

        _initEpochIfNeeded();
        Epoch storage epoch = epochs[currentEpoch];

        uint256 unlocked = _getUnlockedTokens(currentEpoch);
        require(unlocked > epoch.distributedTokens, "No tokens available");

        uint256 available = unlocked - epoch.distributedTokens;
        uint256 pointsPerGENI = BASE_UNIT * totalUnclaimedPoints / available;
        uint256 reward = available * points / totalUnclaimedPoints;

        require(reward > 0, "Reward = 0");

        epoch.distributedTokens += reward;
        totalClaimedTokens[msg.sender] += reward;

        referralPoints[msg.sender] = userPoints - points;
        geniToken.transfer(msg.sender, reward*TEN_POW_10);

        emit Claimed(msg.sender, currentEpoch, reward, points, pointsPerGENI);
    }

    function _addReferralPoints(uint256 points) private {
        address referrer = geniDex.getReferrer(msg.sender);
        if(referrer != address(0)){
            uint256 refPoints = points * 30 / 100;
            referralPoints[referrer] += refPoints;
            totalUnclaimedRefPoints += refPoints;
        }
    }

    function getRewardSystemInfo() external view returns (
        uint256 epoch,
        uint256 pointsPerGENI,
        uint256 startTime,
        uint256 totalUnlockable,
        uint256 unlockedTokens,
        uint256 distributedTokens,
        uint256 availableTokens,
        uint256 unclaimedPoints,
        uint256 geniBalance
    ) {
        epoch = currentEpoch;
        Epoch memory e = epochs[epoch];
        startTime = e.startTime;
        totalUnlockable = e.totalUnlockable;
        distributedTokens = e.distributedTokens;

        unlockedTokens = _getUnlockedTokens(epoch);
        unclaimedPoints = totalUnclaimedRefPoints + geniDex.getTotalUnclaimedPoints();

        availableTokens = unlockedTokens > distributedTokens ? unlockedTokens - distributedTokens : 0;
        pointsPerGENI = availableTokens > 0 ? BASE_UNIT * unclaimedPoints / availableTokens  : 0;
        geniBalance = geniToken.balanceOf(address(this)) / TEN_POW_10;
    }

    function getUserRewardInfo(address user) external view returns (
        uint256 tradingPoints,
        uint256 refPoints,
        uint256 estimatedReward,
        uint256 totalClaimed,
        uint256 pointsPerGENI
    ) {
        uint256 epoch = currentEpoch;
        Epoch memory e = epochs[epoch];

        uint256 unlockedTokens = _getUnlockedTokens(epoch);
        uint256 distributedTokens = e.distributedTokens;
        uint256 unclaimedPoints = totalUnclaimedRefPoints + geniDex.getTotalUnclaimedPoints();

        refPoints = referralPoints[msg.sender];
        tradingPoints = geniDex.getUserPoints(user);
        uint256 available = unlockedTokens > distributedTokens ? unlockedTokens - distributedTokens : 0;
        pointsPerGENI = available > 0 ? BASE_UNIT * unclaimedPoints / available : 0;

        uint256 userPoints = tradingPoints + refPoints;
        estimatedReward = userPoints * pointsPerGENI / BASE_UNIT;
        totalClaimed = totalClaimedTokens[user];
    }
}