// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Multicall3} from "multicall/Multicall3.sol";
import {TickMath} from "v3-core/contracts/libraries/TickMath.sol";
import {INonfungiblePositionManager} from "v3-periphery/interfaces/INonfungiblePositionManager.sol";

import {ILiquidityExamples, LiquidityExamples} from "./helpers/LiquidityExamples.sol";
import {TestBase} from "./helpers/TestBase.sol";

struct UniswapConfig {
    IERC20 DAI;
    IERC20 USDC;
    address nftManager;
}

contract UniswapTest is TestBase {
    LiquidityExamples liquidity;
    UniswapConfig config;

    function setUp() public {
        vm.selectFork(mainnetFork);

        _deployContracts();

        bytes memory _config = _getConfig("uniswap");
        config = abi.decode(_config, (UniswapConfig));

        liquidity = new LiquidityExamples(INonfungiblePositionManager(config.nftManager));
        deal(address(config.DAI), user, 1000e6);
        deal(address(config.USDC), user, 1000e6);
    }

    function testUniswapLiquidity() public {
        //! Transfer config to LiquidityExamples
        // TODO: Need to modify the liquidity router contract

        deal(address(config.DAI), address(liquidity), 10 ether);
        deal(address(config.USDC), address(liquidity), 10 ether);

        Multicall3.Call[] memory calls = new Multicall3.Call[](1);
        calls[0] = Multicall3.Call({
            target: address(liquidity),
            callData: abi.encodeWithSignature("mintNewPosition(uint256,uint256)", 100e6, 100e6)
        });

        vm.recordLogs();
        executor.execute(calls, address(liquidity));

        Vm.Log memory e = _getLogs(keccak256("IncreaseLiquidity(uint256,uint128,uint256,uint256)"));
        uint256 configId = uint256(e.topics[1]);
        ILiquidityExamples.Deposit memory deposit = liquidity.getPosition(configId);
        console.log(deposit.owner);
    }
}
