pragma solidity ^0.4.18;

import './ERC223/ERC223.sol';
import './ERC223/Receiver.sol';
import './math/SafeMath.sol';
import './ownership/Ownable.sol';

/**
 * @title Reference implementation of the ERC223 standard token.
 */
interface tokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external;
}

/**
 * ERC23 token by Dexaran
 *
 * https://github.com/Dexaran/ERC23-tokens
 */
contract ArtvalNewToken is Ownable, ERC223Interface {
    using SafeMath for uint;

    struct FrozenState {
        bool frozen;
        uint fronzentill;//序号
    }

    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    // 18 decimals is the strongly suggested default, avoid changing it
    uint256 public totalSupply;
    // switch to check frozen state
    bool public frozencheck;
    mapping (address => mapping (address => uint256)) public allowance;
    mapping(address => uint) balances; // List of user balances.
    mapping(address => FrozenState)frozens; //List of user forzen state

    event TransferAndFrozen(address indexed from, address indexed to, uint value, uint blocknum);
    event FrozenTillBolckNum(address indexed from, uint blocknum);

    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function ArtvalNewToken(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public {
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        balances[msg.sender] = totalSupply;                // Give the creator all initial tokens
        name = tokenName;                                   // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
        frozencheck = true;                                 // Set to check forzenstate
    }

    /**
     * @dev Before transfer token, if forzencheck is true, need to check the from and to address is forzen or not
     * @param _frozen state _value.
     */
    function setfronzencheck(bool _frozen) onlyOwner public{
        frozencheck = _frozen;
    }

    /**
     * @dev Transfer token to some address and set the address to frozen
     * @param _to           Reveiver address
     * @param _value        Amount of tokens that will be fransferred
     * @param _blockNum     Forzen till this block
     */
    function transferAndFrozen(address _to, uint _value, uint _blockNum) onlyOwner public{
        assert (balances[_to] == 0 );
        assert (_blockNum > block.number+1000);

        FrozenState storage fstate = frozens[_to];
        fstate.frozen = true;
        fstate.fronzentill = _blockNum;

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        TransferAndFrozen(msg.sender, _to, _value, _blockNum);
    }



    /**
     * @dev Transfer the specified amount of tokens to the specified address.
     *      Invokes the `tokenFallback` function if the recipient is a contract.
     *      The token transfer fails if the recipient is a contract
     *      but does not implement the `tokenFallback` function
     *      or the fallback function to receive funds.
     *
     * @param _to    Receiver address.
     * @param _value Amount of tokens that will be transferred.
     * @param _data  Transaction metadata.
     */
    function transfer(address _to, uint _value, bytes _data) public {
        // Standard function transfer similar to ERC20 transfer with no _data .
        // Added due to backwards compatibility reasons .
        if(frozencheck == true)
        {
            FrozenState storage fstate = frozens[msg.sender];
            if(fstate.frozen == true){
                if(fstate.fronzentill < block.number)
                    fstate.frozen = false;
                else{
                    FrozenTillBolckNum(msg.sender, fstate.fronzentill);
                    return;
                }
            }
        }

        uint codeLength;

        assembly {
        // Retrieve the size of the code on target address, this needs assembly .
            codeLength := extcodesize(_to)
        }

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        if (codeLength > 0) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            receiver.tokenFallback(msg.sender, _value, _data);
        }
        Transfer(msg.sender, _to, _value, _data);
    }

    /**
     * @dev Transfer the specified amount of tokens to the specified address.
     *      This function works the same with the previous one
     *      but doesn't contain `_data` param.
     *      Added due to backwards compatibility reasons.
     *
     * @param _to    Receiver address.
     * @param _value Amount of tokens that will be transferred.
     */
    function transfer(address _to, uint _value) public {
        uint codeLength;
        bytes memory empty;

        if(frozencheck == true)
        {
            FrozenState storage fstate = frozens[msg.sender];
            if(fstate.frozen == true){
                if(fstate.fronzentill < block.number)
                    fstate.frozen = false;
                else{
                    FrozenTillBolckNum(msg.sender, fstate.fronzentill);
                    return;
                }
            }
        }

        assembly {
        // Retrieve the size of the code on target address, this needs assembly .
            codeLength := extcodesize(_to)
        }

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        if (codeLength > 0) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            receiver.tokenFallback(msg.sender, _value, empty);
        }
        Transfer(msg.sender, _to, _value, empty);
    }

    /**
     * @dev Returns balance of the `_owner`.
     *
     * @param _owner   The address whose balance will be returned.
     * @return balance Balance of the `_owner`.
     */
    function balanceOf(address _owner) constant public returns (uint balance) {
        return balances[_owner];
    }

    ///////////////////////////////////////////////////////////////////////////////////////////
    // below functions came from ERC20
    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens in your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }
    /**
     * Set allowance for other address and notify
     *
     * Allows `_spender` to spend no more than `_value` tokens in your behalf, and then ping the contract about it
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) public returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }
}