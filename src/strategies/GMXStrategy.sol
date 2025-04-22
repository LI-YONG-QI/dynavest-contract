// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {IV3SwapRouter} from "../../test/helpers/IV3SwapRouter.sol";
import {IBeefyVaultV6} from "../interfaces/IBeefyVaultV6.sol";

// TODO: only for arb mainnet
contract GMXStrategy is Ownable {
    address public constant ETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant GMX = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
    address public constant UNISWAP_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    address public beefyVault;

    constructor(address _beefyVault) {
        beefyVault = _beefyVault;
    }

    function setBeefyVault(address _beefyVault) external onlyOwner {
        beefyVault = _beefyVault;
    }

    function depositToBeefyVaultWithETH() external payable {
        // Create swap parameters for ETH to GMX
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: ETH,
            tokenOut: GMX,
            fee: 10000,
            recipient: address(this),
            amountIn: msg.value,
            amountOutMinimum: 0, // No slippage protection
            sqrtPriceLimitX96: 0 // No price limit
        });

        // Execute swap
        IV3SwapRouter(UNISWAP_ROUTER).exactInputSingle{value: msg.value}(params);

        // Get GMX balance
        uint256 gmxBalance = IERC20(GMX).balanceOf(address(this));

        // Approve and deposit into Beefy Vault
        IERC20(GMX).approve(beefyVault, gmxBalance);
        IBeefyVaultV6(beefyVault).depositAll();

        // Transfer moo tokens to the sender
        uint256 mooTokenBalance = IERC20(beefyVault).balanceOf(address(this));
        IERC20(beefyVault).transfer(msg.sender, mooTokenBalance);
    }
}
