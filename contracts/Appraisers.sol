pragma solidity ^0.4.18;

import "./Owned.sol";
import "./AddressManage.sol";

/**
 * 鉴宝人合约
 */
contract Appraisers is Owned {

    struct SelectedAppraise {
        uint no;//序号
        address appraiserAddress;//鉴定师地址
    }

    struct ArticleSelection {
        address itemAddress;//艺术品地址
        uint   numAppraiser;//鉴定师数目
        mapping(uint=>SelectedAppraise)selectedAppraises;//对应鉴定师地址
    }

    struct AppraisePrice {
        uint no;//序号
        address appraiserAddress;//鉴定师地址
        uint price;//出价
        bool state;//是否已经出价
    }

    struct ArticlePrice {
        address itemAddress;//艺术品地址
        uint   numAppraiser;//
        uint   numPrice;
        uint totalPrice;
        uint lastTS;
        mapping(address=>AppraisePrice)appraiserPrices;//对应艺术品信息
    }

    struct AppCat {
        uint8 catNO;//分类序号
        bool stat;//是否已经注册
    }

    struct Appraiser {
        address appraiserAddress;//鉴定师地址
        uint numAppraise;//评定数
        uint numSelection;//选定次数
        uint numBadPrice;//恶意次数
        uint lastBadPriceTS;//最后一次恶意时间
        mapping(uint8=>AppCat)appCats;//分类注册表
    }

    struct Category {
        uint8 catNO;
        string categoryName;
    }

    struct CatAppraiser {
        uint no;
        address appraiserAddress;
    }

    struct CategoryAppraiser {
        uint8 catNO;
        uint numAppraiser;
        mapping(uint=>CatAppraiser)catAppraisers;//对应艺术品信息
    }

    uint public numAppraiser;//鉴定师人数
    uint numCat;//分类数

    address public manageAddress;
    address public coinAddress;//艺术币地址
    address public warehouseAddress;//仓储合同地址
    address public artItemsAddress;//艺术品合同地址

    mapping(address=>Appraiser)public appraisers;//鉴定师信息表
    mapping(address=>ArticleSelection) public artSelections;//艺术品信息表
    mapping(uint8=>Category)public categories;
    mapping(uint8=>CategoryAppraiser)public categoryAppraisers;
    mapping(address=>ArticlePrice)public artPrices;

    event InviteToAppraise(address item, address appraiser);
    event AppraiseItem(address item, address appraiser, uint price);
    event RegisterCategory(address appraiser, uint8 categoryNo);
    event NewAppraiser(address appraiser);

    function Appraisers(address _manageAddress) public {
        numAppraiser = 0;
        numCat = 4;
        Category storage category1 = categories[1];
        category1.catNO = 1;
        category1.categoryName = "china";
        Category storage category2 = categories[2];
        category2.catNO = 2;
        category2.categoryName = "Jade";
        Category storage category3 = categories[3];
        category3.catNO = 3;
        category3.categoryName = "FeiCui";
        Category storage category4 = categories[4];
        category4.catNO = 4;
        category3.categoryName = "others";
        manageAddress = _manageAddress;
    }

    /**
     * 更新地址
     */
    function updateAddress() onlyOwner public {
        AddressManage addManage = AddressManage(manageAddress);
        var( _coinAddress, , _repoAddress, _artAddress ) = addManage.getAddress();
        coinAddress = _coinAddress;
        //appraiserAddress = _appAddress;
        warehouseAddress = _repoAddress;
        artItemsAddress = _artAddress;
    }

    /**
     * 注册成为鉴宝人
     */
    function newAppraiser() public returns(bool) {
        Appraiser storage appraiser = appraisers[msg.sender];
        require(appraiser.appraiserAddress == 0);
        appraiser.appraiserAddress = msg.sender;
        numAppraiser += 1;
        NewAppraiser(msg.sender);
    }

    /**
     * 注册成为某个分类的鉴宝人
     */
    function registerCategory(uint8 _catN) public returns(bool) {
        require(_catN > 0);
        require(_catN <= numCat);

        Appraiser storage appraiser = appraisers[msg.sender];
        require(appraiser.appraiserAddress == msg.sender);
        require(appraiser.appCats[_catN].stat == false);

        appraiser.appCats[_catN].stat = true;
        CategoryAppraiser storage cateAppraiser = categoryAppraisers[_catN];
        uint no = cateAppraiser.numAppraiser;
        cateAppraiser.numAppraiser++;
        CatAppraiser storage catApp = cateAppraiser.catAppraisers[no];
        catApp.no = no;
        catApp.appraiserAddress = msg.sender;

        RegisterCategory(msg.sender, _catN);
    }

    function newAppraiserWithCategory(uint8[] _catNs)public returns(bool){
        Appraiser storage appraiser = appraisers[msg.sender];
        require(appraiser.appraiserAddress == 0);
        appraiser.appraiserAddress = msg.sender;
        numAppraiser += 1;
        NewAppraiser(msg.sender);
        for(uint i=0; i<_catNs.length; i++){
            uint8 _catN = _catNs[i];
            if(_catN>0 && _catN <= numCat){
                //require(appraiser.appCats[_catN].stat == false );
                appraiser.appCats[_catN].stat = true;
                CategoryAppraiser storage cateAppraiser = categoryAppraisers[_catN];
                uint no = cateAppraiser.numAppraiser;
                cateAppraiser.numAppraiser++;
                CatAppraiser storage catApp = cateAppraiser.catAppraisers[no];
                catApp.no = no;
                catApp.appraiserAddress = msg.sender;
                RegisterCategory(msg.sender, _catN);
            }
        }

    }

    /**
     * 
     */
    function getCategoryStatus(uint8 _no) view public returns (bool) {
        Appraiser storage appraiser = appraisers[msg.sender];
        return appraiser.appCats[_no].stat;
    }
    
    /**
     * 从持宝人合约发起的新鉴宝请求
     */
    function newAppRequest(address _itemAddress, uint8 _catNO, uint numApp, uint _lastTS) public returns(bool) {
        require(msg.sender == artItemsAddress);

        ArticlePrice storage artPrice = artPrices[_itemAddress];
        ArticleSelection storage artSelect = artSelections[_itemAddress];
        require(artPrice.itemAddress == 0);
        require(artSelect.itemAddress == 0);

        artSelect.itemAddress = _itemAddress;
        artPrice.itemAddress = _itemAddress;
        artPrice.lastTS = _lastTS;
        artPrice.totalPrice = 0;

        //get selection appraisers
        CategoryAppraiser storage categoryAppraiser = categoryAppraisers[_catNO];

        if (categoryAppraiser.numAppraiser <= numApp) {
            artPrice.numAppraiser = categoryAppraiser.numAppraiser;
            for (uint i = 1; i < categoryAppraiser.numAppraiser + 1; i++) {
                artPrice.appraiserPrices[categoryAppraiser.catAppraisers[i].appraiserAddress].no = i;
                artSelect.selectedAppraises[i].appraiserAddress = categoryAppraiser.catAppraisers[i].appraiserAddress;
                InviteToAppraise(_itemAddress, categoryAppraiser.catAppraisers[i].appraiserAddress);
            }
        } else {
            artPrice.numAppraiser = numApp;
            uint j = uint(block.blockhash(block.number-1))%(categoryAppraiser.numAppraiser-numApp) + 1;
            for (i = 1; i <= numApp; i++) {
                artPrice.appraiserPrices[categoryAppraiser.catAppraisers[i+j].appraiserAddress].no = i;
                artSelect.selectedAppraises[i].appraiserAddress = categoryAppraiser.catAppraisers[i+j].appraiserAddress;
                InviteToAppraise(_itemAddress, categoryAppraiser.catAppraisers[i+j].appraiserAddress);
            }
        }
    }

    /**
     * 对某一艺术品价格投票
     */
    function priceItem(address _itemAddress,uint _price) public returns(bool) {
        ArticlePrice storage artPrice = artPrices[_itemAddress];
        AppraisePrice storage appPrice = artPrice.appraiserPrices[msg.sender];
        require(appPrice.no > 0);
        require(artPrice.lastTS > now);
        require(appPrice.state == false);

        appPrice.price = _price;
        appPrice.state = true;
        artPrice.numPrice ++;
        artPrice.totalPrice += _price;

        AppraiseItem(_itemAddress, msg.sender, _price);
    }

    /**
     * 获取一个艺术品的价格和状态
     */
    function getItemPrice(address _itemAddress) view public returns(uint price, uint8 stat) {
        require(msg.sender == artItemsAddress);

        ArticlePrice storage artPrice = artPrices[_itemAddress];
        if (artPrice.numPrice < 5) {
            stat = 0;
            return;
        }
        stat = 1;
        price = artPrice.totalPrice / artPrice.numPrice;
    }

    /**
     * 获取一个艺术品的鉴定师
     */
    function getItemApp(address _itemAddress) public returns(uint num, address[100] apps) {
        require(msg.sender == coinAddress);

        ArticlePrice storage artPrice = artPrices[_itemAddress];
        ArticleSelection storage artSelect = artSelections[_itemAddress];
        require(artPrice.itemAddress == _itemAddress);
        require(artPrice.numPrice > 0);
        require(artSelect.itemAddress == _itemAddress);
        
        uint price = artPrice.totalPrice/artPrice.numPrice;
        uint lowP = price/4;
        uint highP = price*2;
        num = 0;
        //address[] memory apps = new address[](100);
        for (uint i = 0; i < artSelect.numAppraiser&&num<100; i++) {
            address appadd = artSelect.selectedAppraises[i].appraiserAddress;
            AppraisePrice storage appPrice = artPrice.appraiserPrices[appadd];
            if (appPrice.state == true) {
                Appraiser storage app = appraisers[appadd];
                if (app.appraiserAddress == appadd) {
                    if (appPrice.price >= lowP && appPrice.price <= highP) {
                        apps[num] = appadd;
                        num += 1;
                        app.numAppraise += 1;
                    } else if (appPrice.price > price * 10) {
                        app.numBadPrice += 1;
                        app.lastBadPriceTS = now;
                    }
                }
            }
        }
        
        return(num, apps);
    }

    function isValidateAccount(address account) view public returns(bool) {
        return account.balance > 100;
    }
}
