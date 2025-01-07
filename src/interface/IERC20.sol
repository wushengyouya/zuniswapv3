// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function approve(address, uint256) external;

    function balanceOf(address) external returns (uint256);

    function transfer(address, uint256) external;

    function transferFrom(address, address, uint256) external;
}
