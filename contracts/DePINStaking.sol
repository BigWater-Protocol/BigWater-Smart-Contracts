// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title ERC20 Interface
/// @notice Minimal ERC20 interface for staking and reward transfer
interface IERC20 {
    /// @notice Transfer tokens from a sender to a recipient
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /// @notice Transfer tokens from this contract to a recipient
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title RewardDistribution Interface
/// @notice Interface for reading scores and participants in the reward program
interface IRewardDistribution {
    /// @notice Get the performance score for a specific user
    function getScore(address owner) external view returns (uint256);

    /// @notice Get the list of all participants eligible for rewards
    function getParticipants() external view returns (address[] memory);
}

/// @title DePINStaking
/// @notice Handles staking of BIGW tokens and distributes rewards based on scores
/// @dev Uses a fixed emission reward model distributed proportionally to scores from IRewardDistribution
contract DePINStaking is Ownable2Step {
    /// @notice The BIGW token used for staking and rewards
    IERC20 public immutable bwtr;

    /// @notice The external reward contract that tracks scores and participants
    IRewardDistribution public immutable rdc;

    /// @notice Total amount of BIGW tokens currently staked
    uint256 public totalStaked;

    /// @notice Fixed amount of BIGW emitted per reward cycle
    uint256 public constant FIXED_EMISSION = 10**16;

    /// @notice Emitted when a user stakes BIGW tokens
    /// @param from The staker's address
    /// @param amount The amount of tokens staked
    event Staked(address indexed from, uint256 amount);

    /// @notice Emitted when rewards are distributed to a user
    /// @param to The recipient of the reward
    /// @param reward The amount of BIGW tokens distributed
    event YieldDistributed(address indexed to, uint256 reward);

    /// @notice Initializes the staking contract
    /// @param _bwtr Address of the BIGW token contract
    /// @param _rdc Address of the reward distribution contract
    /// @param initialOwner Address of the contract owner
    constructor(address _bwtr, address _rdc, address initialOwner)
        Ownable(initialOwner) 
    {
        require(_bwtr != address(0) && _rdc != address(0), "Invalid addresses");
        bwtr = IERC20(_bwtr);
        rdc = IRewardDistribution(_rdc);
    }

    /// @notice Stake BIGW tokens into the contract
    /// @dev Requires prior approval for the transfer
    /// @param amount Amount of BIGW tokens to stake
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(bwtr.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    /// @notice Distribute rewards proportionally based on scores
    /// @dev Can only be called by the contract owner
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
