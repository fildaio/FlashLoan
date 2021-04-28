// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.5.0;

import "../FlashLoanReceiverBase.sol";
import "../dependency.sol";
import "../WETH.sol";

contract TestFlashLoan is FlashLoanReceiverBase {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public governance;
    WETH public _WETH;

    constructor(IFlashLoan _flashLoan, address _governance, address weth) public FlashLoanReceiverBase(_flashLoan) {
        governance = _governance;
        _WETH = WETH(weth);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        params;
        require(initiator == governance, "initiator is not governance.");
        require(msg.sender == address(FLASHLOAN_POOL), "caller is not flash loan contract");

        for (uint i = 0; i < assets.length; i++) {
            uint256 repay = amounts[i].add(premiums[i]);
            if (assets[i] == address(_WETH)) {
                _WETH.withdraw(amounts[i]);
                _WETH.deposit.value(repay)();
            }

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

    function withdraw(address payable _account, uint256 amount) public {
        require(msg.sender == governance, "only governance.");
        if (amount > address(this).balance) {
            amount = address(this).balance;
        }
        _account.transfer(amount);
    }

    function () external payable {}
}
