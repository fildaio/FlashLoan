const FlashLoan = artifacts.require("FlashLoan");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(FlashLoan,
    '0x', // _governance
    '0x', // comptroller
    '0x', // oracle
    '0x' // fHUSD
  );

  console.log("***********************************************");
  console.log("FlashLoan address:", FlashLoan.address);
  console.log("***********************************************");
};
