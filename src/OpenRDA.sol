// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RDA, Bid, Auction} from "src/RDA.sol";

interface RDAEvents {
    event AuctionBegins(bytes32 indexed id, uint256 indexed initBlock);

    event AuctionBid(bytes32 indexed id, uint256 indexed toSwap, uint256 indexed toRedeem);

    event AuctionEnds(bytes32 indexed id);
}

contract OpenRDA is RDA, RDAEvents {
    using SafeERC20 for IERC20;

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
        IERC20(redeemToken).safeTransferFrom(msg.sender, address(this), amountToDistribute);
        emit AuctionBegins(id, block.number);
    }

    function makeBid(bytes32 id, uint256 swapAmount)
        external
        returns (uint256 toCollect, uint256 toDistribute)
    {
        Bid memory bid = previewBid(id, swapAmount, block.number);
        _processBid(id, bid);

        Auction memory auction = auctions[id];
        toCollect = _leftCollect(auction);
        toDistribute = _leftDistribute(auction);
        emit AuctionBid(id, bid.toSwap, bid.toRedeem);

        bool autoClose = toCollect == 0 || toDistribute == 0;

        if (autoClose) _close(id);

        IERC20(swapToken).safeTransferFrom(msg.sender, address(this), bid.toSwap);
        IERC20(redeemToken).safeTransfer(msg.sender, bid.toRedeem);

        if (autoClose) {
            IERC20(swapToken).safeTransfer(owner(), auction.stats.collected);
            if (toDistribute > 0) {
                IERC20(redeemToken).safeTransfer(owner(), toDistribute);
            }
            emit AuctionEnds(id);
        }
    }
}
