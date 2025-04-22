// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {console} from "forge-std/console.sol";

import {IBeefyVaultV6} from "../src/interfaces/IBeefyVaultV6.sol";
import {IV3SwapRouter} from "./helpers/IV3SwapRouter.sol";
import {TestBase} from "./helpers/TestBase.sol";

// Note: Use the Uniswap config
contract GMXTest is TestBase {
    address constant BEEFY_VAULT = 0x5B904f19fb9ccf493b623e5c8cE91603665788b0;
    address constant GMX = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;

    uint256 constant INIT_SUPPLY = 10 * 1e18;

    function setUp() public override {
        vm.selectFork(arbitrumFork);

        super.setUp();
        _deployContracts();
    }

    function test_depositBeefyVaultWithGMX() public {
        uint256 beforeMooGMX = IERC20(BEEFY_VAULT).balanceOf(user);
        uint256 depositAmount = 1 ether;
        deal(GMX, user, depositAmount);

        vm.startPrank(user);
        IERC20(GMX).approve(BEEFY_VAULT, depositAmount);
        IBeefyVaultV6(BEEFY_VAULT).depositAll();
        vm.stopPrank();

        assertGt(IERC20(BEEFY_VAULT).balanceOf(user), beforeMooGMX);
    }

    function test_withdrawBeefyVaultWithETH() public {
        address TOKEN0 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        address TOKEN1 = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
        address ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
        uint256 amount0ToMint = 1 ether;

        deal(user, amount0ToMint + INIT_SUPPLY);

        vm.startPrank(user);

        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: TOKEN0,
            tokenOut: TOKEN1,
            fee: 10000,
            recipient: user,
            amountIn: amount0ToMint,
            amountOutMinimum: 0, //! 0 = no limit
            sqrtPriceLimitX96: 0 //! 0 = no limit
        });

        IV3SwapRouter(ROUTER).exactInputSingle{value: amount0ToMint}(params);
        IERC20(TOKEN1).approve(BEEFY_VAULT, IERC20(TOKEN1).balanceOf(user));
        IBeefyVaultV6(BEEFY_VAULT).depositAll();

        console.log(IERC20(BEEFY_VAULT).balanceOf(user));
        assertGt(IERC20(BEEFY_VAULT).balanceOf(user), 0);
    }
}
