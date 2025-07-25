// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title IDeviceNFT Interface
/// @notice Interface for the NFT contract used to mint device NFTs
interface IDeviceNFT {
    function mint(address to, string memory deviceId, string memory tokenURI) external returns (uint256);
    function owner() external view returns (address);
    function acceptOwnership() external;
}

/// @title Device Registry Contract
/// @notice Manages registration of devices and mints NFTs for them
/// @dev Devices are keyed by the hash of their deviceId. Accepts only URIs starting with 'bigw://'.
contract DeviceRegistry is Ownable2Step {
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
    /// @param initialOwner Address of the initial owner of this registry
    constructor(address _nftAddress, address initialOwner) Ownable(initialOwner) {
        require(_nftAddress != address(0), "Invalid NFT address");
        nft = IDeviceNFT(_nftAddress);
    }

    /// @notice Accept ownership of the NFT contract (completes Ownable2Step)
    function acceptNFTContractOwnership() external onlyOwner {
        nft.acceptOwnership();
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

    function getDeviceOwner(string memory deviceId) external view returns (address) {
        bytes32 idHash = keccak256(abi.encode(deviceId));
        return devices[idHash].owner;
    }

    function isDeviceRegistered(string memory deviceId) external view returns (bool) {
        bytes32 idHash = keccak256(abi.encode(deviceId));
        return devices[idHash].registered;
    }

    function getDeviceNFT(string memory deviceId) external view returns (uint256) {
        bytes32 idHash = keccak256(abi.encode(deviceId));
        return devices[idHash].nftId;
    }

    function getDevicesByOwner(address user) external view returns (string[] memory) {
        return ownerToDevices[user];
    }

    function getAllRegisteredOwners() external view returns (address[] memory) {
        return registeredOwners;
    }

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
