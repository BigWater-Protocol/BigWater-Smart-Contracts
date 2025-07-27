// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.1/contracts/access/Ownable2Step.sol";

/// @title IDeviceNFT Interface
/// @notice Interface for the NFT contract used to mint device NFTs
interface IDeviceNFT {
    /// @notice Mints a device NFT to the specified owner
    /// @param to Address to receive the NFT
    /// @param deviceId Unique identifier of the device
    /// @param tokenURI URI pointing to metadata
    /// @return The ID of the minted NFT
    function mint(address to, string memory deviceId, string memory tokenURI) external returns (uint256);

    /// @notice Returns the current owner of the NFT contract
    function owner() external view returns (address);

    /// @notice Accepts ownership of the NFT contract (used in Ownable2Step)
    function acceptOwnership() external;
}

/// @title Device Registry Contract
/// @notice Manages registration of devices and mints NFTs for them
/// @dev Devices are keyed by the keccak256 hash of their encoded deviceId.
///      Token URIs must start with "bigw://".
contract DeviceRegistry is Ownable2Step {
    /// @notice Struct storing details of a registered device
    struct Device {
        address owner;
        string deviceId;
        bool registered;
        uint256 nftId;
    }

    /// @notice Mapping of device ID hash to device metadata
    mapping(bytes32 => Device) public devices;

    /// @notice Maps user address to list of their registered device IDs
    mapping(address => string[]) public ownerToDevices;

    /// @notice NFT contract used to mint device tokens
    IDeviceNFT public immutable nft;

    /// @notice List of all users who have registered at least one device
    address[] private registeredOwners;

    /// @notice Tracks whether a user is already recorded as a device owner
    mapping(address => bool) private isOwnerRecorded;

    /// @notice Emitted when a new device is registered and NFT is minted
    /// @param owner Address of the device owner
    /// @param deviceId The unique device identifier
    /// @param nftId The NFT ID minted for the device
    event DeviceRegistered(address indexed owner, string deviceId, uint256 nftId);

    /// @notice Constructor to initialize the registry
    /// @param _nftAddress The address of the NFT contract
    /// @param initialOwner Owner of the registry contract
    constructor(address _nftAddress, address initialOwner) Ownable(initialOwner) {
        require(_nftAddress != address(0), "Invalid NFT address");
        nft = IDeviceNFT(_nftAddress);
    }

    /// @notice Accepts ownership of the NFT contract
    /// @dev Caller must be the contract owner
    function acceptNFTContractOwnership() external onlyOwner {
        nft.acceptOwnership();
    }

    /// @notice Registers a new device and mints a corresponding NFT
    /// @param owner Address of the device owner
    /// @param deviceId Unique string identifier of the device
    /// @param tokenURI URI pointing to the device metadata (must start with `bigw://`)
    function registerDevice(address owner, string memory deviceId, string memory tokenURI) public {
        require(owner != address(0), "Invalid owner");
        require(bytes(deviceId).length > 0, "Empty deviceId");
        require(bytes(tokenURI).length > 0, "Empty tokenURI");
        require(_isValidURI(tokenURI), "URI must start with 'bigw://'");
        require(nft.owner() == address(this), "Registry must own NFT contract");

        bytes32 idHash = keccak256(abi.encode(deviceId));
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

    /// @notice Registers multiple devices in a single call
    /// @param owners List of device owner addresses
    /// @param deviceIds List of corresponding device IDs
    /// @param tokenURIs List of corresponding metadata URIs
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

    /// @notice Get the owner of a registered device
    /// @param deviceId Device ID to look up
    /// @return The address of the device owner
    function getDeviceOwner(string memory deviceId) external view returns (address) {
        bytes32 idHash = keccak256(abi.encode(deviceId));
        return devices[idHash].owner;
    }

    /// @notice Check whether a device is registered
    /// @param deviceId Device ID to check
    /// @return True if the device is registered, false otherwise
    function isDeviceRegistered(string memory deviceId) external view returns (bool) {
        bytes32 idHash = keccak256(abi.encode(deviceId));
        return devices[idHash].registered;
    }

    /// @notice Get the NFT ID associated with a registered device
    /// @param deviceId Device ID to query
    /// @return The NFT token ID
    function getDeviceNFT(string memory deviceId) external view returns (uint256) {
        bytes32 idHash = keccak256(abi.encode(deviceId));
        return devices[idHash].nftId;
    }

    /// @notice Get all device IDs registered by a given user
    /// @param user Address of the user
    /// @return List of device IDs owned by the user
    function getDevicesByOwner(address user) external view returns (string[] memory) {
        return ownerToDevices[user];
    }

    /// @notice Returns the list of all unique registered owners
    /// @return List of addresses who have registered devices
    function getAllRegisteredOwners() external view returns (address[] memory) {
        return registeredOwners;
    }

    /// @notice Internal helper to validate token URI format
    /// @param uri URI string to validate
    /// @return valid True if the URI starts with `bigw://`, false otherwise
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
