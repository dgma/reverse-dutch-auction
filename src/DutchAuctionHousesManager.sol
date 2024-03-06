// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {IDutchAuctionHouse} from "src/DutchAuctionHouse.types.sol";

contract DutchAuctionHousesManager is OwnableUpgradeable, UUPSUpgradeable {
    error WrongOwnership();
    error ActiveAuctionHouse();

    event AuctionCreated(address indexed creator, address indexed auctionHouseInstance);

    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => EnumerableSet.AddressSet) private auctionHouses;

    modifier onlyHouseOwner(address auctionHouseInstance) {
        if (Ownable(auctionHouseInstance).owner() != msg.sender) {
            revert WrongOwnership();
        }
        _;
    }

    modifier onlyInActiveHouse(address auctionHouse) {
        if (IDutchAuctionHouse(auctionHouse).isAuctionHouseActive()) {
            revert ActiveAuctionHouse();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __Ownable_init(msg.sender);
    }

    function upgradeCallback(address) external reinitializer(2) {}

    function _authorizeUpgrade(address) internal view override onlyOwner {}

    function createHouse(uint256 lotSize, uint256 stepRate, uint8 stepLength, address auctionHouse)
        external
        returns (address auctionHouseInstance)
    {
        auctionHouseInstance = Clones.clone(address(auctionHouse));
        IDutchAuctionHouse(auctionHouseInstance).setHouseParams(lotSize, stepRate, stepLength);
        Ownable(auctionHouseInstance).transferOwnership(msg.sender);
        auctionHouses[msg.sender].add(auctionHouseInstance);
        emit AuctionCreated(msg.sender, auctionHouseInstance);
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

    function deleteHouse(address auctionHouseInstance)
        external
        onlyHouseOwner(auctionHouseInstance)
        onlyInActiveHouse(auctionHouseInstance)
    {
        auctionHouses[msg.sender].remove(auctionHouseInstance);
    }
}
