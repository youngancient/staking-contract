import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// token address for reward token
const tokenAddress = "0x450A6f494c8C4Fd8F12A02bB016f2615F1D45148";

const StakeEthModule = buildModule("StakeEthersModule", (m) => {

  const stakeEthers = m.contract("StakeEthers", [tokenAddress]);
  return { stakeEthers };
});

export default StakeEthModule;
