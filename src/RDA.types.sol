// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error BidIsTooHigh();
error ActiveAuction();
error AuctionNotActive();
error ActiveAuctionHouse();
error HasNotFinished();

struct AuctionStats {
    uint256 collected;
    uint256 distributed;
}

struct Auction {
    uint256 initBlock;
    uint256 amountToCollect;
    uint256 amountToDistribute;
    AuctionStats stats;
}

struct ActiveAuctionReport {
    uint256 stepRate;
    uint256 step;
    uint256 amountToCollect;
    uint256 amountToDistribute;
    uint256 collected;
    uint256 distributed;
}

struct Bid {
    uint256 toSwap;
    uint256 toRedeem;
}

interface IRDAMeta {
    function decimals() external pure returns (uint8);
}

interface IRDA {
    function initialize(address owner, uint256 lotSize_, uint256 stepRate_, uint8 stepLength_)
        external;

    function setHouseParams(uint256 lotSize_, uint256 stepRate_, uint8 stepLength_) external;

    function actualRate(bytes32 id) external view returns (uint256);

    function previewBid(bytes32 id, uint256 swapAmount, uint256 blockNumber)
        external
        view
        returns (Bid memory);

    function getActiveAuctions() external view returns (ActiveAuctionReport[] memory);
}
