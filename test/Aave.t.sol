// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {console} from "forge-std/console.sol";

import {TestBase} from "./helpers/TestBase.sol";
import {IPool} from "./helpers/IPool.sol";
import {IERC20PermitUpgradeable} from "./helpers/IERC20PermitUpgradeable.sol";
import {SigUtils} from "./libs/SigUtils.sol";
import {IMulticall3} from "../src/interfaces/IMulticall3.sol";

struct AaveConfig {
    address aToken;
    address asset;
    address pool;
}

contract AaveTest is TestBase {
    uint256 constant SUPPLY_AMOUNT = 100e18;
    AaveConfig config;

    function setUp() public override {
        vm.selectFork(celoFork);
        super.setUp();

        _deployContracts();

        bytes memory _config = _getConfig("aave");
        config = abi.decode(_config, (AaveConfig));

        deal(config.asset, user, SUPPLY_AMOUNT + 1e18);
    }

    function test_SupplyAssets() public {
        uint256 deadline = block.timestamp + 1000;
        uint256 nonce = IERC20PermitUpgradeable(config.asset).nonces(user);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](4);
        _callPermitAndTransfer(
            calls, 0, userPrivateKey, config.asset, user, address(executor), SUPPLY_AMOUNT, nonce, deadline
        );

        calls[2] = IMulticall3.Call({
            target: config.asset,
            callData: abi.encodeWithSignature("approve(address,uint256)", config.pool, SUPPLY_AMOUNT)
        });

        calls[3] = IMulticall3.Call({
            target: config.pool,
            callData: abi.encodeWithSignature(
                "supply(address,uint256,address,uint16)", config.asset, SUPPLY_AMOUNT, user, 0
            )
        });

        executor.execute(calls, user);

        assertGt(IERC20(config.aToken).balanceOf(user), 0);
        console.log("aToken balance of user:", IERC20(config.aToken).balanceOf(user));
    }
}
