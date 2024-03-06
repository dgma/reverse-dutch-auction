const config = require("dotenv").config();
const { task } = require("hardhat/config");
const { getLock, getDeployment } = require("@dgma/hardhat-sol-bundler");

const MINT_COLLATERAL = "mint";

task(MINT_COLLATERAL, "Mint SlopeCollateral tokens to faucet").setAction(async (_, hre) => {
  const { SlopeCollateral } = getLock(getDeployment(hre)?.lockFile)[hre.network.name];
  const SlopeCollateralContract = await hre.ethers.getContractAt(
    SlopeCollateral.abi,
    SlopeCollateral.address,
  );
  const defaultAddr = (await hre.ethers.getSigners())[0].address;
  const faucetAddr =
    hre.network.name === "localhost" ? defaultAddr : config?.parsed?.FAUCET_ADDRESS || defaultAddr;
  await SlopeCollateralContract.mint(faucetAddr, hre.ethers.parseEther("10000"));
});
