pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";

import {Vault} from "../src/Vault.sol";
import {Executor} from "../src/Executor.sol";

contract ScriptVault is Script {
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; //? Base sepolia

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        Vault vault = new Vault(msg.sender, USDC);
        Executor executor = new Executor();

        vm.stopBroadcast();

        console.log("Vault deployed at:", address(vault));
        console.log("Executor deployed at:", address(executor));
    }
}
