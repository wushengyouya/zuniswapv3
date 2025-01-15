// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IERC20} from "./interface/IERC20.sol";
import {UniswapV3Pool} from "./UniswapV3Pool.sol";

contract UniswapV3Manager {
    function mint(
        address _poolAddress,
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidity,
        bytes calldata data
    ) public {
        UniswapV3Pool(_poolAddress).mint(
            msg.sender,
            lowerTick,
            upperTick,
            liquidity,
            data
        );
    }

    function swap(
        address _poolAddress,
        bool zeroForOne,
        uint256 amountSpecified,
        bytes calldata data
    ) public {
        UniswapV3Pool(_poolAddress).swap(
            msg.sender,
            zeroForOne,
            amountSpecified,
            data
        );
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        UniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniswapV3Pool.CallbackData)
        );
        if (amount0 > 0) {
            // token0.transfer(msg.sender, uint256(amount0));
            IERC20(extra.token0).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount0)
            );
        }
        if (amount1 > 0) {
            // token1.transfer(msg.sender, uint256(amount1));
            IERC20(extra.token1).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount1)
            );
        }
    }

    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) public {
        UniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniswapV3Pool.CallbackData)
        );
        if (amount0 > 0) {
            // token0.transfer(msg.sender, uint256(amount0));
            IERC20(extra.token0).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount0)
            );
        }
        if (amount1 > 0) {
            // token1.transfer(msg.sender, uint256(amount1));
            IERC20(extra.token1).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount1)
            );
        }
    }
}
