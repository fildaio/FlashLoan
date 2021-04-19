
pragma solidity ^0.5.16;

import "../compound/CToken.sol";

contract ChainlinkAdaptor {
    function getUnderlyingPrice(CToken cToken) external view returns (uint);
}
