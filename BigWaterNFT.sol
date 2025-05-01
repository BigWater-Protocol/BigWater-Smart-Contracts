// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BigWaterDeviceNFT is ERC721URIStorage, Ownable {
    uint256 private nextId = 1;

    mapping(string => uint256) public deviceIdToTokenId;
    mapping(uint256 => string) public tokenIdToDeviceId;

    constructor() ERC721("BigWater Device NFT", "BWDN") Ownable(msg.sender) {}

    /// @notice Mint a new NFT to represent a registered device
    function mint(address to, string memory deviceId, string memory tokenURI) external onlyOwner returns (uint256) {
        require(deviceIdToTokenId[deviceId] == 0, "Already minted");

        uint256 tokenId = nextId++;
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);

        deviceIdToTokenId[deviceId] = tokenId;
        tokenIdToDeviceId[tokenId] = deviceId;

        return tokenId;
    }

    function getDeviceId(uint256 tokenId) external view returns (string memory) {
        return tokenIdToDeviceId[tokenId];
    }

    function getTokenId(string memory deviceId) external view returns (uint256) {
        return deviceIdToTokenId[deviceId];
    }
}
