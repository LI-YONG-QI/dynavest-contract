// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {TestBase} from "./helpers/TestBase.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {console} from "forge-std/console.sol";

contract AnkrTest is TestBase {
    address immutable ANKR_CORE = 0xFE8189A3016cb6A3668b8ccdAC520CE572D4287a;

    address immutable ankrFLOWToken = 0x1b97100eA1D7126C4d60027e231EA4CB25314bdb;

    function setUp() public override {
        vm.selectFork(flowFork);

        super.setUp();
        _deployContracts();

        deal(user, 2e18);
    }

    function testAnkr() public {
        vm.startPrank(user);

        (bool success,) = ANKR_CORE.call{value: 1e18}(abi.encodeWithSelector(0xac76d450));
        require(success, "Failed to send ETH to ANKR");

        assertGt(IERC20(ankrFLOWToken).balanceOf(user), 0);

        console.log("ankrFLOWToken balance of user:", IERC20(ankrFLOWToken).balanceOf(user));
    }
}
