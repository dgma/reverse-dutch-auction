// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {DutchAuctionHouse} from "src/DutchAuctionHouse.sol";

contract DutchAuctionHousesManager is OwnableUpgradeable, UUPSUpgradeable {
    error WrongOwnership();
    error ActiveAuctionHouse();

    event AuctionCreated(address indexed creator, address indexed auctionHouse);

    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => EnumerableSet.AddressSet) private auctionHouses;
    DutchAuctionHouse private baseHouse;

    modifier onlyHouseOwner(address auctionHouse) {
        if (DutchAuctionHouse(auctionHouse).owner() != msg.sender) {
            revert WrongOwnership();
        }
        _;
    }

    modifier onlyInActiveHouse(address auctionHouse) {
        if (DutchAuctionHouse(auctionHouse).isAuctionHouseActive()) {
            revert ActiveAuctionHouse();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        baseHouse = new DutchAuctionHouse();
        __Ownable_init(msg.sender);
    }

    function _authorizeUpgrade(address) internal view override onlyOwner {}

    function createHouse(uint256 lotSize, uint256 stepRate, uint8 stepLength)
        external
        returns (address auctionHouse)
    {
        auctionHouse = Clones.clone(address(baseHouse));
        DutchAuctionHouse(auctionHouse).setHouseParams(lotSize, stepRate, stepLength);
        DutchAuctionHouse(auctionHouse).transferOwnership(msg.sender);
        auctionHouses[msg.sender].add(auctionHouse);
        emit AuctionCreated(msg.sender, auctionHouse);
    }

    function getAuctionHouses(address owner)
        external
        view
        returns (address[] memory ownerAuctionHouses)
    {
        uint256 len = auctionHouses[owner].length();
        ownerAuctionHouses = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            ownerAuctionHouses[i] = auctionHouses[owner].at(i);
        }
    }

    function deleteHouse(address auctionHouse)
        external
        onlyHouseOwner(auctionHouse)
        onlyInActiveHouse(auctionHouse)
    {
        auctionHouses[msg.sender].remove(auctionHouse);
    }
}
