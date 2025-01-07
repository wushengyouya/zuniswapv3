// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(int256, int256, bytes calldata) external;
}
