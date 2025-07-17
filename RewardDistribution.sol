// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Device Registry Interface for Reward Distribution
/// @notice Provides methods to verify and fetch device ownership info
interface IDeviceRegistry {
    /// @notice Returns the owner of a registered device
    /// @param deviceId The unique identifier of the device
    /// @return The address of the device owner
    function getDeviceOwner(string memory deviceId) external view returns (address);

    /// @notice Checks if a device is registered
    /// @param deviceId The unique identifier of the device
    /// @return True if the device is registered, false otherwise
    function isDeviceRegistered(string memory deviceId) external view returns (bool);
}

/// @notice Minimal ERC20 interface for token transfers
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title Reward Distribution Contract for DePIN Scores
/// @author 
/// @notice Manages score submissions and maintains a list of participants for reward distribution
/// @dev Intended to be used by the DePINStaking contract
contract RewardDistribution {
    /// @notice The BWTR token used for rewards
    IERC20 public immutable bwtr;

    /// @notice The device registry used to verify device ownership
    IDeviceRegistry public immutable drc;

    /// @notice Mapping of participant address to their latest score (1–100)
    mapping(address => uint256) public scores;

    /// @notice Tracks whether an address has already been added as a participant
    mapping(address => bool) public isParticipant;

    /// @notice List of all participant addresses with non-zero scores
    address[] public participants;

    /// @notice Emitted when a new score is submitted
    /// @param deviceId The device ID for which the score is submitted
    /// @param owner The owner of the device receiving the score
    /// @param score The submitted score
    event ScoreSubmitted(string deviceId, address indexed owner, uint256 score);

    /// @param _bwtr Address of the BWTR ERC20 token
    /// @param _drc Address of the device registry contract
    constructor(address _bwtr, address _drc) {
        bwtr = IERC20(_bwtr);
        drc = IDeviceRegistry(_drc);
    }

    /// @notice Submit or update the score for a registered device
    /// @dev Links the device to its owner and tracks the owner as a reward participant
    /// @param deviceId The ID of the device being scored
    /// @param score A score between 1 and 100 (inclusive)
    function submitScore(string memory deviceId, uint256 score) external {
        require(score > 0 && score <= 100, "Invalid score");
        require(drc.isDeviceRegistered(deviceId), "Device not registered");

        address owner = drc.getDeviceOwner(deviceId);
        scores[owner] = score;

        if (!isParticipant[owner]) {
            participants.push(owner);
            isParticipant[owner] = true;
        }

        emit ScoreSubmitted(deviceId, owner, score);
    }

    /// @notice Get the current score of a participant
    /// @param owner The participant address
    /// @return The participant's score
    function getScore(address owner) external view returns (uint256) {
        return scores[owner];
    }

    /// @notice Get the list of all participant addresses
    /// @return Array of participant addresses
    function getParticipants() external view returns (address[] memory) {
        return participants;
    }
}
