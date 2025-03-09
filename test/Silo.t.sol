// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Test, console} from "forge-std/Test.sol";
import {ISilo} from "silo-core/interfaces/ISilo.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IUniversalRouter} from "./helpers/IUniversalRouter.sol";
import {TestBase} from "./helpers/TestBase.sol";

struct SiloConfig {
    address silo0;
    address silo1;
    IERC20 stS;
    IERC20 wS;
}

contract SiloTest is TestBase {
    uint256 constant INIT_SUPPLY = 10_000 * 1e18;

    address payable router = payable(0x92643Dc4F75C374b689774160CDea09A0704a9c2);
    address internal constant MSG_SENDER = address(1);
    bytes internal constant V3_SWAP_EXACT_IN = hex"00";

    SiloConfig config;

    function _depositAndBorrow(uint256 depositAsset, uint256 borrowAsset) internal returns (uint256) {
        config.stS.approve(config.silo0, depositAsset);
        ISilo(config.silo0).deposit(depositAsset, user);

        // Borrow S
        ISilo(config.silo1).borrow(borrowAsset, user, user);

        return borrowAsset;
    }

    function setUp() public override {
        vm.selectFork(sonicFork);

        super.setUp();
        _deployContracts();

        bytes memory _config = _getConfig("silo");
        config = abi.decode(_config, (SiloConfig));
    }

    function test_borrowRecursion() public {
        uint256 deadline = block.timestamp + 10000;
        uint256 depositAssets = 100 * 1e18;

        deal(address(config.stS), user, depositAssets);
        deal(address(config.wS), user, 0);

        vm.startPrank(user);
        // ROUND 1
        // Deposit stS
        uint256 borrowAssets = depositAssets / 100;
        _depositAndBorrow(depositAssets, borrowAssets);

        // Swap wS to stS
        config.wS.approve(router, borrowAssets);
        bytes[] memory inputs = new bytes[](1);
        bytes memory path = hex"039e2fb66102314ce7b64ce5ce3e5183bc94ad38000001e5da20f15420ad15de0fa650600afc998bbe3955"; // Hardcode wS -> stS path
        inputs[0] = abi.encode(vm.addr(99999), borrowAssets, 0, path, true);

        IUniversalRouter(router).execute(V3_SWAP_EXACT_IN, inputs, deadline);

        // // ROUND 2
        // // Deposit stS
        // depositAssets = borrowAssets / 2;
        // borrowAssets = depositAssets / 2;
        // _depositAndBorrow(depositAssets, borrowAssets);

        vm.stopPrank();
    }
}
