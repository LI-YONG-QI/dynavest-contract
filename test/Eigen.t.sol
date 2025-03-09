// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Multicall3} from "../src/Multicall3.sol";

import {SigUtils} from "./libs/SigUtils.sol";
import {IStrategyManager} from "./helpers/IStrategyManager.sol";
import {TestBase} from "./helpers/TestBase.sol";

struct EigenConfig {
    IERC20 cbETH;
    address cbETHStrategy;
    address manager;
}

contract EigenTest is TestBase {
    EigenConfig config;

    function setUp() public override {
        vm.selectFork(holeskyFork);

        super.setUp();
        _deployContracts();

        bytes memory _config = _getConfig("eigen");
        config = abi.decode(_config, (EigenConfig));

        deal(address(config.cbETH), user, 100e6);
    }

    function testEigenCall() public {
        _depositToVault(user, 4e6);

        //* Introduce signature
        uint256 expiry = block.timestamp + 1000;
        SigUtils.Deposit memory cbETHDeposit = SigUtils.Deposit({
            strategy: config.cbETHStrategy,
            token: address(config.cbETH),
            amount: 100e6,
            staker: user,
            expiry: expiry
        });
        bytes memory depositSig =
            SigUtils.signAggregate(userPrivateKey, SigUtils.getDepositDigest(cbETHDeposit, config.manager));

        //* Multicall
        Multicall3.Call[] memory calls = new Multicall3.Call[](4);
        _callPermitAndTransfer(calls, userPrivateKey, address(config.cbETH), user, address(executor), 100e6, 0, expiry);

        calls[2] = Multicall3.Call({
            target: address(config.cbETH),
            callData: abi.encodeWithSignature("approve(address,uint256)", config.manager, 100e6)
        });

        calls[3] = Multicall3.Call({
            target: address(config.manager),
            callData: abi.encodeWithSignature(
                "depositIntoStrategyWithSignature(address,address,uint256,address,uint256,bytes)",
                config.cbETHStrategy,
                address(config.cbETH),
                100e6,
                user,
                expiry,
                depositSig
            )
        });

        executor.execute(calls, user);
    }
}
