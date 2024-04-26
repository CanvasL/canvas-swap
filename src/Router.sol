// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {LPTokenFactory} from "./LPTokenFactory.sol";
import {LPToken} from "./LPToken.sol";

contract Router {
    error DeadlineAlreadyPast();
    error LPTokenNotExists();
    error InsufficientAmount(address token);
    error InsufficientLiquidity();
    error LowerThanMinOutAmount();
    error GreaterThanMaxInAmount();
    error InvalidPath();

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

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal < amountBMin) {
                    revert InsufficientAmount(tokenB);
                }

                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;

                assert(amountAOptimal <= amountADesired);

                if (amountAOptimal < amountAMin) {
                    revert InsufficientAmount(tokenA);
                }

                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }

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
        amounts = _getAmountsOut(amountIn, path);
        if(amounts[amounts.length - 1] < amountOutMin) {
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
        amounts = _getAmountsIn(amountOut, path);
        if(amounts[0] > amountInMax) {
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

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");

        if(reserveIn == 0 || reserveOut ==0 ) {
            revert InsufficientLiquidity();
        }
        uint256 amountInWithFee = amountIn * (997);
        uint256 numerator = amountInWithFee * (reserveOut);
        uint256 denominator = reserveIn * (1000) + (amountInWithFee);
        amountOut = numerator / denominator;
    }

    function _getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        if(reserveIn == 0 || reserveOut ==0 ) {
            revert InsufficientLiquidity();
        }
        uint256 numerator = reserveIn * (amountOut) * (1000);
        uint256 denominator = (reserveOut - (amountOut)) * (997);
        amountIn = (numerator / denominator) + (1);
    }

    function _getAmountsOut(
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        if(path.length < 2) {
            revert InvalidPath();
        }

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            address lpToken = LP_TOKEN_FACTORY.getLPTokenByPair(
                path[i],
                path[i + 1]
            );
            (uint256 reserveIn, uint256 reserveOut) = LPToken(lpToken).getReserves();
            amounts[i + 1] = _getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    function _getAmountsIn(
        uint256 amountOut,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        if(path.length < 2) {
            revert InvalidPath();
        }

        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            address lpToken = LP_TOKEN_FACTORY.getLPTokenByPair(
                path[i - 1],
                path[i]
            );
            (uint256 reserveIn, uint256 reserveOut) = LPToken(lpToken).getReserves();
            amounts[i - 1] = _getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}
