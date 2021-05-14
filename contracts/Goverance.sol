// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ShitToken is ERC20{
    
    using Address for address;
    
    address public governance;
    mapping (address => bool) public shitTokens;
    mapping (address => address) public bridges;
    
    address[] public shitTokenList;
    
    constructor(uint256 initialSupply) ERC20("ShitPlanet","SHIT"){
        governance = tx.origin;
        _mint(msg.sender, initialSupply);
    }
    
    function addShitToken(address tokenAddress, address bridge) public {
      require(msg.sender == governance, "!governance");
      shitTokens[tokenAddress] = true;
      bridges[tokenAddress] = bridge;
      shitTokenList.push(tokenAddress);
    }
    
    function getShitTokenList() public view returns(address[] memory) {
      return shitTokenList;
    }
    
    function getBridgeToken(address tokenAddress) public view returns(address) {
      return bridges[tokenAddress];
    }
    
    function removeShitToken(address tokenAddress) public {
      require(msg.sender == governance, "!governance");
      shitTokens[tokenAddress] = false;
      bridges[tokenAddress] = address(0);
    }
    
    function isShitToken(address tokenAddress) public view returns (bool) {
      return shitTokens[tokenAddress];
    }
    
    function setGovernance(address _governance) public {
      require(msg.sender == governance, "!governance");
      governance = _governance;
    }

}