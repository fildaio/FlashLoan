# FlashLoan

Flash Loans are special uncollateralised loans that allow the borrowing of an asset, as long as the borrowed amount (and a fee) is returned before the end of the transaction.

## Overview

For developers, a helpful mental model to consider when developing your solution:

1. Your contract calls the **FlashLoan** contract, requesting a Flash Loan of a certain amounts of reserves using flashLoan().
2. After some sanity checks, the **FlashLoan** transfers the requested amounts of the reserves to your contract, then calls executeOperation() on your contract (or another contract that you specify as the _receiver).
3. Your contract, now holding the flash loaned amounts, executes any arbitrary operation in its code.
    - when your code has finished, you approve the flash loaned amounts of reserves to the **FlashLoan**.
        - The **FlashLoan** contract pulls the flash loaned amount + fee.
        - If the amount owing is not available (due to a lack of balance or approval), then the transaction is reverted.
4. All of the above happens in 1 transaction (hence in a single ethereum block).

## Step by step

1. Setting up

Your contract that receives the flash loaned amounts must conform to the **IFlashLoanReceiver** interface by implementing the relevant executeOperation() function. In the example below, we inherit from **FlashLoanReceiverBase**, which conforms to the **IFlashLoanReceiver**.

Also note that since the owed amounts will be pulled from your contract, your contract must give allowance to the **FlashLoan** contract to pull those funds to pay back the flash loan debts + premiums.

```
pragma solidity ^0.5.0;

import "./FlashLoanReceiverBase.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./IERC20.sol";


/**
    !!!
    Never keep funds permanently on your FlashLoanReceiverBase contract as they could be
    exposed to a 'griefing' attack, where the stored funds are used by an attacker.
    !!!
 */

contract MyFlashLoan is FlashLoanReceiverBase {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;


    constructor(IFlashLoan _flashLoan) public FlashLoanReceiverBase(_flashLoan) {}

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        //
        // This contract now has the funds requested.
        // Your logic goes here.
        //

        // At the end of your logic above, this contract owes
        // the flashloaned amounts + premiums.
        // Therefore ensure your contract has enough to repay
        // these amounts.


        require(msg.sender == address(FLASHLOAN_POOL), "caller is not flash loan contract");

        for (uint i = 0; i < assets.length; i++) {
            uint256 repay = amounts[i].add(premiums[i]);
            IERC20(assets[i]).safeApprove(address(FLASHLOAN_POOL), repay);
        }

        return true;
    }
}
```

2. Calling flashLoan()

To call flashloan() on the **FlashLoan** contract, we need to pass in the relevant parameters. There are 3 ways you can do this.

**From normal heco account**

To use an EOA, send a transaction to the **FlashLoan** contract calling the flashLoan() function. See the flashLoan() function documentation for parameter details, ensuring you use your contract address from step 1 for the receiverAddress.

**From a different contract**

Similar to sending a transaction as above, ensure the receiverAddress is your contract address from step 1.


**From the same contract**

If you want to use the same contract as in step 1, use address(this) for the receiverAddress parameter in the flashLoan function.
The example below shows this third case, where the executeOperation() is in the same contract calling flashLoan() on the **FlashLoan** contract.

```
pragma solidity ^0.5.0;

import "./FlashLoanReceiverBase.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./IERC20.sol";


/**
    !!!
    Never keep funds permanently on your FlashLoanReceiverBase contract as they could be
    exposed to a 'griefing' attack, where the stored funds are used by an attacker.
    !!!
 */

contract MyFlashLoan is FlashLoanReceiverBase {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;


    constructor(IFlashLoan _flashLoan) public FlashLoanReceiverBase(_flashLoan) {}

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        //
        // This contract now has the funds requested.
        // Your logic goes here.
        //

        // At the end of your logic above, this contract owes
        // the flashloaned amounts + premiums.
        // Therefore ensure your contract has enough to repay
        // these amounts.


        require(msg.sender == address(FLASHLOAN_POOL), "caller is not flash loan contract");

        for (uint i = 0; i < assets.length; i++) {
            uint256 repay = amounts[i].add(premiums[i]);
            IERC20(assets[i]).safeApprove(address(FLASHLOAN_POOL), repay);
        }

        return true;
    }

    function myFlashLoanCall() public {
        address receiverAddress = address(this);

        address[] memory assets = new address[](2);
        assets[0] = address(INSERT_ASSET_ONE_ADDRESS);
        assets[1] = address(INSERT_ASSET_TWO_ADDRESS);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = INSERT_ASSET_ONE_AMOUNT;
        amounts[1] = INSERT_ASSET_TWO_AMOUNT;

        bytes memory params = "";

        FLASHLOAN_POOL.flashLoan(
            receiverAddress,
            assets,
            amounts,
            params
        );
    }
}
```

3. Completing the flash loan

Once you have performed your logic with the flash loaned assets (in your executeOperation() function), you will need to pay back the flash loaned amounts.

Ensure your contract has the relevant amount + premium to payback the loaned asset. You can calculate this by taking the sum of the relevant entry in the amounts and premiums array passed into the executeOperation() function.

You do not need to transfer the owed amount back to the **FlashLoan** contract. The funds will be automatically pulled at the conclusion of your operation.


## Encoding and Decoding Parameters

If you would like to pass parameters into your flash loan function, you will first need to encode them, then decode them in your executeOperation().

### Encoding

If you're encoding in solidity, you can use the in-built abi.encode():
```
// Encoding an address and a uint
bytes memory params = abi.encode(address(this), 1234);
```

If you're encoding off-chain, then you can use a package like web3.js which has an abi.encodeParameters():
```
const params = web3.eth.abi.encodeParameters(
    ["bytes32", "address"],
    [
        web3.utils.utf8ToHex("some_value"),
        "0x0298c2b32eae4da002a15f36fdf7615bea3da047"
    ]
)
```

### Decoding

When decoding in your executeOperation(), you will need to use the in-build abi.decode():

`(bytes32 someValue, address addr) = abi.decode(params, (bytes32, address));`


