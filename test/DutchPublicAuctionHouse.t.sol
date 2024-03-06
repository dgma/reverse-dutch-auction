// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
// solhint-disable no-global-import
// solhint-disable no-console

import "@std/Test.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {TestUtils} from "./TestUtils.sol";
import {SomeToken} from "src/SomeToken.sol";

import {DutchPublicAuctionHouse} from "src/DutchPublicAuctionHouse.sol";
import {
    ActiveAuction,
    AuctionNotActive,
    HasNotFinished,
    Bid,
    ActiveAuctionReport
} from "src/DutchAuctionHouse.types.sol";

contract DutchPublicAuctionHouseTest is Test {
    using Math for uint256;
    using TestUtils for SomeToken;

    DutchPublicAuctionHouse private auctionHouse;

    // 1.25% => 0.0125 => 0.0125 * 10 ** 8 = 125 * 10 ** 4
    uint256 private stepRate = 125 * 10 ** 4;
    uint8 private stepLength = 3;
    // 0.1 tokens
    uint256 private lotSize;

    uint256 private amountToCollect;
    uint256 private amountToDistribute;

    bytes32 private id = keccak256(abi.encode(address(this)));

    address private notOwner = makeAddr("alice");

    SomeToken private swapToken;
    SomeToken private redeemToken;

    function setUp() public {
        swapToken = new SomeToken("SWT", "Swap Token");
        redeemToken = new SomeToken("RT", "Redeem Token");

        lotSize = redeemToken.conv(1) / 10;

        amountToCollect = swapToken.conv(100);
        amountToDistribute = redeemToken.conv(500);

        swapToken.mint(notOwner, amountToCollect);
        redeemToken.mint(address(this), amountToDistribute);

        auctionHouse = DutchPublicAuctionHouse(Clones.clone(address(new DutchPublicAuctionHouse())));
        auctionHouse.initialize(address(this), lotSize, stepRate, stepLength);

        redeemToken.approve(address(auctionHouse), type(uint256).max);

        auctionHouse.begin(
            id, amountToCollect, address(swapToken), amountToDistribute, address(redeemToken)
        );
    }

    function _prepareNotOwnerToBid(uint256 bidAmount) internal {
        vm.startPrank(notOwner);
        swapToken.approve(address(auctionHouse), bidAmount);
    }

    function test_makeBid() public {
        _prepareNotOwnerToBid(amountToCollect / 2);
        vm.roll(32);
        auctionHouse.makeBid(id, amountToCollect / 2);
        assertEq(redeemToken.balanceOf(notOwner), 1200000000000000000);
        assertEq(swapToken.balanceOf(address(auctionHouse)), 48000000000000000000);
    }

    function testFuzz_makeBid(uint256 bidAmount) public {
        vm.assume(
            auctionHouse.previewBid(id, bidAmount, 32).toSwap > 0 && bidAmount < amountToCollect
        );
        _prepareNotOwnerToBid(bidAmount);
        vm.roll(32);
        auctionHouse.makeBid(id, bidAmount);
        assert(redeemToken.balanceOf(notOwner) > 0);
        assert(swapToken.balanceOf(address(auctionHouse)) > 0);
    }

    function test_autoclose() public {
        _prepareNotOwnerToBid(amountToCollect);
        vm.roll(253);
        (uint256 leftDebt, uint256 leftCollateral) = auctionHouse.makeBid(id, amountToCollect);
        assertEq(leftDebt, 0);
        assertEq(redeemToken.balanceOf(address(this)), leftCollateral);
    }
}
