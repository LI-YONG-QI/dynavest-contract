// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "v3-core/contracts/libraries/TickMath.sol";
import "v3-periphery/interfaces/ISwapRouter.sol";
import "v3-periphery/interfaces/INonfungiblePositionManager.sol";
import "v3-periphery/libraries/TransferHelper.sol";

interface ILiquidityExamples {
    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }
}

contract LiquidityExamples is IERC721Receiver, ILiquidityExamples {
    address public immutable TOKEN0;
    address public immutable TOKEN1;
    uint24 public constant poolFee = 3000;

    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    //  tokenId => Deposit
    mapping(uint256 => Deposit) public deposits;

    constructor(INonfungiblePositionManager _nonfungiblePositionManager, address _token0, address _token1) {
        TOKEN0 = _token0;
        TOKEN1 = _token1;
        nonfungiblePositionManager = _nonfungiblePositionManager;
    }

    function onERC721Received(address operator, address, uint256 tokenId, bytes calldata)
        external
        override
        returns (bytes4)
    {
        _createDeposit(operator, tokenId);
        return this.onERC721Received.selector;
    }

    function _createDeposit(address owner, uint256 tokenId) internal {
        (,, address token0, address token1,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
        deposits[tokenId] = Deposit(owner, liquidity, token0, token1);
    }

    function mintNewPosition(address user, uint256 amount0ToMint, uint256 amount1ToMint)
        external
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        {
            TransferHelper.safeTransferFrom(TOKEN0, user, address(this), amount0ToMint);
            TransferHelper.safeTransferFrom(TOKEN1, user, address(this), amount1ToMint);

            // Approve the position manager
            TransferHelper.safeApprove(TOKEN0, address(nonfungiblePositionManager), amount0ToMint);
            TransferHelper.safeApprove(TOKEN1, address(nonfungiblePositionManager), amount1ToMint);
        }

        // Set MIN_TICK and MAX_TICK => provide liquidity to the whole range
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: TOKEN0,
            token1: TOKEN1,
            fee: poolFee,
            tickLower: -887220,
            tickUpper: 887220,
            amount0Desired: amount0ToMint,
            amount1Desired: amount1ToMint,
            amount0Min: 0,
            amount1Min: 0,
            recipient: user,
            deadline: block.timestamp
        });

        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager.mint(params);
        _createDeposit(user, tokenId);

        // Remove allowance and refund in both assets.
        if (amount0 < amount0ToMint) {
            TransferHelper.safeApprove(TOKEN0, address(nonfungiblePositionManager), 0);
            uint256 refund0 = amount0ToMint - amount0;
            TransferHelper.safeTransfer(TOKEN0, user, refund0);
        }

        if (amount1 < amount1ToMint) {
            TransferHelper.safeApprove(TOKEN1, address(nonfungiblePositionManager), 0);
            uint256 refund1 = amount1ToMint - amount1;
            TransferHelper.safeTransfer(TOKEN1, user, refund1);
        }
    }

    function increaseLiquidity(uint256 tokenId, uint256 token0Amount, uint256 token1Amount) public {
        Deposit memory deposit = deposits[tokenId];

        {
            require(deposit.owner == address(this), "LiquidityExamples: INVALID_OWNER");

            // Approve the position manager
            TransferHelper.safeApprove(deposit.token0, address(nonfungiblePositionManager), token0Amount);
            TransferHelper.safeApprove(deposit.token1, address(nonfungiblePositionManager), token1Amount);
        }

        INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager
            .IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: token0Amount,
            amount1Desired: token1Amount,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });

        (uint128 liquidity, uint256 amount0, uint256 amount1) = nonfungiblePositionManager.increaseLiquidity(params);

        deposits[tokenId].liquidity += liquidity;

        // Remove allowance and refund in both assets.
        if (amount0 < token0Amount) {
            TransferHelper.safeApprove(deposit.token0, address(nonfungiblePositionManager), 0);
            uint256 refund0 = token0Amount - amount0;
            TransferHelper.safeTransfer(deposit.token0, address(this), refund0);
        }

        if (amount1 < token1Amount) {
            TransferHelper.safeApprove(deposit.token1, address(nonfungiblePositionManager), 0);
            uint256 refund1 = token1Amount - amount1;
            TransferHelper.safeTransfer(deposit.token1, address(this), refund1);
        }
    }

    function getPosition(uint256 tokenId) external view returns (Deposit memory) {
        return deposits[tokenId];
    }
}
