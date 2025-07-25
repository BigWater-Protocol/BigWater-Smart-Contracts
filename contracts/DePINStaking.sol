// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IRewardDistribution {
    function getScore(address owner) external view returns (uint256);
    function getParticipants() external view returns (address[] memory);
}

contract DePINStaking is Ownable2Step {
    IERC20 public immutable bwtr;
    IRewardDistribution public immutable rdc;

    uint256 public totalStaked;
    uint256 public constant FIXED_EMISSION = 10 ether;

    event Staked(address indexed from, uint256 amount);
    event YieldDistributed(address indexed to, uint256 reward);

    constructor(address _bwtr, address _rdc, address initialOwner)
        Ownable(initialOwner) 
    {
        require(_bwtr != address(0) && _rdc != address(0), "Invalid addresses");
        bwtr = IERC20(_bwtr);
        rdc = IRewardDistribution(_rdc);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(bwtr.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function distributeRewards() external onlyOwner {
        address[] memory participants = rdc.getParticipants();
        require(participants.length > 0, "No participants");

        uint256 totalScore = 0;
        for (uint256 i = 0; i < participants.length; i++) {
            totalScore += rdc.getScore(participants[i]);
        }

        require(totalScore > 0, "Total score is zero");
        require(totalStaked >= FIXED_EMISSION, "Insufficient pool");

        for (uint256 i = 0; i < participants.length; i++) {
            address user = participants[i];
            uint256 score = rdc.getScore(user);
            if (score == 0) continue;

            uint256 reward = (FIXED_EMISSION * score) / totalScore;
            require(bwtr.transfer(user, reward), "Transfer failed");
            emit YieldDistributed(user, reward);
        }

        totalStaked -= FIXED_EMISSION;
    }
}
