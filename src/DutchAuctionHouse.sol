// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Utils} from "src/Utils.sol";

import {
    IDutchAuctionHouse,
    Auction,
    AuctionStats,
    ActiveAuctionReport,
    Bid,
    BidIsTooHigh,
    ActiveAuction,
    AuctionNotActive,
    ActiveAuctionHouse,
    HasNotFinished
} from "./DutchAuctionHouse.types.sol";

contract DutchAuctionHouse is IDutchAuctionHouse, OwnableUpgradeable {
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
        if (bid.toRedeem > _leftDistribute(auctions[id])) {
            revert BidIsTooHigh();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, uint256 lotSize_, uint256 stepRate_, uint8 stepLength_)
        external
        initializer
    {
        __Ownable_init(owner);
        _setHouseParams(lotSize_, stepRate_, stepLength_);
    }

    function setHouseParams(uint256 lotSize_, uint256 stepRate_, uint8 stepLength_)
        public
        onlyOwner
        onlyNotActiveHouse
    {
        _setHouseParams(lotSize_, stepRate_, stepLength_);
    }

    function _setHouseParams(uint256 lotSize_, uint256 stepRate_, uint8 stepLength_) private {
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
            swapToken: swapToken,
            amountToDistribute: amountToDistribute,
            stats: AuctionStats({collected: 0, distributed: 0}),
            redeemToken: redeemToken
        });
        auctionsSet.add(id);

        emit AuctionBegins(id, block.number);
    }

    function previewBid(bytes32 id, uint256 swapAmount, uint256 blockNumber)
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
        Auction memory auction = auctions[id];
        return auction.amountToCollect.mulDiv(Utils.appDenominator, auction.amountToDistribute);
    }

    function _auction(bytes32 id) internal view returns (Auction memory) {
        return auctions[id];
    }

    function _rate(bytes32 id, uint256 blockNumber) internal view returns (uint256) {
        return _ratePerStep(id) * _step(id, blockNumber);
    }

    function _ratePerStep(bytes32 id) internal view returns (uint256) {
        return baseSwapRatio(id).mulDiv(stepRate, Utils.appDenominator);
    }

    function _step(bytes32 id, uint256 blockNumber) internal view returns (uint256) {
        return (blockNumber - auctions[id].initBlock).roundToWholeValue(stepLength) / stepLength;
    }

    function _leftCollect(Auction memory auction) internal pure returns (uint256) {
        return auction.amountToCollect - auction.stats.collected;
    }

    function _leftDistribute(Auction memory auction) internal pure returns (uint256) {
        return auction.amountToDistribute - auction.stats.distributed;
    }

    function processBid(bytes32 id, Bid calldata bid) external onlyOwner {
        _processBid(id, bid);
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

        ERC20(auction.swapToken).transferFrom(msg.sender, address(this), bid.toSwap);
        ERC20(auction.redeemToken).transfer(msg.sender, bid.toRedeem);

        emit AuctionBid(id, bid.toSwap, bid.toRedeem);
    }

    function close(bytes32 id) external onlyOwner {
        Auction memory auction = auctions[id];
        uint256 toCollect = _leftCollect(auction);
        uint256 toDistribute = _leftDistribute(auction);

        if (toCollect != 0 && toDistribute != 0) {
            revert HasNotFinished();
        }
        if (toCollect == 0 || toDistribute == 0) {
            _close(id, auction, toDistribute);
        }
    }

    function _close(bytes32 id, Auction memory auction, uint256 toDistribute) internal {
        auctions[id].initBlock = 0;
        ERC20(auction.swapToken).transfer(owner(), auction.stats.collected);
        if (toDistribute > 0) {
            ERC20(auction.redeemToken).transfer(owner(), toDistribute);
        }
        auctionsSet.remove(id);
        emit AuctionEnds(id);
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
                swapToken: auction.swapToken,
                distributed: auction.stats.distributed,
                redeemToken: auction.redeemToken
            });
        }
        return activeAuctionReport;
    }
}
