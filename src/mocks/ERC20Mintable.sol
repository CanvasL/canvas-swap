// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "#/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ERC20Mintable is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {}

    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }
}