// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

interface IFlashLoan {
    /**
     * @dev Emitted when the pause is triggered.
     */
    event Paused();

    /**
    * @dev Emitted when the pause is lifted.
    */
    event Unpaused();


    /**
     * @dev Emitted on flashLoan()
     * @param target The address of the flash loan receiver contract
     * @param initiator The address initiating the flash loan
     * @param asset The address of the asset being flash borrowed
     * @param amount The amount flash borrowed
     * @param premium The fee flash borrowed
     **/
    event FlashLoan(
        address indexed target,
        address indexed initiator,
        address indexed asset,
        uint256 amount,
        uint256 premium
    );

    /**
     * @dev Initializes a reserve, activating it, assigning a fToken and underlying tokens
     * @param asset The address of the underlying asset of the reserve
     * @param fTokenAddress The address of the fToken
     **/
    function initReserve(
        address asset,
        address fTokenAddress,
        uint256 ftokenAmount
    ) external;

    /**
     * @dev Returns the state and configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The state of the reserve
     **/
    function getReserveData(address asset)
        external
        view
        returns (address, uint256, uint8);

    /**
     * @dev Allows smartcontracts to access the liquidity of the pool within one transaction,
     * as long as the amount taken plus a fee is returned.
     * IMPORTANT There are security concerns for developers of flashloan receiver contracts that must be kept into consideration.
     * For further details please visit https://developers.aave.com
     * @param receiverAddress The address of the contract receiving the funds, implementing the IFlashLoanReceiver interface
     * @param assets The addresses of the assets being flash-borrowed
     * @param amounts The amounts amounts being flash-borrowed
     * @param params Variadic packed params to pass to the receiver as extra information
     *   0 if the action is executed directly by the user, without any middle-man
     **/
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        bytes calldata params
    ) external;

    function getReservesList() external view returns (address[] memory);

    function setPause(bool val) external;

    function paused() external view returns (bool);

    function setFlashLoanPremium(uint256 flashLoanPremium) external;

    function getComptroller() external view returns (address);

    function setComptroller(address comptroller) external;

    function initSecurityReserve(
        address asset,
        address fTokenAddress,
        uint256 ftokenAmount
    ) external;
}
