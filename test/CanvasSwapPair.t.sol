// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "#/forge-std/src/Test.sol";
import "#/forge-std/src/console.sol";
import "@/mocks/ERC20Mintable.sol";
import "@/CanvasSwapPair.sol";

contract CanvasSwapPairTest is Test {
    uint256 constant MINIMUM_LIQUIDITY = 1000;

    CanvasSwapPair public pair;
    ERC20Mintable public token0;
    ERC20Mintable public token1;

    function setUp() public {
        token0 = new ERC20Mintable("Token 0", "TK0");
        token1 = new ERC20Mintable("Token 1", "TK1");

        pair = new CanvasSwapPair(address(token0), address(token1));

        token0.mint(10e18);
        token1.mint(10e18);
    }

    function testMintWhenFirstTime() public {
        token0.transfer(address(pair), 1e18);
        token1.transfer(address(pair), 1e18);

        pair.mint();

        assertEq(pair.balanceOf(address(this)), 1e18 - MINIMUM_LIQUIDITY);
        assertEq(pair.totalSupply(), 1e18);
        _assertReserves(1e18, 1e18);
    }

    function testMintWhenSecondTime() public {
        token0.transfer(address(pair), 1e18);
        token1.transfer(address(pair), 1e18);

        pair.mint();

        token0.transfer(address(pair), 2e18);
        token1.transfer(address(pair), 2e18);

        pair.mint();

        assertEq(pair.balanceOf(address(this)), 3e18 - MINIMUM_LIQUIDITY);
        assertEq(pair.totalSupply(), 3e18);
        _assertReserves(3e18, 3e18);
    }

    function testMintWhenInputUnbalanced() public {
        // once
        token0.transfer(address(pair), 1e18);
        token1.transfer(address(pair), 1e18);

        pair.mint();

        // twice
        token0.transfer(address(pair), 1e18);
        token1.transfer(address(pair), 2e18);

        pair.mint();

        assertEq(pair.balanceOf(address(this)), 2e18 - MINIMUM_LIQUIDITY);
        assertEq(pair.totalSupply(), 2e18);
        _assertReserves(2e18, 3e18);
    }

    function testBurn() public {
        token0.transfer(address(pair), 1e18);
        token1.transfer(address(pair), 1e18);

        pair.mint();

        uint256 liquidity = pair.balanceOf(address(this));
        pair.transfer(address(pair), liquidity);
        pair.burn(address(this));

        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.totalSupply(), MINIMUM_LIQUIDITY);
        _assertReserves(uint112(MINIMUM_LIQUIDITY), uint112(MINIMUM_LIQUIDITY));
        assertEq(token0.balanceOf(address(this)), 10e18 - MINIMUM_LIQUIDITY);
        assertEq(token1.balanceOf(address(this)), 10e18 - MINIMUM_LIQUIDITY);
    }

    function testBurnWhenInputUnbalanced() public {
        // once
        token0.transfer(address(pair), 1e18);
        token1.transfer(address(pair), 1e18);

        pair.mint();

        // twice
        token0.transfer(address(pair), 1e18);
        token1.transfer(address(pair), 2e18);

        pair.mint();

        uint256 liquidity = pair.balanceOf(address(this));
        pair.transfer(address(pair), liquidity);
        pair.burn(address(this));

        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.totalSupply(), MINIMUM_LIQUIDITY);
        /* totalSupply=2e18, balance0=2e18, balance1=3e18
           amount0=2e18-1000, amount1=(2e18-1000)*1.5=3e-1500
           reserve0=1000, reserve1=1500
        */
        _assertReserves(1000, 1500);    
        assertEq(token0.balanceOf(address(this)), 10e18 - 1000);
        assertEq(token1.balanceOf(address(this)), 10e18 - 1500);
    }

    function _assertReserves(uint112 _reserve0, uint112 _reserve1) private {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        assertEq(_reserve0, reserve0);
        assertEq(_reserve1, reserve1);
    }
}
