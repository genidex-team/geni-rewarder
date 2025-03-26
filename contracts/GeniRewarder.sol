// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IGeniDex {
    function getUserPoints(address user) external view returns (uint256);
    function getTotalUnclaimedPoints() external view returns (uint256);
    function deductUserPoints(address user, uint256 pointsToDeduct) external;
}

contract GeniRewarder is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    IERC20 public geniToken;
    IGeniDex public geniDex;

    uint256 public constant EPOCH_DURATION = 365 days;
    uint256 public constant UNLOCK_INTERVAL = 60;

    uint256 public currentEpoch;
    uint256 public totalDistributedTokens;

    struct Epoch {
        uint256 startTime;
        uint256 totalUnlockable;
        uint256 totalDistributedTokens;
    }


    mapping(uint256 => Epoch) public epochs;
    mapping(address => uint256) public totalClaimedTokens;

    event Claimed(address indexed user, uint256 epoch, uint256 reward, uint256 pointsUsed, uint256 tokenPerPoint);
    event Contributed(address indexed from, uint256 amount);
    event EpochStarted(uint256 epoch, uint256 startTime);
    event EpochEnded(uint256 epoch);

    function initialize(address initialOwner, address _token, address _geniDex) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        geniToken = IERC20(_token);
        geniDex = IGeniDex(_geniDex);

        currentEpoch = 0;
        epochs[0].startTime = block.timestamp;
        epochs[0].totalUnlockable = geniToken.balanceOf(address(this)) / 2;
        epochs[0].totalDistributedTokens = 0;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _initEpochIfNeeded() internal {
        if (block.timestamp >= epochs[currentEpoch].startTime + EPOCH_DURATION) {
            emit EpochEnded(currentEpoch);

            currentEpoch += 1;
            uint256 currentBalance = geniToken.balanceOf(address(this));
            epochs[currentEpoch].startTime = block.timestamp;
            epochs[currentEpoch].totalUnlockable = currentBalance / 2;
            epochs[currentEpoch].totalDistributedTokens = 0;

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

        uint256 totalUnclaimedPoints = geniDex.getTotalUnclaimedPoints();
        require(totalUnclaimedPoints >= pointsToClaim, "Not enough unclaimed points");

        _initEpochIfNeeded();
        Epoch storage epoch = epochs[currentEpoch];

        uint256 unlocked = _getUnlockedTokens(currentEpoch);
        require(unlocked > epoch.totalDistributedTokens, "No tokens available");

        uint256 available = unlocked - epoch.totalDistributedTokens;
        uint256 tokenPerPoint = available / totalUnclaimedPoints;
        uint256 reward = pointsToClaim * tokenPerPoint;

        require(reward > 0, "Reward = 0");

        epoch.totalDistributedTokens += reward;
        totalDistributedTokens += reward;
        totalClaimedTokens[msg.sender] += reward;

        geniDex.deductUserPoints(msg.sender, pointsToClaim);
        geniToken.transfer(msg.sender, reward);

        emit Claimed(msg.sender, currentEpoch, reward, pointsToClaim, tokenPerPoint);
    }

    function getRewardSystemInfo() external view returns (
        uint256 epoch,
        uint256 unlockedTokens,
        uint256 distributedTokens,
        uint256 unclaimedPoints,
        uint256 tokenPerPoint
    ) {
        epoch = currentEpoch;
        Epoch memory e = epochs[epoch];

        unlockedTokens = _getUnlockedTokens(epoch);
        distributedTokens = e.totalDistributedTokens;

        unclaimedPoints = geniDex.getTotalUnclaimedPoints();

        uint256 available = unlockedTokens > distributedTokens ? unlockedTokens - distributedTokens : 0;
        tokenPerPoint = unclaimedPoints > 0 ? available / unclaimedPoints : 0;
    }

    function getUserRewardInfo(address user) external view returns (
        uint256 userPoints,
        uint256 estimatedReward,
        uint256 totalClaimed
    ) {
        uint256 epoch = currentEpoch;
        Epoch memory e = epochs[epoch];

        uint256 unlockedTokens = _getUnlockedTokens(epoch);
        uint256 distributedTokens = e.totalDistributedTokens;
        uint256 unclaimedPoints = geniDex.getTotalUnclaimedPoints();

        uint256 userPts = geniDex.getUserPoints(user);
        uint256 available = unlockedTokens > distributedTokens ? unlockedTokens - distributedTokens : 0;
        uint256 tokenPerPoint = unclaimedPoints > 0 ? available / unclaimedPoints : 0;

        userPoints = userPts;
        estimatedReward = userPts * tokenPerPoint;
        totalClaimed = totalClaimedTokens[user];
    }
}