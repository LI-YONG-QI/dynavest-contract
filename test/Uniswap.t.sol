// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IMulticall3} from "../src/interfaces/IMulticall3.sol";
import {TickMath} from "v3-core/contracts/libraries/TickMath.sol";
import {INonfungiblePositionManager} from "v3-periphery/interfaces/INonfungiblePositionManager.sol";

import {ILiquidityExamples, LiquidityExamples} from "./helpers/LiquidityExamples.sol";
import {TestBase} from "./helpers/TestBase.sol";
import {SigUtils} from "./libs/SigUtils.sol";

struct UniswapConfig {
    IERC20 TOKEN0;
    IERC20 TOKEN1;
    address nftManager;
}

contract UniswapTest is TestBase {
    LiquidityExamples liquidityRouter;
    UniswapConfig config;

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

    function testUniswapLiquidity() public {
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

    function test_AddLiquidityWithNFTManagerMultiCall() public {
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

        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = nftManager.mint(params);

        console.log("tokenId", tokenId);
        console.log("liquidity", liquidity);
        console.log("amount0", amount0);
        console.log("amount1", amount1);
    }
}
