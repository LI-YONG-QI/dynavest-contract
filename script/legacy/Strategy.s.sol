pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";

import {Strategy} from "../../src/legacy/Strategy.sol";

contract ScriptExecutor is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        Strategy strategy = new Strategy();

        vm.stopBroadcast();

        console.log("Strategy deployed at:", address(strategy));
    }
}
