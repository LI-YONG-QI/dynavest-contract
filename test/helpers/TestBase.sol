// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Vm} from "forge-std/Vm.sol";
import {Test, console} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Strings} from "../libs/Strings.sol";
import {Executor} from "../../src/Executor.sol";
import {SigUtils} from "../libs/SigUtils.sol";
import {IMulticall3} from "../../src/interfaces/IMulticall3.sol";

abstract contract TestBase is Test {
    using stdJson for *;
    using Strings for *;

    Executor executor;

    uint256 constant userPrivateKey = 123;

    address immutable user = vm.addr(userPrivateKey);
    address immutable owner = makeAddr("OWNER");
    address immutable MULTICALL3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    //! For caching fork data, the block number is required
    string INFURA = vm.envString("INFURA_API_KEY");
    string ALCHEMY = vm.envString("ALCHEMY_API_KEY");

    uint256 immutable mainnetFork = vm.createFork(string.concat("https://mainnet.infura.io/v3/", INFURA), 21786590);
    uint256 immutable baseSepoliaFork =
        vm.createFork(string.concat("https://base-sepolia.infura.io/v3/", INFURA), 21533254);
    uint256 immutable holeskyFork =
        vm.createFork(string.concat("https://eth-holesky.g.alchemy.com/v2/", ALCHEMY), 3285618);
    uint256 immutable sonicFork =
        vm.createFork(string.concat("https://sonic-mainnet.g.alchemy.com/v2/", ALCHEMY), 12436736);
    uint256 immutable flowTestnetFork =
        vm.createFork(string.concat("https://flow-testnet.g.alchemy.com/v2/", ALCHEMY), 40221150);
    uint256 immutable flowFork =
        vm.createFork(string.concat("https://flow-mainnet.g.alchemy.com/v2/", ALCHEMY), 22696707);
    uint256 immutable celoFork =
        vm.createFork(string.concat("https://celo-mainnet.g.alchemy.com/v2/", ALCHEMY), 31884686);
    uint256 immutable baseFork =
        vm.createFork(string.concat("https://base-mainnet.g.alchemy.com/v2/", ALCHEMY), 28924840);
    uint256 immutable arbitrumFork =
        vm.createFork(string.concat("https://arb-mainnet.g.alchemy.com/v2/", ALCHEMY), 328919665);

    function setUp() public virtual {}

    function _approveTokens(IERC20 _token, address from, address spender, uint256 amount) internal {
        vm.prank(from);
        IERC20(_token).approve(spender, amount);
    }

    function _buildConfigPath(string memory contractName, uint256 chainId) private pure returns (string memory) {
        return string.concat("configs/", contractName, "/", chainId.toString(), ".json");
    }

    function _deployContracts() internal {
        executor = new Executor();

        _label();
    }

    function _getConfig(string memory contractName) internal view returns (bytes memory) {
        string memory configJson = vm.readFile(_buildConfigPath(contractName, block.chainid));
        return vm.parseJson(configJson);
    }

    function _label() private {
        vm.label(user, "user");
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

    /// @notice build permit call in calls array
    /// @dev permit call will exist in 0 index of calls array
    function _callPermit(
        IMulticall3.Call[] memory calls,
        uint256 index,
        uint256 ownerPrivateKey,
        address token,
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _deadline
    ) internal view {
        SigUtils.Permit memory permit =
            SigUtils.Permit({owner: _owner, spender: _spender, value: _value, nonce: _nonce, deadline: _deadline});
        (uint8 v, bytes32 r, bytes32 s) = SigUtils.sign(ownerPrivateKey, SigUtils.getPermitDigest(permit, token));

        calls[index] = IMulticall3.Call({
            target: token,
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
    }

    function _callPermitAndTransfer(
        IMulticall3.Call[] memory calls,
        uint256 index,
        uint256 ownerPrivateKey,
        address token,
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _deadline
    ) internal view {
        //* Introduce permit signature
        SigUtils.Permit memory permit =
            SigUtils.Permit({owner: _owner, spender: _spender, value: _value, nonce: _nonce, deadline: _deadline});
        (uint8 v, bytes32 r, bytes32 s) = SigUtils.sign(ownerPrivateKey, SigUtils.getPermitDigest(permit, token));

        calls[index] = IMulticall3.Call({
            target: token,
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

        calls[index + 1] = IMulticall3.Call({
            target: token,
            callData: abi.encodeWithSignature("transferFrom(address,address,uint256)", _owner, _spender, _value)
        });
    }
}
