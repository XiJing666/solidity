// SPDX-License-Identifier: MIT
// by 0xAA
pragma solidity ^0.8.4;

import "./ERC721.sol";

contract DAN is ERC721{
    address public factory;
    uint public MAX_APES = 10000; // 总量

    // 构造函数
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_){
        factory = msg.sender;
    }

    // 铸造函数
    function mint(address to, uint tokenId) external {
        require(tokenId >= 0 && tokenId < MAX_APES, "tokenId out of range");
        _mint(to, tokenId);
    }
}

contract NFTfactory{

    // mapping(address => mapping(address => address)) public check_Nft;
    mapping(string => address) public check_Nft;
    address[] public all_nftAddress;
    address[] public _NftList;


    function createNFT (string memory name_, string memory symbol_) public returns(address _nftAddress) {
        bytes32 salt = keccak256(abi.encodePacked(name_,symbol_));
        DAN _nft = new DAN{salt: salt}(name_,symbol_);
        _nftAddress = address(_nft);
        all_nftAddress.push(_nftAddress);
        check_Nft[symbol_] = _nftAddress;
    }

    function checkAddress(string memory name_, string memory symbol_) public view returns(address predictedAddress) {
         bytes32 salt = keccak256(abi.encodePacked(name_,symbol_));
         predictedAddress = address(uint160(uint(keccak256(abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(abi.encodePacked(type(DAN).creationCode,abi.encode(name_,symbol_)))
            )))));
    }
}