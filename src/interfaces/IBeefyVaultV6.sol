// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IBeefyVaultV6 is IERC20 {
    function deposit(uint256 _amount) external;
    function depositAll() external;

    function withdrawAll() external;
    function withdraw(uint256 _shares) external;
}
