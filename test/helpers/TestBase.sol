// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Vm} from "forge-std/Vm.sol";
import {Test, console} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Strings} from "../libs/Strings.sol";
import {Executor} from "../../src/Executor.sol";
import {Vault} from "../../src/Vault.sol";

abstract contract TestBase is Test {
    using stdJson for *;
    using Strings for *;

    Executor executor;
    Vault vault;

    uint256 constant userPrivateKey = 123;
    address immutable user = vm.addr(userPrivateKey);

    function _approveTokens(IERC20 _token, address from, address spender, uint256 amount) internal {
        vm.startBroadcast(from);

        IERC20(_token).approve(spender, amount);

        vm.stopBroadcast();
    }

    function _buildConfigPath(uint256 chainId) private pure returns (string memory) {
        return string.concat("configs/", chainId.toString(), ".json");
    }

    function _deployContracts() internal {
        vault = new Vault(0x8720095Fa5739Ab051799211B146a2EEE4Dd8B37);
        executor = new Executor(address(vault));

        _label();

        // string memory configJson = vm.readFile(_buildConfigPath(block.chainid));
        // bytes memory json = vm.parseJson(configJson);
        // token = abi.decode(json, (Token));
    }

    function _getConfig() internal view returns (bytes memory) {
        string memory configJson = vm.readFile(_buildConfigPath(block.chainid));
        return vm.parseJson(configJson);
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
