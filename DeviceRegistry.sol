// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IDeviceNFT {
    function mint(address to, string memory deviceId, string memory tokenURI) external returns (uint256);
}

contract DeviceRegistry {
    struct Device {
        address owner;
        string deviceId;
        bool registered;
        uint256 nftId;
    }

    mapping(bytes32 => Device) public devices;
    IDeviceNFT public immutable nft;

    event DeviceRegistered(address indexed owner, string deviceId, uint256 nftId);

    constructor(address _nftAddress) {
        require(_nftAddress != address(0), "Invalid NFT address");
        nft = IDeviceNFT(_nftAddress);
    }

    /// @notice Register device and mint NFT
    function registerDevice(address owner, string memory deviceId, string memory tokenURI) external {
        require(owner != address(0), "Invalid owner");
        bytes32 idHash = keccak256(abi.encodePacked(deviceId));
        require(!devices[idHash].registered, "Already registered");

        // Mint NFT to owner with tokenURI
        uint256 nftId = nft.mint(owner, deviceId, tokenURI);

        devices[idHash] = Device({
            owner: owner,
            deviceId: deviceId,
            registered: true,
            nftId: nftId
        });

        emit DeviceRegistered(owner, deviceId, nftId);
    }

    function getDeviceOwner(string memory deviceId) external view returns (address) {
        bytes32 idHash = keccak256(abi.encodePacked(deviceId));
        return devices[idHash].owner;
    }

    function isDeviceRegistered(string memory deviceId) external view returns (bool) {
        bytes32 idHash = keccak256(abi.encodePacked(deviceId));
        return devices[idHash].registered;
    }

    function getDeviceNFT(string memory deviceId) external view returns (uint256) {
        bytes32 idHash = keccak256(abi.encodePacked(deviceId));
        return devices[idHash].nftId;
    }
}
