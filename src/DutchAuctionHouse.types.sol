// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

error BidIsTooHigh();
error ActiveAuction();
error AuctionNotActive();
error ActiveAuctionHouse();
error HasNotFinished();

struct Auction {
    uint256 initBlock;
    uint256 amountToCollect;
    uint256 collected;
    address swapToken;
    uint256 amountToDistribute;
    uint256 distributed;
    address redeemToken;
}

struct ActiveAuctionReport {
    uint256 stepRate;
    uint256 step;
    uint256 amountToCollect;
    uint256 amountToDistribute;
    uint256 collected;
    address swapToken;
    uint256 distributed;
    address redeemToken;
}

struct Bid {
    uint256 toSwap;
    uint256 toRedeem;
}

interface IDutchAuctionHouseEvents {
    event AuctionBegins(bytes32 indexed id, uint256 indexed initBlock);

    event AuctionBid(bytes32 indexed id, uint256 indexed toSwap, uint256 indexed toRedeem);

    event AuctionEnds(bytes32 indexed id);
}

interface IDutchAuctionHouse is IDutchAuctionHouseEvents {
    function setHouseParams(uint256 lotSize_, uint256 stepRate_, uint8 stepLength_) external;

    function isAuctionHouseActive() external view returns (bool);

    function isAutcionActive(bytes32 id) external view returns (bool);

    function actualRate(bytes32 id) external view returns (uint256);

    function begin(
        bytes32 id,
        uint256 amountToCollect,
        address swapToken,
        uint256 amountToDistribute,
        address redeemToken
    ) external;

    function getBid(bytes32 id, uint256 swapAmount, uint256 blockNumber)
        external
        view
        returns (Bid memory);

    function baseSwapRatio(bytes32 id) external view returns (uint256);

    function processBid(bytes32 id, Bid calldata bid) external;

    function close(bytes32 id) external;

    function getActiveAuctions()
        external
        view
        returns (ActiveAuctionReport[] memory activeAuctionReport);
}
