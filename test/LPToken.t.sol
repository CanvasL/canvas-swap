// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {LPToken} from "../src/LPToken.sol";
import "forge-std/Test.sol";

contract LPTokenTest is Test {
    uint256 constant MINIMUM_LIQUIDITY = 1000;

    LPToken public lpToken;
    ERC20Mock public token0;
    ERC20Mock public token1;

    function setUp() public {
        token0 = new ERC20Mock("Token 0", "TK0");
        token1 = new ERC20Mock("Token 1", "TK1");

        lpToken = new LPToken(address(token0), address(token1), "TK0-TK1 LP Token", "TK0-TK1");

        token0.mint(10e18);
        token1.mint(10e18);
    }

    function testMintWhenFirstTime() public {
        token0.transfer(address(lpToken), 1e18);
        token1.transfer(address(lpToken), 1e18);

        lpToken.mint();

        assertEq(lpToken.balanceOf(address(this)), 1e18 - MINIMUM_LIQUIDITY);
        assertEq(lpToken.totalSupply(), 1e18);
        _assertReserves(1e18, 1e18);
    }

    function testMintWhenSecondTime() public {
        token0.transfer(address(lpToken), 1e18);
        token1.transfer(address(lpToken), 1e18);

        lpToken.mint();

        token0.transfer(address(lpToken), 2e18);
        token1.transfer(address(lpToken), 2e18);

        lpToken.mint();

        assertEq(lpToken.balanceOf(address(this)), 3e18 - MINIMUM_LIQUIDITY);
        assertEq(lpToken.totalSupply(), 3e18);
        _assertReserves(3e18, 3e18);
    }

    function testMintWhenInputUnbalanced() public {
        // once
        token0.transfer(address(lpToken), 1e18);
        token1.transfer(address(lpToken), 1e18);

        lpToken.mint();

        // twice
        token0.transfer(address(lpToken), 1e18);
        token1.transfer(address(lpToken), 2e18);

        lpToken.mint();

        assertEq(lpToken.balanceOf(address(this)), 2e18 - MINIMUM_LIQUIDITY);
        assertEq(lpToken.totalSupply(), 2e18);
        _assertReserves(2e18, 3e18);
    }

    function testBurn() public {
        token0.transfer(address(lpToken), 1e18);
        token1.transfer(address(lpToken), 1e18);

        lpToken.mint();

        uint256 liquidity = lpToken.balanceOf(address(this));
        lpToken.transfer(address(lpToken), liquidity);
        lpToken.burn(address(this));

        assertEq(lpToken.balanceOf(address(this)), 0);
        assertEq(lpToken.totalSupply(), MINIMUM_LIQUIDITY);
        _assertReserves(uint112(MINIMUM_LIQUIDITY), uint112(MINIMUM_LIQUIDITY));
        assertEq(token0.balanceOf(address(this)), 10e18 - MINIMUM_LIQUIDITY);
        assertEq(token1.balanceOf(address(this)), 10e18 - MINIMUM_LIQUIDITY);
    }

    function testBurnWhenInputUnbalanced() public {
        // once
        token0.transfer(address(lpToken), 1e18);
        token1.transfer(address(lpToken), 1e18);

        lpToken.mint();

        // twice
        token0.transfer(address(lpToken), 1e18);
        token1.transfer(address(lpToken), 2e18);

        lpToken.mint();

        uint256 liquidity = lpToken.balanceOf(address(this));
        lpToken.transfer(address(lpToken), liquidity);
        lpToken.burn(address(this));

        assertEq(lpToken.balanceOf(address(this)), 0);
        assertEq(lpToken.totalSupply(), MINIMUM_LIQUIDITY);
        /* totalSupply=2e18, balance0=2e18, balance1=3e18
           amount0=2e18-1000, amount1=(2e18-1000)*1.5=3e-1500
           reserve0=1000, reserve1=1500
        */
        _assertReserves(1000, 1500);    
        assertEq(token0.balanceOf(address(this)), 10e18 - 1000);
        assertEq(token1.balanceOf(address(this)), 10e18 - 1500);
    }

    function _assertReserves(uint112 _reserve0, uint112 _reserve1) private view {
        (uint112 reserve0, uint112 reserve1, ) = lpToken.getReserves();

        assertEq(uint256(_reserve0), uint256(reserve0));
        assertEq(uint256(_reserve1), uint256(reserve1));
    }
}
