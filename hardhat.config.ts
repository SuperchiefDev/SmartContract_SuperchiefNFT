import { HardhatUserConfig } from "hardhat/types";
import { node_url, accounts, verifyKey } from "./utils/network";
import { removeConsoleLog } from "hardhat-preprocessor";

import "@nomiclabs/hardhat-ethers";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-abi-exporter";
import "hardhat-deploy";
import "hardhat-gas-reporter";
import "hardhat-watcher";
import "solidity-coverage";
import "hardhat-storage-layout";
import "dotenv/config";

import "./tasks/account";
import "./tasks/verify";
import "./tasks/contracts";

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 1337,
      forking: {
        enabled: process.env.FORKING_ENABLED === "true",
        blockNumber: Number(process.env.FORKING_BLOCK_NUM) || undefined,
        url: node_url("avalanche"),
      },
      accounts: accounts("localhost"),
      mining: {
        auto: process.env.AUTO_MINING_ENABLED === "true",
        // interval: Number(process.env.MINING_INTERVAL),
      },
      tags: ["local", "test"],
    },
    localhost: {
      url: node_url("localhost"),
      accounts: accounts("localhost"),
      tags: ["local", "test"],
    },
    avax: {
      accounts: accounts("avalanche"),
      chainId: 43114,
      url: node_url("avalanche"),
      tags: ["prod", "live"],
    },
    avax_test: {
      accounts: accounts("avalanche_fuji"),
      chainId: 43113,
      url: node_url("avalanche_fuji"),
      tags: ["test", "live"],
    },
  },
  etherscan: {
    apiKey: {
      mainnet: verifyKey("etherscan"),
      goerli: verifyKey("etherscan"),
      polygon: verifyKey("polyscan"),
      avalanche: verifyKey("snowtrace"),
      avalancheFujiTestnet: verifyKey("snowtrace"),
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          metadata: {
            bytecodeHash: "none",
          },
          optimizer: {
            enabled: true,
            runs: 20,
          },
        },
      },
    ],
  },
  namedAccounts: {
    deployer: 0,
    alice: 3,
    bob: 4,
    signer: 1,
    vault: 2,
  },
  abiExporter: {
    path: "./abis",
    runOnCompile: false,
    clear: true,
    flat: true,
    spacing: 2,
    pretty: true,
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5",
  },
  mocha: {
    timeout: 100000,
  },
  gasReporter: {
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    currency: "USD",
    enabled: process.env.REPORT_GAS === "true",
    src: "./contracts",
  },
  preprocess: {
    eachLine: removeConsoleLog((hre) => hre.network.name !== "hardhat" && hre.network.name !== "localhost"),
  },
};

export default config;
