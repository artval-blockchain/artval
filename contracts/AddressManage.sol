pragma solidity ^0.4.18;

import "./Owned.sol";

contract AddressManage is Owned {
    address coinAddress;
    address appAddress;
    address repoAddress;
    address artAddress;

    function AddressManage() public {
    }
    
    function setCoinAddress(address _coinAddress) onlyOwner public {
        coinAddress = _coinAddress;
    }
    
    function setAppAddress(address _appAddress) onlyOwner public {
        appAddress = _appAddress;
    }

    function setRepoAddress(address _repoAddress) onlyOwner public {
        repoAddress = _repoAddress;
    }

    function setArtAddress(address _artAddress) onlyOwner public {
        artAddress = _artAddress;
    }

    function updateAddress(address _coinAddress, address _appAddress, address _repoAddress, address _artAddress ) onlyOwner public returns(bool) {
        coinAddress = _coinAddress;
        appAddress = _appAddress;
        repoAddress = _repoAddress;
        artAddress = _artAddress;
    }

    function getAddress() view public returns(address _coinAddress, address _appAddress, address _repoAddress, address _artAddress) {
        require(coinAddress != 0);
        require(appAddress != 0);
        require(repoAddress != 0);
        require(artAddress != 0);
        
        _coinAddress = coinAddress;
        _appAddress = appAddress;
        _repoAddress = repoAddress;
        _artAddress = artAddress;
    }
}
