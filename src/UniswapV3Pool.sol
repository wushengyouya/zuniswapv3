// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Tick} from "./lib/Tick.sol";
import {Position} from "./lib/Position.sol";
import {IUniswapV3MintCallback} from "./interface/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "./interface/IUniswapV3SwapCallback.sol";
import {IERC20} from "./interface/IERC20.sol";

// spdx, pragma, import, interface, libraries, contracts
// error, type declarations, state variables, events, modifer
// Constructor, receive, fallback, external, public, internal, private, view and pure functions
contract UniswapV3Pool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    /*//////////////////////////////////////////////////////////////
                                errors
    //////////////////////////////////////////////////////////////*/
    error InvalidTickRange();
    error ZeroLiquidity();
    error InsufficientInputAmount();

    /*//////////////////////////////////////////////////////////////
                          type declarations
    //////////////////////////////////////////////////////////////*/
    // Packing variables that are read together, and save gas
    struct Slot0 {
        // current price
        uint160 sqrtPriceX96;
        // current tick
        int24 tick;
    }
    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }
    /*//////////////////////////////////////////////////////////////
                           state variables
    //////////////////////////////////////////////////////////////*/
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    // Pool tokens, immutable
    address public immutable token0;
    address public immutable token1;

    Slot0 public slot0;

    // amount of liquidity, L
    uint128 public liquidity;

    // Tick info
    mapping(int24 => Tick.Info) public ticks;
    // position info
    mapping(bytes32 => Position.Info) public positions;

    /*//////////////////////////////////////////////////////////////
                                events
    //////////////////////////////////////////////////////////////*/
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );
    event Swap(
        address sender,
        address indexed recipient,
        int256 indexed amount0,
        int256 indexed amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    constructor(
        address _token0,
        address _token1,
        uint160 _sqrtPriceX96,
        int24 _tick
    ) {
        token0 = _token0;
        token1 = _token1;
        slot0 = Slot0({sqrtPriceX96: _sqrtPriceX96, tick: _tick});
    }

    function mint(
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1) {
        if (
            lowerTick >= upperTick ||
            lowerTick < MIN_TICK ||
            upperTick > MAX_TICK
        ) {
            revert InvalidTickRange();
        }

        if (amount == 0) {
            revert ZeroLiquidity();
        }

        // 添加流动的代币数量，当前为写死状态，后续会根据公式计算得出
        amount0 = 0.998976618347425280 ether;
        amount1 = 5000 ether;

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) {
            balance0Before = balance0();
        }
        if (amount1 > 0) {
            balance1Before = balance1();
        }
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(
            amount0,
            amount1,
            data
        );
        if (amount0 > 0 && balance0Before + amount0 > balance0()) {
            revert InsufficientInputAmount();
        }
        if (amount1 > 0 && balance1Before + amount1 > balance1()) {
            revert InsufficientInputAmount();
        }

        Position.Info storage posInfo = positions.get(
            owner,
            lowerTick,
            upperTick
        );
        posInfo.update(amount);

        ticks.update(lowerTick, amount);
        ticks.update(upperTick, amount);

        // 用户可能会增加token
        liquidity += amount;

        emit Mint(
            msg.sender,
            owner,
            lowerTick,
            upperTick,
            amount,
            amount0,
            amount1
        );
    }

    function swap(
        address recipient,
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1) {
        // 计算交换后的价格，当前为写死状态，后续通过公式计算得出
        int24 nextTick = 85184;
        uint160 nextPrice = 5604469350942327889444743441197;

        amount0 = -0.008396714242162444 ether;
        amount1 = 42 ether;

        // 更新slot的tick、sqrtPriceX96
        (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextPrice);

        IERC20(token0).transfer(recipient, uint256(-amount0));
        uint256 balance1Before = balance1();
        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
            amount0,
            amount1,
            data
        );

        if (balance1Before + uint256(amount1) < balance1()) {
            revert InsufficientInputAmount();
        }

        emit Swap(
            msg.sender,
            recipient,
            amount0,
            amount1,
            nextPrice,
            liquidity,
            nextTick
        );
    }

    function balance0() public returns (uint256) {
        return IERC20(token0).balanceOf(address(this));
    }

    function balance1() public returns (uint256) {
        return IERC20(token1).balanceOf(address(this));
    }
}
