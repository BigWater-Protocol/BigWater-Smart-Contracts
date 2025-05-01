// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IDeviceRegistry {
    function getDeviceOwner(string memory deviceId) external view returns (address);
    function isDeviceRegistered(string memory deviceId) external view returns (bool);
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract RewardDistribution {
    IERC20 public immutable bwtr;
    IDeviceRegistry public immutable drc;

    // reward ledger
    mapping(address => uint256) public scores;
    mapping(address => uint256) public rewards;

    event ScoreSubmitted(string deviceId, address indexed owner, uint256 score);
    event RewardClaimed(address indexed owner, uint256 reward);

    constructor(address _bwtr, address _drc) {
        bwtr = IERC20(_bwtr);
        drc = IDeviceRegistry(_drc);
    }

    /// Called by validator or oracle service
    function submitScore(string memory deviceId, uint256 score) external {
        require(score > 0 && score <= 100, "Invalid score");
        require(drc.isDeviceRegistered(deviceId), "Device not registered");

        address owner = drc.getDeviceOwner(deviceId);
        scores[owner] = score;
        rewards[owner] = score * 1e18;

        emit ScoreSubmitted(deviceId, owner, score);
    }

    function claimRewards(address owner) external {
        uint256 reward = rewards[owner];
        require(reward > 0, "No rewards");

        rewards[owner] = 0;
        require(bwtr.transfer(owner, reward), "Transfer failed");

        emit RewardClaimed(owner, reward);
    }

    function getScore(address owner) external view returns (uint256) {
        return scores[owner];
    }
}
