// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {LPToken} from "./LPToken.sol";

contract LPTokenFactory {
    error IdenticalTokenAddresses();
    error ZeroAddress();
    error LPTokenAlreadyExists();

    event LPTokenCreated(address indexed token0, address indexed token1, address indexed lpToken, uint256 lpTokensLength);

    mapping(address => mapping(address => address)) internal _lpTokenByPair;
    address[] internal _lpTokens;

    function getLPTokenByPair(address tokenA, address tokenB) public view returns (address) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return _lpTokenByPair[token0][token1];
    }

    function getLPTokens() public view returns (address[] memory) {
        return _lpTokens;
    }

    function createLPToken(address tokenA, address tokenB) public returns (address) {
        if(tokenA == tokenB) {
            revert IdenticalTokenAddresses();
        }
        if(tokenA == address(0)) {
            revert ZeroAddress();
        }

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        if(_lpTokenByPair[token0][token1] != address(0)) {
            revert LPTokenAlreadyExists();
        }

        (string memory lpName, string memory lpSymbol) = _generateLPTokenNameAndSymbol(token0, token1);
        LPToken lpToken = new LPToken(token0, token1, lpName, lpSymbol);

        _lpTokenByPair[token0][token1] = address(lpToken);
        _lpTokens.push(address(lpToken));

        emit LPTokenCreated(token0, token1, address(lpToken), _lpTokens.length);

        return address(lpToken);
    }

    function _generateLPTokenNameAndSymbol(
        address token0,
        address token1
    )
        private
        view
        returns (string memory lpName, string memory lpSymbol)
    {
        string memory symbol0 = ERC20(token0).symbol();
        string memory symbol1 = ERC20(token1).symbol();

        lpName = string(abi.encodePacked(symbol0, "-", symbol1, " LP Token"));
        lpSymbol = string(abi.encodePacked(symbol0, "-", symbol1));
    }
}