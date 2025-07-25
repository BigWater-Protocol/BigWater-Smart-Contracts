// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Reward Distribution Contract with Max Participants and Admin-Controlled Removal
/// @notice Manages reward scoring for devices registered in a device registry and enforces a cap on active participants
/// @dev Designed to prevent Denial-of-Service risk by capping the participant list length

/// @notice Interface for interacting with the Device Registry to validate and resolve device ownership
interface IDeviceRegistry {
    function getDeviceOwner(string memory deviceId) external view returns (address);
    function isDeviceRegistered(string memory deviceId) external view returns (bool);
}

/// @notice Minimal interface for ERC20 tokens used for internal transfers (not used directly in this contract)
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract RewardDistribution {
    /// @notice Address of the BWTR token used for rewards (not used directly in this contract)
    IERC20 public immutable bwtr;

    /// @notice Address of the external device registry
    IDeviceRegistry public immutable drc;

    /// @notice Administrator address with permission to remove participants
    address public immutable admin;

    /// @notice Maximum number of unique participants allowed
    uint256 public constant MAX_PARTICIPANTS = 200000;

    /// @notice Mapping of participant address to their latest submitted score
    mapping(address => uint256) public scores;

    /// @notice Tracks if an address is currently a participant
    mapping(address => bool) public isParticipant;

    /// @notice List of all participant addresses
    address[] public participants;

    /// @notice Emitted when a score is submitted or updated
    /// @param deviceId The ID of the device being scored
    /// @param owner The resolved owner of the device
    /// @param score The score submitted (1–100)
    event ScoreSubmitted(string deviceId, address indexed owner, uint256 score);

    /// @notice Emitted when a participant is removed by the admin
    /// @param owner The address of the removed participant
    event ParticipantRemoved(address indexed owner);

    /// @notice Restricts function access to only the admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    /// @param _bwtr Address of the BWTR token (unused internally but stored for future-proofing)
    /// @param _drc Address of the Device Registry contract
    constructor(address _bwtr, address _drc) {
        require(_bwtr != address(0) && _drc != address(0), "Invalid address");
        bwtr = IERC20(_bwtr);
        drc = IDeviceRegistry(_drc);
        admin = msg.sender;
    }

    /// @notice Submit or update a score for a device
    /// @dev Automatically adds the device owner to the participant list if not already included
    /// @param deviceId The ID of the device being scored
    /// @param score The score to assign (must be in range 1–100)
    function submitScore(string memory deviceId, uint256 score) external {
        require(score > 0 && score <= 100, "Invalid score");
        require(drc.isDeviceRegistered(deviceId), "Device not registered");

        address owner = drc.getDeviceOwner(deviceId);

        // Add to participant list if not present
        if (!isParticipant[owner]) {
            require(participants.length < MAX_PARTICIPANTS, "Max participants reached");
            participants.push(owner);
            isParticipant[owner] = true;
        }

        scores[owner] = score;
        emit ScoreSubmitted(deviceId, owner, score);
    }

    /// @notice Removes a participant and resets their score
    /// @dev Can only be called by the admin. Swaps with the last element and pops to save gas.
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

    /// @notice Retrieves the latest score of a given participant
    /// @param owner The address of the participant
    /// @return The current score associated with the address
    function getScore(address owner) external view returns (uint256) {
        return scores[owner];
    }

    /// @notice Returns the full list of current participants
    /// @return An array of participant addresses
    function getParticipants() external view returns (address[] memory) {
        return participants;
    }
}
