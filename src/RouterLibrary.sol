// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {LPTokenFactory} from "./LPTokenFactory.sol";
import {LPToken} from "./LPToken.sol";

library RouterLibrary {
    error InsufficientLiquidity();
    error InsufficientInputAmount();
    error InsufficientOutputAmount();
    error OptimalLowerThanMinimum();
    error LowerThanMinOutAmount();
    error GreaterThanMaxInAmount();
    error InvalidPath();

    function getOptimalAmount(
        uint256 reserveA,
        uint256 reserveB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external pure returns (uint256 amountA, uint256 amountB) {
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal < amountBMin) {
                    revert OptimalLowerThanMinimum();
                }

                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;

                assert(amountAOptimal <= amountADesired);

                if (amountAOptimal < amountAMin) {
                    revert OptimalLowerThanMinimum();
                }

                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function getAmountsOut(
        LPTokenFactory lpTokenFactory,
        uint256 amountIn,
        address[] memory path
    ) external view returns (uint256[] memory amounts) {
        if (path.length < 2) {
            revert InvalidPath();
        }

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            address lpToken = lpTokenFactory.getLPTokenByPair(
                path[i],
                path[i + 1]
            );
            (uint256 reserveIn, uint256 reserveOut) = LPToken(lpToken)
                .getReserves();
            amounts[i + 1] = _getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    function getAmountsIn(
        LPTokenFactory lpTokenFactory,
        uint256 amountOut,
        address[] memory path
    ) external view returns (uint256[] memory amounts) {
        if (path.length < 2) {
            revert InvalidPath();
        }

        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            address lpToken = lpTokenFactory.getLPTokenByPair(
                path[i - 1],
                path[i]
            );
            (uint256 reserveIn, uint256 reserveOut) = LPToken(lpToken)
                .getReserves();
            amounts[i - 1] = _getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        if (amountIn == 0) {
            revert InsufficientInputAmount();
        }
        if (reserveIn == 0 || reserveOut == 0) {
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
        if (amountOut == 0) {
            revert InsufficientOutputAmount();
        }
        if (reserveIn == 0 || reserveOut == 0) {
            revert InsufficientLiquidity();
        }
        uint256 numerator = reserveIn * (amountOut) * (1000);
        uint256 denominator = (reserveOut - (amountOut)) * (997);
        amountIn = (numerator / denominator) + (1);
    }
}
