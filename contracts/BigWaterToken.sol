// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title BigWater Token Contract
/// @author 
/// @notice ERC20 token with capped supply, owner-only minting, and public burning
/// @dev Inherits from OpenZeppelin's ERC20 and Ownable
contract BigWaterToken is ERC20, Ownable {
    /// @notice Tracks the total amount of tokens burned by users
    uint256 public totalBurned;

    /// @notice Maximum cap on total token supply
    uint256 public immutable cap;

    /// @notice Deploys the token contract with an initial supply and supply cap
    /// @param initialSupply The number of tokens to mint on deployment
    /// @param maxCap The maximum supply limit for the token
    constructor(address recipient, uint256 initialSupply, uint256 maxCap) 
    ERC20("BigWater Token", "BIGW") 
    Ownable(msg.sender) 
    {
        require(initialSupply <= maxCap, "Initial exceeds cap");
        _mint(recipient, initialSupply);
        cap = maxCap;
    }

    /// @notice Mints new tokens to a specified address
    /// @dev Only callable by the contract owner
    /// @param to The address to receive the newly minted tokens
    /// @param amount The number of tokens to mint
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= cap, "Cap exceeded");
        _mint(to, amount);
    }

    /// @notice Burns tokens from the caller’s balance
    /// @param amount The number of tokens to burn
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        totalBurned += amount;
    }
}
