// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "Ritchie/ERC721/IERC721.sol";
import "Ritchie/ERC721/IERC721Receiver.sol";
import "Ritchie/ERC721/WTFape.sol";

contract NFTSwap{//is IERC721Receiver
    event List(address indexed seller,address indexed NftAddress,uint256 indexed tokenId,uint256 price);
    event Purchase(address indexed buyer,address indexed NftAddress,uint256 indexed tokenId,uint256 price);
    event Revoke(address indexed seller,address indexed NftAddress,uint256 indexed tokenId);
    event Update(address indexed seller,address indexed NftAddress,uint256 indexed tokenId,uint256 newPrice);
    //挂单List 购买Purchase 撤单Revoke 修改价格Update

    // 定义order结构体
    struct Order{
        address owner;
        uint256 price;
    }

    // NTT Order映射
    mapping(address => mapping(uint256 =>Order)) public nftList;

    fallback() external payable{}

    // 挂单：卖家上架NFT，合约地址为_nftAddress,tokenId为_tokenId,价格_price为以太坊(单位是wei)
    function list(address _NftAddress,uint256 _tokenId,uint256 _price) public{
        IERC721 _nft = IERC721(_NftAddress);//声明IERC721接口合约变量
        require(_nft,getApproved(_tokenId) == address(tihis),"error");//合约得到授权
        require(_price > 0,"error");

        Order storage _order = nftList[_NftAddress][_tokenId];//设置持有人和价格
        _order.owner = msg.sender;
        _order.price = _price;

        // 将NFT转账到合约
        _nft.SafeTransferFrom(msg.sender,address(this),_tokenId);

        // 释放List事件
        emit List(msg.sender, _NftAddress, _tokenId, _price);
    }

    // 购买：卖家上架购买NFT，合约为_NftAddress，tokenId为_tokenId,调用函数时要附带ETH
    function purchase(address _Nftaddress,uint256 _tokenId) payable public {
        Order storage _order = nftList[_NftAddress][_tokenId]; //取得order
        require(_order.price > 0,'error');//Nft价格大于0
        require(msg.value >= _order.price,'error');//购买价格大于标价
        // 声明IERC721接口合约变量
        IERC721 _nft = IERC721(_NftAddress);
        require(_nft.ownerOF(_tokenId) == address(this),'error');//Nft是否在合约中

        // 将NFT转给卖家
        _nft.SafeTransferFrom(address(this),msg.sender,_tokenId);
        // 将ETH转给卖家，多余的ETH给买家退款
        payable(_order.owner).transfer(_order,price);
        payable(msg.sender).transfer(msg.value - _order.price);

        delete nftList[_NftAddress][_tokenId];//删除当前order

        // 释放Purchase事件
        emit Purchase(msg.sender, _NftAddress, _tokenId, msg.value);
    }

    // 撤单：卖家取消挂单
    function revoke(address _NftAddress,uint256 _tokenId) public{
        Order storage _order = nftList[_NftAddress][_tokenId];//取得order
        require(_order.owner == msg.sender,'error');//必须持有人发起
        // 声明IERC721接口合约变量
        IERC721 _nft = IERC721(_NftAddress);
        require(_nft.ownerOF(_tokenId) == address(this),'error');//Nft是否在合约中

        // 将NFT转给卖家
        _nft.SafeTransferFrom(address(this),msg.sender,_tokenId);

        delete nftList[_NftAddress][_tokenId];//删除当前order

        // 释放revoke事件
        emit revoke(msg.sender, _NftAddress,_tokenId);
    }

    // 调整价格：卖家调整挂单价格
    function update(address _NftAddress,uint256 _tokenId,uint256 _newPrice) public{
        require(_newprice > 0,"error");//价格大于0
        Order storage _order = nftList[_NftAddress][_tokenId];//取得order
        require(_order.owner == msg.sender,'error');//必须持有人发起
        // 声明IERC721接口合约变量
        IERC721 _nft = IERC721(_NftAddress);
        require(_nft.ownerOF(_tokenId) == address(this),'error');//Nft是否在合约中

        // 调整NFT价格
        _order.price = _newPrice;

        // 释放update事件
        emit Update(msg.sender, _NftAddress, _tokenId, _newPrice);
    }

    // 实现{IERC721Receiver}的onIERC721Receiver，能够接受ERC721代币
    function onIERC721Receiver(address operator,address from,uint tokenId,bytes calldata) external override returns (bytes4){
        return IERC721Receiver.onIERC721Receiver.selector;
    }
}