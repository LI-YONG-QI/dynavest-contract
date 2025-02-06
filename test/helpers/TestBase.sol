// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Vm} from "forge-std/Vm.sol";
import {Test, console} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Strings} from "../libs/Strings.sol";
import {Executor} from "../../src/Executor.sol";
import {Vault} from "../../src/Vault.sol";

struct TestConfig {
    IERC20 USDC;
}

abstract contract TestBase is Test {
    using stdJson for *;
    using Strings for *;

    Executor executor;
    Vault vault;

    TestConfig baseConfig;

    uint256 constant userPrivateKey = 123;
    address immutable user = vm.addr(userPrivateKey);
    address immutable owner = makeAddr("OWNER");

    //! For caching fork data, the block number is required
    string INFURA = vm.envString("INFURA_KEY_API");
    string ALCHEMY = vm.envString("ALCHEMY_KEY_API");

    uint256 immutable mainnetFork = vm.createFork(string.concat("https://mainnet.infura.io/v3/", INFURA), 21786590);
    uint256 immutable baseSepoliaFork =
        vm.createFork(string.concat("https://base-sepolia.infura.io/v3/", INFURA), 21533254);
    uint256 immutable holeskyFork =
        vm.createFork(string.concat("https://eth-holesky.g.alchemy.com/v2/", ALCHEMY), 3285618);

    function setUp() public virtual {
        bytes memory _config = _getConfig("vault");
        baseConfig = abi.decode(_config, (TestConfig));
    }

    function _approveTokens(IERC20 _token, address from, address spender, uint256 amount) internal {
        vm.prank(from);
        IERC20(_token).approve(spender, amount);
    }

    function _buildConfigPath(string memory contractName, uint256 chainId) private pure returns (string memory) {
        return string.concat("configs/", contractName, "/", chainId.toString(), ".json");
    }

    function _deployContracts() internal {
        vault = new Vault(owner, address(baseConfig.USDC));
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

    function _depositToVault(address caller, uint256 amount) internal {
        deal(address(baseConfig.USDC), caller, amount);

        vm.startPrank(caller);

        baseConfig.USDC.approve(address(vault), amount);
        vault.deposit(amount);

        vm.stopPrank();
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
