// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {TestBase} from "./helpers/TestBase.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract KittyTest is TestBase {
    // TODO: only for Flow EVM Mainnet
    address immutable KITTY = 0x7296a9C350cad25fc69B47Ec839DCf601752C3C2;
    address immutable ANKR_CORE = 0xFE8189A3016cb6A3668b8ccdAC520CE572D4287a;
    address immutable ankrFLOWToken = 0x1b97100eA1D7126C4d60027e231EA4CB25314bdb;

    uint256 constant ANKR_STAKE_AMOUNT = 1e18;

    function setUp() public override {
        vm.selectFork(flowFork);
        super.setUp();

        _deployContracts();

        deal(user, ANKR_STAKE_AMOUNT + 1e18);
    }

    function test_ProvideLiquidity() public {
        vm.startPrank(user);

        (bool stakeSuccess,) = ANKR_CORE.call{value: ANKR_STAKE_AMOUNT}(abi.encodeWithSelector(0xac76d450));
        require(stakeSuccess, "Failed to stake ANKR");
        uint256 ankrFlowBalance = IERC20(ankrFLOWToken).balanceOf(user);

        IERC20(ankrFLOWToken).approve(KITTY, ankrFlowBalance);

        uint256[2] memory amounts = [uint256(0), ankrFlowBalance];
        (bool success,) = KITTY.call(abi.encodeWithSelector(0x0b4c7e4d, amounts, 0));
        require(success, "Failed to send ETH to Kitty");

        vm.stopPrank();
    }
}
