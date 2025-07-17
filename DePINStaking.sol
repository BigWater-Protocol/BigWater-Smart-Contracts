// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IRewardDistribution {
    function getScore(address owner) external view returns (uint256);
    function getParticipants() external view returns (address[] memory);
}

/// @title DePIN Staking Contract for BIGW Token
/// @notice Users stake tokens, and rewards are distributed based on external scoring
/// @dev Includes admin control, pausing, and emergency withdrawals
contract DePINStaking is Ownable, Pausable {
    IERC20 public immutable bwtr;
    IRewardDistribution public immutable rdc;

    uint256 public totalStaked;
    uint256 public emissionRate; // e.g., 10 = 10%

    mapping(address => uint256) public claimableRewards;

    event Staked(address indexed from, uint256 amount);
    event YieldAllocated(uint256 distributed, uint256 timestamp);
    event YieldClaimed(address indexed user, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);
    event EmissionRateUpdated(uint256 newRate);

    /// @param _bwtr Address of BIGW token
    /// @param _rdc Address of reward distribution contract
    /// @param _emissionRate Percentage of total pool to distribute each round
    constructor(address _bwtr, address _rdc, uint256 _emissionRate) {
        require(_bwtr != address(0) && _rdc != address(0), "Invalid addresses");
        require(_emissionRate > 0 && _emissionRate <= 100, "Emission rate must be 1-100");

        bwtr = IERC20(_bwtr);
        rdc = IRewardDistribution(_rdc);
        emissionRate = _emissionRate;
    }

    /// @notice Stake tokens into the reward pool
    /// @param amount Number of tokens to stake
    function stake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be > 0");
        require(bwtr.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    /// @notice Distribute emission to participants based on scores
    function distributeRewards() external whenNotPaused {
        address[] memory participants = rdc.getParticipants();
        require(participants.length > 0, "No participants");

        uint256 totalScore = 0;
        for (uint256 i = 0; i < participants.length; ++i) {
            totalScore += rdc.getScore(participants[i]);
        }
        require(totalScore > 0, "Total score is zero");

        uint256 emission = (totalStaked * emissionRate) / 100;
        for (uint256 i = 0; i < participants.length; ++i) {
            address user = participants[i];
            uint256 score = rdc.getScore(user);
            if (score == 0) continue;

            uint256 reward = (emission * score) / totalScore;
            claimableRewards[user] += reward;
        }

        totalStaked -= emission;
        emit YieldAllocated(emission, block.timestamp);
    }

    /// @notice Claim available rewards
    function claim() external whenNotPaused {
        uint256 amount = claimableRewards[msg.sender];
        require(amount > 0, "No rewards");

        claimableRewards[msg.sender] = 0;
        require(bwtr.transfer(msg.sender, amount), "Transfer failed");

        emit YieldClaimed(msg.sender, amount);
    }

    /// @notice Owner can update emission rate (% of pool per round)
    /// @param rate New emission rate (1–100)
    function updateEmissionRate(uint256 rate) external onlyOwner {
        require(rate > 0 && rate <= 100, "Rate must be 1-100");
        emissionRate = rate;
        emit EmissionRateUpdated(rate);
    }

    /// @notice Pause staking, claims, and distribution
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resume staking and rewards
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Withdraw unallocated tokens from the contract
    /// @param to Address to send the tokens to
    /// @param amount Amount to withdraw
    function withdraw(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(bwtr.transfer(to, amount), "Transfer failed");

        emit Withdrawn(to, amount);
    }

    /// @notice View claimable rewards for a given user
    /// @param user Address to check
    /// @return Amount of reward tokens
    function getClaimable(address user) external view returns (uint256) {
        return claimableRewards[user];
    }
}
