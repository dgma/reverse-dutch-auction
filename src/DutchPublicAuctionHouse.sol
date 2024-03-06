// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {DutchAuctionHouse, Bid, Auction} from "src/DutchAuctionHouse.sol";

contract DutchPublicAuctionHouse is DutchAuctionHouse {
    constructor() DutchAuctionHouse() {}

    function makeBid(bytes32 id, uint256 swapAmount)
        external
        returns (uint256 toCollect, uint256 toDistribute)
    {
        Bid memory bid = previewBid(id, swapAmount, block.number);
        _processBid(id, bid);

        Auction memory auction = _auction(id);
        toCollect = _leftCollect(auction);
        toDistribute = _leftDistribute(auction);

        if (toCollect == 0 || toDistribute == 0) {
            _close(id, auction, toDistribute);
        }
    }
}
