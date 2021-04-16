pragma solidity ^0.5.0;

contract Governable {

  address public governance;

  constructor(address _governance) public {
    require(_governance != address(0), "governance shouldn't be empty");
    governance = _governance;
  }

  modifier onlyGovernance() {
    require(isGovernance(msg.sender), "Not governance");
    _;
  }

  function setGovernance(address _governance) public onlyGovernance {
    require(_governance != address(0), "new governance shouldn't be empty");
    governance = _governance;
  }


  function isGovernance(address account) public view returns (bool) {
    return account == governance;
  }
}
