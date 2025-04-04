// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {console} from "forge-std/console.sol";

import {TestBase} from "./helpers/TestBase.sol";
import {IPool} from "./helpers/IPool.sol";
import {IERC20PermitUpgradeable} from "./helpers/IERC20PermitUpgradeable.sol";
import {SigUtils} from "./libs/SigUtils.sol";
import {IMulticall3} from "../src/interfaces/IMulticall3.sol";

contract AaveTest is TestBase {
    address immutable pool = 0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402;
    address immutable cEUR = 0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73;
    address immutable aCelcEUR = 0x34c02571094e08E935B8cf8dC10F1Ad6795f1f81;

    uint256 constant SUPPLY_AMOUNT = 100e18;

    function setUp() public override {
        vm.selectFork(celoFork);
        super.setUp();

        _deployContracts();

        deal(cEUR, user, SUPPLY_AMOUNT + 1e18);
    }

    function test_SupplyAssets() public {
        uint256 deadline = block.timestamp + 1000;
        uint256 nonce = IERC20PermitUpgradeable(cEUR).nonces(user);

        IMulticall3.Call[] memory calls = new IMulticall3.Call[](4);
        _callPermitAndTransfer(calls, 0, userPrivateKey, cEUR, user, address(executor), SUPPLY_AMOUNT, nonce, deadline);

        calls[2] = IMulticall3.Call({
            target: cEUR,
            callData: abi.encodeWithSignature("approve(address,uint256)", pool, SUPPLY_AMOUNT)
        });

        calls[3] = IMulticall3.Call({
            target: pool,
            callData: abi.encodeWithSignature("supply(address,uint256,address,uint16)", cEUR, SUPPLY_AMOUNT, user, 0)
        });

        executor.execute(calls, user);

        assertGt(IERC20(aCelcEUR).balanceOf(user), 0);
        console.log("aCelcEUR balance of user:", IERC20(aCelcEUR).balanceOf(user));
    }
}
