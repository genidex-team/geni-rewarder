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
            distributedInPrevEpochs += epochs[currentEpoch].distributedTokens;
            currentEpoch += 1;
            uint256 currentBalance = geniToken.balanceOf(address(this));
            epochs[currentEpoch].startTime = block.timestamp;
            epochs[currentEpoch].totalUnlockable = currentBalance / 2;
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

    function contribute(uint256 amount) external {
        require(amount > 0, "Zero amount");
        require(geniToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        epochs[currentEpoch].totalUnlockable += amount / 2;
        emit Contributed(msg.sender, amount);
    }

    function claim(uint256 pointsToClaim) external {
        require(pointsToClaim > 0, "Zero points");

        uint256 userPoints = geniDex.getUserPoints(msg.sender);
        require(userPoints >= pointsToClaim, "Not enough user points");

        uint256 totalUnclaimedPoints = totalUnclaimedRefPoints + geniDex.getTotalUnclaimedPoints();
        require(totalUnclaimedPoints >= pointsToClaim, "Not enough unclaimed points");

        _initEpochIfNeeded();
        Epoch storage epoch = epochs[currentEpoch];

        uint256 unlocked = _getUnlockedTokens(currentEpoch);
        require(unlocked > epoch.distributedTokens, "No tokens available");

        uint256 available = unlocked - epoch.distributedTokens;
        uint256 pointsPerGENI = WAD * totalUnclaimedPoints / available;
        // uint256 reward = pointsToClaim / pointsPerGENI;
        uint256 reward = available * pointsToClaim / totalUnclaimedPoints;

        require(reward > 0, "Reward = 0");

        epoch.distributedTokens += reward;
        totalClaimedTokens[msg.sender] += reward;

        geniDex.deductUserPoints(msg.sender, pointsToClaim);
        geniToken.transfer(msg.sender, reward);
        _addReferralPoints(pointsToClaim);

        emit Claimed(msg.sender, currentEpoch, reward, pointsToClaim, pointsPerGENI);
    }

    function redeemReferralPoints(uint256 amount) external {
        require(amount > 0, "Zero points");

        uint256 userPoints = referralPoints[msg.sender];
        require(userPoints >= amount, "Not enough user points");

        uint256 totalUnclaimedPoints = totalUnclaimedRefPoints + geniDex.getTotalUnclaimedPoints();
        require(totalUnclaimedPoints >= amount, "Not enough unclaimed points");

        _initEpochIfNeeded();
        Epoch storage epoch = epochs[currentEpoch];

        uint256 unlocked = _getUnlockedTokens(currentEpoch);
        require(unlocked > epoch.distributedTokens, "No tokens available");

        uint256 available = unlocked - epoch.distributedTokens;
        uint256 pointsPerGENI = WAD * totalUnclaimedPoints / available;
        uint256 reward = available * amount / totalUnclaimedPoints;

        require(reward > 0, "Reward = 0");

        epoch.distributedTokens += reward;
        totalClaimedTokens[msg.sender] += reward;

        referralPoints[msg.sender] = userPoints - amount;
        geniToken.transfer(msg.sender, reward);

        emit Claimed(msg.sender, currentEpoch, reward, amount, pointsPerGENI);
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
        uint256 totalDistributedInPrevEpochs,
        uint256 availableTokens,
        uint256 unclaimedPoints,
        uint256 geniBalance
    ) {
        epoch = currentEpoch;
        Epoch memory e = epochs[epoch];
        startTime = e.startTime;
        totalUnlockable = e.totalUnlockable;
        distributedTokens = e.distributedTokens;
        totalDistributedInPrevEpochs = distributedInPrevEpochs;

        unlockedTokens = _getUnlockedTokens(epoch);
        unclaimedPoints = totalUnclaimedRefPoints + geniDex.getTotalUnclaimedPoints();

        availableTokens = unlockedTokens > distributedTokens ? unlockedTokens - distributedTokens : 0;
        pointsPerGENI = availableTokens > 0 ? WAD * unclaimedPoints / availableTokens  : 0;
        geniBalance = geniToken.balanceOf(address(this));
    }

    function getUserRewardInfo(address user) external view returns (
        uint256 userPoints,
        uint256 estimatedReward,
        uint256 totalClaimed,
        uint256 pointsPerGENI
    ) {
        uint256 epoch = currentEpoch;
        Epoch memory e = epochs[epoch];

        uint256 unlockedTokens = _getUnlockedTokens(epoch);
        uint256 distributedTokens = e.distributedTokens;
        uint256 unclaimedPoints = totalUnclaimedRefPoints + geniDex.getTotalUnclaimedPoints();

        uint256 userPts = geniDex.getUserPoints(user);
        uint256 available = unlockedTokens > distributedTokens ? unlockedTokens - distributedTokens : 0;
        pointsPerGENI = available > 0 ? WAD * unclaimedPoints / available : 0;

        userPoints = userPts;
        estimatedReward = unclaimedPoints > 0 ? userPts * available / unclaimedPoints : 0;
        totalClaimed = totalClaimedTokens[user];
    }
}