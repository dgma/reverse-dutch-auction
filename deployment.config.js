const path = require("path");
const { VerifyPlugin } = require("@dgma/hardhat-sol-bundler/plugins/Verify");

const config = {
  OpenRDA: {},
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
