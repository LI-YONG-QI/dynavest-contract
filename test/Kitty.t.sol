// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {TestBase} from "./helpers/TestBase.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Strategy} from "../src/Strategy.sol";

contract KittyTest is TestBase {
    // TODO: only for Flow EVM Mainnet
    address immutable KITTY = 0x7296a9C350cad25fc69B47Ec839DCf601752C3C2;
    address immutable ANKR_CORE = 0xFE8189A3016cb6A3668b8ccdAC520CE572D4287a;
    address immutable ankrFLOWToken = 0x1b97100eA1D7126C4d60027e231EA4CB25314bdb;
    address immutable LPToken = 0x7296a9C350cad25fc69B47Ec839DCf601752C3C2;

    uint256 constant ANKR_STAKE_AMOUNT = 1e16;

    Strategy strategy;

    function setUp() public override {
        vm.selectFork(flowFork);
        super.setUp();

        _deployContracts();
        strategy = new Strategy();

        deal(user, ANKR_STAKE_AMOUNT + 1e18);
    }

    function test_LSTAndLiquidity() public {
        vm.startPrank(user);

        strategy.execute{value: ANKR_STAKE_AMOUNT}();

        vm.stopPrank();

        assertGt(IERC20(LPToken).balanceOf(user), 0);
    }

    function test_LST() public {
        vm.startPrank(user);

        (bool stakeSuccess,) = ANKR_CORE.call{value: ANKR_STAKE_AMOUNT}(abi.encodeWithSelector(0xac76d450)); // liquid staking FLOW
        require(stakeSuccess, "Failed to stake ANKR");

        vm.stopPrank();

        assertGt(IERC20(ankrFLOWToken).balanceOf(user), 0);
    }

    function test_AddLiquidity() public {
        deal(ankrFLOWToken, user, ANKR_STAKE_AMOUNT);

        vm.startPrank(user);

        IERC20(ankrFLOWToken).approve(KITTY, ANKR_STAKE_AMOUNT);

        uint256[2] memory amounts = [uint256(0), ANKR_STAKE_AMOUNT];
        (bool success,) = KITTY.call(abi.encodeWithSelector(0x0c3e4b54, amounts, 0, msg.sender)); // add liquidity

        vm.stopPrank();
    }
}
