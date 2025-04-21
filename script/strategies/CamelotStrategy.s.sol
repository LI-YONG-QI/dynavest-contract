// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";

import {CamelotStrategy} from "../../src/strategies/CamelotStrategy.sol";

contract CamelotStrategyScript is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        CamelotStrategy camelotStrategy = new CamelotStrategy();
        vm.stopBroadcast();

        console.log("CamelotStrategy deployed at:", address(camelotStrategy));
    }
}
