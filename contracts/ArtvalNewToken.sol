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
        uint frozentill;//序号
    }

    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    // 18 decimals is the strongly suggested default, avoid changing it
    uint256 public totalSupply;
    // switch to check frozen state
    bool public frozencheck;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint) balances; // List of user balances.
    mapping(address => FrozenState)frozens; //List of user forzen state

    event TransferAndFrozen(address indexed from, address indexed to, uint value, uint blocknum);
    event FrozenTillBolckNum(address indexed from, uint blocknum);
    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function ArtvalNewToken(uint256 initialSupply, string tokenName, string tokenSymbol) public {
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
    function setfrozencheck(bool _frozen) onlyOwner public {
        frozencheck = _frozen;
    }

    /**
     * @dev Transfer token to some address and set the address to frozen
     * @param _to           Reveiver address
     * @param _value        Amount of tokens that will be fransferred
     * @param _blockNum     Forzen till this block
     */
    function transferAndFrozen(address _to, uint _value, uint _blockNum) onlyOwner public {
//        assert (balances[_to] == 0);
        require(_blockNum > 1000);

        FrozenState storage fstate = frozens[_to];
        fstate.frozen = true;
        fstate.frozentill = block.number + _blockNum;

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        TransferAndFrozen(msg.sender, _to, _value, _blockNum);
    }

    /**
     * @dev Query an address is in frozen or not. If not, return 0; else return the frozentill block number
     * param _adr             the address to check frozen status
     */
    function checkFrozenStatus(address _adr) public returns(uint) {
        if (frozencheck == true) {
            FrozenState storage fstate = frozens[_adr];
            if (fstate.frozen == true) {
                if (fstate.frozentill < block.number) {
                    fstate.frozen = false;
                } else {
                    return fstate.frozentill;
                }
            }
        }

        return 0;
    }

    /**
     * @dev Query self address is in frozen or not. If not, return 0; else return the frozentill block number
     */
    function checkSelfFrozenStatus() public returns(uint) {
        uint frozenTillBlock = checkFrozenStatus(msg.sender);
        FrozenTillBolckNum(msg.sender, frozenTillBlock);
        return frozenTillBlock;
    }

    /**
     * @dev Query frozen status for address.
     */
    function frozenStatusOf(address _addr) view public returns(bool, uint) {
        FrozenState storage state = frozens[_addr];
        return (state.frozen, state.frozentill);
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
        uint frozenTill = checkFrozenStatus(msg.sender);
        if (frozenTill > 0) {
            FrozenTillBolckNum(msg.sender, frozenTill);
            return;
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
        uint frozenTill = checkFrozenStatus(msg.sender);
        if (frozenTill > 0) {
            FrozenTillBolckNum(msg.sender, frozenTill);
            return;
        }

        uint codeLength;
        bytes memory empty;

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

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint _value) public returns (bool success) {
        require(balances[msg.sender] >= _value);   // Check if the sender has enough
        balances[msg.sender].sub(_value);
        totalSupply.sub(_value);
        Burn(msg.sender, _value);
        return true;
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