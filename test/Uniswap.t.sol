// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Multicall3} from "multicall/Multicall3.sol";
import {TickMath} from "v3-core/contracts/libraries/TickMath.sol";
import {INonfungiblePositionManager} from "v3-periphery/interfaces/INonfungiblePositionManager.sol";

import {ILiquidityExamples, LiquidityExamples} from "./helpers/LiquidityExamples.sol";
import {TestBase} from "./helpers/TestBase.sol";
import {SigUtils} from "./libs/SigUtils.sol";

struct UniswapConfig {
    IERC20 DAI;
    IERC20 USDC;
    address nftManager;
}

contract UniswapTest is TestBase {
    LiquidityExamples liquidityRouter;
    UniswapConfig config;

    function _fund() internal {
        deal(address(config.DAI), user, 1000e6);
        deal(address(config.USDC), user, 1000e6);
    }

    function setUp() public override {
        vm.selectFork(mainnetFork);

        super.setUp();
        _deployContracts();

        bytes memory _config = _getConfig("uniswap");
        config = abi.decode(_config, (UniswapConfig));

        liquidityRouter = new LiquidityExamples(
            INonfungiblePositionManager(config.nftManager), address(config.DAI), address(config.USDC)
        );
    }

    function testUniswapLiquidity() public {
        uint256 amount = 10e6;
        _depositToVault(user, 100e6);
        _fund();

        //* Introduce permit signature
        uint256 expiry = block.timestamp + 1000;
        SigUtils.Permit memory usdcPermit =
            SigUtils.Permit({owner: user, spender: address(liquidityRouter), value: amount, nonce: 0, deadline: expiry});
        (uint8 v, bytes32 r, bytes32 s) =
            SigUtils.sign(userPrivateKey, SigUtils.getPermitDigest(usdcPermit, address(config.USDC)));

        SigUtils.DaiPermit memory daiPermit = SigUtils.DaiPermit({
            owner: user,
            spender: address(liquidityRouter),
            nonce: 0,
            deadline: expiry,
            allowed: true
        });
        (uint8 daiV, bytes32 daiR, bytes32 daiS) =
            SigUtils.sign(userPrivateKey, SigUtils.getDaiPermitDigest(daiPermit, address(config.DAI)));

        //* Multicall
        Multicall3.Call[] memory calls = new Multicall3.Call[](3);
        calls[0] = Multicall3.Call({
            target: address(config.USDC),
            callData: abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                usdcPermit.owner,
                usdcPermit.spender,
                usdcPermit.value,
                usdcPermit.deadline,
                v,
                r,
                s
            )
        });

        calls[1] = Multicall3.Call({
            target: address(config.DAI),
            callData: abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32)",
                daiPermit.owner,
                daiPermit.spender,
                daiPermit.nonce,
                daiPermit.deadline,
                daiPermit.allowed,
                daiV,
                daiR,
                daiS
            )
        });

        calls[2] = Multicall3.Call({
            target: address(liquidityRouter),
            callData: abi.encodeWithSignature("mintNewPosition(address,uint256,uint256)", user, amount, amount)
        });

        vm.recordLogs();
        executor.execute(calls, address(user));

        //* Parse event
        Vm.Log memory e = _getLogs(keccak256("IncreaseLiquidity(uint256,uint128,uint256,uint256)"));
        uint256 configId = uint256(e.topics[1]);
        ILiquidityExamples.Deposit memory deposit = liquidityRouter.getPosition(configId);
        assertEq(deposit.owner, user);
    }
}
