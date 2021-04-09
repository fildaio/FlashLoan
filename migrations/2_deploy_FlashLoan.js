const FlashLoanProxy = artifacts.require("FlashLoanProxy");
const FlashLoan = artifacts.require("FlashLoan");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(FlashLoan);
  await deployer.deploy(FlashLoanProxy, FlashLoan.address);

  const instance = await FlashLoan.at(FlashLoanProxy.address);
  // heco
  await instance.initialize(
    '0x', // _governance
    '0x' // comptroller
  );

  console.log("***********************************************");
  console.log("FlashLoan address:", FlashLoanProxy.address);
  console.log("***********************************************");
};
