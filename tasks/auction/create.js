const { task } = require("hardhat/config");
const { getLock, getDeployment } = require("@dgma/hardhat-sol-bundler");

const CREATE_AUCTION = "create-auction";

task(CREATE_AUCTION, "Create public auction").setAction(async (_, hre) => {
  const { DutchPublicAuctionHouse, DutchAuctionHousesManager, RedeemToken } = getLock(
    getDeployment(hre)?.lockFile,
  )[hre.network.name];

  const DutchPublicAuctionHouseContract = await hre.ethers.getContractAt(
    DutchPublicAuctionHouse.abi,
    DutchPublicAuctionHouse.address,
  );

  const DutchAuctionHousesManagerContract = await hre.ethers.getContractAt(
    DutchAuctionHousesManager.abi,
    DutchAuctionHousesManager.address,
  );

  const RedeemTokenContract = await hre.ethers.getContractAt(RedeemToken.abi, RedeemToken.address);

  const decimals = Number(await RedeemTokenContract.decimals());

  await DutchAuctionHousesManagerContract.createHouse(
    hre.ethers.parseUnits("1", decimals - 1),
    hre.ethers.parseUnits("125", 4),
    "3",
    DutchPublicAuctionHouse.address,
  );
});
