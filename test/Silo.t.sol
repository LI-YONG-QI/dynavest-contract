// // SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.12;

// import {Test, console} from "forge-std/Test.sol";
// import {ISilo} from "silo-core/interfaces/ISilo.sol";
// import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
// import {IERC20} from "forge-std/interfaces/IERC20.sol";
// import {IUniversalRouter} from "./helpers/IUniversalRouter.sol";
// import {TestBase} from "./helpers/TestBase.sol";
// import {Multicall3} from "../src/Multicall3.sol";

// struct SiloConfig {
//     address silo0;
//     address silo1;
//     IERC20 stS;
//     IERC20 wS;
// }

// interface IERC20Permit {
//     function nonces(address owner) external view returns (uint256);
// }

// contract SiloTest is TestBase {
//     uint256 constant INIT_SUPPLY = 10_000 * 1e18;

//     address payable router = payable(0x92643Dc4F75C374b689774160CDea09A0704a9c2);
//     address internal constant MSG_SENDER = address(1);
//     bytes internal constant V3_SWAP_EXACT_IN = hex"00";

//     SiloConfig config;

//     function _depositAndBorrow(uint256 depositAsset, uint256 borrowAsset) internal returns (uint256) {
//         // Deposit stS
//         config.stS.approve(config.silo0, depositAsset);
//         ISilo(config.silo0).deposit(depositAsset, user);

//         // Borrow S
//         ISilo(config.silo1).borrow(borrowAsset, user, user);

//         return borrowAsset;
//     }

//     function setUp() public override {
//         vm.selectFork(sonicFork);

//         super.setUp();
//         _deployContracts();

//         bytes memory _config = _getConfig("silo");
//         config = abi.decode(_config, (SiloConfig));
//     }

//     function test_borrowRecursion() public {
//         _depositToVault(user, 5e6);

//         uint256 deadline = block.timestamp + 10000;
//         uint256 depositAssets = 100 * 1e18;

//         deal(address(config.stS), user, depositAssets);
//         deal(address(config.wS), user, 0);

//         vm.startPrank(user);

//         // ROUND 1
//         // Deposit stS
//         uint256 borrowAssets = depositAssets / 100;
//         _depositAndBorrow(depositAssets, borrowAssets);

//         // Swap wS to stS
//         config.wS.approve(router, borrowAssets);
//         bytes[] memory inputs = new bytes[](1);
//         bytes memory path = hex"039e2fb66102314ce7b64ce5ce3e5183bc94ad38000001e5da20f15420ad15de0fa650600afc998bbe3955"; // Hardcode wS -> stS path
//         inputs[0] = abi.encode(vm.addr(99999), borrowAssets, 0, path, true);

//         IUniversalRouter(router).execute(V3_SWAP_EXACT_IN, inputs, deadline);

//         vm.stopPrank();
//     }

//     // TODO: Permit error
//     function test_borrowRecursionWithCalls() public {
//         _depositToVault(user, 10e6);

//         uint256 deadline = block.timestamp + 10000;
//         uint256 depositAssets = 100 * 1e18;
//         uint256 borrowAssets = depositAssets / 100;

//         deal(address(config.stS), user, depositAssets);
//         deal(address(config.wS), user, 0);

//         Multicall3.Call[] memory calls = new Multicall3.Call[](6);
//         _callPermitAndTransfer(
//             calls, 0, userPrivateKey, address(config.stS), user, address(executor), depositAssets, 0, deadline
//         );
//         calls[2] = Multicall3.Call({
//             target: address(config.stS),
//             callData: abi.encodeWithSignature("approve(address,uint256)", config.silo0, depositAssets)
//         });
//         calls[3] = Multicall3.Call({
//             target: address(config.silo0),
//             callData: abi.encodeWithSignature("deposit(uint256,address)", depositAssets, user)
//         });
//         _callPermit(
//             calls,
//             4,
//             userPrivateKey,
//             0x74477D70453213Dc1484503dABCDb64f9146884d,
//             user,
//             address(executor),
//             borrowAssets,
//             0,
//             deadline
//         );
//         calls[5] = Multicall3.Call({
//             target: address(config.silo1),
//             callData: abi.encodeWithSignature("borrow(uint256,address,address)", borrowAssets, user, user)
//         });

//         executor.execute(calls, user);
//     }

//     function test_swap() public {
//         _depositToVault(user, 10e6);
//         uint256 swapAmount = 1 * 1e18;
//         uint256 deadline = block.timestamp + 10000;

//         deal(address(config.stS), user, swapAmount);

//         Multicall3.Call[] memory calls = new Multicall3.Call[](4);

//         _callPermitAndTransfer(
//             calls, 0, userPrivateKey, address(config.stS), user, address(executor), swapAmount, 0, deadline
//         );

//         calls[2] = Multicall3.Call({
//             target: address(config.stS),
//             callData: abi.encodeWithSignature("approve(address,uint256)", router, swapAmount)
//         });

//         bytes[] memory inputs = new bytes[](1);
//         bytes memory path = hex"e5da20f15420ad15de0fa650600afc998bbe3955000001039e2fb66102314ce7b64ce5ce3e5183bc94ad38"; // Hardcode stS -> wS path
//         inputs[0] = abi.encode(user, swapAmount, 0, path, true);
//         calls[3] = Multicall3.Call({
//             target: address(router),
//             callData: abi.encodeWithSignature("execute(bytes,bytes[],uint256)", V3_SWAP_EXACT_IN, inputs, deadline)
//         });

//         executor.execute(calls, user);
//         assertGt(config.wS.balanceOf(user), 0);
//     }

//     //  vm.startPrank(user);

//     //     // Swap wS to stS
//     //     config.wS.approve(router, swapAmount);
//     //     bytes[] memory inputs = new bytes[](1);
//     //     // Hardcode wS -> stS path
//     //     bytes memory path = hex"039e2fb66102314ce7b64ce5ce3e5183bc94ad38000001e5da20f15420ad15de0fa650600afc998bbe3955";
//     //     inputs[0] = abi.encode(user, swapAmount, 0, path, true);
//     //     IUniversalRouter(router).execute(V3_SWAP_EXACT_IN, inputs, deadline);

//     //     vm.stopPrank();
// }
