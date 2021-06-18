// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "./compound/Comptroller.sol";
import "./oracle/ChainlinkAdaptor.sol";
import "./WETH.sol";

contract FlashLoanStorage {

    struct ReserveData {
        //tokens addresses
        address fTokenAddress;
        address tokenAddress;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint8 id;
    }

    struct WhiteListData {
        bool isInWhiteList;
        uint256 premium;
    }

    mapping(address => ReserveData) internal _reserves;

    // the list of the available reserves, structured as a mapping for gas savings reasons
    mapping(uint256 => address) internal _reservesList;

    uint256 internal _reservesCount;

    bool internal _paused;

    uint256 internal _flashLoanPremiumTotal;

    uint256 internal _maxNumberOfReserves;

    Comptroller internal _comptroller;

    ChainlinkAdaptor internal _oracle;

    address internal _fHUSD;

    WETH internal _WETH;

    mapping (address => WhiteListData) internal _whitelist;
}
