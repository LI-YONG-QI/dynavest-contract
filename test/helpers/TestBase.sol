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

    //! For caching fork data, the block number is required
    uint256 mainnetFork = vm.createFork("https://mainnet.infura.io/v3/b9fda36a1b28432485712d8d73975208", 21786590);
    uint256 baseSepoliaFork =
        vm.createFork("https://base-sepolia.infura.io/v3/b9fda36a1b28432485712d8d73975208", 21533254);

    function _approveTokens(IERC20 _token, address from, address spender, uint256 amount) internal {
        vm.startBroadcast(from);

        IERC20(_token).approve(spender, amount);

        vm.stopBroadcast();
    }

    function _buildConfigPath(string memory contractName, uint256 chainId) private pure returns (string memory) {
        return string.concat("configs/", contractName, "/", chainId.toString(), ".json");
    }

    function _deployContracts() internal {
        vault = new Vault(0x8720095Fa5739Ab051799211B146a2EEE4Dd8B37);
        executor = new Executor(address(vault));

        _label();
    }

    function _getConfig(string memory contractName) internal view returns (bytes memory) {
        string memory configJson = vm.readFile(_buildConfigPath(contractName, block.chainid));
        return vm.parseJson(configJson);
    }

    function _label() private {
        vm.label(user, "user");
        vm.label(address(vault), "vault");
        vm.label(address(executor), "executor");
    }

    // function _createForks() internal {
    //     baseSepoliaFork = vm.createFork("https://mainnet.infura.io/v3/311142eea537485aabe9b15954cb5960");
    //     mainnetFork = vm.createFork("https://base-sepolia.infura.io/v3/311142eea537485aabe9b15954cb5960");
    // }

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
