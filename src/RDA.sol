// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RDAMathLib} from "./RDAMathLib.sol";

import {IRDA, Auction, ActiveAuctionReport, Bid, ActiveAuctionHouse} from "./RDA.types.sol";

import {RDABase} from "./RDABase.sol";

abstract contract RDA is IRDA, OwnableUpgradeable, RDABase {
    using Math for uint256;
    using RDAMathLib for uint256;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        uint256 lotSize_,
        uint256 stepRate_,
        uint8 stepLength_,
        uint8 decimals_
    ) external initializer {
        decimals = decimals_;
        __Ownable_init(owner);
        _setHouseParams(lotSize_, stepRate_, stepLength_);
    }

    // modifiers

    modifier onlyNotActiveHouse() {
        if (auctionsSet.length() > 0) {
            revert ActiveAuctionHouse();
        }
        _;
    }

    // public API setters

    function setHouseParams(uint256 lotSize_, uint256 stepRate_, uint8 stepLength_)
        public
        onlyOwner
        onlyNotActiveHouse
    {
        _setHouseParams(lotSize_, stepRate_, stepLength_);
    }

    // public API getters

    function actualRate(bytes32 id) external view returns (uint256) {
        return _rate(id, block.number);
    }

    function previewBid(bytes32 id, uint256 swapAmount, uint256 blockNumber)
        public
        view
        onlyActiveAuction(id)
        returns (Bid memory)
    {
        uint256 rate = _rate(id, blockNumber);
        uint256 maxRedeem = swapAmount.mulDiv(rate, _denominator()).roundToWholeValue(lotSize);
        if (maxRedeem > 0) {
            uint256 adjustedSwapAmount = maxRedeem.mulDiv(_denominator(), rate);

            return Bid({toSwap: adjustedSwapAmount, toRedeem: maxRedeem});
        }
        return Bid({toSwap: 0, toRedeem: 0});
    }

    function getActiveAuctions() external view returns (ActiveAuctionReport[] memory) {
        uint256 len = auctionsSet.length();
        ActiveAuctionReport[] memory activeAuctionReport = new ActiveAuctionReport[](len);
        bytes32 id;
        for (uint256 i = 0; i < len; i++) {
            id = auctionsSet.at(i);
            Auction memory auction = auctions[id];
            activeAuctionReport[i] = ActiveAuctionReport({
                stepRate: _ratePerStep(id),
                step: _step(id, block.number) + 1,
                amountToCollect: auction.amountToCollect,
                amountToDistribute: auction.amountToDistribute,
                collected: auction.stats.collected,
                distributed: auction.stats.distributed
            });
        }
        return activeAuctionReport;
    }
}
