import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// token address for reward token
const tokenAddress = "0x669eEe68Ef39E12D1b38d1f274BFc9aC46D771CB";

const StakeEthModule = buildModule("StakeEthersModule", (m) => {

  const stakeEthers = m.contract("StakeEthers", [tokenAddress]);
  return { stakeEthers };
});

export default StakeEthModule;
