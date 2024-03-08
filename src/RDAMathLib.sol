// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library RDAMathLib {
    function roundToWholeValue(uint256 value, uint256 denominator)
        internal
        pure
        returns (uint256)
    {
        uint256 valueToCut = value % denominator;
        return value - valueToCut;
    }

    function divDown(uint256 value, uint256 denominator) internal pure returns (uint256) {
        return roundToWholeValue(value, denominator) / denominator;
    }
}
