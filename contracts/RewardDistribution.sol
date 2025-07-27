// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

/// @title Reward Distribution Contract with Max Participants and Admin-Controlled Submission & Removal
/// @notice Manages reward scoring for devices registered in a device registry and enforces a cap on active participants

/// @notice Interface to interact with the external DeviceRegistry
interface IDeviceRegistry {
    /// @notice Get the owner of a registered device by deviceId
    function getDeviceOwner(string memory deviceId) external view returns (address);

    /// @notice Check if a device is registered by its deviceId
    function isDeviceRegistered(string memory deviceId) external view returns (bool);
}

/// @notice ERC20 token interface used for transferring rewards
interface IERC20 {
    /// @notice Transfer tokens to a recipient
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title RewardDistribution
/// @notice Tracks participant scores and facilitates controlled reward distribution for registered DePIN devices
contract RewardDistribution {
    /// @notice Reward token used for distributing BIGW tokens
    IERC20 public immutable bwtr;

    /// @notice Reference to the device registry used for device ownership validation
    IDeviceRegistry public immutable drc;

    /// @notice Address with administrative permissions to submit scores and manage participants
    address public immutable admin;

    /// @notice Maximum number of active participants allowed
    uint256 public constant MAX_PARTICIPANTS = 200000;

    /// @notice Mapping from participant address to their score
    mapping(address => uint256) public scores;

    /// @notice Mapping to check if an address is an active participant
    mapping(address => bool) public isParticipant;

    /// @notice List of current participants
    address[] public participants;

    /// @notice Emitted when a score is submitted or updated
    /// @param deviceId ID of the device associated with the score
    /// @param owner Owner of the device
    /// @param score Submitted score
    event ScoreSubmitted(string deviceId, address indexed owner, uint256 score);

    /// @notice Emitted when a participant is removed from the rewards list
    /// @param owner Address of the removed participant
    event ParticipantRemoved(address indexed owner);

    /// @notice Restricts function access to the contract admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    /// @notice Initializes the contract with the reward token, device registry, and sets the admin
    /// @param _bwtr Address of the BIGW ERC20 token
    /// @param _drc Address of the deployed DeviceRegistry contract
    constructor(address _bwtr, address _drc) {
        require(_bwtr != address(0) && _drc != address(0), "Invalid address");
        bwtr = IERC20(_bwtr);
        drc = IDeviceRegistry(_drc);
        admin = msg.sender;
    }

    /// @notice Admin submits or updates a score for a device
    /// @dev Registers the device owner as a participant if they aren't already one
    /// @param deviceId The ID of the device being scored
    /// @param score The score to assign (must be 1–100)
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
    /// @dev This operation reduces the participant count and ensures data consistency
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

    /// @notice View the current score of a participant
    /// @param owner Address of the participant
    /// @return The score assigned to the participant
    function getScore(address owner) external view returns (uint256) {
        return scores[owner];
    }

    /// @notice Returns the full list of active reward participants
    /// @return Array of participant addresses
    function getParticipants() external view returns (address[] memory) {
        return participants;
    }
}
