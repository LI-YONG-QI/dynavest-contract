// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {TestBase} from "./helpers/TestBase.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {console} from "forge-std/console.sol";
import {IYakRouter, Trade} from "./helpers/IYakRouter.sol";
import {IXGrailToken} from "./helpers/IXGrailToken.sol";

contract CamelotTest is TestBase {
    IYakRouter constant yakRouter = IYakRouter(0x99D4e80DB0C023EFF8D25d8155E0dCFb5aDDeC5E); // Example address
    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant GRAIL = 0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8;
    address constant xGRAIL = 0x3CAaE25Ee616f2C8E13C74dA0813402eae3F496b;
    address constant DividendsV2 = 0x5422AA06a38fd9875fc2501380b40659fEebD3bB;

    uint256 constant INIT_SUPPLY = 10 * 1e18;

    receive() external payable {}

    function setUp() public override {
        vm.selectFork(arbitrumFork);

        super.setUp();
        _deployContracts();

        deal(user, INIT_SUPPLY);
    }

    function test_SwapETHToGRAIL() public {
        uint256 amountIn = 0.000001 ether; //! avoid slippage
        Trade memory trade = _buildTradeParams(amountIn);

        vm.prank(user);
        yakRouter.swapNoSplitFromETH{value: amountIn}(trade, 0, user);

        assertGt(IERC20(GRAIL).balanceOf(user), 0);
    }

    function test_ConvertGRAILToxGRAIL() public {
        uint256 amountConvert = 1e18;
        deal(GRAIL, user, amountConvert);
        uint256 beforeBalance = IERC20(xGRAIL).balanceOf(user);

        vm.startPrank(user);
        IERC20(GRAIL).approve(xGRAIL, amountConvert);
        IXGrailToken(xGRAIL).convert(amountConvert);
        vm.stopPrank();

        assertGt(IERC20(xGRAIL).balanceOf(user), beforeBalance);
    }

    function test_AllocateXGrail() public {
        uint256 amountAllocate = 1e18;
        address usage = 0x5422AA06a38fd9875fc2501380b40659fEebD3bB;
        deal(xGRAIL, user, amountAllocate);

        vm.startPrank(user);
        IXGrailToken(xGRAIL).approveUsage(usage, amountAllocate);
        IXGrailToken(xGRAIL).allocate(usage, amountAllocate, new bytes(0));
        vm.stopPrank();

        assertEq(IERC20(xGRAIL).balanceOf(user), 0);
    }

    /// @notice Swap ETH to GRAIL -> convert GRAIL to xGRAIL -> allocate xGRAIL to usage
    function test_GRAILStrategyWithUser() public {
        uint256 amountIn = 0.000001 ether; //! avoid slippage
        address usage = DividendsV2;
        Trade memory trade = _buildTradeParams(amountIn);

        vm.startPrank(user);
        yakRouter.swapNoSplitFromETH{value: amountIn}(trade, 0, user);
        uint256 amountConvert = IERC20(GRAIL).balanceOf(user);
        IERC20(GRAIL).approve(xGRAIL, amountConvert);
        IXGrailToken(xGRAIL).convert(amountConvert);

        uint256 amountAllocate = IERC20(xGRAIL).balanceOf(user);
        IXGrailToken(xGRAIL).approveUsage(usage, amountAllocate);
        IXGrailToken(xGRAIL).allocate(usage, amountAllocate, new bytes(0));

        vm.stopPrank();
    }

    /// @notice Swap ETH to GRAIL -> convert GRAIL to xGRAIL -> allocate xGRAIL to usage
    function test_GRAILStrategyWithMultiCall() public {
        uint256 amountIn = 0.000001 ether; //! avoid slippage
        address usage = DividendsV2;
        Trade memory trade = _buildTradeParams(amountIn);

        vm.prank(user);
        (bool success,) = address(this).call{value: amountIn}("");
        require(success, "Transfer failed");

        // From this contract
        yakRouter.swapNoSplitFromETH{value: amountIn}(trade, 0, address(this));
        uint256 amountConvert = IERC20(GRAIL).balanceOf(address(this));
        IERC20(GRAIL).approve(xGRAIL, amountConvert);
        IXGrailToken(xGRAIL).convertTo(amountConvert, user);

        uint256 amountAllocate = IERC20(xGRAIL).balanceOf(user);
        vm.startPrank(user);
        IXGrailToken(xGRAIL).approveUsage(usage, amountAllocate);
        IXGrailToken(xGRAIL).allocate(usage, amountAllocate, new bytes(0));
        vm.stopPrank();

        assertEq(IERC20(xGRAIL).balanceOf(address(this)), 0);
        assertEq(IERC20(xGRAIL).balanceOf(user), 0);
    }

    /// @dev only support WETH -> GRAIL
    function _buildTradeParams(uint256 amountIn) internal pure returns (Trade memory trade) {
        address pair = 0xf82105aA473560CfBF8Cbc6Fd83dB14Eb4028117; // TODO: WETH-GRAIL Pair hardcode
        address adapter = 0x610934FEBC44BE225ADEcD888eAF7DFf3B0bc050; // TODO: hardcode

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = GRAIL;

        address[] memory adapters = new address[](1);
        adapters[0] = adapter;

        address[] memory recipients = new address[](1);
        recipients[0] = pair;

        return Trade({
            amountIn: amountIn,
            amountOut: 0, // no limit
            path: path,
            adapters: adapters,
            recipients: recipients
        });
    }
}
