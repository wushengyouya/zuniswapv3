// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mintable} from "./ERC20Mintable.sol";
import {UniswapV3Pool} from "../src/UniswapV3Pool.sol";

contract UniswapV3PoolTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;
    bool shouldTransferInCallback;

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool shouldTransferInCallback;
        bool mintLiquidity;
    }

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
        token0.mint(address(this), 1 ether);
        token1.mint(address(this), 5001 ether);
    }

    function testMintSuccess() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiquidity: true
        });

        (uint256 poolBalance0, uint256 poolBalance1) = setUpTestCase(params);
        uint256 expectedAmount0 = 0.998628802115141959 ether;
        uint256 expectedAmount1 = 5000209190920489524100 wei;

        assertEq(
            poolBalance0,
            expectedAmount0,
            "incorrect token0 deposited amount"
        );
        assertEq(
            poolBalance1,
            expectedAmount1,
            "incorrect token1 deposited amount"
        );
        assertEq(
            token0.balanceOf(address(pool)),
            expectedAmount0,
            "incorrect pool balance0"
        );
        assertEq(
            token1.balanceOf(address(pool)),
            expectedAmount1,
            "incorrect pool balance1"
        );

        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), params.lowerTick, params.upperTick)
        );
        uint128 posLiquidity = pool.positions(positionKey);
        assertEq(params.liquidity, posLiquidity);

        (bool tickInitialized, uint128 tickLiquidity) = pool.ticks(
            params.lowerTick
        );
        assertTrue(tickInitialized);
        assertEq(tickLiquidity, params.liquidity);

        (tickInitialized, tickLiquidity) = pool.ticks(params.upperTick);
        assertTrue(tickInitialized);
        assertEq(tickLiquidity, params.liquidity);

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(sqrtPriceX96, params.currentSqrtP, "invalid current sqrtP");
        assertEq(tick, params.currentTick);
        assertEq(
            pool.liquidity(),
            params.liquidity,
            "invalid current liquidity"
        );
    }

    // TODO: 测试输入不足时的情况
    function SwapInsufficientInputAmount() public {
        uint256 amountSpecified = 0.01 ether;
        // 添加流动性
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiquidity: true
        });

        (uint256 poolBalance0, uint256 poolBalance1) = setUpTestCase(params);

        token1.mint(address(this), 40 ether);
        // 授权pool
        token1.approve(address(pool), 40 ether);
        UniswapV3Pool.CallbackData memory data = UniswapV3Pool.CallbackData({
            token0: address(token0),
            token1: address(token1),
            payer: address(this)
        });
        vm.expectRevert(UniswapV3Pool.InsufficientInputAmount.selector);
        pool.swap(address(this), true, amountSpecified, abi.encode(data));
    }

    function testSwapBuyETH() public {
        uint256 amountSpecified = 42 ether;
        // 添加流动性
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5001 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiquidity: true
        });

        (uint256 poolBalance0, uint256 poolBalance1) = setUpTestCase(params);

        // usdc => ETH
        token1.mint(address(this), 42 ether);
        token1.approve(address(this), 42 ether);
        UniswapV3Pool.CallbackData memory data = UniswapV3Pool.CallbackData({
            token0: address(token0),
            token1: address(token1),
            payer: address(this)
        });
        // 转为int256与amount0Delta进行运算
        int256 balance0 = int256(token0.balanceOf(address(this)));
        uint256 balance1 = token1.balanceOf(address(this));
        // 执行交换
        // 转入 42 usdc,收到 ETH
        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            false,
            amountSpecified,
            abi.encode(data)
        );
        console.log(uint256(amount0Delta));
        assertEq(amount0Delta, -0.008396714242162445 ether, "invalid ETH out");
        assertEq(amount1Delta, 42 ether, "invalid USDC in");
        // FIXME:错误的写法 ✅
        // 在solidity中将一个负数强制转为uint256时,solidity会直接将其二进制补码解释为一个无符号整数
        // 例如：-1 的二进制补码是全 1，转为uint256后会变成2^256-1
        // 所以，将负数-0.008396714242162444 ether,转为uint256会得到下面这个非常大的数,实际上是2^256 - 0.008396714242162444 ether 的结果
        // 115792089237316195423570985008687907853269984665640564039457584007913129639935
        /*
             assertEq(
               uint256(balance0) + uint256(amount0Delta),
               token0.balanceOf(address(this)),
               "invalid token0 balance"
              );
         
         */
        // 验证sender
        assertEq(
            uint256(balance0 - amount0Delta),
            token0.balanceOf(address(this)),
            "invalid token0 balance"
        );

        assertEq(
            790809079510475900,
            token1.balanceOf(address(this)),
            "invalid token1 balance"
        );

        // 验证Pool
        assertEq(
            uint256(int256(poolBalance0) + amount0Delta),
            token0.balanceOf(address(pool)),
            "invalid pool balance0"
        );
        assertEq(
            uint256(int256(poolBalance1) + amount1Delta),
            token1.balanceOf(address(pool)),
            "invalid pool balance1"
        );

        // 验证tick,与价格
        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(
            sqrtPriceX96,
            5604469350942327889444743441197,
            "invalid current sqrtPriceX96"
        );
        assertEq(pool.liquidity(), params.liquidity);
    }

    function setUpTestCase(
        TestCaseParams memory params
    ) internal returns (uint256 poolBalance0, uint256 poolBalance1) {
        // 授权给自己,因为uniswapV3MintCallback方法
        token0.approve(address(this), 1 ether);
        token1.approve(address(this), 5001 ether);
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            params.currentSqrtP,
            params.currentTick
        );

        shouldTransferInCallback = params.shouldTransferInCallback;
        UniswapV3Pool.CallbackData memory data = UniswapV3Pool.CallbackData({
            token0: address(token0),
            token1: address(token1),
            payer: address(this)
        });
        if (params.mintLiquidity) {
            (poolBalance0, poolBalance1) = pool.mint(
                address(this),
                params.lowerTick,
                params.upperTick,
                params.liquidity,
                abi.encode(data)
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
            token0.transferFrom(extra.payer, msg.sender, uint256(amount0));
        }
        if (amount1 > 0) {
            // token1.transfer(msg.sender, uint256(amount1));
            token1.transferFrom(extra.payer, msg.sender, uint256(amount1));
        }
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        if (shouldTransferInCallback) {
            UniswapV3Pool.CallbackData memory extra = abi.decode(
                data,
                (UniswapV3Pool.CallbackData)
            );
            // token0.transfer(msg.sender, amount0);
            // token1.transfer(msg.sender, amount1);
            token0.transferFrom(extra.payer, msg.sender, amount0);
            token1.transferFrom(extra.payer, msg.sender, amount1);
        }
    }
}
