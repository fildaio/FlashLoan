// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import './Governable.sol';
import './FlashLoanStorage.sol';
import './IFlashLoan.sol';
import './IFlashLoanReceiver.sol';
import './compound/CTokenInterfaces.sol';
import './compound/Comptroller.sol';
import './compound/CEther.sol';
import './dependency.sol';
import './oracle/ChainlinkAdaptor.sol';

contract IERC20Extented is IERC20 {
    function decimals() public view returns (uint8);
}

contract FlashLoan is IFlashLoan, FlashLoanStorage, Governable, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for WETH;

    modifier whenNotPaused() {
        _whenNotPaused();
        _;
    }

    function _whenNotPaused() internal view {
        require(!_paused, "FlashLoan: flash loan is paused!");
    }

    constructor(address _governance, address comptroller, address oracle, address fHUSD, address weth) public Governable(_governance) {
        _comptroller = Comptroller(comptroller);
        _oracle = ChainlinkAdaptor(oracle);
        _fHUSD = fHUSD;
        _WETH = WETH(weth);
        _flashLoanPremiumTotal = 10;
        _maxNumberOfReserves = 128;
    }

    struct FlashLoanLocalVars {
        IFlashLoanReceiver receiver;
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

        uint256 liquidity = _getLiquidity();

        address[] memory fTokenAddresses = new address[](assets.length);
        uint256[] memory premiums = new uint256[](assets.length);

        vars.receiver = IFlashLoanReceiver(receiverAddress);

        for (vars.i = 0; vars.i < assets.length; vars.i++) {
            uint256 maxTokenAmount = getMaxTokenAmount(assets[vars.i]);
            require(amounts[vars.i] <= maxTokenAmount, "FlashLoan: Insufficient liquidity");

            fTokenAddresses[vars.i] = _reserves[assets[vars.i]].fTokenAddress;

            if (assets[vars.i] == address(_WETH)) {
                borrowETH(fTokenAddresses[vars.i], amounts[vars.i]);
            } else {
                err = CToken(fTokenAddresses[vars.i]).borrow(amounts[vars.i]);
                require(err == 0, "FlashLoan: borrow error");
            }

            premiums[vars.i] = isInWhitelist(receiverAddress) ? 0 : amounts[vars.i].mul(_flashLoanPremiumTotal).div(10000);

            IERC20(assets[vars.i]).safeTransfer(receiverAddress, amounts[vars.i]);
        }

        require(
            vars.receiver.executeOperation(assets, amounts, premiums, msg.sender, params),
            "FlashLoan: invalid flash loan executor return!"
        );

        for (vars.i = 0; vars.i < assets.length; vars.i++) {
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

            uint256 borrowBalance = CToken(vars.currentFTokenAddress).borrowBalanceCurrent(address(this));
            if (vars.currentAsset == address(_WETH)) {
                _WETH.withdraw(vars.currentAmountPlusPremium);

                // repay loan.
                CEther(vars.currentFTokenAddress).repayBorrow.value(borrowBalance)();

                if (vars.currentPremium > 0) {
                    // send premium to owner.
                    address(uint160(owner())).transfer(vars.currentAmountPlusPremium.sub(borrowBalance));
                }
            } else {
                IERC20(vars.currentAsset).safeApprove(vars.currentFTokenAddress, 0);
                IERC20(vars.currentAsset).safeApprove(vars.currentFTokenAddress, borrowBalance);

                 // repay loan.
                err = CToken(vars.currentFTokenAddress).repayBorrow(borrowBalance);
                require(err == 0, "FlashLoan: repayBorrow error");

                if (vars.currentPremium > 0) {
                    // send premium to owner.
                    IERC20(vars.currentAsset).safeTransfer(owner(), vars.currentAmountPlusPremium.sub(borrowBalance));
                }
            }

            emit FlashLoan(
                receiverAddress,
                msg.sender,
                vars.currentAsset,
                vars.currentAmount,
                vars.currentPremium
            );
        }

        require(liquidity <= _getLiquidity(), "FlashLoan: liquidity decreased!");
    }

    function borrowETH(address cetherAddr, uint256 amount) internal {
        uint err = CEther(cetherAddr).borrow(amount);
        require(err == 0, "FlashLoan: borrow error");

        _WETH.deposit.value(amount)();
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
     * @param assets The address list of the underlying asset of the reserve
     * @param fTokenAddresses The address list of the fToken
     **/
    function initReserve(
        address[] calldata assets,
        address[] calldata fTokenAddresses
    ) external onlyGovernance {
        for (uint8 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            require(Address.isContract(asset), "FlashLoan: asset address is not contract");
            require(_reserves[asset].fTokenAddress == address(0), "FlashLoan: reserve already initialized.");

            enterMarket(fTokenAddresses[i]);

            _reserves[asset].fTokenAddress = fTokenAddresses[i];
            _reserves[asset].tokenAddress = asset;

            _addReserveToList(asset);
        }
    }

    /**
     * @dev Returns the state and configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The state of the reserve
     **/
    function getReserveData(address asset)
        external
        view
        returns (address, uint8)
    {
        return (_reserves[asset].fTokenAddress, _reserves[asset].id);
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

    function withdrawERC20(address _token, address _account, uint256 amount) public onlyOwner {
        require(_token != address(0) && _account != address(0) && amount > 0, "FlashLoan: Invalid parameter");
        IERC20 token = IERC20(_token);
        if (amount > token.balanceOf(address(this))) {
            amount = token.balanceOf(address(this));
        }
        token.safeTransfer(_account, amount);
    }

    function withdraw(address payable _account, uint256 amount) public onlyOwner {
        require(_account != address(0) && amount > 0, "FlashLoan: Invalid parameter");
        if (amount > address(this).balance) {
            amount = address(this).balance;
        }
        _account.transfer(amount);
    }

    function getComptroller() external view returns (address) {
        return address(_comptroller);
    }

    function setComptroller(address comptroller) external onlyGovernance {
        require(comptroller != address(0), "FlashLoan: comptroller address can not be zero");
        _comptroller = Comptroller(comptroller);
    }

    function enterMarket(address ftoken) internal {
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

    function _getLiquidity() private view returns (uint256) {
        (uint error, uint256 liquidity, uint shortfall) = _comptroller.getAccountLiquidity(address(this));
        if (error != 0 || shortfall != 0) {
            return 0;
        }

        return liquidity;
    }

    function getLiquidity() public view returns (uint256) {
        return _getLiquidity().mul(getHtPrice()).div(1e18);
    }

    function getOracle() external view returns (address) {
        return address(_oracle);
    }

    function setOracle(address oracle) external onlyGovernance {
        require(Address.isContract(oracle), "FlashLoan: oracle address is not contract");

        address from = address(_oracle);
        _oracle = ChainlinkAdaptor(oracle);

        emit OracleChanged(from, oracle);
    }

    function getMaxTokenAmount(address asset) public view returns (uint256) {
        require(Address.isContract(asset), "FlashLoan: asset address is not contract");
        require(_reserves[asset].fTokenAddress != address(0), "FlashLoan: this asset is not surpported");

        if (asset == address(_WETH)) {
            return _getLiquidity();
        }

        uint256 liquidity = getLiquidity();
        if (liquidity == 0) {
            return 0;
        }

        uint256 husdHTPrice = _oracle.getUnderlyingPrice(CToken(_fHUSD));
        uint256 tokenHTPrice = _oracle.getUnderlyingPrice(CToken(_reserves[asset].fTokenAddress));

        uint256 decimals = IERC20Extented(asset).decimals();
        uint256 tokenPrice = tokenHTPrice.mul(10**decimals).div(husdHTPrice);

        return liquidity.mul(10**decimals).div(tokenPrice);
    }

    function getHtPrice() private view returns (uint256) {
        return uint256(1e36).div(_oracle.getUnderlyingPrice(CToken(_fHUSD)));
    }

    function WETH() external view returns (address) {
        return address(_WETH);
    }

    function () external payable {}

    function addToWhitelist(address[] calldata _targets) external onlyGovernance {
        require(_targets.length > 0, "FlashLoan: invalid argument");
        for (uint i = 0; i < _targets.length; i++) {
            require(_targets[i] != address(0), "FlashLoan: whitelist can not be zero address");
            _whitelist[_targets[i]] = true;
        }
    }

    function removeFromWhitelist(address _target) external onlyGovernance {
        require(_target != address(0), "FlashLoan: whitelist can not be zero address");
        _whitelist[_target] = false;
    }

    function isInWhitelist(address _target) public view returns (bool) {
        return _whitelist[_target];
    }
}
