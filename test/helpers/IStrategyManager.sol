// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface IStrategyManager {
    function depositIntoStrategy(address strategy, IERC20 token, uint256 amount) external;

    function nonces(address owner) external view returns (uint256);

    function stakerStrategyShares(address staker, address strategy) external view returns (uint256);

    function domainSeparator() external view returns (bytes32);

    function depositIntoStrategyWithSignature(
        address strategy,
        address token,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external;
}
