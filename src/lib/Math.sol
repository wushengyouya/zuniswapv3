// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./FixedPoint96.sol";
import "./PRBMath.sol";

library Math {
    // src/lib/Math.sol
    // token x
    // (L * (sqrtUpper-sqrtLower)) /sqrtUpper * sqrtLower
    function calcAmount0Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        require(sqrtPriceAX96 > 0);

        amount0 = divRoundingUp(
            mulDivRoundingUp(
                (uint256(liquidity) << FixedPoint96.RESOLUTION), // liquidity * 2^96
                (sqrtPriceBX96 - sqrtPriceAX96),
                sqrtPriceBX96
            ),
            sqrtPriceAX96
        );
    }

    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = PRBMath.mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }

    // L (sqrtUpper - sqrtLower)
    // token y
    function calcAmount1Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        // mulmod 是Solidity的一个函数，将两个数 a 和 b 相乘，乘积除以 denominator，返回余数。如果余数为正，我们将结果上取整。
        amount1 = mulDivRoundingUp(
            liquidity,
            (sqrtPriceBX96 - sqrtPriceAX96),
            FixedPoint96.Q96
        );
    }

    function divRoundingUp(
        uint256 numerator,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        assembly {
            result := add(
                div(numerator, denominator),
                gt(mod(numerator, denominator), 0)
            )
        }
    }

    /**
     * sqrtPrice + (amountIn / L)
     * sqrtPriceX96 + (amountIn * 2^96 / liquidity)
     * @param sqrtPriceX96 当前价格
     * @param liquidity 流动性
     * @param amountIn 传入的token数量
     */
    function getNextSqrtPriceFromAmount1RoundingDown(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn
    ) internal pure returns (uint160) {
        // amountIn << FixedPoint96.RESOLUTION 简化写法：amountIn * 2^96
        // 此处放大精度以适用 sqrtPriceX96 的精度
        return
            sqrtPriceX96 +
            uint160((amountIn << FixedPoint96.RESOLUTION) / liquidity);
    }

    /**
     * L * sqrtPrice / L + amountIn * sqrtPrice
     * (liquidity * 2^96 * sqrtPriceX96) / (liquidity * 2^96 + amountIn * sqrtPriceX96)
     * @param sqrtPriceX96 价格
     * @param liquidity 流动性
     * @param amountIn 传入的amount
     */
    function getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn
    ) internal pure returns (uint160) {
        uint256 numerator = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 product = amountIn * sqrtPriceX96; // 有可能发生溢出

        // If product doesn't overflow, use the precise formula.
        // 检测是否会溢出
        if (product / amountIn == sqrtPriceX96) {
            uint256 denominator = numerator + product;
            if (denominator >= numerator) {
                return
                    uint160(
                        mulDivRoundingUp(numerator, sqrtPriceX96, denominator)
                    );
            }
        }

        // If product overflows, use a less precise formula.
        // 精度更低的公式
        return
            uint160(
                divRoundingUp(numerator, (numerator / sqrtPriceX96) + amountIn)
            );
    }

    // 根据input得出交换后的价格
    function getNextSqrtPriceFromInput(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtPriceNextX96) {
        sqrtPriceNextX96 = zeroForOne
            ? getNextSqrtPriceFromAmount0RoundingUp(
                sqrtPriceX96,
                liquidity,
                amountIn
            )
            : getNextSqrtPriceFromAmount1RoundingDown(
                sqrtPriceX96,
                liquidity,
                amountIn
            );
    }
}
