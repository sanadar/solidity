pragma solidity ^0.4.25;

import '../common/Agent.sol';
import '../common/SafeMath.sol';
import '../ERC20/ERC20I.sol';

/**
 * @title P2P Credit Platform core contract
 */
contract Core is Agent, SafeMath {

    uint DelayWithdraw = 1 hours;  
    uint TTL = 1 days;            // Time To Life for Request
    uint fee = 1000; // 10%
    address feeAddress;

    struct _Token {
        address addr;
        bytes32 symb;
        bool state;
    }
    
    _Token[] public Tokens;

    string[] public Purposes; // loan purposes

    mapping (uint => mapping (address => uint)) public Balances;
    mapping (uint => mapping (address => uint)) public WithdrawState;
    
    mapping (bytes32 => bool) AlreadyTaken;
    mapping (bytes32 => bool) AlreadyCanceled;

    event creditIssued(address from, address to, uint amount, bytes32 currency, uint rate, uint term, string purpose);

    event cancelAnswer(bytes32 ans_hash, uint time);

    event deposit(uint tokenID, address sender, uint amount);

    event requestWithdraw(uint tokenID, address sender, uint time);
    event withdraw(uint tokenID, address sender, uint amount);

    event addedNewToken(uint tokenID, address token, bytes32 symbol);
    event changeStateToken(uint tokenID, bool state);

    event changeDelayWithdraw(uint delay);
    event changeFee(uint fee);
    event changeFeeAddress(address feeAddress);
    event changeTTL(uint TTL);    

    constructor() public {
        Tokens.push(_Token({addr: address(0), symb: "ETH", state: true}));
        emit addedNewToken(0, address(0),"ETH");

        feeAddress = address(this);

        Purposes.push("Payday");
        Purposes.push("Medical");
        Purposes.push("Car repair");
        Purposes.push("Home repair");
        Purposes.push("Tourism");
    }

    /**
     * Deposit ETH or ERC20 token (stablecoin)
     */
    function Deposit(uint _tokenID, uint _amount) payable external {        
        require(Tokens[_tokenID].state);

        if (Tokens[_tokenID].symb == "ETH") {
            Balances[_tokenID][msg.sender] = safeAdd(Balances[_tokenID][msg.sender], msg.value);
            emit deposit(_tokenID, msg.sender, msg.value);
        } else {
            require(ERC20I(Tokens[_tokenID].addr).transferFrom(msg.sender, address(this), _amount));
            Balances[_tokenID][msg.sender] = safeAdd(Balances[_tokenID][msg.sender], _amount);
            emit deposit(_tokenID, msg.sender, _amount);
        }
    }

    /**
     * Deposit ERC223 token (stablecoin)
     */ 
    function tokenFallback(address _recipient, uint _amount, bytes _data) external {        
        uint tokenID = 0;
        for (uint i = 1; i < Tokens.length; i++) {
            if (Tokens[i].addr == msg.sender) {
                tokenID = i;
                break;
            }
        }
        require(tokenID > 0);
        require(Tokens[tokenID].state);
        Balances[tokenID][_recipient] = safeAdd(Balances[tokenID][_recipient], _amount);
        emit deposit(tokenID, _recipient, _amount);
    }

    /**
     * Check hash of loan request parameters
     */
    function CheckLoanRequestHash(address _borrower, bytes32 _req_hash, uint _amount, uint _currency, uint _rate, uint _term, uint _purpose, uint _date, uint _nonce) view external returns (bool result) {
        return _req_hash == keccak256(abi.encodePacked(this, _borrower, _amount, Tokens[_currency].symb, _rate, _term, _purpose, _date, _nonce));
    }

    /**
     * Check hash of answer parameters
     */       
    function CheckAnswerHash(address _creditor, bytes32 _ans_hash, bytes32 _req_hash, uint _amount, uint _rate, uint _term, uint _nonce) view external returns (bool result) {
        return _ans_hash == keccak256(abi.encodePacked(this, _creditor, _req_hash, _amount, _rate, _term, _nonce));
    }

    /**
     * Take loan
     *
     * @param creditor - creditor address
     * @param puint - array of uint256 parameters:
     *        puint[0] = requested amount
     *        puint[1] = requested currency (token ID from Tokens array)
     *        puint[2] = requested rate (annual interest rate)
     *        puint[3] = requested term (term in days)
     *        puint[4] = requested purpose (purpose ID from Purposes array)
     *        puint[5] = requested date (date of application)
     *        puint[6] = requested nonce
     *        puint[7] = answered amount
     *        puint[8] = answered rate (annual interest rate)
     *        puint[9] = answered term (term in days)
     *        puint[10] = answered nonce
     * @param v - recovery id:
     *        v[0] = requested v
     *        v[1] = answered v
     * @param pbytes - array of bytes32 parameters:
     *        pbytes[0] = requested hash
     *        pbytes[1] = requested r
     *        pbytes[2] = requested s
     *        pbytes[3] = answered r
     *        pbytes[4] = answered s
     */
    function TakeLoan(address creditor, uint[] puint, uint8[] v, bytes32[] pbytes) public {
        require(Tokens[puint[1]].state);
        require(puint[5] <= block.timestamp + TTL);
        require(Balances[puint[1]][creditor] >= puint[7]);        

        bytes32 req_hash = keccak256(abi.encodePacked(address(this), msg.sender, puint[0], Tokens[puint[1]].symb, puint[2], puint[3], puint[4], puint[5], puint[6]));
        bytes32 ans_hash = keccak256(abi.encodePacked(address(this), creditor, pbytes[0],puint[7], puint[8], puint[9], puint[10]));

        require(!AlreadyCanceled[ans_hash]);

        require(!AlreadyTaken[req_hash]);
        AlreadyTaken[req_hash] = true;

        require( ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", req_hash)), v[0], pbytes[1], pbytes[2]) == msg.sender );
        require( ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", ans_hash)), v[1], pbytes[3], pbytes[4]) == creditor );

        Balances[puint[1]][creditor] = safeSub(Balances[puint[1]][creditor], puint[7]);

        uint feeAmount = safePerc(puint[7], fee);
        Balances[puint[1]][feeAddress] = safeAdd(Balances[puint[1]][feeAddress], feeAmount);
        Balances[puint[1]][msg.sender] = safeAdd(Balances[puint[1]][msg.sender], safeSub(puint[7], feeAmount));

        emit creditIssued(creditor, msg.sender, puint[7], Tokens[puint[1]].symb, puint[8], puint[9], Purposes[puint[4]]);
    }


    /**
     * Cancel Answer on Request
     */
    function CancelAnswer(bytes32 _ans_hash, uint8 _v, bytes32 _r, bytes32 _s) public {
        require(!AlreadyCanceled[_ans_hash]);
        
        require( ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _ans_hash)), _v, _r, _s) == msg.sender );

        AlreadyCanceled[_ans_hash] = true;

        emit cancelAnswer(_ans_hash, block.timestamp);
    }

    function RequestWithdraw(uint _tokenID) external {
        require(WithdrawState[_tokenID][msg.sender] == 0);
        WithdrawState[_tokenID][msg.sender] = block.timestamp + DelayWithdraw;
        emit requestWithdraw(_tokenID, msg.sender, WithdrawState[_tokenID][msg.sender]);
    }

    /**
     * Withdraw amount by user
     */
    function Withdraw(uint _tokenID, uint _amount) external {
        require(Balances[_tokenID][msg.sender] >= _amount);
        require(WithdrawState[_tokenID][msg.sender] < block.timestamp);
        WithdrawState[_tokenID][msg.sender] = 0;

        Balances[_tokenID][msg.sender] = safeSub(Balances[_tokenID][msg.sender], _amount);

        if (Tokens[_tokenID].symb == "ETH") {            
            msg.sender.transfer(_amount);
        } else {
            require(ERC20I(Tokens[_tokenID].addr).transfer(msg.sender, _amount));
        }
        
        emit withdraw(_tokenID, msg.sender, _amount);
    }

    /**
     * Withdraw amount by owner
     */
    function Withdraw(address _recipient, uint _tokenID, uint _amount) external onlyOwner {
        require(Balances[_tokenID][address(this)] >= _amount);

        Balances[_tokenID][address(this)] = safeSub(Balances[_tokenID][address(this)], _amount);

        if (Tokens[_tokenID].symb == "ETH") {            
            _recipient.transfer(_amount);
        } else {
            require(ERC20I(Tokens[_tokenID].addr).transfer(_recipient, _amount));
        }
        
        emit withdraw(_tokenID, address(this), _amount);
    }    

    // service functions
    function addToken(address _address, bytes32 _symbol) external onlyOwner {
        require(_address != address(0));
        Tokens.push(_Token({addr: _address, symb: _symbol, state: true}));
        emit addedNewToken(Tokens.length-1, _address, _symbol);
    }

    function ChangeStateToken(uint _tokenID, bool _state) external onlyOwner {
        Tokens[_tokenID].state = _state;
        emit changeStateToken(_tokenID, _state);
    }

    function setDelayWithdraw(uint _delay) external onlyOwner {
        DelayWithdraw = _delay;
        emit changeDelayWithdraw(_delay);
    }  

    function setFee(uint _fee) external onlyOwner {
        fee = _fee;
        emit changeFee(_fee);
    }      

    function setFeeAddress(address _feeAddress) external onlyOwner {
        feeAddress = feeAddress;
        emit changeFeeAddress(_feeAddress);
    }      

    function setTTL(uint _TTL) external onlyOwner {
        TTL = _TTL;
        emit changeTTL(_TTL);
    }    
}