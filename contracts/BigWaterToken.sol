// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title BigWater Token Contract
/// @notice ERC20 token with capped supply, owner-only minting, and public burning
/// @dev Uses OpenZeppelin's ERC20 and Ownable2Step for secure ownership management
contract BigWaterToken is ERC20, Ownable2Step {
    /// @notice Tracks the total amount of tokens burned by users
    uint256 public totalBurned;

    /// @notice Maximum cap on total token supply
    uint256 public immutable cap;

    /// @notice Deploys the token contract with an initial supply and supply cap
    /// @param recipient Address that receives the initial supply and becomes initial owner
    /// @param initialSupply Amount of tokens to mint at deployment
    /// @param maxCap Maximum supply of the token
    constructor(address recipient, uint256 initialSupply, uint256 maxCap) 
        ERC20("BigWater Token", "BIGW") 
        Ownable(recipient) 
    {
        require(initialSupply <= maxCap, "Initial exceeds cap");
        _mint(recipient, initialSupply);
        cap = maxCap;
    }

    /// @notice Mints new tokens to a specified address (owner-only)
    /// @param to Address to receive minted tokens
    /// @param amount Number of tokens to mint
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= cap, "Cap exceeded");
        _mint(to, amount);
    }

    /// @notice Burns tokens from sender’s balance
    /// @param amount Amount to burn
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        totalBurned += amount;
    }
}
