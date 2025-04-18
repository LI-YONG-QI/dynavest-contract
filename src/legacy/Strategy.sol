// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";

contract Strategy is IStrategy {
    // TODO: Flow EVM Mainnet Hardcoded
    address immutable KITTY = 0x7296a9C350cad25fc69B47Ec839DCf601752C3C2;
    address immutable ANKR_CORE = 0xFE8189A3016cb6A3668b8ccdAC520CE572D4287a;
    address immutable ankrFLOWToken = 0x1b97100eA1D7126C4d60027e231EA4CB25314bdb;
    address immutable LPToken = 0x7296a9C350cad25fc69B47Ec839DCf601752C3C2;

    function execute() external payable {
        (bool stakeSuccess,) = ANKR_CORE.call{value: msg.value}(abi.encodeWithSelector(0xac76d450)); // liquid staking FLOW
        require(stakeSuccess, "Failed to stake ANKR");
        uint256 ankrFlowBalance = IERC20(ankrFLOWToken).balanceOf(address(this));

        IERC20(ankrFLOWToken).approve(KITTY, ankrFlowBalance);

        uint256[2] memory amounts = [uint256(0), ankrFlowBalance];
        (bool success,) = KITTY.call(abi.encodeWithSelector(0x0c3e4b54, amounts, 0, msg.sender)); // add liquidity
        require(success, "Failed to add liquidity");
    }
}
