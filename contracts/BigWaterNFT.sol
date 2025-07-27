// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.1/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.1/contracts/access/Ownable2Step.sol";

/// @title BigWater Device NFT Contract
/// @notice ERC721 contract for minting NFTs representing registered devices
/// @dev Uses ERC721URIStorage to store metadata URIs; only the owner can mint
contract BigWaterDeviceNFT is ERC721URIStorage, Ownable2Step {
    /// @notice Counter for generating unique token IDs
    uint256 private nextId = 1;

    /// @notice Maps a deviceId string to its corresponding NFT tokenId
    mapping(string => uint256) public deviceIdToTokenId;

    /// @notice Maps an NFT tokenId back to its associated deviceId string
    mapping(uint256 => string) public tokenIdToDeviceId;

    /// @notice Deploys the BigWaterDeviceNFT contract with name and symbol
    constructor(address initialOwner)
        ERC721("BigWater Device NFT", "BWDN")
        Ownable(initialOwner)
    {}

    /// @notice Mints a new NFT to represent a device
    /// @dev Only callable by the contract owner
    /// @param to Address that will receive the NFT
    /// @param deviceId Unique identifier of the device being registered
    /// @param tokenURI Metadata URI for the NFT
    /// @return tokenId The unique identifier of the minted NFT
    function mint(address to, string memory deviceId, string memory tokenURI)
        external
        onlyOwner
        returns (uint256)
    {
        require(deviceIdToTokenId[deviceId] == 0, "Already minted");

        uint256 tokenId = nextId++;
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);

        deviceIdToTokenId[deviceId] = tokenId;
        tokenIdToDeviceId[tokenId] = deviceId;

        return tokenId;
    }

    /// @notice Returns the deviceId associated with a given tokenId
    function getDeviceId(uint256 tokenId) external view returns (string memory) {
        return tokenIdToDeviceId[tokenId];
    }

    /// @notice Returns the tokenId associated with a given deviceId
    function getTokenId(string memory deviceId) external view returns (uint256) {
        return deviceIdToTokenId[deviceId];
    }
}
