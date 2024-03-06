const path = require("path");
const { VerifyPlugin } = require("@dgma/hardhat-sol-bundler/plugins/Verify");
const { dynamicAddress, SupportedProxies } = require("@dgma/hardhat-sol-bundler");

const config = {
  Utils: {},
  DutchAuctionHouse: {
    options: {
      libs: {
        Utils: dynamicAddress("Utils"),
      },
    },
  },
  DutchPublicAuctionHouse: {
    options: {
      libs: {
        Utils: dynamicAddress("Utils"),
      },
    },
  },
  DutchAuctionHousesManager: {
    proxy: {
      type: SupportedProxies.UUPS,
      unsafeAllow: ["constructor"],
    },
  },
};

module.exports = {
  hardhat: {
    config: config,
  },
  localhost: { lockFile: path.resolve("./local.deployment-lock.json"), config: config },
  "arbitrum-sepolia": {
    lockFile: path.resolve("./deployment-lock.json"),
    verify: true,
    plugins: [VerifyPlugin],
    config: config,
  },
};
