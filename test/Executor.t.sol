// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Multicall3} from "multicall/Multicall3.sol";
import {IMorpho, MarketParams, IMorphoStaticTyping, Id} from "morpho-blue/src/interfaces/IMorpho.sol";
import {TickMath} from "v3-core/contracts/libraries/TickMath.sol";
import "v3-periphery/interfaces/INonfungiblePositionManager.sol";

import {Executor} from "../src/Executor.sol";
import {Vault} from "../src/Vault.sol";
import {ILiquidityExamples, LiquidityExamples} from "./helpers/LiquidityExamples.sol";
import {SigUtils} from "./libs/SigUtils.sol";
import {MorphoLib} from "./libs/MorphoLib.sol";

interface IStrategyManager {
    function depositIntoStrategy(address strategy, IERC20 token, uint256 amount) external;

    function nonces(address owner) external view returns (uint256);

    function stakerStrategyShares(address staker, address strategy) external view returns (uint256);

    function domainSeparator() external view returns (bytes32);

    function depositIntoStrategyWithSignature(
        address strategy,
        address token,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external;
}

contract ExecutorTest is Test {
    Executor executor;
    Vault vault;
    LiquidityExamples liquidity;

    //* Tokens
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 constant cbETH = IERC20(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);
    IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    //* Users
    uint256 constant userPrivateKey = 123;
    address user = vm.addr(userPrivateKey);

    //* Protocols *//

    //* Eigen
    address cbETHStrategy = 0x54945180dB7943c0ed0FEE7EdaB2Bd24620256bc;
    address manager = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;

    //* Morpho
    address morphoBlue = MorphoLib.MORPHO_BLUE;

    //* Uniswap
    address nftManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    function _beforeExecute() internal {
        vm.startBroadcast(user);

        USDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopBroadcast();
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

    function setUp() public {
        vault = new Vault(address(USDC));
        executor = new Executor(address(vault));
        liquidity = new LiquidityExamples(INonfungiblePositionManager(nftManager));

        vm.label(user, "user");
        vm.label(cbETHStrategy, "stETHStrategy");
        vm.label(morphoBlue, "morphoBlue");
        vm.label(address(liquidity), "liquidity");
        vm.label(address(vault), "vault");
        vm.label(address(executor), "executor");

        deal(address(USDC), user, 1000e6);
        deal(address(cbETH), user, 1000e6);
        deal(address(DAI), user, 1000e6);
    }

    function testEigenCall() public {
        _beforeExecute();

        //* Introduce signature
        uint256 expiry = block.timestamp + 1000;
        SigUtils.Deposit memory cbETHDeposit = SigUtils.Deposit({
            strategy: cbETHStrategy,
            token: address(cbETH),
            amount: 100e6,
            staker: user,
            expiry: expiry
        });
        bytes memory depositSig =
            SigUtils.signAggregate(userPrivateKey, SigUtils.getDepositDigest(cbETHDeposit, manager));

        SigUtils.Permit memory permit =
            SigUtils.Permit({owner: user, spender: address(executor), value: 100e6, nonce: 0, deadline: expiry});
        (uint8 v, bytes32 r, bytes32 s) =
            SigUtils.sign(userPrivateKey, SigUtils.getPermitDigest(permit, address(cbETH)));

        //* Multicall
        Multicall3.Call[] memory calls = new Multicall3.Call[](4);
        calls[0] = Multicall3.Call({
            target: address(cbETH),
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
            target: address(cbETH),
            callData: abi.encodeWithSignature("transferFrom(address,address,uint256)", user, address(executor), 100e6)
        });

        calls[2] = Multicall3.Call({
            target: address(cbETH),
            callData: abi.encodeWithSignature("approve(address,uint256)", manager, 100e6)
        });

        calls[3] = Multicall3.Call({
            target: address(manager),
            callData: abi.encodeWithSignature(
                "depositIntoStrategyWithSignature(address,address,uint256,address,uint256,bytes)",
                cbETHStrategy,
                address(cbETH),
                100e6,
                user,
                expiry,
                depositSig
            )
        });

        executor.execute(calls, user);
    }

    //* Supply directly USDC to cbETH/USDC market
    function testMorphoCall() public {
        _beforeExecute();
        uint256 amount = 5e6;
        bytes32 marketId = 0x64d65c9a2d91c36d56fbc42d69e979335320169b3df63bf92789e2c8883fcc64;

        MarketParams memory params = MorphoLib.getMarketParams(marketId);

        //* Introduce permit signature
        uint256 expiry = block.timestamp + 1000;
        SigUtils.Permit memory permit =
            SigUtils.Permit({owner: user, spender: address(executor), value: amount, nonce: 0, deadline: expiry});
        (uint8 v, bytes32 r, bytes32 s) = SigUtils.sign(userPrivateKey, SigUtils.getPermitDigest(permit, address(USDC)));

        //* Multicall
        Multicall3.Call[] memory calls = new Multicall3.Call[](4);

        // TODO: Use `MorphoCallback` to eliminate this pre-transfer step
        calls[0] = Multicall3.Call({
            target: address(USDC),
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
            target: address(USDC),
            callData: abi.encodeWithSignature("transferFrom(address,address,uint256)", user, executor, amount)
        });

        calls[2] = Multicall3.Call({
            target: address(USDC),
            callData: abi.encodeWithSignature("approve(address,uint256)", morphoBlue, amount)
        });

        calls[3] = Multicall3.Call({
            target: morphoBlue,
            callData: abi.encodeWithSignature(
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                params,
                amount,
                0,
                user,
                new bytes(0)
            )
        });
        executor.execute(calls, user);

        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(morphoBlue).position(Id.wrap(marketId), user);
        console.log("Supply Shares: %d", supplyShares);
        console.log("Borrow Shares: %d", borrowShares);
        console.log("Collateral: %d", collateral);
    }

    function testUniswapLiquidity() public {
        //! Transfer token to LiquidityExamples
        // TODO: Need to modify the liquidity router contract
        deal(address(DAI), address(liquidity), 10 ether);
        deal(address(USDC), address(liquidity), 10 ether);

        Multicall3.Call[] memory calls = new Multicall3.Call[](1);
        calls[0] = Multicall3.Call({
            target: address(liquidity),
            callData: abi.encodeWithSignature("mintNewPosition(uint256,uint256)", 100e6, 100e6)
        });

        vm.recordLogs();
        executor.execute(calls, address(liquidity));

        Vm.Log memory e = _getLogs(keccak256("IncreaseLiquidity(uint256,uint128,uint256,uint256)"));
        uint256 tokenId = uint256(e.topics[1]);
        ILiquidityExamples.Deposit memory deposit = liquidity.getPosition(tokenId);
        console.log(deposit.owner);
    }
}
