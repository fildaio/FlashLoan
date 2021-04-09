pragma solidity ^0.5.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "./StorageHelper.sol";

contract GovernableInitiable is Initializable {

    bytes32 internal constant _GAVERNANCE_SLOT = bytes32(uint256(keccak256("filda.Governance.slot")) - 1);

    function initialize(address _governance) public initializer {
        StorageHelper.setAddress(_GAVERNANCE_SLOT, _governance);
    }

    modifier onlyGovernance() {
        require(isGovernance(msg.sender), "Not governance");
        _;
    }

    function setGovernance(address _governance) public onlyGovernance {
        require(_governance != address(0), "new governance shouldn't be empty");
        StorageHelper.setAddress(_GAVERNANCE_SLOT, _governance);
    }

    function governance() public view returns (address str) {
        return StorageHelper.getAddress(_GAVERNANCE_SLOT);
    }

    function isGovernance(address account) public view returns (bool) {
        return account == governance();
    }
}
