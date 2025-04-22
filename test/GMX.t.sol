// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {console} from "forge-std/console.sol";

import {IBeefyVaultV6} from "../src/interfaces/IBeefyVaultV6.sol";
import {TestBase} from "./helpers/TestBase.sol";

contract GMXTest is TestBase {
    address constant BEEFY_VAULT = 0x5B904f19fb9ccf493b623e5c8cE91603665788b0;
    address constant GMX = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;

    uint256 constant INIT_SUPPLY = 10 * 1e18;

    function setUp() public override {
        vm.selectFork(arbitrumFork);

        super.setUp();
        _deployContracts();
    }

    function test_depositBeefyVaultWithGMX() public {
        uint256 beforeMooGMX = IERC20(BEEFY_VAULT).balanceOf(user);
        uint256 depositAmount = 1 ether;
        deal(GMX, user, depositAmount);

        vm.startPrank(user);
        IERC20(GMX).approve(BEEFY_VAULT, depositAmount);
        IBeefyVaultV6(BEEFY_VAULT).depositAll();
        vm.stopPrank();

        assertGt(IERC20(BEEFY_VAULT).balanceOf(user), beforeMooGMX);
    }
}
