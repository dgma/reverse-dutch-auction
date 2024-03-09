// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
// solhint-disable no-global-import
// solhint-disable no-console

import "@std/Test.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {TestUtils} from "./TestUtils.sol";
import {SomeToken} from "./mocks/SomeToken.sol";

import {OpenRDA, RDAEvents} from "src/OpenRDA.sol";
import {
    ActiveAuction,
    AuctionNotActive,
    HasNotFinished,
    Bid,
    ActiveAuctionReport
} from "src/RDA.types.sol";

contract DutchAuctionHouseTest is RDAEvents, Test {
    using Math for uint256;
    using TestUtils for SomeToken;

    OpenRDA private auctionHouse;

    // 1.25% => 0.0125 => 0.0125 * 10 ** 8 = 125 * 10 ** 4
    uint256 private stepRate = 125 * 10 ** 4;
    uint8 private stepLength = 3;
    // 0.1 tokens
    uint256 private lotSize;

    uint256 private amountToCollect;
    uint256 private amountToDistribute;

    uint8 private constant decimals = 8;

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

        auctionHouse = OpenRDA(Clones.clone(address(new OpenRDA())));
        auctionHouse.initialize(address(this), lotSize, stepRate, stepLength, decimals);
    }

    function _maxFizzAuctionBlocks() private view returns (uint256) {
        return Math.mulDiv(stepLength, 10 ** decimals, stepRate);
    }

    function _prepareNotOwnerToBid(uint256 bidAmount) internal {
        vm.startPrank(notOwner);
        swapToken.approve(address(auctionHouse), bidAmount);
    }

    function test_base_getters() public {
        assertEq(auctionHouse.owner(), address(this));
    }

    function _begin() internal {
        auctionHouse.begin(
            id, amountToCollect, address(swapToken), amountToDistribute, address(redeemToken)
        );
    }

    function _approveAll() internal {
        redeemToken.approve(address(auctionHouse), amountToDistribute);
    }

    function test_begin_only_owner() public {
        hoax(notOwner);
        vm.expectRevert();
        _begin();
    }

    function testFails_begin_only_unapproved_transfer() public {
        _begin();
    }

    function test_begin_only_approved_transfer() public {
        _approveAll();
        assertEq(redeemToken.balanceOf(address(auctionHouse)), 0);
        vm.expectEmit(true, true, false, true);
        emit AuctionBegins(id, block.number);
        _begin();
        assertEq(redeemToken.balanceOf(address(auctionHouse)), amountToDistribute);
    }

    function test_begin_only_once() public {
        _approveAll();
        _begin();
        vm.expectRevert(abi.encodeWithSelector(ActiveAuction.selector));
        _begin();
    }

    function test_actualRate_floor_rounding() public {
        _approveAll();
        _begin();
        vm.roll(32);
        // (32 - 1) / 3 = 10.33(3) => 10th step
        // (amountToCollect/amountToDistribute) * stepRate * step
        // = 100 * 10 ** 18 / 500 * 10 ** 18 * 125 * 10 ** 4 * 10
        // = (1/5) * 125 * 10 ** 5 = (125/5) * 10 ** 5 = 25 * 10 ** 5
        assertEq(auctionHouse.actualRate(id), 2500000);
    }

    function testFuzz_actualRate(uint8 blockNumber) public {
        vm.assume(blockNumber > 3);
        _approveAll();
        _begin();
        vm.roll(blockNumber);
        assertEq(auctionHouse.actualRate(id) > 0, true);
    }

    function test_previewBid_uninitialized() public {
        vm.expectRevert(abi.encodeWithSelector(AuctionNotActive.selector));
        auctionHouse.previewBid(id, amountToCollect, 10);
    }

    function test_previewBid() public {
        _approveAll();
        _begin();
        Bid memory bid = auctionHouse.previewBid(id, amountToCollect, 32);
        // rate: 2500000 * 10 ** (-8)
        // rawToCollect: amountToCollect * rate = 100 * 10 ** 18 * 2500000 * 10 ** (-8) =
        // = 25 * 10 ** 17
        // rounded distribution amount = rawToCollect - rawToCollect % lotSize
        // = 25 * 10 ** 17 - 25 * 10 ** 17 % 1 * 10 ** 17 = (25 - 25 % 1) * 10 ** 17
        // = 25 * 10 ** 17
        uint256 expectedDistribution = swapToken.conv(25) / 10;
        assertEq(bid.toRedeem, expectedDistribution);
        assertEq(bid.toSwap, amountToCollect);
    }

    function testFuzz_previewBid(uint8 blockNumber, uint256 swapBid) public {
        vm.assume(
            amountToCollect >= swapBid && swapBid > 0 && _maxFizzAuctionBlocks() >= blockNumber
                && blockNumber > 0
        );
        _approveAll();
        _begin();
        Bid memory bid = auctionHouse.previewBid(id, swapBid, blockNumber);
        assertEq(bid.toSwap <= swapBid, true);
    }

    function test_makeBid_notActive() public {
        _prepareNotOwnerToBid(amountToCollect / 2);
        vm.expectRevert(abi.encodeWithSelector(AuctionNotActive.selector));
        auctionHouse.makeBid(id, amountToCollect / 2);
    }

    function test_makeBid() public {
        _approveAll();
        _begin();
        _prepareNotOwnerToBid(amountToCollect / 2);
        Bid memory bid = auctionHouse.previewBid(id, amountToCollect / 2, 32);
        vm.roll(32);
        vm.expectEmit(true, true, false, true);
        emit AuctionBid(id, bid.toSwap, bid.toRedeem);
        auctionHouse.makeBid(id, amountToCollect / 2);
        assertEq(redeemToken.balanceOf(notOwner), 1200000000000000000);
        assertEq(swapToken.balanceOf(address(auctionHouse)), 48000000000000000000);
    }

    function testFuzz_makeBid(uint256 bidAmount) public {
        _approveAll();
        _begin();
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
        _approveAll();
        _begin();
        _prepareNotOwnerToBid(amountToCollect);
        vm.roll(253);
        (uint256 leftDebt, uint256 leftCollateral) = auctionHouse.makeBid(id, amountToCollect);
        assertEq(leftDebt, 0);
        assertEq(redeemToken.balanceOf(address(this)), leftCollateral);
    }

    function test_getActiveAuctions() public {
        _approveAll();
        _begin();
        _prepareNotOwnerToBid(amountToCollect / 2);
        swapToken.approve(address(auctionHouse), type(uint256).max);
        vm.roll(32);
        auctionHouse.makeBid(id, amountToCollect / 2);
        ActiveAuctionReport[] memory report = auctionHouse.getActiveAuctions();
        assert(report.length == 1);
        // todo: add more fields check
        assertEq(report[0].step, 11);
        assertEq(report[0].stepRate, 250000);
    }
}
