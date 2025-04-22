// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";

import {GMXStrategy} from "../../src/strategies/GMXStrategy.sol";

contract GMXStrategyScript is Script {
    function run() public {
        // Set the Beefy vault address
        address beefyVault = 0x5B904f19fb9ccf493b623e5c8cE91603665788b0; // Replace with the actual Beefy vault address

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        GMXStrategy gmxStrategy = new GMXStrategy(beefyVault);
        vm.stopBroadcast();

        console.log("GMXStrategy deployed at:", address(gmxStrategy));
    }
}
