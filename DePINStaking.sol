// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IRewardDistribution {
    function getScore(address owner) external view returns (uint256);
}

contract DePINStaking {
    IERC20 public immutable bwtr;               // BigWater Token
    IRewardDistribution public immutable rdc;   // RewardDistribution Contract

    mapping(address => uint256) public stakes;
    mapping(address => bool) public hasClaimed;

    event Staked(address indexed user, uint256 amount);
    event YieldClaimed(address indexed user, uint256 reward);

    constructor(address _bwtr, address _rdc) {
        require(_bwtr != address(0) && _rdc != address(0), "Invalid addresses");
        bwtr = IERC20(_bwtr);
        rdc = IRewardDistribution(_rdc);
    }

    /// @notice Stake BigWater tokens
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(bwtr.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        stakes[msg.sender] += amount;

        emit Staked(msg.sender, amount);
    }

    /// @notice Multiplier based on stake amount
    function getStakeMultiplier(address user) public view returns (uint256) {
        uint256 staked = stakes[user];
        if (staked >= 100 ether) return 2e18;     // 2.0x
        if (staked >= 50 ether)  return 15e17;    // 1.5x
        if (staked > 0)          return 1e18;     // 1.0x
        return 0;
    }

    /// @notice Compute yield from base score and multiplier
    function computeYield(address user) public view returns (uint256) {
        uint256 score = rdc.getScore(user);
        uint256 multiplier = getStakeMultiplier(user);
        return (score * 1e18 * multiplier) / 1e36; 
    }

    /// @notice Claim yield in BWTR tokens (only once per cycle)
    function claimStakingYield() external {
        require(!hasClaimed[msg.sender], "Already claimed");
        uint256 reward = computeYield(msg.sender);
        require(reward > 0, "No reward");

        hasClaimed[msg.sender] = true;
        require(bwtr.transfer(msg.sender, reward), "Reward transfer failed");

        emit YieldClaimed(msg.sender, reward);
    }

    /// @notice View total staked for a user
    function getStake(address user) external view returns (uint256) {
        return stakes[user];
    }

    /// @notice Admins can reset claim status (for a new epoch)
    function resetClaimStatus(address user) external {
        // optional access control
        hasClaimed[user] = false;
    }
}
