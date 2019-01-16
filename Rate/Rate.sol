pragma solidity ^0.4.25;

import '../common/SafeMath.sol';
import '../common/Agent.sol';

/**
 * @title Rate Contract 
 * @dev Letter values of currencies according to the standard ISO4217.
 * @dev ETH alfa-3 code as it's and contains the rate to USD. Example: rate["ETH"] = 227$. 
 * @dev rate[alfa-3 field of currency in ISO4217] contains rate to USD. 
 * @dev examples: rate["USD"] = 1, rate["EUR"] = 0.86, rate["RUB"] = 68.25
 */
contract Rate is Agent, SafeMath {

    struct ISO4217 {
        string name;        
        uint number3;
        uint decimal;
        uint timeadd;
        uint timeupdate;
    }
    
    mapping(bytes32 => ISO4217) public currency;
    mapping(bytes32 => uint) public rate;
    
    event addCurrencyEvent(bytes32 _code, string _name, uint _number3, uint _decimal, uint _timeadd);
    event updateCurrencyEvent(bytes32 _code, string _name, uint _number3, uint _decimal, uint _timeupdate);
    event updateRateEvent(bytes32 _code, uint _value);
    event donationEvent(address _from, uint _value);

    constructor() public {
        addCurrency("ETH", "Ethereum", 0, 2);           // 0x455448
        addCurrency("RUB", "Russian Ruble", 643, 2);    // 0x525542        
        addCurrency("USD", "US Dollar", 840, 2);        // 0x555344
    }

    // returns the Currency
    function getCurrency(bytes32 _code) public view returns (string name, uint number3, uint decimal, uint timeadd, uint timeupdate) {
        return (currency[_code].name, currency[_code].number3, currency[_code].decimal, currency[_code].timeadd, currency[_code].timeupdate);
    }

    // returns Rate of coin to USD
    function getRate(bytes32 _code) public view returns (uint) {
        return rate[_code];
    }

    // returns Price of Object in the specified currency (local user currency (the result must be divided by the currency decimal))
    // _code - specified currency
    // _amount - price of object in USD
    function getLocalPrice(bytes32 _code, uint _amount) public view returns (uint) {
        return safeMul(rate[_code], _amount);
    }

    // returns Price of Object in the crypto currency (WEI)    
    // _amount - price of object in USD
    function getCryptoPrice(uint _amount) public view returns (uint) {
        return safeDiv(safeMul(safeMul(_amount, 1 ether), 10**currency["ETH"].decimal), rate["ETH"]);
    }

    // update rates for a specific coin
    function updateRate(bytes32 _code, uint _USD) public onlyAgent {
        rate[_code] = _USD;
        emit updateRateEvent(_code, _USD);
    }

    // Add new Currency
    function addCurrency(bytes32 _code, string _name, uint _number3, uint _decimal) public onlyAgent {        
        currency[_code] = ISO4217(_name, _number3, _decimal, block.timestamp, 0);
        emit addCurrencyEvent(_code, _name, _number3, _decimal, block.timestamp);
    }

    // update Currency
    function updateCurrency(bytes32 _code, string _name, uint _number3, uint _decimal) public onlyAgent {        
        currency[_code] = ISO4217(_name, _number3, _decimal, currency[_code].timeadd, block.timestamp);
        emit updateCurrencyEvent(_code, _name, _number3, _decimal, block.timestamp);
    }

    // execute function by owner if ERC20 token get stuck in this contract
    function execute(address _to, uint _value, bytes _data) external onlyOwner {
        require(_to.call.value(_value)(_data));        
    }
    
    function() public payable {}

    // donation function that get forwarded to the contract updater
    function donate() external payable {
        require(msg.value >= 0);        
        emit donationEvent(msg.sender, msg.value);
    }
}