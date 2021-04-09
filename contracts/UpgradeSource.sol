pragma solidity ^0.5.0;

import "./GovernableInitiable.sol";
import "./dependency.sol";

contract UpgradeSource is GovernableInitiable {
    using SafeMath for uint256;

    bytes32 internal constant _IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("filda.Implementation.slot")) - 1);
    bytes32 internal constant _UPGRADE_TIME_SLOT = bytes32(uint256(keccak256("filda.UpgradeTime.slot")) - 1);

    function initialize(address _governance) public initializer {
        GovernableInitiable.initialize(_governance);
    }
    
    /**
    * Schedules an upgrade for this vault's proxy.
    */
    function scheduleUpgrade(address impl, uint256 delay) public onlyGovernance {
        require(impl != address(0), "implement address is 0!");
        StorageHelper.setAddress(_IMPLEMENTATION_SLOT, impl);
        StorageHelper.setUint256(_UPGRADE_TIME_SLOT, block.timestamp.add(delay));
    }

    function nextImplementationTimestamp() public view returns (uint256) {
        return StorageHelper.getUint256(_UPGRADE_TIME_SLOT);
    }

    function nextImplementation() public view returns (address) {
        return StorageHelper.getAddress(_IMPLEMENTATION_SLOT);
    }

    function shouldUpgrade() external view returns (bool, address) {
        return (
            nextImplementationTimestamp() != 0
                && block.timestamp > nextImplementationTimestamp()
                && nextImplementation() != address(0),
            nextImplementation()
        );
    }

    function finalizeUpgrade() external onlyGovernance {
        StorageHelper.setAddress(_IMPLEMENTATION_SLOT, address(0));
        StorageHelper.setUint256(_UPGRADE_TIME_SLOT, 0);
    }
}
