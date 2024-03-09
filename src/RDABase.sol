// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RDAMathLib} from "./RDAMathLib.sol";

import {
    Auction,
    AuctionStats,
    Bid,
    BidIsTooHigh,
    ActiveAuction,
    AuctionNotActive
} from "./RDA.types.sol";

abstract contract RDABase {
    using Math for uint256;
    using RDAMathLib for uint256;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    uint256 public stepRate;
    uint256 public stepLength;
    uint256 public lotSize;
    uint256 public decimals;

    mapping(bytes32 => Auction) internal auctions;
    EnumerableSet.Bytes32Set internal auctionsSet;

    // modifiers

    modifier notActive(bytes32 id) {
        if (_isAutcionActive(id)) {
            revert ActiveAuction();
        }
        _;
    }

    modifier onlyActiveAuction(bytes32 id) {
        if (!_isAutcionActive(id)) {
            revert AuctionNotActive();
        }
        _;
    }

    modifier withValidBid(bytes32 id, Bid memory bid) {
        if (bid.toRedeem > _leftDistribute(auctions[id])) {
            revert BidIsTooHigh();
        }
        _;
    }

    // internal API setters

    function _setHouseParams(uint256 lotSize_, uint256 stepRate_, uint8 stepLength_) internal {
        stepRate = stepRate_;
        stepLength = stepLength_;
        lotSize = lotSize_;
    }

    function _begin(bytes32 id, uint256 amountToCollect, uint256 amountToDistribute)
        internal
        notActive(id)
    {
        auctions[id] = Auction({
            initBlock: block.number,
            amountToCollect: amountToCollect,
            amountToDistribute: amountToDistribute,
            stats: AuctionStats({collected: 0, distributed: 0})
        });
        auctionsSet.add(id);
    }

    function _processBid(bytes32 id, Bid memory bid)
        internal
        onlyActiveAuction(id)
        withValidBid(id, bid)
    {
        Auction memory auction = auctions[id];
        auctions[id].stats = AuctionStats({
            collected: auction.stats.collected + bid.toSwap,
            distributed: auction.stats.distributed + bid.toRedeem
        });
    }

    function _close(bytes32 id) internal {
        auctions[id].initBlock = 0;
        auctionsSet.remove(id);
    }

    // internal API Getters

    function _denominator() internal view returns (uint256) {
        return 10 ** decimals;
    }

    function _isAutcionActive(bytes32 id) internal view returns (bool) {
        return auctionsSet.contains(id) && auctions[id].initBlock != 0;
    }

    function _baseSwapRatio(bytes32 id) internal view returns (uint256) {
        Auction memory auction = auctions[id];
        return auction.amountToCollect.mulDiv(_denominator(), auction.amountToDistribute);
    }

    function _rate(bytes32 id, uint256 blockNumber) internal view returns (uint256) {
        return _ratePerStep(id) * _step(id, blockNumber);
    }

    function _ratePerStep(bytes32 id) internal view returns (uint256) {
        return _baseSwapRatio(id).mulDiv(stepRate, _denominator());
    }

    function _step(bytes32 id, uint256 blockNumber) internal view returns (uint256) {
        return (blockNumber - auctions[id].initBlock).divDown(stepLength);
    }

    function _leftCollect(Auction memory auction) internal pure returns (uint256) {
        return auction.amountToCollect - auction.stats.collected;
    }

    function _leftDistribute(Auction memory auction) internal pure returns (uint256) {
        return auction.amountToDistribute - auction.stats.distributed;
    }
}
