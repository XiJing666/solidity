// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@sushiswap/core/contracts/uniswapv2/interfaces/IUniswapV2Pair.sol";
import "@sushiswap/core/contracts/uniswapv2/interfaces/IUniswapV2Factory.sol";
import "@sushiswap/core/contracts/uniswapv2/interfaces/IUniswapV2Router02.sol";
import "./libraries/IOracle.sol";

library Math {
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

interface IFISH {
    function mint(address account_, uint256 amount_) external returns (bool);
    //IFISH的接口
}


interface IFISHNFT {
    //IFISHNFT的接口
    function totalSupply() external view returns (uint256);


    function mintFromExecutor(
        address _to,
        uint256 _seed,
        uint256 _remainingReward
    ) external returns (bool);
}

contract usdcBuyNftLogic is Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMath for uint256;

    //代理合约函数初始化
    function initialize(
        IFISH _FISH,
        IFISHNFT _FISHNFT,
        IUniswapV2Factory _Factory,
        IUniswapV2Router02 _Router,
        address _multiSignature,
        address _multiSignatureToSToken,
        address _dev,
        address _op,
        address _sFISH,
        IOracle _oracle,
        IERC20Upgradeable _USDC
    ) external initializer {
        __Ownable_init();
        USDC = _USDC;
        oracle = _oracle;
        dev = _dev;
        op = _op;
        multiSignature = _multiSignature;
        multiSignatureToSToken = _multiSignatureToSToken;
        Router = _Router;
        Factory = _Factory;
        FISH = _FISH;
        FISHNFT = _FISHNFT;
        sFISH = _sFISH;
        PRECISION = 10000;
        ROI = 10000;
        direction = 0;
        stepSize = 100;
        TargetROI = 1000;
        price = 100 * 1e18;
        whitelistDiscount[0] = 10000;
        whitelistDiscount[1] = 9000;
        whitelistDiscount[2] = 8000;
        maxSellAmt = 1000;
        toLiquidityPec = 5000;
        toDevPec = 1500;
        toOpPec = 1500;
        addLiquidityOpen = false;
        stateOpen = false;
    }

    uint256 public exchangeRate;//FISH的价格
    IOracle public oracle;//oracle地址
    address public sFISH;//地址
    address public multiSignature;//多签地址
    address public multiSignatureToSToken;//SToken的多签地址
    //多签地址指的是社区用户交易时临时中转放钱的中间人地址
    address public dev;//dve地址
    address public op;//团队地址
    IUniswapV2Router02 public Router;
    IUniswapV2Factory public Factory;
    IERC20Upgradeable public USDC;
    //路由跟工厂的接口 以及usdc的接口
    uint256 public maxSellAmt;//最大销售数量
    IFISH public FISH;
    IFISHNFT public FISHNFT;
    //fish的地址以及fish nft的地址
    uint256 public ROI;//成本收益比
    uint256 public PRECISION;//百分比分母 区块链并没有小数点 想准确表示就需要分子除分母表示小数点
    uint256 public direction;//
    uint256 public stepSize;//
    uint256 public TargetROI;
    uint256 public price;//买NFT的价格
    mapping(address => uint256) public whitelistLevel;//白名单的等级 等级决定打折等级
    mapping(uint256 => uint256) public whitelistDiscount;//对应的白名单等级打折的等级
    uint256 public toLiquidityPec;//流动性
    uint256 public toDevPec;//dve流动性
    uint256 public toOpPec;//运营团队的流动性
    bool public stateOpen;//能够购买的开启 后备用
    bool public addLiquidityOpen;//流动性的开启 后备用
    bytes public oracleData;//oracleData是给oracle传的一个参 



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1){
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2Library: ZERO_ADDRESS");
    }//想知道token0到底是usdc还是fish的方法sortTokens
    }


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    function setOracle(IOracle _newOracle, bytes memory _newOracleData)public onlyOwner returns (bool) {
        oracle = _newOracle;
        oracleData = _newOracleData;
        return true;
        //设置oracle地址
    }


     function setToLiquidityPec(uint256 _toLiquidityPec)public onlyOwner returns (bool) {
        toLiquidityPec = _toLiquidityPec;
        return true;
    }


    function setToDevPec(uint256 _toDevPec) public onlyOwner returns (bool) {
        toDevPec = _toDevPec;
        return true;
    }


    function setToOpPec(uint256 _toOpPec) public onlyOwner returns (bool) {
        toOpPec = _toOpPec;
        return true;
    }

    function setAddLiquidityOpen(bool _bool) public onlyOwner returns (bool) {
        addLiquidityOpen = _bool;
        return true;
        //添加流动性的开关
    }

    function setDev(address _dev) public onlyOwner returns (bool) {
        dev = _dev;
        return true;
        //动态设置dev团队
    }

    function setOp(address _op) public onlyOwner returns (bool) {
        op = _op;
        return true;
        //动态设置运营团队
    }

    function setMultiSignature(address _multiSignature)public onlyOwner returns (bool) {
        multiSignature = _multiSignature;
        return true;
        //动态修改多签地址
    }

    function setMultiSignatureToSToken(address _multiSignatureToSToken) public onlyOwner returns (bool) {
        multiSignatureToSToken = _multiSignatureToSToken;
        return true;
        //动态修改SToken多签地址
    }

    function setStateOpen(bool _bool) public onlyOwner returns (bool) {
        stateOpen = _bool;
        return true;
        //开启关闭状态的动态调整
    }

    //以下其实就是个大可以动态设置的参数都给一个set funciton去动态修改参数

    function setMaxSellAmt(uint256 _val) public onlyOwner returns (bool) {
        maxSellAmt = _val;
        return true;
    }

    function setROI(uint256 _val) public onlyOwner returns (bool) {
        ROI = _val;
        return true;
    }

    function setDirection(uint256 _val) public onlyOwner returns (bool) {
        direction = _val;
        return true;
    }

    function setStepSize(uint256 _val) public onlyOwner returns (bool) {
        stepSize = _val;
        return true;
    }

    function setTargetROI(uint256 _val) public onlyOwner returns (bool) {
        TargetROI = _val;
        return true;
    }

    function setPrice(uint256 _val) public onlyOwner returns (bool) {
        price = _val;
        return true;
    }

    function setWhitelistLevel(address _user, uint256 _lev)public onlyOwner returns (bool) {
        whitelistLevel[_user] = _lev;
        return true;
    }

    function setWhitelistDiscount(uint256 _val, uint256 _lev) public onlyOwner returns (bool) {
        whitelistDiscount[_val] = _lev;
        return true;
    }


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

     function updateExchangeRate() public returns (bool updated, uint256 rate) {
        (updated, rate) = oracle.get(oracleData);
        if (updated) { exchangeRate = rate; } else {
            // Return the old rate if fetching wasn't successful
            rate = exchangeRate;}
        //同步预言机并更新价格
    }

    function peekSpot() public view returns (uint256) {
        return oracle.peekSpot("0x");
        //return oracle的peekspot价格
    }

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



    function buyNft(uint256 _amt) public returns (bool) {
        uint256 amt = _amt;


        //防止外部合约调用
        require(tx.origin == _msgSender(), "Only EOA");


        //销售额 USDC数量 = 价格*价格*（折扣/折扣分母）
        uint256 amount = price
            .mul(amt)
            .mul(whitelistDiscount[whitelistLevel[msg.sender]])
            .div(PRECISION);
        IERC20Upgradeable(address(USDC)).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );


        //销售额度的百分之a的usdc = 给流动性充值
        uint256 amountUSDCToLiquidity = amount.mul(toLiquidityPec).div(PRECISION);

        //销售额度的百分之b的usdc = 给开发团队
        uint256 amountUSDCToDev = amount.mul(toDevPec).div(PRECISION);

        //销售额度的百分之c的usdc = 给运营团队
        uint256 amountUSDCToOP = amount.mul(toOpPec).div(PRECISION);

        //销售额度的百分之d 的usdc = sFish的分赃。。
        uint256 amountUSDCToSFISH = amount
            .sub(amountUSDCToLiquidity)
            .sub(amountUSDCToDev)
            .sub(amountUSDCToOP);

        //查询usdc-fish 的lp token地址
        address pairAddress = Factory.getPair(address(USDC), address(FISH));
        // (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pairAddress)
        //     .getReserves();


        //因为不知道usdc和fish 谁是第0号的token 现在这里定义一个token 后面拿来做比较
        (address token0, ) = sortTokens(address(USDC), address(FISH));



        //addLiquidityOpen流动性的开关 可以中途改变状态来决定是否拿销售额度的百分之a 的usdc来给流动性充值
        if (addLiquidityOpen) {
            //如果充流动性的话



            //先对uniswap路由授权 让他可以用fish进行扣款 因为要交易
            IERC20Upgradeable(address(USDC)).safeApprove(address(Router), 0);
            IERC20Upgradeable(address(USDC)).safeApprove(
                address(Router),
                type(uint256).max
            );


            IERC20Upgradeable(address(FISH)).safeApprove(address(Router), 0);
            IERC20Upgradeable(address(FISH)).safeApprove(
                address(Router),
                type(uint256).max
            );


            //执行卖一半 因为充流动性需要两个币 现在手头上只有usdc 所以要卖一半 
            //但此处因为有xy=k的公式 而且还需要手续费 所以不能单纯的扣一半
            calAndSwap(
                IUniswapV2Pair(pairAddress),
                address(FISH),
                address(USDC),
                amountUSDCToLiquidity
            );
            uint256 addLiquidityForUSDC = IERC20Upgradeable(address(USDC))
                .balanceOf(address(this))
                .sub(amountUSDCToDev)
                .sub(amountUSDCToOP)
                .sub(amountUSDCToSFISH);
            
            //这就是添加流动性
            Router.addLiquidity(
                address(USDC),
                address(FISH),
                addLiquidityForUSDC,
                IERC20Upgradeable(address(FISH)).balanceOf(address(this)),
                0,
                0,
                multiSignature,
                block.timestamp + 1000
            );



            //否的内容
        } else {
            USDC.safeTransfer(address(multiSignature), amountUSDCToLiquidity);
            //如果不对流动性进行充值 钱就转给多签保管
        }
        USDC.safeTransfer(address(dev), amountUSDCToDev);
        USDC.safeTransfer(address(op), amountUSDCToOP);







        //stateOpen的状态开关 可以改变状态让管理员决定是否拿usdc来购买fish
        //并且把fish转给sFish作为持有Sfishtoken的用户进行奖励（分赃）

        if (stateOpen) {

            //因为不知道usdc和fish谁是第0号reserve0 先在这定义一个reserve0 后续用来做比较。
            (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pairAddress)
                .getReserves();
            (reserve0, reserve1) = address(USDC) == token0
                ? (reserve0, reserve1)
                : (reserve1, reserve0);

            //计算如果用 amountUSDCToSFISH 来购买fish usdc可以购买多少fish
            uint256 amountFish = getAmountOut(
                amountUSDCToSFISH,
                reserve0,
                reserve1
            );
            (uint256 amount0Out, uint256 amount1Out) = address(USDC) == token0
                ? (uint256(0), amountFish)
                : (amountFish, uint256(0));

            
            //把usdc转给lp来用于交易
            USDC.safeTransfer(address(pairAddress), amountUSDCToSFISH);

            //全额购买fish
            IUniswapV2Pair(pairAddress).swap(
                amount0Out,
                amount1Out,
                address(this),
                new bytes(0)
            );

            //查看有多少的fish 全额转给sFish来做奖励
            IERC20Upgradeable(address(FISH)).safeTransfer(
                address(sFISH),
                IERC20Upgradeable(address(FISH)).balanceOf(address(this))
            );
        } else {
            //转给多签地址
            USDC.safeTransfer(
                address(multiSignatureToSToken),
                amountUSDCToSFISH
            );
        }


        //更新预言机价格
        (, uint256 rate) = updateExchangeRate();

        //更新债券的收益比例
        updateRoi();

        //创建NFT
        for (uint256 i = 0; i < amt; i++) {
            FISHNFT.mintFromExecutor(
                msg.sender,
                block.timestamp + i,
                (((price * rate) / 1e18) * (ROI + PRECISION)) / PRECISION
            );
        }
        return true;
    }



///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////




    //计算borrowToken和tokenRelative之间的数量和交换。
    function calAndSwap(IUniswapV2Pair lpToken,address tokenA,address tokenB,uint256 amountUSDCToLiquidity) internal {
        (uint256 token0Reserve, uint256 token1Reserve, ) = lpToken
            .getReserves();
        (uint256 debtReserve, uint256 relativeReserve) = address(FISH) ==
            lpToken.token0()
            ? (token0Reserve, token1Reserve)
            : (token1Reserve, token0Reserve);
        (uint256 swapAmt, bool isReversed) = optimalDeposit(
            0,
            amountUSDCToLiquidity,
            debtReserve,
            relativeReserve
        );


        if (swapAmt > 0) {
            address[] memory path = new address[](2);
            (path[0], path[1]) = isReversed
                ? (tokenB, tokenA)
                : (tokenA, tokenB);
            Router.swapExactTokensForTokens(
                swapAmt,
                0,
                path,
                address(this),
                block.timestamp
            );
        }
    }



    function optimalDeposit(uint256 amtA,uint256 amtB,uint256 resA,uint256 resB) internal pure returns (uint256 swapAmt, bool isReversed) {
        if (amtA.mul(resB) >= amtB.mul(resA)) {
            swapAmt = _optimalDepositA(amtA, amtB, resA, resB);
            isReversed = false;
        } else {
            swapAmt = _optimalDepositA(amtB, amtA, resB, resA);
            isReversed = true;
        }
    }



    function _optimalDepositA(uint256 amtA,uint256 amtB,uint256 resA,uint256 resB) internal pure returns (uint256) {
        require(amtA.mul(resB) >= amtB.mul(resA), "Reversed");

        uint256 a = 997;
        uint256 b = uint256(1997).mul(resA);
        uint256 _c = (amtA.mul(resB)).sub(amtB.mul(resA));
        uint256 c = _c.mul(1000).div(amtB.add(resB)).mul(resA);

        uint256 d = a.mul(c).mul(4);
        uint256 e = Math.sqrt(b.mul(b).add(d));

        uint256 numerator = e.sub(b);
        uint256 denominator = a.mul(2);

        return numerator.div(denominator);
    }
}
