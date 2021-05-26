// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import './IFlashLoan.sol';
import './IFlashLoanReceiver.sol';

contract FlashLoanReceiverBase is IFlashLoanReceiver {

    IFlashLoan public FLASHLOAN_POOL;

    constructor(IFlashLoan _flashLoan) public {
        FLASHLOAN_POOL = IFlashLoan(_flashLoan);
    }
}
