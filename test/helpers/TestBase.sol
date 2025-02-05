// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Vm} from "forge-std/Vm.sol";
import {Test} from "forge-std/Test.sol";

import {Executor} from "../../src/Executor.sol";
import {Vault} from "../../src/Vault.sol";

abstract contract TestBase is Test {
    Executor executor;
    Vault vault;

    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 constant cbETH = IERC20(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);
    IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    uint256 constant userPrivateKey = 123;
    address immutable user = vm.addr(userPrivateKey);

    function _approveTokens(IERC20 token, address from, address spender, uint256 amount) internal {
        vm.startBroadcast(from);

        IERC20(token).approve(spender, amount);

        vm.stopBroadcast();
    }

    function _deployContracts() internal {
        vault = new Vault(address(USDC));
        executor = new Executor(address(vault));

        _label();
    }

    function _fund(address to, uint256 amount) internal {
        deal(address(USDC), to, amount);
        deal(address(cbETH), to, amount);
        deal(address(DAI), to, amount);
    }

    function _label() private {
        vm.label(user, "user");
        vm.label(address(vault), "vault");
        vm.label(address(executor), "executor");
    }

    function _getLogs(bytes32 events) internal returns (Vm.Log memory) {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        for (uint256 i = 0; i < entries.length; i++) {
            bytes32 sig = entries[i].topics[0];
            if (sig == events) {
                return entries[i];
            }
        }

        revert("Event not found");
    }
}
