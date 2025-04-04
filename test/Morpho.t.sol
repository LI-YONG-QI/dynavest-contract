// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {IMorpho, MarketParams, IMorphoStaticTyping, Id} from "morpho-blue/src/interfaces/IMorpho.sol";
import {IMulticall3} from "../src/interfaces/IMulticall3.sol";

import {SigUtils} from "./libs/SigUtils.sol";
import {MorphoLib} from "./libs/MorphoLib.sol";
import {TestBase} from "./helpers/TestBase.sol";

struct MorphoConfig {
    IERC20 USDC;
    IERC20 WETH;
    address morphoBlue;
}

contract MorphoTest is TestBase {
    uint256 constant INIT_SUPPLY = 1e27;

    MorphoConfig config;

    function setUp() public override {
        vm.selectFork(baseSepoliaFork);

        super.setUp();
        _deployContracts();

        bytes memory _config = _getConfig("morpho");
        config = abi.decode(_config, (MorphoConfig));

        deal(address(config.USDC), user, INIT_SUPPLY);
        deal(address(config.WETH), user, INIT_SUPPLY);
    }

    //* Supply directly USDC to cbETH/USDC market
    function testMorphoCall() public {
        _depositToVault(user, 5e6);

        deal(address(config.USDC), user, INIT_SUPPLY);
        uint256 amount = 5e6;
        bytes32 marketId = 0xe36464b73c0c39836918f7b2b9a6f1a8b70d7bb9901b38f29544d9b96119862e; // WETH/USDC market

        MarketParams memory params = MorphoLib.getMarketParams(marketId, config.morphoBlue);

        //* Multicall
        IMulticall3.Call[] memory calls = new IMulticall3.Call[](4);
        _callPermitAndTransfer(
            calls, 0, userPrivateKey, address(config.USDC), user, address(executor), amount, 0, block.timestamp + 10000
        );

        calls[2] = IMulticall3.Call({
            target: address(config.USDC),
            callData: abi.encodeWithSignature("approve(address,uint256)", config.morphoBlue, amount)
        });

        calls[3] = IMulticall3.Call({
            target: config.morphoBlue,
            callData: abi.encodeWithSignature(
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                params,
                amount,
                0,
                user,
                new bytes(0)
            )
        });
        executor.execute(calls, user);

        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(config.morphoBlue).position(Id.wrap(marketId), user);
        console.log("Supply Shares: %d", supplyShares);
        console.log("Borrow Shares: %d", borrowShares);
        console.log("Collateral: %d", collateral);
    }
}
