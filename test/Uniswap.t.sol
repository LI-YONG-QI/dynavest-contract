// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Test, Vm} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IMulticall} from "v3-periphery/interfaces/IMulticall.sol";
import {INonfungiblePositionManager} from "v3-periphery/interfaces/INonfungiblePositionManager.sol";
import {IPeripheryPayments} from "v3-periphery/interfaces/IPeripheryPayments.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {PermitHash} from "permit2/src/libraries/PermitHash.sol";
import {PermitSignature} from "permit2/test/utils/PermitSignature.sol";

import {ILiquidityExamples, LiquidityExamples} from "./helpers/LiquidityExamples.sol";
import {IMulticall3} from "../src/interfaces/IMulticall3.sol";
import {TestBase} from "./helpers/TestBase.sol";
import {IV3SwapRouter} from "./helpers/IV3SwapRouter.sol";
import {SigUtils} from "./libs/SigUtils.sol";
import {Commands} from "./helpers/Commands.sol";
import {IUniversalRouter} from "./helpers/IUniversalRouter.sol";

struct UniswapConfig {
    IERC20 TOKEN0;
    IERC20 TOKEN1;
    address nftManager;
    address router;
    address universalRouter;
}

contract UniswapTest is TestBase, PermitSignature {
    LiquidityExamples liquidityRouter;
    UniswapConfig config;

    using PermitHash for IAllowanceTransfer.PermitSingle;

    uint256 constant INIT_SUPPLY = 10e18;
    uint24 constant FEE = 100;

    function _fund() internal {
        deal(address(config.TOKEN0), user, INIT_SUPPLY);
        deal(address(config.TOKEN1), user, INIT_SUPPLY);
    }

    function setUp() public override {
        vm.selectFork(baseFork);

        super.setUp();
        _deployContracts();

        bytes memory _config = _getConfig("uniswap");
        config = abi.decode(_config, (UniswapConfig));

        liquidityRouter = new LiquidityExamples(
            INonfungiblePositionManager(config.nftManager), address(config.TOKEN0), address(config.TOKEN1), FEE
        );

        _fund();
    }

    function test_AddLiquidityWithPermit() public {
        uint256 amount = 10e6;

        //* Introduce permit signature
        uint256 expiry = block.timestamp + 1000;
        SigUtils.Permit memory token0Permit =
            SigUtils.Permit({owner: user, spender: address(liquidityRouter), value: amount, nonce: 0, deadline: expiry});
        (uint8 token0PermitV, bytes32 token0PermitR, bytes32 token0PermitS) =
            SigUtils.sign(userPrivateKey, SigUtils.getPermitDigest(token0Permit, address(config.TOKEN0)));

        SigUtils.Permit memory token1Permit =
            SigUtils.Permit({owner: user, spender: address(liquidityRouter), value: amount, nonce: 0, deadline: expiry});
        (uint8 token1PermitV, bytes32 token1PermitR, bytes32 token1PermitS) =
            SigUtils.sign(userPrivateKey, SigUtils.getPermitDigest(token1Permit, address(config.TOKEN1)));

        //* Multicall
        IMulticall3.Call[] memory calls = new IMulticall3.Call[](3);

        calls[0] = IMulticall3.Call({
            target: address(config.TOKEN0),
            callData: abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                token0Permit.owner,
                token0Permit.spender,
                token0Permit.value,
                token0Permit.deadline,
                token0PermitV,
                token0PermitR,
                token0PermitS
            )
        });

        calls[1] = IMulticall3.Call({
            target: address(config.TOKEN1),
            callData: abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                token1Permit.owner,
                token1Permit.spender,
                token1Permit.value,
                token1Permit.deadline,
                token1PermitV,
                token1PermitR,
                token1PermitS
            )
        });

        calls[2] = IMulticall3.Call({
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

    function test_AddLiquidityWithNFTManager() public {
        // Note: parameters are from https://app.blocksec.com/explorer/tx/base/0x793c0add695f68aad2c6e6ead731127f6bc0f93b59bc6a7820935fe6cc5694cb?line=22
        uint256 amount0ToMint = 601933840884576;
        uint256 amount1ToMint = 10e6;

        vm.startPrank(user);
        IERC20(config.TOKEN0).approve(config.nftManager, amount0ToMint);
        IERC20(config.TOKEN1).approve(config.nftManager, amount1ToMint);

        INonfungiblePositionManager nftManager = INonfungiblePositionManager(config.nftManager);
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(config.TOKEN0),
            token1: address(config.TOKEN1),
            fee: FEE,
            tickLower: -887220,
            tickUpper: 887220,
            amount0Desired: amount0ToMint,
            amount1Desired: amount1ToMint,
            amount0Min: 0,
            amount1Min: 0,
            recipient: user,
            deadline: block.timestamp
        });

        nftManager.mint(params);
    }

    function test_AddLiquidityWithNFTManagerMultiCall() public {
        uint256 amount0ToMint = 601933840884576;
        uint256 amount1ToMint = 10e6;

        vm.startPrank(user);
        IERC20(config.TOKEN0).approve(config.nftManager, amount0ToMint);
        IERC20(config.TOKEN1).approve(config.nftManager, amount1ToMint);

        INonfungiblePositionManager nftManager = INonfungiblePositionManager(config.nftManager);
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(config.TOKEN0),
            token1: address(config.TOKEN1),
            fee: FEE,
            tickLower: -887220,
            tickUpper: 887220,
            amount0Desired: amount0ToMint,
            amount1Desired: amount1ToMint,
            amount0Min: 0,
            amount1Min: 0,
            recipient: user,
            deadline: block.timestamp
        });

        bytes memory mintCall = abi.encodeWithSelector(
            INonfungiblePositionManager.mint.selector,
            params.token0,
            params.token1,
            params.fee,
            params.tickLower,
            params.tickUpper,
            params.amount0Desired,
            params.amount1Desired,
            params.amount0Min,
            params.amount1Min,
            params.recipient,
            params.deadline
        );

        bytes memory refundCall = abi.encodeWithSelector(IPeripheryPayments.refundETH.selector, 0, user);

        bytes[] memory calls = new bytes[](2);
        calls[0] = mintCall;
        calls[1] = refundCall;

        IMulticall(config.nftManager).multicall(calls);
    }

    function test_AddLiquidityWithOneSideToken() public {
        uint256 amount0ToMint = 100e6 / 2;
        // uint256 beforeToken1Balance = IERC20(config.TOKEN1).balanceOf(user);

        vm.startPrank(user);
        IERC20(config.TOKEN0).approve(config.router, amount0ToMint);

        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: address(config.TOKEN0),
            tokenOut: address(config.TOKEN1),
            fee: FEE,
            recipient: user,
            amountIn: amount0ToMint,
            amountOutMinimum: 0, //! 0 = no limit
            sqrtPriceLimitX96: 0 //! 0 = no limit
        });

        (uint256 amountOut) = IV3SwapRouter(config.router).exactInputSingle(params);

        IERC20(config.TOKEN1).approve(config.nftManager, amountOut);
        IERC20(config.TOKEN0).approve(config.nftManager, amount0ToMint);

        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            token0: address(config.TOKEN0),
            token1: address(config.TOKEN1),
            fee: FEE,
            tickLower: -887220,
            tickUpper: 887220,
            amount0Desired: amount0ToMint,
            amount1Desired: amountOut,
            amount0Min: 0,
            amount1Min: 0,
            recipient: user,
            deadline: block.timestamp
        });

        bytes memory mintCall = abi.encodeWithSelector(
            INonfungiblePositionManager.mint.selector,
            mintParams.token0,
            mintParams.token1,
            mintParams.fee,
            mintParams.tickLower,
            mintParams.tickUpper,
            mintParams.amount0Desired,
            mintParams.amount1Desired,
            mintParams.amount0Min,
            mintParams.amount1Min,
            mintParams.recipient,
            mintParams.deadline
        );

        bytes[] memory calls = new bytes[](1);
        calls[0] = mintCall;

        vm.startPrank(user);
        IMulticall(config.nftManager).multicall(calls);
    }

    function test_Permit2Permit() public {
        uint256 amount0ToMint = INIT_SUPPLY / 2;
        address spender = address(this);

        IPermit2 permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3); // TODO: hardcode
        vm.prank(user);
        IERC20(config.TOKEN0).approve(address(permit2), type(uint256).max);

        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(config.TOKEN0),
                amount: uint160(amount0ToMint),
                expiration: uint48(block.timestamp + 10000),
                nonce: 0
            }),
            spender: spender,
            sigDeadline: block.timestamp + 10000
        });

        bytes32 DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();
        bytes memory sig = PermitSignature.getPermitSignature(permitSingle, userPrivateKey, DOMAIN_SEPARATOR);

        permit2.permit(user, permitSingle, sig);
        (uint160 amount, uint48 expiration, uint48 nonce) = permit2.allowance(user, address(config.TOKEN0), spender);

        assertEq(amount, amount0ToMint);
        assertEq(expiration, permitSingle.details.expiration);
        assertEq(nonce, 1);

        permit2.transferFrom(user, address(config.router), amount, address(config.TOKEN0));
    }

    function test_PermitAndSwapTokenWithUniversalRouter() public {
        uint256 amount0ToMint = INIT_SUPPLY / 2;
        IPermit2 permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3); // TODO: hardcode

        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.PERMIT2_PERMIT)), bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));

        vm.prank(user);
        IERC20(config.TOKEN0).approve(address(permit2), type(uint256).max);

        // Note: permit command input (permit2)
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(config.TOKEN0),
                amount: uint160(amount0ToMint),
                expiration: uint48(block.timestamp + 10000),
                nonce: 0
            }),
            spender: address(config.universalRouter),
            sigDeadline: block.timestamp + 10000
        });
        bytes32 DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();
        bytes memory sig = PermitSignature.getPermitSignature(permitSingle, userPrivateKey, DOMAIN_SEPARATOR);

        // Note: swap command input
        // address[] memory path = new address[](2);
        // path[0] = address(config.TOKEN0);
        // path[1] = address(config.TOKEN1);

        bytes memory path = abi.encodePacked(address(config.TOKEN0), uint24(100), address(config.TOKEN1));
        bytes memory swapCall = abi.encode(address(this), amount0ToMint, 0, path, true);

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(permitSingle, sig);
        inputs[1] = swapCall;

        vm.prank(user);
        IUniversalRouter(config.universalRouter).execute(commands, inputs, block.timestamp + 10000);
    }
}
