import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const CasTokenModule = buildModule("CasTokenModule", (m) => {

    const erc20 = m.contract("CasToken");

    return { erc20 };
});

export default CasTokenModule;
