import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const WinTokenModule = buildModule("WinTokenModule", (m) => {

    const erc20 = m.contract("WinToken");

    return { erc20 };
});

export default WinTokenModule;
