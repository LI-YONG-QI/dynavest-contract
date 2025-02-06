// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Multicall3} from "multicall/Multicall3.sol";
import {IMorpho, MarketParams, IMorphoStaticTyping, Id} from "morpho-blue/src/interfaces/IMorpho.sol";

import {SigUtils} from "./libs/SigUtils.sol";
import {MorphoLib} from "./libs/MorphoLib.sol";
import {TestBase} from "./helpers/TestBase.sol";

struct MorphoConfig {
    IERC20 USDC;
    IERC20 WETH;
    address morphoBlue;
}

contract MorphoTest is TestBase {
    address morphoBlue = MorphoLib.MORPHO_BLUE;
    uint256 constant INIT_SUPPLY = 1e27;

    MorphoConfig config;

    function setUp() public {
        _deployContracts();

        bytes memory _config = _getConfig();
        config = abi.decode(_config, (MorphoConfig));

        deal(address(config.USDC), user, INIT_SUPPLY);
        deal(address(config.WETH), user, INIT_SUPPLY);
    }

    //* Supply directly USDC to cbETH/USDC market
    function testMorphoCall() public {
        uint256 amount = 5e6;
        _approveTokens(config.USDC, user, address(executor), amount);
        bytes32 marketId = 0xe36464b73c0c39836918f7b2b9a6f1a8b70d7bb9901b38f29544d9b96119862e; // WETH/USDC market

        MarketParams memory params = MorphoLib.getMarketParams(marketId);

        //* Introduce permit signature
        uint256 expiry = block.timestamp + 1000;
        SigUtils.Permit memory permit =
            SigUtils.Permit({owner: user, spender: address(executor), value: amount, nonce: 0, deadline: expiry});
        (uint8 v, bytes32 r, bytes32 s) =
            SigUtils.sign(userPrivateKey, SigUtils.getPermitDigest(permit, address(config.USDC)));

        //* Multicall
        Multicall3.Call[] memory calls = new Multicall3.Call[](4);

        // TODO: Use `MorphoCallback` to eliminate this pre-transfer step
        calls[0] = Multicall3.Call({
            target: address(config.USDC),
            callData: abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                permit.owner,
                permit.spender,
                permit.value,
                permit.deadline,
                v,
                r,
                s
            )
        });

        calls[1] = Multicall3.Call({
            target: address(config.USDC),
            callData: abi.encodeWithSignature("transferFrom(address,address,uint256)", user, executor, amount)
        });

        calls[2] = Multicall3.Call({
            target: address(config.USDC),
            callData: abi.encodeWithSignature("approve(address,uint256)", config.morphoBlue, amount)
        });

        calls[3] = Multicall3.Call({
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
