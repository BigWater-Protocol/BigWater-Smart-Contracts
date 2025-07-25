// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IDeviceNFT Interface
/// @notice Interface for the NFT contract used to mint device NFTs
interface IDeviceNFT {
    /// @notice Mints a new NFT for a device
    /// @param to The address receiving the NFT
    /// @param deviceId The unique string identifier of the device
    /// @param tokenURI The metadata URI of the device NFT
    /// @return The ID of the newly minted NFT
    function mint(address to, string memory deviceId, string memory tokenURI) external returns (uint256);
}

/// @title Device Registry Contract
/// @notice Manages registration of devices and mints NFTs for them
/// @dev Devices are keyed by the hash of their deviceId. Accepts only URIs starting with 'bigw://'.
contract DeviceRegistry {
    struct Device {
        address owner;
        string deviceId;
        bool registered;
        uint256 nftId;
    }

    mapping(bytes32 => Device) public devices;
    mapping(address => string[]) public ownerToDevices;

    IDeviceNFT public immutable nft;

    address[] private registeredOwners;
    mapping(address => bool) private isOwnerRecorded;

    event DeviceRegistered(address indexed owner, string deviceId, uint256 nftId);

    /// @notice Initializes the registry with the NFT contract address
    /// @param _nftAddress Address of the NFT contract
    constructor(address _nftAddress) {
        require(_nftAddress != address(0), "Invalid NFT address");
        nft = IDeviceNFT(_nftAddress);
    }

    /// @notice Registers a new device and mints an NFT
    /// @param owner Address of the device owner
    /// @param deviceId Unique identifier for the device
    /// @param tokenURI Metadata URI for the device NFT; must begin with 'bigw://'
    function registerDevice(address owner, string memory deviceId, string memory tokenURI) public {
        require(owner != address(0), "Invalid owner");
        require(bytes(deviceId).length > 0, "Empty deviceId");
        require(bytes(tokenURI).length > 0, "Empty tokenURI");
        require(_isValidURI(tokenURI), "URI must start with 'bigw://'");

        bytes32 idHash = keccak256(abi.encodePacked(deviceId));
        require(!devices[idHash].registered, "Already registered");

        uint256 nftId = nft.mint(owner, deviceId, tokenURI);
        require(nftId > 0, "Mint failed");

        devices[idHash] = Device({
            owner: owner,
            deviceId: deviceId,
            registered: true,
            nftId: nftId
        });

        ownerToDevices[owner].push(deviceId);

        if (!isOwnerRecorded[owner]) {
            isOwnerRecorded[owner] = true;
            registeredOwners.push(owner);
        }

        emit DeviceRegistered(owner, deviceId, nftId);
    }

    /// @notice Batch registers multiple devices
    /// @param owners Array of owner addresses
    /// @param deviceIds Array of device identifiers
    /// @param tokenURIs Array of metadata URIs
    function batchRegisterDevices(
        address[] calldata owners,
        string[] calldata deviceIds,
        string[] calldata tokenURIs
    ) external {
        require(
            owners.length == deviceIds.length && deviceIds.length == tokenURIs.length,
            "Input lengths mismatch"
        );

        for (uint256 i = 0; i < owners.length; ++i) {
            registerDevice(owners[i], deviceIds[i], tokenURIs[i]);
        }
    }

    /// @notice Gets the owner of a device
    /// @param deviceId The device ID
    /// @return The address of the owner
    function getDeviceOwner(string memory deviceId) external view returns (address) {
        bytes32 idHash = keccak256(abi.encodePacked(deviceId));
        return devices[idHash].owner;
    }

    /// @notice Checks if a device is registered
    /// @param deviceId The device ID
    /// @return True if registered
    function isDeviceRegistered(string memory deviceId) external view returns (bool) {
        bytes32 idHash = keccak256(abi.encodePacked(deviceId));
        return devices[idHash].registered;
    }

    /// @notice Gets the NFT ID for a device
    /// @param deviceId The device ID
    /// @return The NFT ID
    function getDeviceNFT(string memory deviceId) external view returns (uint256) {
        bytes32 idHash = keccak256(abi.encodePacked(deviceId));
        return devices[idHash].nftId;
    }

    /// @notice Gets all device IDs registered by a user
    /// @param user The owner's address
    /// @return An array of device IDs
    function getDevicesByOwner(address user) external view returns (string[] memory) {
        return ownerToDevices[user];
    }

    /// @notice Gets all registered owner addresses
    /// @return An array of addresses
    function getAllRegisteredOwners() external view returns (address[] memory) {
        return registeredOwners;
    }

    /// @dev Internal helper to check that tokenURI starts with 'bigw://'
    /// @param uri The tokenURI string
    /// @return valid True if valid
    function _isValidURI(string memory uri) internal pure returns (bool valid) {
        bytes memory b = bytes(uri);
        return b.length >= 7 &&
            b[0] == 'b' &&
            b[1] == 'i' &&
            b[2] == 'g' &&
            b[3] == 'w' &&
            b[4] == ':' &&
            b[5] == '/' &&
            b[6] == '/';
    }
}
