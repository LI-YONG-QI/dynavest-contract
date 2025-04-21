// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IXGrailToken is IERC20 {
    function allocate(address usageAddress, uint256 amount, bytes calldata usageData) external;
    function usageAllocations(address userAddress, address usageAddress) external view returns (uint256 allocation);

    function allocateFromUsage(address userAddress, uint256 amount) external;
    function convertTo(uint256 amount, address to) external;
    function convert(uint256 amount) external;
    function deallocateFromUsage(address userAddress, uint256 amount) external;

    function isTransferWhitelisted(address account) external view returns (bool);

    function approveUsage(address usage, uint256 amount) external;
}
