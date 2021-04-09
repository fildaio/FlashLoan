pragma solidity ^0.5.16;

import "./CTokenInterfaces.sol";

contract CEther is CTokenInterface {
    function liquidateBorrow(address borrower, address cTokenCollateral) external payable;
    function repayBorrowBehalf(address borrower) external payable;
}
