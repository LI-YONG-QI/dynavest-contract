// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IYakRouter, Trade} from "../../test/helpers/IYakRouter.sol";
import {IXGrailToken} from "../../test/helpers/IXGRAILToken.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// TODO: only for arb mainnet
contract CamelotStrategy {
    IYakRouter constant yakRouter = IYakRouter(0x99D4e80DB0C023EFF8D25d8155E0dCFb5aDDeC5E);
    address constant GRAIL = 0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8;
    address constant xGRAIL = 0x3CAaE25Ee616f2C8E13C74dA0813402eae3F496b;

    function swapETHToXGrail(Trade memory trade, address user) external payable {
        yakRouter.swapNoSplitFromETH{value: msg.value}(trade, 0, address(this));

        uint256 amountConvert = IERC20(GRAIL).balanceOf(address(this));
        IERC20(GRAIL).approve(xGRAIL, amountConvert);
        IXGrailToken(xGRAIL).convertTo(amountConvert, user);
    }
}
