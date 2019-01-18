pragma solidity ^0.4.25;

import './Ownable.sol';

/**
 * @title Agent contract - base contract with an agent
 */
contract Agent is Ownable {

  mapping(address => bool) public Agents;
  
  constructor() public {
    Agents[msg.sender] = true;
  }
  
  modifier onlyAgent() {
    assert(Agents[msg.sender]);
    _;
  }
  
  function updateAgent(address _agent, bool _status) public onlyOwner {
    assert(_agent != address(0));
    Agents[_agent] = _status;
  }  
}