// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title DePIN Staking Contract for BIGW Tokens
/// @author 
/// @notice Allows users to stake tokens into a shared reward pool and claim yield based on scores
/// @dev Uses external interfaces for ERC20 transfers and dynamic reward distribution logic

/// @notice Minimal interface for an ERC20 token
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @notice Interface for reward distribution scoring logic
interface IRewardDistribution {
    function getScore(address owner) external view returns (uint256);
    function getParticipants() external view returns (address[] memory);
}

/// @notice Contract for staking and reward distribution in a DePIN system
contract DePINStaking {
    /// @notice The ERC20 token used for staking and rewards (e.g., BIGW)
    IERC20 public immutable bwtr;

    /// @notice External contract that provides scores and participant lists
    IRewardDistribution public immutable rdc;

    /// @notice Total amount of tokens currently staked in the pool
    uint256 public totalStaked;

    /// @notice Percentage of the pool emitted each distribution round (e.g., 10 = 10%)
    uint256 public emissionRate;

    /// @notice Accumulated claimable rewards per user
    mapping(address => uint256) public claimableRewards;

    /// @notice Emitted when a user stakes tokens
    event Staked(address indexed from, uint256 amount);

    /// @notice Emitted when yield is allocated during distribution
    event YieldAllocated(uint256 distributed, uint256 timestamp);

    /// @notice Emitted when a user claims rewards
    event YieldClaimed(address indexed user, uint256 amount);

    /// @param _bwtr Address of the ERC20 token contract used for staking
    /// @param _rdc Address of the reward distribution contract
    /// @param _emissionRate Percentage of the pool to emit each round (1-100)
    constructor(address _bwtr, address _rdc, uint256 _emissionRate) {
        require(_bwtr != address(0) && _rdc != address(0), "Invalid addresses");
        require(_emissionRate > 0 && _emissionRate <= 100, "Emission rate must be 1-100");

        bwtr = IERC20(_bwtr);
        rdc = IRewardDistribution(_rdc);
        emissionRate = _emissionRate;
    }

    /// @notice Stake tokens into the shared pool
    /// @param amount Amount of tokens to stake
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(bwtr.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    /// @notice Distribute emissionRate% of the pool to participants proportionally by score
    /// @dev Only callable manually by anyone; uses external score logic from `rdc`
    function distributeRewards() external {
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

    /// @notice Claim accumulated yield rewards
    function claim() external {
        uint256 amount = claimableRewards[msg.sender];
        require(amount > 0, "No rewards");

        claimableRewards[msg.sender] = 0;
        require(bwtr.transfer(msg.sender, amount), "Transfer failed");

        emit YieldClaimed(msg.sender, amount);
    }

    /// @notice Update the emission rate (admin only)
    /// @param rate New emission rate (1-100)
    function updateEmissionRate(uint256 rate) external {
        require(rate > 0 && rate <= 100, "Rate must be 1-100");
        emissionRate = rate;
    }

    /// @notice Get the claimable reward balance for a user
    /// @param user Address to query
    /// @return Amount of claimable reward tokens
    function getClaimable(address user) external view returns (uint256) {
        return claimableRewards[user];
    }
}
