// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {CanvasSwapERC20} from "@/CanvasSwapERC20.sol";
import {IERC20} from "#/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "#/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@/libraries/Math.sol";
import "#/forge-std/src/console.sol";

error InsufficientLiquidityMint();
error InsufficientLiquidityBurn();
error InsufficientLiquiditySwap();
error InsufficientOutputAmount();
error TransferFailed();
error InvalidK();

contract CanvasSwapPair is CanvasSwapERC20, Math {
    using SafeERC20 for IERC20;
    uint256 constant MINIMUM_LIQUIDITY = 1000;

    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;

    event Burn(address indexed sender, uint256 amount0, uint256 amount1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Sync(uint256 reserve0, uint256 reserve1);
    event Swap(address indexed sender, uint256 amount0Out, uint256 amount1Out, address indexed to);

    constructor(address _token0, address _token1) CanvasSwapERC20("Canvas Swap", "CASP") {
        token0 = _token0;
        token1 = _token1;
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to) public {
        if(amount0Out == 0 && amount1Out == 0) {
            revert InsufficientOutputAmount();
        }

        (uint112 _reserve0, uint _reserve1,) = getReserves();

        if(amount0Out > _reserve0 || amount1Out > _reserve1) {
            revert InsufficientLiquiditySwap();
        }

        uint256 balance0 = IERC20(token0).balanceOf(address(this)) - amount0Out;
        uint256 balance1 = IERC20(token1).balanceOf(address(this)) - amount1Out;

        if(balance0 * balance1 < uint256(_reserve0)* uint256(_reserve1)) {
            revert InvalidK();
        }

        _updateReserves(balance0, balance1);

        if(amount0Out > 0) {
            IERC20(token0).safeTransfer(to, amount0Out);
        }
        if(amount1Out > 0) {
            IERC20(token1).safeTransfer(to, amount1Out);
        }

        emit Swap(msg.sender, amount0Out, amount1Out, to);
    }

    function mint() public {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        uint256 liquidity;

        if (totalSupply() == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(
                (totalSupply() * amount0) / reserve0,
                (totalSupply() * amount1) / reserve1
            );
        }

        if (liquidity <= 0) {
            revert InsufficientLiquidityMint();
        }
        
        _mint(msg.sender, liquidity);

        _updateReserves(balance0, balance1);

        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) public returns(uint256 amount0, uint256 amount1) {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 liquidity = balanceOf(address(this));
        amount0 = liquidity * balance0 / totalSupply();
        amount1 = liquidity * balance1 / totalSupply();

        _burn(address(this), liquidity);
        IERC20(token0).safeTransfer(to, amount0);
        IERC20(token1).safeTransfer(to, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));
        _updateReserves(balance0, balance1);

        emit Burn(msg.sender, amount0, amount1);
    }

    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, 0);
    }

    function _updateReserves(uint256 balance0, uint256 balance1) private {
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);

        emit Sync(reserve0, reserve1);
    }
}
