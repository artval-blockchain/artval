pragma solidity ^0.4.18;

import "./Owned.sol";
import './AddressManage.sol';
import './ArticleItems.sol';
import './Repository.sol';
import './AppraisersContract.sol';

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public; }
contract TokenERC20 {
    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    // 18 decimals is the strongly suggested default, avoid changing it
    uint256 public totalSupply;
    // This creates an array with all balances
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);
    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);
    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function TokenERC20(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public {
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        balanceOf[msg.sender] = totalSupply;                // Give the creator all initial tokens
        name = tokenName;                                   // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
    }
    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _value) internal {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != 0x0);
        // Check if the sender has enough
        require(balanceOf[_from] >= _value);
        // Check for overflows
        require(balanceOf[_to] + _value > balanceOf[_to]);
        // Save this for an assertion in the future
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        // Subtract from the sender
        balanceOf[_from] -= _value;
        // Add the same to the recipient
        balanceOf[_to] += _value;
        Transfer(_from, _to, _value);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }
    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }
    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` in behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);     // Check allowance
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }
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
    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);   // Check if the sender has enough
        balanceOf[msg.sender] -= _value;            // Subtract from the sender
        totalSupply -= _value;                      // Updates totalSupply
        Burn(msg.sender, _value);
        return true;
    }
    /**
     * Destroy tokens from other account
     *
     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value);                // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]);    // Check allowance
        balanceOf[_from] -= _value;                         // Subtract from the targeted balance
        allowance[_from][msg.sender] -= _value;             // Subtract from the sender's allowance
        totalSupply -= _value;                              // Update totalSupply
        Burn(_from, _value);
        return true;
    }
}

/******************************************/
/*       ADVANCED TOKEN STARTS HERE       */
/******************************************/
contract MooToken is Owned, TokenERC20 {
    struct SelectedAppraise {
        uint no;//序号
        address appraiserAddress;//鉴定师地址
    }
    address public manageAddress;
    address public appraiserAddress;//艺术币地址
    address public warehouseAddress;//仓储合同地址
    address public artItemsAddress;//艺术品合同地址
    mapping (address => bool) public frozenAccount;
    // This creates an array with all incoming
    mapping (address => uint256) public incomingOf;
    /* This generates a public event on the blockchain that will notify clients */
    event FrozenFunds(address target, bool frozen);
    event PreMint(address item, address owner, uint price, address wareHouse, uint wareHouseIncome);
    event Mint(address item, address owner, uint price);
    event Rewards(address item, address appraiser, uint reward);
    /* Initializes contract with initial supply tokens to the creator of the contract */
    function MooToken(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol,
        address _manageAddress
    ) TokenERC20(initialSupply, tokenName, tokenSymbol) public {
        manageAddress = _manageAddress;
    }

    function updateAddress() public onlyOwner {
        AddressManage addManage = AddressManage(manageAddress);
        var ( , _appAddress, _repoAddress, _artAddress ) = addManage.getAddress();
        //coinAddress = _coinAddress;
        appraiserAddress = _appAddress;
        warehouseAddress = _repoAddress;
        artItemsAddress = _artAddress;
    }

    /* Internal transfer, only can be called by this contract */
    function _transfer(address _from, address _to, uint _value) internal {
        require (_to != 0x0);                               // Prevent transfer to 0x0 address. Use burn() instead
        require (balanceOf[_from] > _value);                // Check if the sender has enough
        require (balanceOf[_to] + _value > balanceOf[_to]); // Check for overflows
        require(!frozenAccount[_from]);                     // Check if sender is frozen
        require(!frozenAccount[_to]);                       // Check if recipient is frozen

        balanceOf[_from] -= _value;                         // Subtract from the sender
        balanceOf[_to] += _value;                           // Add the same to the recipient

        Transfer(_from, _to, _value);
    }

    function preMint(address _warehouse, address _itemAddress) public {
        require(msg.sender == warehouseAddress);

        ArticleItems articleItems = ArticleItems(artItemsAddress);
        bool flg = false;
        uint price = 0;
        uint storeIncome = 0;
        address itemOwner = 0;
        (flg, price, itemOwner ) = articleItems.checkItemWarehouse(_itemAddress, _warehouse);
        require(flg == true);

        Repository repository = Repository( warehouseAddress);
        require(repository.checkMintItem(_itemAddress, _warehouse));

        incomingOf[itemOwner] += price;

        var num = repository.getNumWareHouse();
        uint256 minnum = 5;

        if (num < minnum)
            storeIncome = 500000000000000000;
        else
            storeIncome = 100000000000000000;

        incomingOf[_warehouse] += storeIncome;
        PreMint(_itemAddress, itemOwner, price, _warehouse, storeIncome);
    }

    function mintToken(address _warehouse, address _itemAddress) public {
        require(msg.sender == warehouseAddress);

        ArticleItems articleItems = ArticleItems(artItemsAddress);
        bool flag = false;
        uint price = 0;

        //uint storeIncome = 0;
        address itemOwner = 0;
        
        (flag, price, itemOwner) = articleItems.checkItemWarehouse(_itemAddress, _warehouse);

        require(flag == true);

        Repository repository = Repository(warehouseAddress);
        require(repository.checkMintItem(_itemAddress, _warehouse));

        balanceOf[itemOwner] += price;
        incomingOf[itemOwner] -= price;
        totalSupply += price;
        Transfer(0, this, price);
        Transfer(this, itemOwner, price);

        var nums = repository.getNumWareHouse();
        uint256 minnum = 5;

        if (nums < minnum)
            price = 5000000000000000000;
        else
            price = 1000000000000000000;

        balanceOf[_warehouse] += price;
        incomingOf[_warehouse] -= price;
        totalSupply += price;
        Transfer(0, this, price);
        Transfer(this, _warehouse, price);
        Mint(_itemAddress, itemOwner, price);

        Appraisers appraisers = Appraisers(appraiserAddress);
        var (num, apps) = appraisers.getItemApp(_itemAddress);
        for (uint i = 0; i < num; i++) {
            itemOwner = apps[i];
            balanceOf[itemOwner] += 100000000000000000;
            totalSupply += 1000000000000000000;
            Transfer(0, this, 1000000000000000000);
            Transfer(this, itemOwner, 1000000000000000000);
            Rewards(_itemAddress, itemOwner, 1000000000000000000);
        }
    }

    /// @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
    /// @param target Address to be frozen
    /// @param freeze either to freeze it or not
    function freezeAccount(address target, bool freeze) onlyOwner public {
        frozenAccount[target] = freeze;
        FrozenFunds(target, freeze);
    }
}
