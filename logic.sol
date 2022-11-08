// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

contract Ritchie is Initializable,Ownable{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
   
    mapping(address => bool) public executor;
    mapping(address => bool) public announcer;
    mapping(uint256 => OrderInfo) public _OrderInfo;
    mapping(uint => uint) public cont;//orderid => cont拆分次数
    mapping(uint=>mapping(uint=>uint)) public splitVal;//orderid => cont拆分次数 => splitvalue拆分金额
    mapping(uint=>mapping(uint=>address)) public splitAddress;//orderid => cont拆分次数 => splitaddress拆分地址
    
    address _ERC20;
    address Me;
    uint256 OrderId;
    uint256 SetNumber = 5;
    uint256 Balance = 1000000000000000;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    struct OrderInfo{
        uint256 DoneNumber;//任务条件
        address executor;//发布者地址 检查函数是否能运行状态
        bool state;//订单是否处于可以接受状态
        uint256 bounty;//赏金数额
        uint256 cont;//拆分次数
        uint256 Remaining;//剩下的总额度
    }

    struct UserInfo {
        uint256 Balance;//用户余额
        address User;//User的地址
        uint256 OrderId;//订单的ID
        uint256 BillableBounty;//可结算的赏金数额
    }

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //发布任务功能
    function PostTask (uint256 _bounty,uint256 _SetNumber) public {
        require(_bounty <= Balance ,"Balance is't enough");//检查余额是否足够

        setOrderInfo(OrderId,msg.sender,true,_bounty,_SetNumber);//使用setOrderInfo

        OrderId = OrderId.add(1);//订单号加一

        IERC20(_ERC20).transfer(address(Me),_bounty);
        //IERC20 token,
    }

    //使_OrderInfo[_OrderId]与OrderInfo进行绑定
    function SOrderInfo(uint256 _OrderId) external view returns (OrderInfo memory) {
        return _OrderInfo[_OrderId];
    }

    //setOrderInfo 输入参数产生订单
    function setOrderInfo(uint256 _OrderId,address _executor,bool _state,uint256 _bounty,uint256 _setNumber) internal returns (bool){
        _OrderInfo[_OrderId] = OrderInfo({executor:_executor,state:_state,bounty:_bounty,DoneNumber:_setNumber,cont:0,Remaining:_setNumber});
        return true;
    }

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //接受Order功能
    function ReceiveOrder(uint256 _OrderId) public {

        uint256 NowCont = cont[_OrderId] ; //当前拆分的数额
        bool IsTheTaskAcceptable = _OrderInfo[_OrderId].state;

        require(IsTheTaskAcceptable == true,"Order not receive yet");

        splitAddress[_OrderId][NowCont] = msg.sender;//这个id以及这次拆分次数下的地址为msg.sender
        _OrderInfo[_OrderId].state = false;
        _OrderInfo[_OrderId].executor = msg.sender;
    }

    //发布Order功能
    function PostOrder(uint256 _OrderId,uint256 Dividend) public {//输入参数orderid，以及分红

        uint256 NowCont = cont[_OrderId] ; //当前拆分的数额
        uint256 _cont = _OrderInfo[_OrderId].cont;
        uint256 _remaining;//新的拆分的金额总额

        address CurrentAddress = _OrderInfo[_OrderId].executor;//当前地址 = executor执行地址
        require(CurrentAddress == msg.sender,"Order Control does not belong to the current address");//查询当前地址是否是executor地址
        require(_OrderInfo[_OrderId].Remaining > Dividend,"Insufficient amount");//赏金额度 - 被拆分的总额 > 设定的金额
        
        cont[_OrderId]=cont[_OrderId].add(1);//发布任务 cont + 1
        NowCont = cont[_OrderId];//新的拆分索引
        splitVal[_OrderId][NowCont] = Dividend;//该用户指定自己留下多少钱

        _OrderInfo[_OrderId].Remaining = _remaining.sub(Dividend);//拆分总额写入sturct
        _OrderInfo[_OrderId].state = true;
        _OrderInfo[_OrderId].executor = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148;
        _OrderInfo[_OrderId].cont = _cont.add(1);
    }

    //判断done的执行条件并转账
    function done (uint256 _OrderId,uint256 Num) public {

        uint256 Number = _OrderInfo[_OrderId].DoneNumber;
        address CurrentAddress = _OrderInfo[_OrderId].executor;
        uint256 NowCont = cont[_OrderId] ; //当前拆分的数额

        require(Number == Num,"DoneNumber not right");
        require(CurrentAddress == msg.sender,"Order Control does not belong to the current address");

        splitVal[_OrderId][NowCont] = _OrderInfo[_OrderId].Remaining;

        for(uint i=0;i<_OrderInfo[_OrderId].cont;i++){
            IERC20(_ERC20).transfer(splitAddress[_OrderId][i],splitVal[_OrderId][i]);
        }
    }
}
