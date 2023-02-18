// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "#/forge-std/src/Test.sol";
import "#/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "@/CanvasSwapPair.sol";

contract ERC20Mintable is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {}

    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }
}

contract CanvasSwapPairTest is Test {
    CanvasSwapPair pair;
    ERC20Mintable token0;
    ERC20Mintable token1;

    function setUp() public {
        token0 = new ERC20Mintable("Token 0", "TK0");
        token1 = new ERC20Mintable("Token 1", "TK1");
        pair = new CanvasSwapPair(address(token0), address(token1));

        token0.mint(10 ether);
        token1.mint(10 ether);
    }

    function testMint() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertEq(pair.totalSupply(), 1 ether);
        _assertReserves(1 ether, 1 ether);
    }

    function testMintTwice() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 2 ether);

        pair.mint();

        assertEq(pair.balanceOf(address(this)), 3 ether - 1000);
        assertEq(pair.totalSupply(), 3 ether);
        _assertReserves(3 ether, 3 ether);
    }

    function testMintUnbalanced() public {
        // once
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        // twice
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);

        pair.mint();

        assertEq(pair.balanceOf(address(this)), 2 ether - 1000);
        assertEq(pair.totalSupply(), 2 ether);
        _assertReserves(2 ether, 3 ether);
    }

    function _assertReserves(uint112 _reserve0, uint112 _reserve1) private {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        assertEq(_reserve0, reserve0);
        assertEq(_reserve1, reserve1);
    }
}
