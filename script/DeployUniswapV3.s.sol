// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Script, console} from "forge-std/Script.sol";
import {UniswapV3Pool} from "../src/UniswapV3Pool.sol";
import {UniswapV3Manager} from "../src/UniswapV3Manager.sol";
import {ERC20Mintable} from "../test/ERC20Mintable.sol";

contract DeployUniswapV3 is Script {
    uint256 wethBalance = 1 ether;
    uint256 usdcBalance = 5042 ether;
    int24 currentTick = 85176;
    uint160 currentSqrtP = 5602277097478614198912276234240;

    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Manager manager;
    UniswapV3Pool pool;

    function run() external returns (UniswapV3Manager, UniswapV3Pool) {
        vm.startBroadcast();
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
        token0.mint(msg.sender, wethBalance);
        token1.mint(msg.sender, usdcBalance);
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            currentSqrtP,
            currentTick
        );
        manager = new UniswapV3Manager();
        vm.stopBroadcast();
        console.log("Token0 addr: ", address(token0));
        console.log("Token1 addr: ", address(token1));
        console.log("UniswapV3Manager: ", address(manager));
        console.log("UniswapV3Pool: ", address(pool));
        return (manager, pool);
    }
}
