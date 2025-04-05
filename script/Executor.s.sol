pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";

import {Executor} from "../src/Executor.sol";

contract ScriptExecutor is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        Executor executor = new Executor();

        vm.stopBroadcast();

        console.log("Executor deployed at:", address(executor));
    }
}
