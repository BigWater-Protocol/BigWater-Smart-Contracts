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
/// @author 
/// @notice Manages registration of devices and mints NFTs for them
/// @dev Uses a hash of the device ID as the key in the registry
contract DeviceRegistry {
    /// @notice Struct representing a registered device
    struct Device {
        address owner;
        string deviceId;
        bool registered;
        uint256 nftId;
    }

    /// @notice Mapping of deviceId hash to Device info
    mapping(bytes32 => Device) public devices;

    /// @notice Mapping of owner to list of their device IDs
    mapping(address => string[]) public ownerToDevices;

    /// @notice Immutable reference to the external NFT contract
    IDeviceNFT public immutable nft;

    /// @notice Emitted when a device is successfully registered and an NFT is minted
    /// @param owner The address of the device owner
    /// @param deviceId The string identifier of the device
    /// @param nftId The ID of the minted NFT
    event DeviceRegistered(address indexed owner, string deviceId, uint256 nftId);

    /// @notice Initializes the DeviceRegistry contract
    /// @param _nftAddress Address of the IDeviceNFT-compatible contract
    constructor(address _nftAddress) {
        require(_nftAddress != address(0), "Invalid NFT address");
        nft = IDeviceNFT(_nftAddress);
    }

    /// @notice Registers a new device and mints an NFT for it
    /// @param owner Address of the device owner
    /// @param deviceId Unique string identifier for the device
    /// @param tokenURI Metadata URI for the device NFT
    function registerDevice(address owner, string memory deviceId, string memory tokenURI) public {
        require(owner != address(0), "Invalid owner");
        require(bytes(deviceId).length > 0, "Empty deviceId");
        require(bytes(tokenURI).length > 0, "Empty tokenURI");

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

        emit DeviceRegistered(owner, deviceId, nftId);
    }

    /// @notice Registers multiple devices in a batch
    /// @param owners Array of device owner addresses
    /// @param deviceIds Array of device identifiers
    /// @param tokenURIs Array of metadata URIs for each device NFT
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

    /// @notice Gets the owner address of a registered device
    /// @param deviceId The identifier of the device
    /// @return The address of the device owner
    function getDeviceOwner(string memory deviceId) external view returns (address) {
        bytes32 idHash = keccak256(abi.encodePacked(deviceId));
        return devices[idHash].owner;
    }

    /// @notice Checks if a device is registered
    /// @param deviceId The identifier of the device
    /// @return True if the device is registered, otherwise false
    function isDeviceRegistered(string memory deviceId) external view returns (bool) {
        bytes32 idHash = keccak256(abi.encodePacked(deviceId));
        return devices[idHash].registered;
    }

    /// @notice Gets the NFT ID associated with a registered device
    /// @param deviceId The identifier of the device
    /// @return The ID of the NFT representing the device
    function getDeviceNFT(string memory deviceId) external view returns (uint256) {
        bytes32 idHash = keccak256(abi.encodePacked(deviceId));
        return devices[idHash].nftId;
    }

    /// @notice Retrieves all device IDs registered by a specific owner
    /// @param user The address of the device owner
    /// @return An array of device identifiers
    function getDevicesByOwner(address user) external view returns (string[] memory) {
        return ownerToDevices[user];
    }
}
