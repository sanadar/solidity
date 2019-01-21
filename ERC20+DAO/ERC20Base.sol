pragma solidity ^0.4.25;

import '../common/SafeMath.sol';
import '../ERC20/ERC20I.sol';

/**
 * @title Standard ERC20 token + balance on date
 * @dev Implementation of the basic standard token.
 * @dev https://github.com/ethereum/EIPs/issues/20 
 */
contract ERC20Base is ERC20I, SafeMath {
	
  uint256 totalSupply_;
  mapping (address => uint256) balances;
  mapping (address => mapping (address => uint256)) internal allowed;

  uint256 public start = 0;               // Must be equal to the date of issue tokens
  uint256 public period = 30 days;        // By default, the dividend accrual period is 30 days
  mapping (address => mapping (uint256 => int256)) public ChangeOverPeriod;

  address[] public owners;
  mapping (address => bool) public ownersIndex;

  struct _Prop {
    uint propID;          // proposal ID in DAO    
    uint endTime;         // end time of voting
  }
  
  _Prop[] public ActiveProposals;  // contains active proposals

  // contains voted Tokens on proposals
  mapping (uint => mapping (address => uint)) public voted;

  /** 
   * @dev Total Supply
   * @return totalSupply_ 
   */  
  function totalSupply() public view returns (uint256) {
    return totalSupply_;
  }
  
  /** 
   * @dev Tokens balance
   * @param _owner holder address
   * @return balance amount 
   */
  function balanceOf(address _owner) public view returns (uint256) {
    return balances[_owner];
  }

  /** 
   * @dev Balance of tokens on date
   * @param _owner holder address
   * @return balance amount 
   */
  function balanceOf(address _owner, uint _date) public view returns (uint256) {
    require(_date >= start);
    uint256 N1 = (_date - start) / period + 1;    

    uint256 N2 = 1;
    if (block.timestamp > start) {
      N2 = (block.timestamp - start) / period + 1;
    }

    require(N2 >= N1);

    int256 B = int256(balances[_owner]);

    while (N2 > N1) {
      B = B - ChangeOverPeriod[_owner][N2];
      N2--;
    }

    require(B >= 0);
    return uint256(B);
  }

  /** 
   * @dev Tranfer tokens to address
   * @param _to dest address
   * @param _value tokens amount
   * @return transfer result
   */
  function transfer(address _to, uint256 _value) public returns (bool success) {
    require(_to != address(0));

    uint lock = 0;
    for (uint k = 0; k < ActiveProposals.length; k++) {
      if (ActiveProposals[k].endTime > now) {
        if (lock < voted[ActiveProposals[k].propID][msg.sender]) {
          lock = voted[ActiveProposals[k].propID][msg.sender];
        }
      }
    }

    require(safeSub(balances[msg.sender], lock) >= _value);

    if (ownersIndex[_to] == false && _value > 0) {
      ownersIndex[_to] = true;
      owners.push(_to);
    }
    
    balances[msg.sender] = safeSub(balances[msg.sender], _value);
    balances[_to] = safeAdd(balances[_to], _value);

    uint256 N = 1;
    if (block.timestamp > start) {
      N = (block.timestamp - start) / period + 1;
    }

    ChangeOverPeriod[msg.sender][N] = ChangeOverPeriod[msg.sender][N] - int256(_value);
    ChangeOverPeriod[_to][N] = ChangeOverPeriod[_to][N] + int256(_value);
   
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  /** 
   * @dev Token allowance
   * @param _owner holder address
   * @param _spender spender address
   * @return remain amount
   */
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }

  /**    
   * @dev Transfer tokens from one address to another
   * @param _from source address
   * @param _to dest address
   * @param _value tokens amount
   * @return transfer result
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
    require(_to != address(0));

    uint lock = 0;
    for (uint k = 0; k < ActiveProposals.length; k++) {
      if (ActiveProposals[k].endTime > now) {
        if (lock < voted[ActiveProposals[k].propID][_from]) {
          lock = voted[ActiveProposals[k].propID][_from];
        }
      }
    }
    
    require(safeSub(balances[_from], lock) >= _value);
    
    require(allowed[_from][msg.sender] >= _value);

    if (ownersIndex[_to] == false && _value > 0) {
      ownersIndex[_to] = true;
      owners.push(_to);
    }
    
    balances[_from] = safeSub(balances[_from], _value);
    balances[_to] = safeAdd(balances[_to], _value);
    allowed[_from][msg.sender] = safeSub(allowed[_from][msg.sender], _value);
    
    uint256 N = 1;
    if (block.timestamp > start) {
      N = (block.timestamp - start) / period + 1;
    }

    ChangeOverPeriod[_from][N] = ChangeOverPeriod[_from][N] - int256(_value);
    ChangeOverPeriod[_to][N] = ChangeOverPeriod[_to][N] + int256(_value);

    emit Transfer(_from, _to, _value);
    return true;
  }
  
  /** 
   * @dev Approve transfer
   * @param _spender holder address
   * @param _value tokens amount
   * @return result  
   */
  function approve(address _spender, uint256 _value) public returns (bool success) {
    require((_value == 0) || (allowed[msg.sender][_spender] == 0));
    allowed[msg.sender][_spender] = _value;
    
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /** 
   * @dev Trim owners with zero balance
   */
  function trim(uint offset, uint limit) external returns (bool) { 
    uint k = offset;
    uint ln = limit;
    while (k < ln) {
      if (balances[owners[k]] == 0) {
        ownersIndex[owners[k]] =  false;
        owners[k] = owners[owners.length-1];
        owners.length = owners.length-1;
        ln--;
      } else {
        k++;
      }
    }
    return true;
  }

  // current number of shareholders (owners)
  function getOwnersCount() external view returns (uint256 count) {
    return owners.length;
  }

  // current period
  function getCurrentPeriod() external view returns (uint256 N) {
    if (block.timestamp > start) {
      return (block.timestamp - start) / period;
    } else {
      return 0;
    }
  }

  function addProposal(uint _propID, uint _endTime) internal {
    ActiveProposals.push(_Prop({
      propID: _propID,
      endTime: _endTime
    }));
  }

  function delProposal(uint _propID) internal {
    uint k = 0;
    while (k < ActiveProposals.length){
      if (ActiveProposals[k].propID == _propID) {
        require(ActiveProposals[k].endTime < now);
        ActiveProposals[k] = ActiveProposals[ActiveProposals.length-1];
        ActiveProposals.length = ActiveProposals.length-1;   
      } else {
        k++;
      }
    }    
  }

  function getVoted(uint _propID, address _voter) external view returns (uint) {
    return voted[_propID][_voter];
  }
}