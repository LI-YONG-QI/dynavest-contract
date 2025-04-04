// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {IMulticall3} from "./interfaces/IMulticall3.sol";

contract Executor {
    IMulticall3 public multicall;

    constructor(address _multicall) {
        multicall = IMulticall3(_multicall);
    }

    function execute(IMulticall3.Call[] calldata calls, address sender)
        public
        payable
        returns (uint256 blockNumber, bytes[] memory returnData)
    {
        // TODO execution fee
        return multicall.aggregate(calls); //! send tx
    }

    
}
