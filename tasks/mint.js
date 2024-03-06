const config = require("dotenv").config();
const { task } = require("hardhat/config");
const { getLock, getDeployment } = require("@dgma/hardhat-sol-bundler");

const MINT_COLLATERAL = "mint";

const mintToken = async (lockContract, amount, address) => {
  const Contract = await hre.ethers.getContractAt(lockContract.abi, lockContract.address);
  await Contract.mint(address, hre.ethers.parseEther(amount));
};

task(MINT_COLLATERAL, "Mint SlopeCollateral tokens to faucet").setAction(async (_, hre) => {
  const { SwapToken, RedeemToken } = getLock(getDeployment(hre)?.lockFile)[hre.network.name];
  const defaultAddr = (await hre.ethers.getSigners())[0].address;
  const faucetAddr =
    hre.network.name === "localhost" ? defaultAddr : config?.parsed?.FAUCET_ADDRESS || defaultAddr;

  await mintToken(SwapToken, "100", faucetAddr);
  await mintToken(RedeemToken, "1000", faucetAddr);
});
