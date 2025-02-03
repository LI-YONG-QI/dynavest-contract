// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface IVault {
    function balances(address) external view returns (uint256);

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;
}

contract Vault {
    IERC20 public immutable USDC;

    mapping(address => uint256) public balances;

    constructor(address _usdc) {
        USDC = IERC20(_usdc);
    }

    function deposit(uint256 amount) external {
        USDC.transferFrom(msg.sender, address(this), amount);

        balances[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Vault: insufficient balance");
        USDC.transfer(msg.sender, amount);

        balances[msg.sender] -= amount;
    }
}
