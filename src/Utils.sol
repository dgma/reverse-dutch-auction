// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

library Utils {
    uint256 public constant appDenominator = 100000000;
    uint8 public constant appDecimals = 8;

    function roundToWholeValue(uint256 value, uint256 denominator)
        external
        pure
        returns (uint256)
    {
        uint256 valueToCut = value % denominator;
        return value - valueToCut;
    }

    function toAppDecimals(uint256 val) external pure returns (uint256) {
        return val * 10 ** appDecimals;
    }
}
