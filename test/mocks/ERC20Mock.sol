// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {}

    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }
}