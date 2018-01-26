pragma solidity ^0.4.18;

import './ownership/Ownable.sol';

contract Artwork is Ownable {

    struct ArtInfo {
        string name;
        string author;
        string desc;
        bytes32 hash;
    }

    // Transactions of Arts, tha last address of the array is current owner
    // of the Art;
    mapping (bytes32 => address[]) artTransactions; 
    mapping (bytes32 => ArtInfo) arts;

    event ArtRegistered(bytes32 indexed artHash, address owner);
    event ArtTransfered(bytes32 indexed artHash, address from, address to);
    
    function Artwork() public {
    }

    function register(string name, string author, string desc, bytes32 artHash, address owner) onlyOwner public {
        require(arts[artHash].hash.length == 0);

        address[] storage trans = artTransactions[artHash];
        require(trans.length == 0);

        ArtInfo memory art = ArtInfo(name, author, desc, artHash);
        arts[artHash] = art;
        
        trans.push(owner);

        ArtRegistered(artHash, owner);
    }

    function transfer(address from, address to, bytes32 artHash) onlyOwner public {
        ArtInfo storage art = arts[artHash];
        require(art.hash.length > 0);

        address[] storage trans = artTransactions[artHash];
        address curOwner = trans[trans.length-1];
        require(curOwner == from && curOwner != to);
        
        trans.push(to);

        ArtTransfered(artHash, from, to);
    }

    function artInfo(bytes32 artHash) view public returns(ArtInfo) {
        return arts[artHash];
    }
}
