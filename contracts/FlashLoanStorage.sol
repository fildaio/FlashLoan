// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "./compound/Comptroller.sol";

contract FlashLoanStorage {

    struct ReserveData {
        //tokens addresses
        address fTokenAddress;
        address tokenAddress;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint8 id;
    }

    mapping(address => ReserveData) internal _reserves;

    // the list of the available reserves, structured as a mapping for gas savings reasons
    mapping(uint256 => address) internal _reservesList;

    uint256 internal _reservesCount;

    bool internal _paused;

    uint256 internal _flashLoanPremiumTotal;

    uint256 internal _maxNumberOfReserves;

    Comptroller internal _comptroller;
}
