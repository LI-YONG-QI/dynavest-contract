// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {INonfungiblePositionManager} from "v3-periphery/interfaces/INonfungiblePositionManager.sol";

import {LiquidityExamples} from "../test/helpers/LiquidityExamples.sol";

struct UniswapConfig {
    IERC20 TOKEN0;
    IERC20 TOKEN1;
    address nftManager;
}

contract LiquidityRouter is Script {
    LiquidityExamples liquidityRouter;

    address constant NFT_MANAGER = 0x3d79EdAaBC0EaB6F08ED885C05Fc0B014290D95A; // TODO: only for celo
    address constant TOKEN0 = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C; // TODO: only for celo
    address constant TOKEN1 = 0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73; // TODO: only for celo
    uint24 constant FEE = 100;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        liquidityRouter = new LiquidityExamples(INonfungiblePositionManager(NFT_MANAGER), TOKEN0, TOKEN1, FEE);

        vm.stopBroadcast();

        console.log("LiquidityRouter deployed at:", address(liquidityRouter));
    }
}
