// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Multicall3} from "multicall/Multicall3.sol";

import {SigUtils} from "./libs/SigUtils.sol";
import {IStrategyManager} from "./helpers/IStrategyManager.sol";
import {TestBase} from "./helpers/TestBase.sol";

struct EigenConfig {
    IERC20 cbETH;
    address cbETHStrategy;
    address manager;
}

contract EigenTest is TestBase {
    // address constant cbETHStrategy = 0x54945180dB7943c0ed0FEE7EdaB2Bd24620256bc;
    // address constant manager = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;

    EigenConfig config;

    function setUp() public {
        _deployContracts();

        bytes memory _config = _getConfig();
        config = abi.decode(_config, (EigenConfig));

        deal(address(config.cbETH), user, 100e6);
    }

    function testEigenCall() public {
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

        SigUtils.Permit memory permit =
            SigUtils.Permit({owner: user, spender: address(executor), value: 100e6, nonce: 0, deadline: expiry});
        (uint8 v, bytes32 r, bytes32 s) =
            SigUtils.sign(userPrivateKey, SigUtils.getPermitDigest(permit, address(config.cbETH)));

        //* Multicall
        Multicall3.Call[] memory calls = new Multicall3.Call[](4);
        calls[0] = Multicall3.Call({
            target: address(config.cbETH),
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
            target: address(config.cbETH),
            callData: abi.encodeWithSignature("transferFrom(address,address,uint256)", user, address(executor), 100e6)
        });

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
