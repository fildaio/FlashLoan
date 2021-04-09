// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.5.0;

import "../FlashLoanReceiverBase.sol";

contract TestFlashLoan is FlashLoanReceiverBase {

    address public governance;

    constructor(FlashLoan _flashLoan, address _governance) public FlashLoanReceiverBase(_flashLoan) {
        governance = _governance;
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(initiator == governance, "initiator is not governance.");
        require(msg.sender == address(FLASHLOAN_POOL), "caller is not flash loan contract");

        for (uint i = 0; i < assets.length; i++) {
            uint256 repay = amounts[i].add(premiums[i]);
            IERC20(assets[i]).safeApprove(address(FLASHLOAN_POOL), repay);
        }

        return true;
    }

    function withdrawERC20(address _token, address _account, uint256 amount) public returns (uint256) {
        require(msg.sender == governance, "only governance.");
        IERC20 token = IERC20(_token);
        if (amount > token.balanceOf(address(this))) {
            amount = token.balanceOf(address(this));
        }
        token.safeTransfer(_account, amount);
        return amount;
    }
}
