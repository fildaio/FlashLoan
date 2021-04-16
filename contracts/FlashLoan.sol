// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import './Governable.sol';
import './FlashLoanStorage.sol';
import './IFlashLoan.sol';
import './IFlashLoanReceiver.sol';
import './compound/CTokenInterfaces.sol';
import './compound/Comptroller.sol';
import './dependency.sol';

contract FlashLoan is IFlashLoan, FlashLoanStorage, Governable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    modifier whenNotPaused() {
        _whenNotPaused();
        _;
    }

    function _whenNotPaused() internal view {
        require(!_paused, "FlashLoan: flash loan is paused!");
    }

    constructor(address _governance, address comptroller) public Governable(_governance) {
        _comptroller = Comptroller(comptroller);
        _flashLoanPremiumTotal = 10;
        _maxNumberOfReserves = 128;
    }

    struct FlashLoanLocalVars {
        IFlashLoanReceiver receiver;
        bool borrowed;
        uint256 i;
        address currentAsset;
        address currentFTokenAddress;
        uint256 currentAmount;
        uint256 currentPremium;
        uint256 currentAmountPlusPremium;
    }

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
    ) external whenNotPaused {
        FlashLoanLocalVars memory vars;
        uint err = 0;

        require(assets.length == amounts.length, "FlashLoan: invalid flash loan parameter.");

        address[] memory fTokenAddresses = new address[](assets.length);
        uint256[] memory premiums = new uint256[](assets.length);
        bool[] memory borrowed = new bool[](assets.length);

        vars.receiver = IFlashLoanReceiver(receiverAddress);

        for (vars.i = 0; vars.i < assets.length; vars.i++) {
            fTokenAddresses[vars.i] = _reserves[assets[vars.i]].fTokenAddress;

            uint256 underlyingAmount = CTokenInterface(fTokenAddresses[vars.i]).exchangeRateCurrent()
                    .mul(IERC20(fTokenAddresses[vars.i]).balanceOf(address(this))).div(1e18);
            if (underlyingAmount < amounts[vars.i]) {
                borrowed[vars.i] = true;
                err = CErc20Interface(fTokenAddresses[vars.i]).borrow(amounts[vars.i]);
                require(err == 0, "FlashLoan: borrow error");
            } else {
                borrowed[vars.i] = false;
                err = CErc20Interface(fTokenAddresses[vars.i]).redeemUnderlying(amounts[vars.i]);
                require(err == 0, "FlashLoan: redeemUnderlying error");
            }

            premiums[vars.i] = amounts[vars.i].mul(_flashLoanPremiumTotal).div(10000);

            IERC20(assets[vars.i]).safeTransfer(receiverAddress, amounts[vars.i]);
        }
        enterMarket(_securityReserve.fTokenAddress);

        require(
            vars.receiver.executeOperation(assets, amounts, premiums, msg.sender, params),
            "FlashLoan: invalid flash loan executor return!"
        );

        for (vars.i = 0; vars.i < assets.length; vars.i++) {
            vars.borrowed = borrowed[vars.i];
            vars.currentAsset = assets[vars.i];
            vars.currentAmount = amounts[vars.i];
            vars.currentPremium = premiums[vars.i];
            vars.currentFTokenAddress = fTokenAddresses[vars.i];
            vars.currentAmountPlusPremium = vars.currentAmount.add(vars.currentPremium);

            IERC20(vars.currentAsset).safeTransferFrom(
                receiverAddress,
                address(this),
                vars.currentAmountPlusPremium
            );

            uint256 mintAmount = vars.currentAmountPlusPremium;
            IERC20(vars.currentAsset).safeApprove(vars.currentFTokenAddress, vars.currentAmountPlusPremium);
            if (vars.borrowed) {
                uint256 borrowBalance = CTokenInterface(vars.currentFTokenAddress).borrowBalanceCurrent(address(this));
                err = CErc20Interface(vars.currentFTokenAddress).repayBorrow(borrowBalance);
                require(err == 0, "FlashLoan: repayBorrow error");

                mintAmount = vars.currentAmountPlusPremium.sub(borrowBalance);
            }

            err = CErc20Interface(vars.currentFTokenAddress).mint(mintAmount);
            require(err == 0, "FlashLoan: mint error");

            emit FlashLoan(
                receiverAddress,
                msg.sender,
                vars.currentAsset,
                vars.currentAmount,
                vars.currentPremium
            );
        }
        exitMarket(_securityReserve.fTokenAddress);
    }

    /**
     * @dev Returns the list of the initialized reserves
     **/
    function getReservesList() external view returns (address[] memory) {
        address[] memory _activeReserves = new address[](_reservesCount);

        for (uint256 i = 0; i < _reservesCount; i++) {
            _activeReserves[i] = _reservesList[i];
        }
        return _activeReserves;
    }

    /**
     * @dev Returns the fee on flash loans
     */
    function FLASHLOAN_PREMIUM_TOTAL() public view returns (uint256) {
        return _flashLoanPremiumTotal;
    }

    /**
     * @dev Returns the maximum number of reserves supported to be listed in this LendingPool
     */
    function MAX_NUMBER_RESERVES() public view returns (uint256) {
        return _maxNumberOfReserves;
    }

    /**
     * @dev Set the _pause state of a reserve
     * - Only callable by the LendingPoolConfigurator contract
     * @param val `true` to pause the reserve, `false` to un-pause it
     */
    function setPause(bool val) external onlyGovernance {
        _paused = val;
        if (_paused) {
            emit Paused();
        } else {
            emit Unpaused();
        }
    }

    function paused() external view returns (bool) {
        return _paused;
    }

    function setFlashLoanPremium(uint256 flashLoanPremium) external onlyGovernance {
        _flashLoanPremiumTotal = flashLoanPremium;
    }

    /**
     * @dev Initializes a reserve, activating it, assigning a fToken and underlying tokens
     * @param asset The address of the underlying asset of the reserve
     * @param fTokenAddress The address of the fToken
     **/
    function initReserve(
        address asset,
        address fTokenAddress,
        uint256 ftokenAmount
    ) external onlyGovernance {
        require(Address.isContract(asset), "FlashLoan: asset address is not contract");
        require(_reserves[asset].fTokenAddress == address(0), "FlashLoan: reserve already initialized.");
        require(fTokenAddress != _securityReserve.fTokenAddress, "FlashLoan: reserve can not be security token");

        if (ftokenAmount > 0) {
            IERC20(fTokenAddress).safeTransferFrom(msg.sender, address(this), ftokenAmount);
            //enterMarket(_reserves[asset].fTokenAddress);
        }

        _reserves[asset].ftokenAmount = _reserves[asset].ftokenAmount.add(ftokenAmount);
        _reserves[asset].fTokenAddress = fTokenAddress;
        _reserves[asset].tokenAddress = asset;

        _addReserveToList(asset);
    }

    /**
     * @dev Returns the state and configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The state of the reserve
     **/
    function getReserveData(address asset)
        external
        view
        returns (address, uint256, uint8)
    {
        return (_reserves[asset].fTokenAddress, _reserves[asset].ftokenAmount, _reserves[asset].id);
    }


    function _addReserveToList(address asset) internal {
        uint256 reservesCount = _reservesCount;

        require(reservesCount < _maxNumberOfReserves, "FlashLoan: no more reserves allowed!");

        bool reserveAlreadyAdded = _reserves[asset].id != 0 || _reservesList[0] == asset;

        if (!reserveAlreadyAdded) {
            _reserves[asset].id = uint8(reservesCount);
            _reservesList[reservesCount] = asset;

            _reservesCount = reservesCount + 1;
        }
    }

    function withdrawERC20(address _token, address _account, uint256 amount) public onlyGovernance returns (uint256) {
        require(_token != address(0) && _account != address(0) && amount > 0, "FlashLoan: Invalid parameter");
        IERC20 token = IERC20(_token);
        if (amount > token.balanceOf(address(this))) {
            amount = token.balanceOf(address(this));
        }
        token.safeTransfer(_account, amount);
        return amount;
    }

    function getComptroller() external view returns (address) {
        return address(_comptroller);
    }

    function setComptroller(address comptroller) external onlyGovernance {
        require(comptroller != address(0), "FlashLoan: comptroller address can not be zero");
        _comptroller = Comptroller(comptroller);
    }

    function enterMarket(address ftoken) public onlyGovernance {
        if (_comptroller.checkMembership(address(this), CToken(ftoken))) {
            return;
        }

        address[] memory tokens = new address[](1);
        tokens[0] = ftoken;
        uint[] memory errs = _comptroller.enterMarkets(tokens);
        require(errs[0] == 0, "FlashLoan: enter market error");
    }

    function exitMarket(address ftoken) internal {
        if (!_comptroller.checkMembership(address(this), CToken(ftoken))) {
            return;
        }

        uint err = _comptroller.exitMarket(ftoken);
        require(err == 0, "FlashLoan: exit market error");
    }

    function initSecurityReserve(
        address asset,
        address fTokenAddress,
        uint256 ftokenAmount
    ) external onlyGovernance {
        require(Address.isContract(asset), "FlashLoan: asset address is not contract");

        if (ftokenAmount > 0) {
            IERC20(fTokenAddress).safeTransferFrom(msg.sender, address(this), ftokenAmount);
            exitMarket(fTokenAddress);
        }

        _securityReserve.ftokenAmount = _securityReserve.ftokenAmount.add(ftokenAmount);
        _securityReserve.fTokenAddress = fTokenAddress;
        _securityReserve.tokenAddress = asset;
    }
}
