// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {TestBase} from "./helpers/TestBase.sol";
import {SigUtils} from "./libs/SigUtils.sol";

interface IBeetsStaking is IERC20 {
    function deposit() external payable returns (uint256);
}

struct BeetsConfig {
    IERC20 S;
    address beets;
    IERC20 stS;
}

contract BeetsTest is TestBase {
    BeetsConfig config;

    uint256 constant INIT_SUPPLY = 10 * 1e18;

    function setUp() public override {
        vm.selectFork(sonicFork);

        super.setUp();
        _deployContracts();

        bytes memory _config = _getConfig("beets");
        config = abi.decode(_config, (BeetsConfig));
    }

    function test_depositLiquidStaking() public {
        deal(user, INIT_SUPPLY);

        vm.startPrank(user);

        IBeetsStaking beetsStaking = IBeetsStaking(config.beets);
        beetsStaking.deposit{value: INIT_SUPPLY}();

        vm.stopPrank();
    }
}
