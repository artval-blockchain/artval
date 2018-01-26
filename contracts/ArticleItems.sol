pragma solidity ^0.4.18;

import "./Appraisers.sol";
import "./Repository.sol";

/**
 * 持宝人合约
 */
contract ArticleItems is Owned {

    struct ArticleItem {
        address itemAddress;//艺术品地址
        address itemOwner;//持宝人地址
        address storer;//仓储地址
        uint8 state;//1 初始状态, 2 等待鉴定, 3 鉴定完成, 4 鉴定失败, 5 选择仓储,
        //6 等待入仓, 7 入仓完毕, 8 冻结, 9 损坏, 10 待售, 11 已卖出
        string  title;//名称
        bytes32  itemHash;//哈希值
        string description;//描述
        string sURL;//详细信息网址
        uint endAppTSP;//鉴定终止时间
        uint8 category;//分类
        uint price;//
    }

    struct OwnItem {
        uint no;
        address itemAddress;
    }

    struct PeopleAsset {
        address peopleAddress;//持宝人地址
        uint numItem;//该持宝人持有艺术品数
        mapping(uint=>OwnItem)ownItems;//对应艺术品信息
    }

    uint public numPeople;//持宝人数
    address public manageAddress;
    address public coinAddress;//艺术币地址
    address public appraiserAddress;//鉴定师合同地址
    address public repositoryAddress;//仓储合同地址
    mapping(address=>PeopleAsset) public peopleAssets;//持宝人艺术品信息表
    mapping(address=>ArticleItem) public artItems;//艺术品信息表

    event NewItem(address item, string title, address owner);
    event ApplyAppraise(address owner, address item, uint TS);

    function ArticleItems(address _manageAddress) public {
        numPeople = 0;
        manageAddress = _manageAddress;
    }

    function updateAddress() public onlyOwner {
        AddressManage addManage = AddressManage(manageAddress);
        var ( _coinAddress, _appAddress, _repoAddress,  ) = addManage.getAddress();
        coinAddress = _coinAddress;
        appraiserAddress = _appAddress;
        repositoryAddress = _repoAddress;
    }

    /**
     * 添加新的艺术品
     */
    function newItem(string _title, bytes32 _itemhash, uint8 _v, bytes32 _ram, string _descp, string _sURL, uint8 _category) public returns(address) {
        address itemAddress = address(ripemd160(_itemhash, _v, bytes32(msg.sender), _ram));
        ArticleItem storage artItem = artItems[itemAddress];
        require(artItem.itemAddress == 0);

        artItem.itemAddress = itemAddress;
        artItem.itemOwner = msg.sender;
        artItem.state = 1;
        artItem.itemHash = _itemhash;
        artItem.title = _title;
        artItem.description = _descp;
        artItem.sURL = _sURL;
        artItem.category = _category;

        PeopleAsset storage peopleAsset = peopleAssets[msg.sender];
        if (peopleAsset.numItem == 0)
            numPeople++;
        peopleAsset.peopleAddress = msg.sender;
        peopleAsset.ownItems[peopleAsset.numItem].itemAddress = itemAddress;
        peopleAsset.numItem++;

        NewItem(itemAddress, _title, msg.sender);

        return itemAddress;
    }

    /**
     * 获取持宝人持有的艺术品
     */
    function getPeopleItem(uint _no) view public returns (address) {
        PeopleAsset storage peopleAsset = peopleAssets[msg.sender];
        require(peopleAsset.numItem > _no);
        return peopleAsset.ownItems[_no].itemAddress;
    }

    /**
     * 新鉴定申请
     */
    function newAppraise(address _itemAddress, uint _days) public returns(bool) {

        ArticleItem storage artItem = artItems[_itemAddress];
        require(artItem.itemOwner == msg.sender);
        require(artItem.state == 1);
        require(_days < 8);
        if (_days > 0)
            artItem.endAppTSP = now + _days * 10 minutes;//1 days;
        else
            artItem.endAppTSP = now + 10 minutes;//1 days;

        //message to AppraiserContracts new app 9
        Appraisers appraisers = Appraisers(appraiserAddress);
        appraisers.newAppRequest(_itemAddress, artItem.category, 10, artItem.endAppTSP);

        artItem.state = 2;

        //Event ApplyAppraise
        ApplyAppraise(msg.sender, _itemAddress, artItem.endAppTSP);
    }

    function newItemWithApprsaise(string _title, bytes32 _itemhash, uint8 _v, bytes32 _ram,
        string _descp, string _sURL, uint8 _category, uint _days)public returns(address) {
        address itemAddress = address(ripemd160(_itemhash, _v, bytes32(msg.sender), _ram));
        ArticleItem storage artItem = artItems[itemAddress];
        require(artItem.itemAddress == 0);
        require(_days < 8);
        artItem.itemAddress = itemAddress;
        artItem.itemOwner = msg.sender;
        artItem.state = 1;
        artItem.itemHash = _itemhash;
        artItem.title = _title;
        artItem.description = _descp;
        artItem.sURL = _sURL;
        artItem.category = _category;

        PeopleAsset storage peopleAsset = peopleAssets[msg.sender];
        if (peopleAsset.numItem == 0)
            numPeople++;
        peopleAsset.peopleAddress = msg.sender;
        peopleAsset.ownItems[peopleAsset.numItem].itemAddress = itemAddress;
        peopleAsset.numItem++;

        if (_days > 0)
            artItem.endAppTSP = now + _days * 10 minutes;//1 days;
        else
            artItem.endAppTSP = now + 10 minutes;//1 days;

        //message to AppraiserContracts new app 9
        Appraisers appraisers = Appraisers( appraiserAddress );
        appraisers.newAppRequest(itemAddress, artItem.category, 10, artItem.endAppTSP);

        artItem.state = 2;

        //Event ApplyAppraise
        NewItem(itemAddress, _title, msg.sender);
        ApplyAppraise(msg.sender, itemAddress, artItem.endAppTSP);

        return itemAddress;
    }

    /**
     * 获取一个艺术品的鉴定结果
     */
    function getAppraiseResult(address _itemAddress) public returns(bool) {
        ArticleItem storage artItem = artItems[_itemAddress];
        require(artItem.itemOwner == msg.sender);
        require(artItem.state == 2);
        require(now > artItem.endAppTSP);

        //message to AppraiserContracts to get result 10
        Appraisers appraisers = Appraisers(appraiserAddress);
        // uint price = 0;
        // uint8 stat = 0;
        var (price, stat) = appraisers.getItemPrice(_itemAddress);

        if (stat == 1) {
            artItem.state = 3;
            artItem.price = price;
        } else {
            artItem.state = 4;
        }

        //Event getAppraiseResult
    }

    /**
     * 持宝人接受鉴定结果
     */
    function acceptAppraiseResult(address _itemAddress) public returns(bool) {
        ArticleItem storage artItem = artItems[_itemAddress];
        require(artItem.itemOwner == msg.sender);

        //message to RepositoryContract 18
        Repository repository = Repository(repositoryAddress);
        repository.newItem(_itemAddress);
        artItem.state = 5;
    }

    function setWareHousing(address _itemAddress, address _wareHouse) public returns(bool) {
        require(msg.sender == repositoryAddress);

        ArticleItem storage artItem = artItems[_itemAddress];
        require(artItem.state == 5);
        require(artItem.storer == 0);

        artItem.storer = _wareHouse;
        artItem.state = 6;
    }

    /**
     * 仓库接收一个艺术品
     */
    function storeItem(address _itemAddress, address _wareHouse) public returns(bool) {
        require(msg.sender == repositoryAddress);

        ArticleItem storage artItem = artItems[_itemAddress];
        require(artItem.state == 6);
        require(artItem.storer == _wareHouse);
        //no need to change owner at this time
        artItem.state = 7;
    }

    /**
     * 获取艺术品仓储信息
     */
    function checkItemWarehouse(address _itemAddress, address _wareHouse) view public returns(bool flag, uint price, address itemOwner) {
        flag = false;
        ArticleItem storage artItem = artItems[_itemAddress];
        require(artItem.itemAddress == _itemAddress);
        require(artItem.storer == _wareHouse);
        //require( artItem.state == 7 );
        flag = true;
        price = artItem.price;
        itemOwner = artItem.itemOwner;
        return (flag, price, itemOwner);
    }
}