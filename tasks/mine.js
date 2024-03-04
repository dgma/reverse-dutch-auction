const { task } = require("hardhat/config");

const MINE_BLOCKS = "mine-blocks";

task(MINE_BLOCKS, "Enable fixed amount of block mining").setAction(async (_, hre) => {
  await network.provider.send("evm_setIntervalMining", [1000]);
});
