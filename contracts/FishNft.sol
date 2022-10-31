// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IFISH {
    function mint(address account_, uint256 amount_) external returns (bool);
}


library Random {
    
    //用封闭区间[earliestBlock, latestBlock]中区块的blockhash的熵初始化池
    //参数“seed”是可选的，在大多数情况下可以保留为零。
    //这个额外的种子允许您为同一块范围选择不同的随机数序列。

    function init(
        uint256 earliestBlock,
        uint256 latestBlock,
        uint256 seed
    ) internal view returns (bytes32[] memory) {
        //require(block.number-1 >= latestBlock && latestBlock >= earliestBlock && earliestBlock >= block.number-256, "Random.init: invalid block interval");
        //require(block.number-1 >= latestBlock && latestBlock >= earlyBlock && earlyBlock >= block.number-256, "Random.init: 无效块间隔");
        require(
            block.number - 1 >= latestBlock && latestBlock >= earliestBlock,
            "Random.init: invalid block interval"
        );


        bytes32[] memory pool = new bytes32[](latestBlock - earliestBlock + 2);
        bytes32 salt = keccak256(abi.encodePacked(block.number, seed));
        for (uint256 i = 0; i <= latestBlock - earliestBlock; i++) {
            // 为每个区块hash添加一些salt 这样我们就不会重用那些哈希链
            // 当这个函数在另一个块中被再次调用时
            pool[i + 1] = keccak256(
                abi.encodePacked(blockhash(earliestBlock + i), salt)
            );
        }
        return pool;
    }

   
    //从最新的“num”块初始化池。
    
    function initLatest(uint256 num, uint256 seed) internal view returns (bytes32[] memory) {
        return init(block.number - num, block.number - 1, seed);
    }

   
    //前进到哈希链池中的下一个 256 位随机数。
    
    function next(bytes32[] memory pool) internal pure returns (uint256) {
        require(pool.length > 1, "Random.next: invalid pool");
        uint256 roundRobinIdx = (uint256(pool[0]) % (pool.length - 1)) + 1;
        bytes32 hash = keccak256(abi.encodePacked(pool[roundRobinIdx]));
        pool[0] = bytes32(uint256(pool[0]) + 1);
        pool[roundRobinIdx] = hash;
        return uint256(hash);
    }

    
    //产生随机整数值，均匀分布在闭区间[a, b]
    
    function uniform(bytes32[] memory pool,int256 a,int256 b) internal pure returns (int256) {
        require(a <= b, "Random.uniform: invalid interval");
        return int256(next(pool) % uint256(b - a + 1)) + a;
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

contract FishNft is Initializable,ERC721EnumerableUpgradeable,OwnableUpgradeable{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMath for uint256;

    mapping(address => bool) public executor;

    //赋值定义
    uint256 public tokenIdIndex;
    string public _baseURI_;
    address public FISH;
    uint256 public maxPreSale;
    uint256 public preSaleEnd;
    bool public stateOpen;

    
    //用户结构
    struct UserInfo {
        uint256 lastClaimTimestamp;//上一次Claim的时间
        uint256 releaseSecond;//释放时间
        uint256 claimble;//还有多少没有领取的或者是可以领取的奖励
    }

   

    struct NftInfo {
        string fishStr;
        uint256 remainingReward;//如果释放的话 奖励的数量
        uint256 lv;//nft的等级
        uint256 random;//随机数 备用
    }

    mapping(uint256 => uint256) public releaseCycle;//mapping释放周期
    mapping(uint256 => NftInfo) internal _nftInfo;//结构体 内部调用
    mapping(address => UserInfo) internal _userInfo;//结构体 内部调用



     //  constructor(){} 构造函数 因代理合约所以用初始化函数
    // 传参 回传上面设置好的数值
    function initialize(string memory _name,string memory _symbol,address _FISH) external initializer {
        FISH = _FISH;
        maxPreSale = 1000;
        stateOpen = false;
        __ERC721_init(_name, _symbol);
        __Ownable_init();//必须引用此函数的初始化 如果input了owner合约
        executor[msg.sender] = true;//授权msg.sender作为执行者
        releaseCycle[0] = 14 days;//释放时间的等级和需要的时间
        releaseCycle[1] = 10 days;
        releaseCycle[2] = 5 days;
        // tokenLimit = 9999;
    }


    //修饰符定义onlyExecutor权限
    modifier onlyExecutor() {
        require(executor[msg.sender], "executor: caller is not the executor");
        _;
    }



    //输入_id 通过nftInfo这个函数去把_nftInfo[_id]这两参数进行绑定 nftInfo数据结构=_nftInfo=_id
    function nftInfo(uint256 _id) external view returns (NftInfo memory) {
        return _nftInfo[_id];
    }



   //后门程序setNftInfo 后门官方开挂 自由设置
    function setNftInfo(uint256 i,string memory str,uint256 _remainingReward,uint256 _lv,uint256 _random) public onlyExecutor returns (bool) {
        return _setNftInfo(i, str, _remainingReward, _lv, _random);
    }

    function _setNftInfo(uint256 i,string memory str,uint256 _remainingReward,uint256 _lv,uint256 _random) internal returns (bool) {
        _nftInfo[i] = NftInfo({fishStr: str,remainingReward: _remainingReward,lv: _lv,random: _random});
        return true;
    }


    //userInfo设置
    function userInfo(address _user) external view returns (UserInfo memory) {
        return _userInfo[_user];
    }

    function setUserInfo(address _user,uint256 _lastClaimTimestamp,uint256 _releaseSecond,uint256 _claimble) public onlyExecutor returns (bool) {
        return _setUserInfo(_user, _lastClaimTimestamp, _releaseSecond, _claimble);
    }

    function _setUserInfo(address _user,uint256 _lastClaimTimestamp,uint256 _releaseSecond,uint256 _claimble) internal returns (bool) {
        _userInfo[_user] = UserInfo({lastClaimTimestamp: _lastClaimTimestamp,releaseSecond: _releaseSecond,claimble: _claimble});
        return true;
    }



    //个大参数的设置 包括执行者权限
    function setReleaseCycle(uint256 _lv, uint256 _releaseSecond)public onlyOwner returns (bool){
        releaseCycle[_lv] = _releaseSecond;
        return true;
    }

    function setStateOpen(bool _bool) public onlyOwner returns (bool) {
        stateOpen = _bool;
        return true;
    }

    function setBaseURI(string memory _str) public onlyOwner returns (bool) {
        _baseURI_ = _str;
        return true;
    }

    function setMaxPreSale(uint256 _val) public onlyOwner returns (bool) {
        maxPreSale = _val;
        return true;
    }

    function setPreSaleEnd(uint256 _val) public onlyOwner returns (bool) {
        preSaleEnd = _val;
        return true;
    }

    function setExecutor(address _address, bool _type) external onlyOwner returns (bool) {
        executor[_address] = _type;
        return true;
    }


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    //制定NFT等级
    function getLvPoint(uint256 seed) internal view returns (uint256 lv) {
        bytes32[] memory pool = Random.initLatest(3, seed);

        uint256 RNG = uint256(Random.uniform(pool, 1, 100));

        if (RNG <= 60) {
            lv = 0;
        } else if (RNG <= 90) {
            lv = 1;
        } else {
            lv = 2;
        }
    }



    function getFishBodyPoint(uint256 seed)
        internal
        view
        returns (uint256 ret)
    {
        bytes32[] memory pool = Random.initLatest(10, seed);

        uint256 RNG = uint256(Random.uniform(pool, 1, 100));
        //直接使用library Random

        if (RNG <= 10) {
            ret = 0;
        } else if (RNG <= 20) {
            ret = 1;
        } else if (RNG <= 30) {
            ret = 2;
        } else if (RNG <= 40) {
            ret = 3;
        } else if (RNG <= 50) {
            ret = 4;
        } else if (RNG <= 60) {
            ret = 5;
        } else if (RNG <= 70) {
            ret = 6;
        } else if (RNG <= 80) {
            ret = 7;
        } else if (RNG <= 90) {
            ret = 8;
        } else {
            ret = 9;
        }
    }

    function createFish(address _to,uint256 seed,uint256 _remainingReward) internal returns (bool) {
        string[10] memory fishBodys = [
            "|",
            "#",
            "(",
            ")",
            "!",
            "]",
            "$",
            "[",
            "+",
            "&"
        ];



        uint256 fishBodysID1 = getFishBodyPoint(seed + 1 + totalSupply());
        uint256 fishBodysID2 = getFishBodyPoint(seed + 2 + totalSupply());
        uint256 fishBodysID3 = getFishBodyPoint(seed + 3 + totalSupply());
        uint256 fishBodysID4 = getFishBodyPoint(seed + 4 + totalSupply());
        uint256 fishBodysID5 = getFishBodyPoint(seed + 5 + totalSupply());




        string memory fishAssembly = string(
            abi.encodePacked(
                "<",
                "\u00b0", //"°"
                fishBodys[fishBodysID1],
                fishBodys[fishBodysID2],
                fishBodys[fishBodysID3],
                fishBodys[fishBodysID4],
                fishBodys[fishBodysID5],
                "\u2264" //"≤"
            )
        );



        bytes32[] memory pool = Random.initLatest(8, seed);
        uint256 backupPoint = uint256(Random.uniform(pool, 1, 10000));//备用随机数



        uint256 lv = getLvPoint(seed);//等级设置
        _registerToken(_to, fishAssembly, _remainingReward, lv, backupPoint);//传参logic算 回传此合约
        return true;
    }


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    //创建NFT内容



    function _registerToken(
        address _to,
        string memory _fishAssembly,
        uint256 _remainingReward,
        uint256 _lv,
        uint256 _backupPoint
    ) internal returns (bool) {
        _setNftInfo(
            tokenIdIndex,
            _fishAssembly,
            _remainingReward,
            // releaseCycle[_lv],
            _lv,
            _backupPoint
        );

        super._safeMint(_to, tokenIdIndex);
        tokenIdIndex = tokenIdIndex.add(1);
        return true;
    }





    function mintFromExecutor(
        address _to,
        uint256 _seed,
        uint256 _remainingReward
    ) external onlyExecutor returns (bool) {
        require(executor[msg.sender], "executor no good");
        return createFish(_to, _seed, _remainingReward);
    }




    //数字变成字符串
    function integerToString(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 temp = _i;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (_i != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(_i % 10)));
            _i /= 10;
        }
        return string(buffer);
    }

    

    //@dev See {IERC721Metadata-tokenURI}.
    
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );
        return string(abi.encodePacked(_baseURI_, integerToString(tokenId)));
    }





    function burn(uint256 _id) external returns (bool) {
        require(msg.sender == ownerOf(_id), "No approved");
        checkState();
        UserInfo storage user = _userInfo[msg.sender];
        user.lastClaimTimestamp = block.timestamp;
        user.releaseSecond = releaseCycle[_nftInfo[_id].lv];
        user.claimble = user.claimble.add(_nftInfo[_id].remainingReward);

        super._burn(_id);
        return true;
    }






    function claim() external returns (bool) {
        UserInfo storage user = _userInfo[msg.sender];
        require(user.claimble > 0, "claimble is 0");
        uint256 diffTimestamp = block.timestamp.sub(user.lastClaimTimestamp);
        if (diffTimestamp >= user.releaseSecond) {
            IFISH(FISH).mint(msg.sender, user.claimble);
            user.lastClaimTimestamp = block.timestamp;
            user.claimble = 0;
            user.releaseSecond = 0;
        } else {
            uint256 _pending = diffTimestamp.mul(user.claimble).div(
                user.releaseSecond
            );
            IFISH(FISH).mint(msg.sender, _pending);
            user.lastClaimTimestamp = block.timestamp;
            user.claimble = user.claimble.sub(_pending);
            user.releaseSecond = user.releaseSecond.sub(diffTimestamp);
        }
        return true;
    }





    function pending() external view returns (uint256) {
        UserInfo storage user = _userInfo[msg.sender];
        uint256 diffTimestamp = block.timestamp.sub(user.lastClaimTimestamp);
        if (diffTimestamp >= user.releaseSecond) {
            return user.claimble;
        } else {
            return diffTimestamp.mul(user.claimble).div(user.releaseSecond);
        }
    }




    //检查项目是否启动
    function checkState() internal view returns (bool) {
        require(stateOpen, "Please wait for the agreement to start");
        if (maxPreSale <= totalSupply() || block.timestamp >= preSaleEnd) {
            return true;
        } else {
            require(
                false,
                "The sales time has not ended or the totalSupply quantity has not reached the target"
            );
        }
        return false;
    }
}
