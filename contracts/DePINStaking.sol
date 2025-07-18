// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Minimal ERC20 interface used for staking and reward transfers
interface IERC20 {
    /// @notice Transfers tokens from one address to another using allowance
    /// @param sender The address to transfer tokens from
    /// @param recipient The address to transfer tokens to
    /// @param amount The number of tokens to transfer
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /// @notice Transfers tokens from caller's account to another address
    /// @param to The address to receive tokens
    /// @param amount The number of tokens to transfer
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title Interface for external reward scoring system
interface IRewardDistribution {
    /// @notice Returns the score for a given participant
    /// @param owner The participant address
    /// @return The score assigned to the participant
    function getScore(address owner) external view returns (uint256);

    /// @notice Returns a list of all participant addresses
    /// @return Array of participant addresses
    function getParticipants() external view returns (address[] memory);
}

/// @title DePIN Staking Contract with Fixed Emission
/// @author 
/// @notice Allows users to stake tokens and distributes a fixed reward pool based on external scores
/// @dev Emission is fixed per round and distributed according to participant scores from RewardDistribution
contract DePINStaking {
    /// @notice ERC20 token used for staking and reward distribution
    IERC20 public immutable bwtr;

    /// @notice External contract providing participant scores
    IRewardDistribution public immutable rdc;

    /// @notice Total tokens currently staked in the pool
    uint256 public totalStaked;

    /// @notice Fixed reward emission per distribution round (10 BIGW)
    uint256 public constant FIXED_EMISSION = 10 ether;

    /// @notice Emitted when a user stakes tokens
    /// @param from The address staking the tokens
    /// @param amount The amount of tokens staked
    event Staked(address indexed from, uint256 amount);

    /// @notice Emitted when rewards are distributed
    /// @param to The address receiving the reward
    /// @param reward The reward amount transferred
    event YieldDistributed(address indexed to, uint256 reward);

    /// @notice Initializes the contract with token and reward distribution references
    /// @param _bwtr The address of the ERC20 token (BWTR)
    /// @param _rdc The address of the reward distribution contract
    constructor(address _bwtr, address _rdc) {
        require(_bwtr != address(0) && _rdc != address(0), "Invalid addresses");
        bwtr = IERC20(_bwtr);
        rdc = IRewardDistribution(_rdc);
    }

    /// @notice Allows any user to stake tokens into the pool
    /// @param amount The number of tokens to stake
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(bwtr.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    /// @notice Distributes fixed rewards (10 BIGW) to participants based on score share
    /// @dev Reduces `totalStaked` by the emitted reward pool
    function distributeRewards() external {
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
