// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapV3MintCallback {
    function uniswapV3MintCallback(uint256, uint256, bytes calldata) external;
}
