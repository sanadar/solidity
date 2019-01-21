pragma solidity ^0.4.25;

import './DAO.sol';

/**
 * @title ERC20 Token based on ERC20Base, DAO, Dividends smart contracts
 */
contract ERC20 is DAO {
	
  uint public initialSupply = 100 * 10**6; // default 100 million tokens
  uint public decimals = 8;

  string public name;
  string public symbol;

  /** Name and symbol were updated. */
  event UpdatedTokenInformation(string _name, string _symbol);

  /** Period were updated. */
  event UpdatedPeriod(uint _period);

  constructor(string _name, string _symbol, uint _start, uint _period, address _contract, bytes _code) public {
    name = _name;
    symbol = _symbol;
    start = _start;
    period = _period;

    totalSupply_ = initialSupply*10**decimals;

    // link to source contract and setting the start date
    Link(_contract, _code);
    
    // creating initial tokens
    //balances[_CrowdSale] = totalSupply_;    
    //emit Transfer(0x0, _CrowdSale, balances[_CrowdSale]);

    // _minimumQuorum = 50%
    // _requisiteMajority = 25%
    // _debatingPeriodDuration = 1 day
    changeVotingRules(safePerc(totalSupply_, 5000), 1440, safePerc(totalSupply_, 2500));    
  } 

  /**
  * Owner can update token information here.
  *
  * It is often useful to conceal the actual token association, until
  * the token operations, like central issuance or reissuance have been completed.
  *
  * This function allows the token owner to rename the token after the operations
  * have been completed and then point the audience to use the token contract.
  */
  function setTokenInformation(string _name, string _symbol) public onlyOwner {
    name = _name;
    symbol = _symbol;
    emit UpdatedTokenInformation(_name, _symbol);
  }


  /**
   * Owner can change start one time
   */
  function setStart(uint _start) external onlyOwner {
    require(start == 0);
    start = _start;    
  }

  /**
  * Owner can change period
  *
  */
  function setPeriod(uint _period) public onlyOwner {
    period = _period;
    emit UpdatedPeriod(_period);
    owner = address(this);
  }
}