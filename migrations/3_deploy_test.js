const TestFlashLoan = artifacts.require("TestFlashLoan");
const FlashLoan = artifacts.require("FlashLoan");

module.exports = async function (deployer, network, accounts) {
    const flashloan = await FlashLoan.deployed();
    await deployer.deploy(TestFlashLoan, flashloan.address,
        "0x" // _governance
        );

    console.log("***********************************************");
    console.log("TestFlashLoan address:", TestFlashLoan.address);
    console.log("***********************************************");
};
