// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Minimal ERC20 interface used for staking and reward transfers
interface IERC20 {
    /// @notice Transfers tokens from one address to another using allowance
    /// @param sender The address to transfer tokens from
    /// @param recipient The address to transfer tokens to
    /// @param amount The number of tokens to transfer
    /// @return success Whether the transfer was successful
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /// @notice Transfers tokens from the caller to another address
    /// @param to The address to transfer tokens to
    /// @param amount The number of tokens to transfer
    /// @return success Whether the transfer was successful
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title Interface for external reward scoring system
interface IRewardDistribution {
    /// @notice Gets the score for a given participant
    /// @param owner The participant address
    /// @return score The score assigned to the participant
    function getScore(address owner) external view returns (uint256);

    /// @notice Returns a list of all addresses participating in rewards
    /// @return participants An array of addresses participating in the reward distribution
    function getParticipants() external view returns (address[] memory);
}

/// @title DePIN Staking Contract
/// @author 
/// @notice Allows users to stake BWTR tokens and receive fixed emissions based on external scores
/// @dev Uses Ownable for access control. Rewards are distributed by the owner using an external scoring oracle.
contract DePINStaking is Ownable {
    /// @notice ERC20 token used for staking and reward distribution
    IERC20 public immutable bwtr;

    /// @notice External contract that provides participant scores
    IRewardDistribution public immutable rdc;

    /// @notice Total BWTR tokens staked in the contract
    uint256 public totalStaked;

    /// @notice Fixed reward emission per distribution round (10 BIGW)
    uint256 public constant FIXED_EMISSION = 10 ether;

    /// @notice Emitted when a user stakes tokens
    /// @param from The address that staked the tokens
    /// @param amount The amount of tokens staked
    event Staked(address indexed from, uint256 amount);

    /// @notice Emitted when a reward is distributed to a participant
    /// @param to The address receiving the reward
    /// @param reward The amount of reward distributed
    event YieldDistributed(address indexed to, uint256 reward);

    /// @notice Constructor to initialize the staking contract
    /// @param _bwtr Address of the BWTR token
    /// @param _rdc Address of the external reward distribution contract
    constructor(address _bwtr, address _rdc) Ownable(msg.sender) {
        require(_bwtr != address(0) && _rdc != address(0), "Invalid addresses");
        bwtr = IERC20(_bwtr);
        rdc = IRewardDistribution(_rdc);
    }

    /// @notice Allows users to stake BWTR tokens into the pool
    /// @dev Caller must approve this contract to transfer tokens on their behalf
    /// @param amount Amount of BWTR tokens to stake
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(bwtr.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    /// @notice Distributes fixed reward emissions (10 BIGW) to participants based on scores
    /// @dev Only the contract owner can call this. Participants and scores are fetched from the reward distribution contract.
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
