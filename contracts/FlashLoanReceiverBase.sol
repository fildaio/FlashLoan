// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.5.0;

import './FlashLoan.sol';
import './IFlashLoanReceiver.sol';

contract FlashLoanReceiverBase is IFlashLoanReceiver {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    FlashLoan public FLASHLOAN_POOL;

    constructor(FlashLoan _flashLoan) public {
        FLASHLOAN_POOL = FlashLoan(_flashLoan);
    }
}
