// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {LPTokenFactory} from "./LPTokenFactory.sol";
import {LPToken} from "./LPToken.sol";
import {RouterLibrary} from "./RouterLibrary.sol";

contract Router {
    error DeadlineAlreadyPast();
    error LPTokenNotExists();
    error InsufficientAmount(address token);
    error LowerThanMinOutAmount();
    error GreaterThanMaxInAmount();

    using SafeERC20 for IERC20;

    LPTokenFactory public immutable LP_TOKEN_FACTORY;

    constructor(address factory) {
        LP_TOKEN_FACTORY = LPTokenFactory(factory);
    }

    modifier unexpired(uint256 deadline) {
        if (block.timestamp > deadline) {
            revert DeadlineAlreadyPast();
        }
        _;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        public
        unexpired(deadline)
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        address lpToken = LP_TOKEN_FACTORY.getLPTokenByPair(tokenA, tokenB);
        if (lpToken == address(0)) {
            lpToken = LP_TOKEN_FACTORY.createLPToken(tokenA, tokenB);
        }

        (uint256 reserveA, uint256 reserveB) = LPToken(lpToken).getReserves();

        (amountA, amountB) = RouterLibrary.getOptimalAmount(
            reserveA,
            reserveB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );

        IERC20(tokenA).safeTransferFrom(msg.sender, lpToken, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, lpToken, amountB);

        liquidity = LPToken(lpToken).mint(to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public unexpired(deadline) returns (uint256 amountA, uint256 amountB) {
        address lpToken = LP_TOKEN_FACTORY.getLPTokenByPair(tokenA, tokenB);
        if (lpToken == address(0)) {
            revert LPTokenNotExists();
        }

        IERC20(lpToken).safeTransferFrom(msg.sender, lpToken, liquidity);
        (uint256 amount0, uint256 amount1) = LPToken(lpToken).burn(to);

        (address token0, ) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);

        if (amountA < amountAMin) {
            revert InsufficientAmount(tokenA);
        }
        if (amountB < amountBMin) {
            revert InsufficientAmount(tokenB);
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) public unexpired(deadline) returns (uint256[] memory amounts) {
        amounts = RouterLibrary.getAmountsOut(LP_TOKEN_FACTORY, amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin) {
            revert LowerThanMinOutAmount();
        }
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            LP_TOKEN_FACTORY.getLPTokenByPair(path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) public unexpired(deadline) returns (uint256[] memory amounts) {
        amounts = RouterLibrary.getAmountsIn(LP_TOKEN_FACTORY, amountOut, path);
        if (amounts[0] > amountInMax) {
            revert GreaterThanMaxInAmount();
        }
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            LP_TOKEN_FACTORY.getLPTokenByPair(path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address token0, ) = path[i] < path[i + 1]
                ? (path[i], path[i + 1])
                : (path[i + 1], path[i]);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = path[i] == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? LP_TOKEN_FACTORY.getLPTokenByPair(path[i + 1], path[i + 2])
                : _to;
            LPToken(LP_TOKEN_FACTORY.getLPTokenByPair(path[i], path[i + 1]))
                .swap(amount0Out, amount1Out, to);
        }
    }
}
