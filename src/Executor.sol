// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {IMulticall3} from "./interfaces/IMulticall3.sol";
import {Multicall3} from "./Multicall3.sol";

contract Executor is Multicall3 {
    event Executed(address indexed sender, uint256 blockNumber, bytes[] returnData);

    function execute(Multicall3.Call[] calldata calls, address sender)
        public
        payable
        returns (uint256, bytes[] memory)
    {
        // TODO execution fee
        (uint256 blockNumber, bytes[] memory returnData) = aggregate(calls);

        emit Executed(sender, blockNumber, returnData);
        return (blockNumber, returnData);
    }
}
