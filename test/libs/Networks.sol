// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

contract Networks {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string INFURA = vm.envString("INFURA_API_KEY");
    string ALCHEMY = vm.envString("ALCHEMY_API_KEY");

    uint256 immutable mainnetFork = vm.createFork(string.concat("https://mainnet.infura.io/v3/", INFURA), 21786590);
    uint256 immutable baseSepoliaFork =
        vm.createFork(string.concat("https://base-sepolia.infura.io/v3/", INFURA), 21533254);
    uint256 immutable holeskyFork =
        vm.createFork(string.concat("https://eth-holesky.g.alchemy.com/v2/", ALCHEMY), 3285618);
}
