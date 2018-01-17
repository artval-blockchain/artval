pragma solidity ^0.4.18;

import './MooToken.sol';

/**
 * 仓储合约
 */
contract Repository is Owned {

    struct ArticleItem {
        address itemaddress;//艺术品地址
        address warehouse;//仓储地址
        uint8   state;//1 normal, 2 wait for identfy, 3 identfied, 4 fail to identify, 5 select store,
        //6 wait to store, 7 stored, 8 freeze, 9 damaged, 10 pending sale, 11 soled
        //uint appPrice;//鉴定price
    }
    
    struct OwnItem {
        uint no;
        address itemaddress;
    }

    struct WarehouseAsset {
        address wareAddress;//仓储地址
        uint numItem; //该仓储入仓的艺术品数
        mapping(uint=>OwnItem)ownItems;//对应艺术品信息
        string wareHouseURL;
        uint toltalValue;
        uint numItemSoled;
        uint toltalSoledValue;
        uint failedTimes;
        uint lostValue;
    }

    uint public numWarehouse;//仓储数
    address public manageAddress;
    address public coinAddress;//艺术币地址
    address public appraiserAddress;//鉴定师合同地址
    address public artItemsAddress;//艺术品合同地址
    mapping(address=>WarehouseAsset)public warehouseAssets;//仓储人艺术品信息表
    mapping(address=>ArticleItem) public artItems;//艺术品信息表
    
    event NewItem(address item);
    event DigItem(address item, address warehouse);
    event StoreItem(address item, address warehouse);
    event NewWarehouse(address warehouse);

    function Repository(address _manageAddress) public {
        numWarehouse = 0;
        manageAddress = _manageAddress;
    }

    function updateAddress() public onlyOwner {
        AddressManage addManage = AddressManage(manageAddress);
        var( _coinAddress, _appAddress, , _artAddress ) = addManage.getAddress();
        coinAddress = _coinAddress;
        appraiserAddress = _appAddress;
        //repositoryAddress = _repoAddress;
        artItemsAddress = _artAddress;
    }

    /**
     * 注册成为仓库
     */
    function newWarehouse() public returns(bool) {
        //Check balance of msg.sender
        MooToken mooToken = MooToken(coinAddress);
        require(mooToken.balanceOf(msg.sender) > 150000000000000000000);

        WarehouseAsset storage warehouseAsset = warehouseAssets[msg.sender];
        require(warehouseAsset.wareAddress == 0);

        warehouseAsset.wareAddress = msg.sender;
        numWarehouse += 1;

        NewWarehouse(msg.sender);
    }

    /**
     * 获取仓储的某一个艺术品
     */
    function getWarehouseItem(uint _no) view public returns (address) {
        WarehouseAsset storage warehouseAsset = warehouseAssets[msg.sender];
        require(warehouseAsset.numItem > _no);

        return warehouseAsset.ownItems[_no].itemaddress;
    }

    /**
     * 持宝人发起准备登记某艺术品
     */
    function newItem(address _itemAddress) public returns(bool) {
        require(msg.sender == artItemsAddress);

        ArticleItem storage artItem = artItems[_itemAddress];
        require(artItem.itemaddress == 0);

        artItem.itemaddress = _itemAddress;
        artItem.state = 5;
        //event to notify all warehouses

        NewItem(_itemAddress);
    }

    /**
     * 预备挖矿
     */
    function digItem(address _itemAddress) public returns(bool) {
        ArticleItem storage artItem = artItems[_itemAddress];
        require(artItem.warehouse == 0);
        require(artItem.state == 5);

        artItem.warehouse = msg.sender;
        artItem.state = 6;
        //message to artItems contract 16
        ArticleItems articleItems = ArticleItems(artItemsAddress);
        articleItems.setWareHousing(_itemAddress, msg.sender);
        //message to token contract 21
        MooToken mooToken = MooToken(coinAddress);
        mooToken.preMint(msg.sender, _itemAddress);

        //event
        DigItem(_itemAddress,msg.sender);
    }

    /**
     * 入库
     */
    function storeItem(address _itemAddress) public returns(bool) {
        ArticleItem storage artItem = artItems[_itemAddress];
        require(artItem.state == 6);
        require(artItem.warehouse == msg.sender);

        WarehouseAsset storage warehouse = warehouseAssets[msg.sender];
        warehouse.numItem += 1;
        ArticleItems articleItems = ArticleItems(artItemsAddress);
        articleItems.storeItem(_itemAddress, msg.sender);
        //real mine
        MooToken mooToken = MooToken(coinAddress);
        mooToken.mintToken(msg.sender, _itemAddress);
        artItem.state = 7;

        StoreItem(_itemAddress,msg.sender);
    }

    /**
     * 检查挖矿结果
     */
    function checkMintItem(address _itemAddress, address _warehouse )view public returns(bool) {
        ArticleItem storage artItem = artItems[_itemAddress];
        require(artItem.state == 6);
        require(artItem.warehouse == _warehouse);
        return true;
    }

    function getNumWareHouse() view public returns(uint256) {
        return numWarehouse;
    }

    function isValidateAccount(address account) view public returns(bool) {
        MooToken mooToken = MooToken(coinAddress);
        return (mooToken.balanceOf(account) > 1500);
    }
}