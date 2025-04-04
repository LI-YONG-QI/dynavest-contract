// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {TestBase} from "./helpers/TestBase.sol";
import {IStakedCelo} from "./helpers/IStakedCelo.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract StakedCeloTest is TestBase {
    address constant STAKE_MANAGER = 0x0239b96D10a434a56CC9E09383077A0490cF9398;
    address constant stCELO = 0xC668583dcbDc9ae6FA3CE46462758188adfdfC24;

    uint256 constant DEPOSIT_AMOUNT = 1e18;

    function setUp() public override {
        vm.selectFork(celoFork);

        super.setUp();
        _deployContracts();

        deal(user, DEPOSIT_AMOUNT + 1e18);
    }

    function test_Deposit() public {
        vm.prank(user);
        IStakedCelo(STAKE_MANAGER).deposit{value: DEPOSIT_AMOUNT}();

        assertGt(IERC20(stCELO).balanceOf(user), 0);
    }
}
