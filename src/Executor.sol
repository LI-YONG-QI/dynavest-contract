// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {IVault} from "./Vault.sol";
import {Multicall3} from "./Multicall3.sol";

contract Executor is Multicall3 {
    IVault public vault;

    constructor(address _vault) {
        vault = IVault(_vault);
    }

    function execute(Call[] calldata calls, address sender)
        public
        payable
        returns (uint256 blockNumber, bytes[] memory returnData)
    {
        require(vault.balances(sender) >= calls.length * 1e6, "Executor: insufficient balance"); //! 1 USDC = 1 TX by default

        // TODO transfer USDC to owner
        return aggregate(calls); //! send tx
    }
}
