pragma solidity ^0.5.0;

import "./CTokenInterfaces.sol";

contract CEther is CTokenInterface {
    function liquidateBorrow(address borrower, address cTokenCollateral) external payable;
    function repayBorrowBehalf(address borrower) external payable;
    function repayBorrow() external payable;
    function borrow(uint borrowAmount) external returns (uint);
}
