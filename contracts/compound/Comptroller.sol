pragma solidity ^0.5.16;

import "./ComptrollerInterface.sol";
import "./CToken.sol";

contract Comptroller is ComptrollerInterface {
    function checkMembership(address account, CToken cToken) external view returns (bool);
}
