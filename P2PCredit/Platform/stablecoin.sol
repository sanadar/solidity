pragma solidity ^0.4.25;

import '../common/Agent.sol';
import '../ERC20/ERC20.sol';

/**
 * @title Stable Coin based on ERC20 token
 */
contract StableCoin is ERC20, Agent {
    
    string public name;
    string public symbol;

    uint public decimals = 18;

    event Transfer(address indexed from, address indexed to, uint256 value, string receiver);
    event UpdatedTokenInformation(string _name, string _symbol);

    constructor(string _name, string _symbol) public {
        name = _name;
        symbol = _symbol;
    }

    /** 
    * @dev Tranfer tokens to address
    * @param _to dest address
    * @param _value tokens amount
    * @param _receiver recipient's address in the token-related blockchain 
    * @return transfer result
    */
    function transfer(address _to, uint256 _value, string _receiver) public returns (bool success) {
        require(_to == address(this));
        require(balances[msg.sender] >= _value);

        _to = address(0);
        
        balances[msg.sender] = safeSub(balances[msg.sender], _value);
        balances[_to] = safeAdd(balances[_to], _value);
        
        emit Transfer(msg.sender, _to, _value, _receiver);
        return true;
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
    * Owner may issue new tokens
    */
    function mint(address _receiver, uint _amount) public onlyOwner {
        balances[_receiver] = safeAdd(balances[_receiver], _amount);
        totalSupply_ = safeAdd(totalSupply_, _amount);
        emit Transfer(0x0, _receiver, _amount);    
    }

    /**
    * Owner of the tokens can burn tokens by sending them to address (0)
    * ERC20.transfer(address(0), _amount);
    */
}