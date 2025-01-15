// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {BitMath} from "./BitMath.sol";

library TickBitmap {
    // 添加流动性后，标记tick
    function flipTick(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        require(tick % tickSpacing == 0); // ensure that the tick spaced
        (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);
        uint256 mask = 1 << bitPos;
        self[wordPos] ^= mask;
    }

    // TODO: 不是很理解这个计算过程
    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = tick / tickSpacing;
        // 为 true 时，卖出 token x, 右边寻找下一个 tick；false 时相反。
        if (lte) {
            (int16 wordPos, uint8 bitPos) = position(compressed / tickSpacing);
            // 2*(1<<bitPost)-1 => (1<<(bitPost+1))-1
            // 如果bitPos=3:
            // (1 << 3) - 1 + (1 << 3) = 7 + 8 = 15  二进制为: 1111
            // (1 << (3 + 1)) - 1 = (1 << 4) - 1 = 16 - 1 = 15
            // 假设self[wordPos] 是 10110101 (binary),  bitPos = 3
            // 10110101 & 00001111 => 00001010 找到currentTick右边的存在流动性的Tick
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = self[wordPos] & mask;

            initialized = masked != 0;
            next = initialized
                ? (compressed -
                    int24(
                        uint24(bitPos - BitMath.mostSignificantBit(masked)) // mostSignificantBit 找出最高有效位的索引
                    )) * tickSpacing
                : (compressed - int24(uint24(bitPos))) * tickSpacing;
        } else {
            // 卖出token y
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = self[wordPos] & mask;
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = initialized
                ? (compressed +
                    1 +
                    int24(
                        uint24((BitMath.leastSignificantBit(masked) - bitPos))
                    )) * tickSpacing
                : (compressed + 1 + int24(uint24((type(uint8).max - bitPos)))) *
                    tickSpacing;
        }
    }

    function position(
        int24 tick
    ) private pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(tick >> 8); // tick / 256
        bitPos = uint8(uint24(tick % 256));
    }
}
