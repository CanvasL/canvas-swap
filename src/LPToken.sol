// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

contract LPToken is ERC20, ReentrancyGuard {
    error InsufficientLiquidityMint();
    error InsufficientLiquiditySwap();
    error InsufficientOutputAmount();
    error InvalidK();

    event Burn(address indexed sender, uint256 amount0, uint256 amount1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Sync(uint256 reserve0, uint256 reserve1);
    event Swap(
        address indexed sender,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    using SafeERC20 for IERC20;

    uint256 constant MINIMUM_LIQUIDITY = 1000;

    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;

    constructor(
        address _token0,
        address _token1,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        token0 = _token0;
        token1 = _token1;
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) public nonReentrant {
        if (amount0Out == 0 && amount1Out == 0) {
            revert InsufficientOutputAmount();
        }

        (uint112 _reserve0, uint256 _reserve1) = getReserves();

        if (amount0Out > _reserve0 || amount1Out > _reserve1) {
            revert InsufficientLiquiditySwap();
        }

        uint256 balance0 = IERC20(token0).balanceOf(address(this)) - amount0Out;
        uint256 balance1 = IERC20(token1).balanceOf(address(this)) - amount1Out;

        if (balance0 * balance1 < uint256(_reserve0) * uint256(_reserve1)) {
            revert InvalidK();
        }

        _updateReserves(balance0, balance1);

        if (amount0Out > 0) {
            IERC20(token0).safeTransfer(to, amount0Out);
        }
        if (amount1Out > 0) {
            IERC20(token1).safeTransfer(to, amount1Out);
        }

        emit Swap(msg.sender, amount0Out, amount1Out, to);
    }

    function mint(address to) public returns (uint256) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves();

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        uint256 liquidity;

        if (totalSupply() == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(this), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(
                (totalSupply() * amount0) / reserve0,
                (totalSupply() * amount1) / reserve1
            );
        }

        if (liquidity <= 0) {
            revert InsufficientLiquidityMint();
        }

        _mint(to, liquidity);

        _updateReserves(balance0, balance1);

        emit Mint(to, amount0, amount1);

        return liquidity;
    }

    function burn(
        address to
    ) public returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 liquidity = balanceOf(address(this));
        amount0 = (liquidity * balance0) / totalSupply();
        amount1 = (liquidity * balance1) / totalSupply();

        _burn(address(this), liquidity);
        IERC20(token0).safeTransfer(to, amount0);
        IERC20(token1).safeTransfer(to, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));
        _updateReserves(balance0, balance1);

        emit Burn(msg.sender, amount0, amount1);
    }

    function getReserves() public view returns (uint112, uint112) {
        return (reserve0, reserve1);
    }

    function _updateReserves(uint256 balance0, uint256 balance1) private {
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);

        emit Sync(reserve0, reserve1);
    }
}
