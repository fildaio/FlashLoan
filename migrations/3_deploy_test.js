const TestFlashLoan = artifacts.require("TestFlashLoan");
const FlashLoanProxy = artifacts.require("FlashLoanProxy");

module.exports = async function (deployer, network, accounts) {
    const flashloan = await FlashLoanProxy.deployed();
    await deployer.deploy(TestFlashLoan, flashloan.address,
        "0x" // _governance
        );

    console.log("***********************************************");
    console.log("TestFlashLoan address:", TestFlashLoan.address);
    console.log("***********************************************");
};
