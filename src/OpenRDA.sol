// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {RDA, Bid, Auction} from "src/RDA.sol";

interface RDAEvents {
    event AuctionBegins(bytes32 indexed id, uint256 indexed initBlock);

    event AuctionBid(bytes32 indexed id, uint256 indexed toSwap, uint256 indexed toRedeem);

    event AuctionEnds(bytes32 indexed id);
}

contract OpenRDA is RDA, RDAEvents {
    address redeemToken;
    address swapToken;

    constructor() RDA() {}

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function begin(
        bytes32 id,
        uint256 amountToCollect,
        address swapToken_,
        uint256 amountToDistribute,
        address redeemToken_
    ) external onlyOwner {
        _begin(id, amountToCollect, amountToDistribute);
        redeemToken = redeemToken_;
        swapToken = swapToken_;
        ERC20(redeemToken).transferFrom(msg.sender, address(this), amountToDistribute);
        emit AuctionBegins(id, block.number);
    }

    function makeBid(bytes32 id, uint256 swapAmount)
        external
        returns (uint256 toCollect, uint256 toDistribute)
    {
        Bid memory bid = previewBid(id, swapAmount, block.number);
        _processBid(id, bid);

        ERC20(swapToken).transferFrom(msg.sender, address(this), bid.toSwap);
        ERC20(redeemToken).transfer(msg.sender, bid.toRedeem);

        Auction memory auction = auctions[id];
        toCollect = _leftCollect(auction);
        toDistribute = _leftDistribute(auction);
        emit AuctionBid(id, bid.toSwap, bid.toRedeem);

        if (toCollect == 0 || toDistribute == 0) {
            ERC20(swapToken).transfer(owner(), auction.stats.collected);
            if (toDistribute > 0) {
                ERC20(redeemToken).transfer(owner(), toDistribute);
            }
            _close(id);
            emit AuctionEnds(id);
        }
    }
}
