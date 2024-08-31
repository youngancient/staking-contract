import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// token address for reward token
const tokenAddress = "0x450A6f494c8C4Fd8F12A02bB016f2615F1D45148";

const StakeERC20Module = buildModule("StakeERC20Module", (m) => {
  const stakeERC20 = m.contract("StakeEthers", [tokenAddress]);
  return { stakeERC20 };
});

export default StakeERC20Module;
