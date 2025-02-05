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

contract MorphoTest is TestBase {
    address morphoBlue = MorphoLib.MORPHO_BLUE;

    function setUp() public {
        _deployContracts();
        _fund(user, 1000e6);
    }

    //* Supply directly USDC to cbETH/USDC market
    function testMorphoCall() public {
        // _beforeExecute();
        _approveTokens(USDC, user, address(executor), 5e6);
        uint256 amount = 5e6;
        bytes32 marketId = 0x64d65c9a2d91c36d56fbc42d69e979335320169b3df63bf92789e2c8883fcc64; // cbETH/USDC market

        MarketParams memory params = MorphoLib.getMarketParams(marketId);

        //* Introduce permit signature
        uint256 expiry = block.timestamp + 1000;
        SigUtils.Permit memory permit =
            SigUtils.Permit({owner: user, spender: address(executor), value: amount, nonce: 0, deadline: expiry});
        (uint8 v, bytes32 r, bytes32 s) = SigUtils.sign(userPrivateKey, SigUtils.getPermitDigest(permit, address(USDC)));

        //* Multicall
        Multicall3.Call[] memory calls = new Multicall3.Call[](4);

        // TODO: Use `MorphoCallback` to eliminate this pre-transfer step
        calls[0] = Multicall3.Call({
            target: address(USDC),
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
            target: address(USDC),
            callData: abi.encodeWithSignature("transferFrom(address,address,uint256)", user, executor, amount)
        });

        calls[2] = Multicall3.Call({
            target: address(USDC),
            callData: abi.encodeWithSignature("approve(address,uint256)", morphoBlue, amount)
        });

        calls[3] = Multicall3.Call({
            target: morphoBlue,
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
            IMorphoStaticTyping(morphoBlue).position(Id.wrap(marketId), user);
        console.log("Supply Shares: %d", supplyShares);
        console.log("Borrow Shares: %d", borrowShares);
        console.log("Collateral: %d", collateral);
    }
}
