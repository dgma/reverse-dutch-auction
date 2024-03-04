// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Utils} from "src/Utils.sol";

import {
    IDutchAuctionHouse,
    Auction,
    ActiveAuctionReport,
    Bid,
    BidIsTooHigh,
    ActiveAuction,
    AuctionNotActive,
    ActiveAuctionHouse,
    HasNotFinished
} from "./DutchAuctionHouse.types.sol";

contract DutchAuctionHouse is IDutchAuctionHouse, Ownable {
    using Math for uint256;
    using Utils for uint256;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    uint256 public stepRate;
    uint256 public stepLength;
    uint256 public lotSize;

    mapping(bytes32 => Auction) private auctions;
    EnumerableSet.Bytes32Set private auctionsSet;

    modifier notActive(bytes32 id) {
        if (isAutcionActive(id)) {
            revert ActiveAuction();
        }
        _;
    }

    modifier onlyActiveAuction(bytes32 id) {
        if (!isAutcionActive(id)) {
            revert AuctionNotActive();
        }
        _;
    }

    modifier onlyNotActiveHouse() {
        if (isAuctionHouseActive()) {
            revert ActiveAuctionHouse();
        }
        _;
    }

    modifier withValidBid(bytes32 id, Bid memory bid) {
        if (bid.toRedeem > _leftDistribute(id)) {
            revert BidIsTooHigh();
        }
        _;
    }

    constructor() Ownable(msg.sender) {}

    function setHouseParams(uint256 lotSize_, uint256 stepRate_, uint8 stepLength_)
        public
        onlyOwner
        onlyNotActiveHouse
    {
        stepRate = stepRate_;
        stepLength = stepLength_;
        lotSize = lotSize_;
    }

    function isAuctionHouseActive() public view returns (bool) {
        return auctionsSet.length() > 0;
    }

    function isAutcionActive(bytes32 id) public view returns (bool) {
        return auctionsSet.contains(id) && auctions[id].initBlock != 0;
    }

    function actualRate(bytes32 id) external view returns (uint256) {
        return _rate(id, block.number);
    }

    function begin(
        bytes32 id,
        uint256 amountToCollect,
        address swapToken,
        uint256 amountToDistribute,
        address redeemToken
    ) external onlyOwner notActive(id) {
        ERC20(redeemToken).transferFrom(msg.sender, address(this), amountToDistribute);
        auctions[id] = Auction({
            initBlock: block.number,
            amountToCollect: amountToCollect,
            collected: 0,
            swapToken: swapToken,
            amountToDistribute: amountToDistribute,
            distributed: 0,
            redeemToken: redeemToken
        });
        auctionsSet.add(id);

        emit AuctionBegins(id, block.number);
    }

    function getBid(bytes32 id, uint256 swapAmount, uint256 blockNumber)
        public
        view
        onlyActiveAuction(id)
        returns (Bid memory)
    {
        uint256 rate = _rate(id, blockNumber);
        uint256 maxRedeem = swapAmount.mulDiv(rate, Utils.appDenominator).roundToWholeValue(lotSize);
        if (maxRedeem > 0) {
            uint256 adjustedSwapAmount = maxRedeem.mulDiv(Utils.appDenominator, rate);

            return Bid({toSwap: adjustedSwapAmount, toRedeem: maxRedeem});
        }
        return Bid({toSwap: 0, toRedeem: 0});
    }

    function baseSwapRatio(bytes32 id) public view returns (uint256) {
        return auctions[id].amountToCollect.mulDiv(
            Utils.appDenominator, auctions[id].amountToDistribute
        );
    }

    function _rate(bytes32 id, uint256 blockNumber) private view returns (uint256) {
        return _ratePerStep(id) * _step(id, blockNumber);
    }

    function _ratePerStep(bytes32 id) private view returns (uint256) {
        return baseSwapRatio(id).mulDiv(stepRate, Utils.appDenominator);
    }

    function _step(bytes32 id, uint256 blockNumber) private view returns (uint256) {
        return (blockNumber - auctions[id].initBlock).roundToWholeValue(stepLength) / stepLength;
    }

    function _leftCollect(bytes32 id) private view returns (uint256) {
        return auctions[id].amountToCollect - auctions[id].collected;
    }

    function _leftDistribute(bytes32 id) private view returns (uint256) {
        return auctions[id].amountToDistribute - auctions[id].distributed;
    }

    function processBid(bytes32 id, Bid calldata bid)
        external
        onlyOwner
        onlyActiveAuction(id)
        withValidBid(id, bid)
    {
        auctions[id].collected += bid.toSwap;
        auctions[id].distributed += bid.toRedeem;

        ERC20(auctions[id].swapToken).transferFrom(msg.sender, address(this), bid.toSwap);
        ERC20(auctions[id].redeemToken).transfer(msg.sender, bid.toRedeem);

        emit AuctionBid(id, bid.toSwap, bid.toRedeem);
    }

    function close(bytes32 id) external onlyOwner {
        uint256 toCollect = _leftCollect(id);
        uint256 toDistribute = _leftDistribute(id);

        if (toCollect != 0 && toDistribute != 0) {
            revert HasNotFinished();
        }

        if (toCollect == 0 || toDistribute == 0) {
            auctions[id].initBlock = 0;
            ERC20(auctions[id].swapToken).transfer(owner(), auctions[id].collected);
            if (toDistribute > 0) {
                ERC20(auctions[id].redeemToken).transfer(owner(), toDistribute);
            }
            auctionsSet.remove(id);
            emit AuctionEnds(id);
        }
    }

    function getActiveAuctions()
        external
        view
        returns (ActiveAuctionReport[] memory activeAuctionReport)
    {
        uint256 len = auctionsSet.length();
        activeAuctionReport = new ActiveAuctionReport[](len);
        bytes32 id;
        for (uint256 index = 0; index < len; index++) {
            id = auctionsSet.at(index);
            activeAuctionReport[index] = ActiveAuctionReport({
                stepRate: _ratePerStep(id),
                step: _step(id, block.number) + 1,
                amountToCollect: auctions[id].amountToCollect,
                amountToDistribute: auctions[id].amountToDistribute,
                collected: auctions[id].collected,
                swapToken: auctions[id].swapToken,
                distributed: auctions[id].distributed,
                redeemToken: auctions[id].redeemToken
            });
        }
    }
}
