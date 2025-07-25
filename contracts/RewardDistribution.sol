// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Reward Distribution Contract with Max Participants and Admin-Controlled Submission & Removal
/// @notice Manages reward scoring for devices registered in a device registry and enforces a cap on active participants

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
    address public immutable admin;

    uint256 public constant MAX_PARTICIPANTS = 200000;

    mapping(address => uint256) public scores;
    mapping(address => bool) public isParticipant;
    address[] public participants;

    event ScoreSubmitted(string deviceId, address indexed owner, uint256 score);
    event ParticipantRemoved(address indexed owner);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor(address _bwtr, address _drc) {
        require(_bwtr != address(0) && _drc != address(0), "Invalid address");
        bwtr = IERC20(_bwtr);
        drc = IDeviceRegistry(_drc);
        admin = msg.sender;
    }

    /// @notice Admin submits or updates a score for a device
    /// @param deviceId The ID of the device being scored
    /// @param score The score to assign (1–100)
    function submitScore(string memory deviceId, uint256 score) external onlyAdmin {
        require(score > 0 && score <= 100, "Invalid score");
        require(drc.isDeviceRegistered(deviceId), "Device not registered");

        address owner = drc.getDeviceOwner(deviceId);

        if (!isParticipant[owner]) {
            require(participants.length < MAX_PARTICIPANTS, "Max participants reached");
            participants.push(owner);
            isParticipant[owner] = true;
        }

        scores[owner] = score;
        emit ScoreSubmitted(deviceId, owner, score);
    }

    /// @notice Admin removes a participant and resets their score
    /// @param addr Address of the participant to remove
    function removeParticipant(address addr) external onlyAdmin {
        require(isParticipant[addr], "Not a participant");

        isParticipant[addr] = false;
        scores[addr] = 0;

        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] == addr) {
                participants[i] = participants[participants.length - 1];
                participants.pop();
                emit ParticipantRemoved(addr);
                break;
            }
        }
    }

    function getScore(address owner) external view returns (uint256) {
        return scores[owner];
    }

    function getParticipants() external view returns (address[] memory) {
        return participants;
    }
}
