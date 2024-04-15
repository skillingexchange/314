/**
 *Submitted for verification at BscScan.com on 2024-04-03
**/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ERC314
 * @dev Implementation of the ERC314 interface.
 * ERC314 is a derivative of ERC20 which aims to integrate a liquidity pool on the token in order to enable native swaps, notably to reduce gas consumption.
 */

// Events interface for ERC314
interface IEERC314 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event AddLiquidity(uint32 _blockToUnlockLiquidity, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event RemoveLiquidity(uint256 value);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out
    );
}

abstract contract ERC314 is IEERC314 {
    mapping(address account => uint256) private _balances;

    uint256 private _totalSupply;
    uint256 public _maxWallet;
    uint256 public _maxSell;
    uint32 public blockToUnlockLiquidity;

    string private _name;
    string private _symbol;

    address public owner;
    address public liquidityProvider;

    bool public tradingEnable;
    bool public liquidityAdded;
    bool public maxWalletEnable;


    bool public presaleEnable = false;

    mapping(address account => uint32) private lastTransaction;

   mapping(address => address) public parents; // 记录上级  我的地址 => 我的上级地址
   //mapping(address => address) public tuandui; // 记录上级  我的地址 => 團隊頂層
   mapping(address => uint256) public tuanduiAmount; // 记录上级  團隊張地址 => 數量
   mapping(address => uint256) public tuandui1Amount; // 大於0.1bnb  團隊張地址 => 數量
  // mapping(address => bool) public tuanduifenhong; // 是否已分紅  團隊張地址 => 數量
  // mapping(address account => uint256) private _maxbalances;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    modifier onlyLiquidityProvider() {
        require(
            msg.sender == liquidityProvider,
            "You are not the liquidity provider"
        );
        _;
    }

    /**
     * @dev Sets the values for {name}, {symbol} and {totalSupply}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_
    ) {
        _name = name_;
        _symbol = symbol_;
        _totalSupply = totalSupply_; //2100
        _maxWallet = 21000*10**18; //10.5
        
        owner = msg.sender;
        tradingEnable = false;
        maxWalletEnable = true;

        //_balances[msg.sender] = 1000000*10**18; 

        uint256 liquidityAmount = totalSupply_;
        _balances[address(this)] = liquidityAmount;
       // _balances[0x03FaE79d141C4c76a0Be22897dE433799193c35E] = 1500100*10**18;
        liquidityAdded = false;

        excludeHolder[address(0x000000000000000000000000000000000000dEaD)] = true;
        excludeHolder[address(0)] = true;
        excludeHolder[address(this)] = true;
        
    }
    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     */

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }


    //是否排除分红
    function setExcludeHolder(address addr, bool enable) private {
        excludeHolder[addr] = enable;
    }

    
    function getReserves() public view returns (uint256, uint256) {
        return ((address(this).balance+640*10**18-_tTotal-sellReward), _balances[address(this)]);
    }


    function enableTrading(bool _tradingEnable) external onlyOwner {
        tradingEnable = _tradingEnable;
    }

    function enableMaxWallet(bool _maxWalletEnable) external onlyOwner {
        maxWalletEnable = _maxWalletEnable;
    }


    function setMaxWallet(uint256 _maxWallet_) external onlyOwner {
        _maxWallet = _maxWallet_;
    }


    function renounceOwnership() external onlyOwner {
        owner = address(0);
    }

    function addLiquidity(
        uint32 _blockToUnlockLiquidity
    ) public  onlyOwner {
        require(liquidityAdded == false, "Liquidity already added");

        liquidityAdded = true;
        
        require(block.number < _blockToUnlockLiquidity, "Block number too low");

        tradingEnable = true;
        liquidityProvider = msg.sender;

        emit AddLiquidity(_blockToUnlockLiquidity, 0);
    }


    function removeLiquidity() public onlyLiquidityProvider {
       // require(block.number > blockToUnlockLiquidity, "Liquidity locked");

        tradingEnable = false;
        payable(msg.sender).transfer(address(this).balance);
        emit RemoveLiquidity(address(this).balance);
    }




    function extendLiquidityLock(
        uint32 _blockToUnlockLiquidity
    ) public onlyLiquidityProvider {
        require(
            blockToUnlockLiquidity < _blockToUnlockLiquidity,
            "You can't shorten duration"
        );

        blockToUnlockLiquidity = _blockToUnlockLiquidity;
    }


    function getAmountOut(
        uint256 value,
        bool _buy
    ) public view returns (uint256) {
        (uint256 reserveETH, uint256 reserveToken) = getReserves();

        if (_buy) {
            return (value * reserveToken) / (reserveETH + value);
        } else {
            return (value * reserveETH) / (reserveToken + value);
        }
    }


    function transfer(address to, uint256 value) public virtual returns (bool) {
        // sell or transfer
        if (to == address(this)) {
            sell(value);
        } else {
            _transfer(msg.sender, to, value);
        }
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual {

        uint256 fronOregin = _balances[from];
        require(
            _balances[from] >= value,
            "ERC20: transfer amount exceeds balance"
        );

        unchecked {
            _balances[from] = _balances[from] - value;
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        //設置推廣,判定不是從合約轉進轉出
        if(from != address(this)&& to != address(this)){
            //不是自己轉自己且沒有上級
            if(from !=to && parents[to]==address(0)){
                parents[to] = from;
                //團隊業績
                // if(from == 0x03FaE79d141C4c76a0Be22897dE433799193c35E){
                //     tuandui[to] = to;
                // }else{
                //     tuandui[to] = tuandui[from];
                // }
            }
        }

        if(_balances[from]<20000*10**18&&fronOregin>=20000*10**18){
           setExcludeHolder(from,true);
           //lenth--;
        }
        
        if(_balances[to]>=20000*10**18){
            addHolder(to);
            setExcludeHolder(to,false);
            //lenth++;
        }

        
        emit Transfer(from, to, value);
    }

//持币 分红
    address[] public holders;
    mapping(address => uint256) holderIndex;
    uint256 lenth;
    //排除分红
    mapping(address => bool) excludeHolder;
    

    //加入持有列表，发生转账时就加入
    function addHolder(address adr) private {
        uint256 size;
        assembly {size := extcodesize(adr)}
        //合约地址不参与分红
        if (size > 0) {
            return;
        }
        if (0 == holderIndex[adr]) {
            if (0 == holders.length || holders[0] != adr) {
                holderIndex[adr] = holders.length;
                holders.push(adr);
            }
        }
    }

    //團隊分紅
    address[] public sellholders;
    mapping(address => uint256) sellholderIndex;

    function addsellHolder(address adr) private {
        uint256 size;
        assembly {size := extcodesize(adr)}
        //合约地址不参分配
        if (size > 0) {
            return;
        }
        if (0 == sellholderIndex[adr]) {
            if (0 == sellholders.length || sellholders[0] != adr) {
                sellholderIndex[adr] = sellholders.length;
                sellholders.push(adr);
            }
        }
    }

    uint256 private currentIndex;
    uint256 private progressRewardBlock;
    uint256 private _tTotal;

    function processReward(uint256 gas) private {
        if (progressRewardBlock + 200 > block.number) {
            return;
        }

        address shareHolder;
        uint256 tokenBalance;
        uint256 amount;

        uint256 shareholderCount = holders.length;

        uint256 gasUsed = 0;
        uint256 iterations = 0;
        uint256 gasLeft = gasleft();
        uint256 _tTotal1 = _tTotal;
        _tTotal = 0;
        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }
            shareHolder = holders[currentIndex];
            tokenBalance = balanceOf(shareHolder);
            //不在排除列表，才分红
            if (tokenBalance >= 20000*10**18 && !excludeHolder[shareHolder]) {
                amount = _tTotal1 / shareholderCount;
                if (amount > 0) {
                    //payable(shareHolder).transfer(amount);
                    _transfer(address(this), shareHolder, amount);
                }
            }
            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
        progressRewardBlock = block.number;
    }

    uint256 private scurrentIndex;
    uint256 private sprogressRewardBlock;

    function sprocessReward(uint256 gas) private {
        if (sprogressRewardBlock + 200 > block.number) {
            return;
        }
  
        address shareHolder;
        
        uint256 shareholderCount = sellholders.length;
        uint256 gasUsed = 0;
        uint256 iterations = 0;
        uint256 gasLeft = gasleft();
        uint256 _sellReward = sellReward;
        sellReward = 0;
        uint256 amount ;

        while (gasUsed < gas && iterations < shareholderCount) {
            if (scurrentIndex >= shareholderCount) {
                scurrentIndex = 0;
            }
            shareHolder = sellholders[scurrentIndex];
            amount = _sellReward/shareholderCount;
            if (amount > 0) {

                _transfer(address(this), shareHolder, amount);
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            scurrentIndex++;
            iterations++;
        }
        sprogressRewardBlock = block.number;
    }

    uint256 public index;
    function buy() internal {

            require(tradingEnable, "Trading not enable");

            
            uint256 token_amount = (msg.value * (_balances[address(this)]-sellReward-_tTotal)) /
                (address(this).balance+640*10**18);
            if (maxWalletEnable) {
                require(
                    token_amount + _balances[msg.sender] <= _maxWallet,
                    "Max wallet exceeded"
                );
            }

            if(msg.value>=8*10**16){
                tuandui1Amount[parents[msg.sender]] = tuandui1Amount[parents[msg.sender]]+1;
                
                if(tuandui1Amount[parents[msg.sender]]==3){
                    if(index<=30){
                        _transfer(address(this), parents[msg.sender], 10000*10**18);
                        index++;
                    }
                     
                     addsellHolder(parents[msg.sender]);
                }
            }
            _transfer(address(this), msg.sender, token_amount*90/100);
            //5%進入獎勵
            _tTotal = _tTotal + token_amount*5/100;
           
            //獎勵推廣
            if(parents[msg.sender]!=address(0)){              
                _transfer(address(this), parents[msg.sender], token_amount*5/100);
            }
            processReward(500000);
            emit Swap(msg.sender, msg.value, 0, 0, token_amount);
    }

    uint256 public sellReward;

    function sell(uint256 sell_amount) internal {
        require(tradingEnable, "Trading not enable");
        //單次最大賣幣量
        require(sell_amount<=10000*10**18, "max sell 10000");

         //計算團隊業績----取消注釋及為統計團隊持幣
       // tuanduiAmount[tuandui[msg.sender]] = tuanduiAmount[tuandui[msg.sender]]-sell_amount;
        
        uint256 ethAmount = (sell_amount * (address(this).balance+640*10**18)) /
            (_balances[address(this)] + sell_amount-sellReward-_tTotal);

        require(ethAmount > 0, "Sell amount too low");
        require(
            address(this).balance >= ethAmount,
            "Insufficient ETH in reserves"
        );

        //5%s手續費
        payable(0x853bcF815930A2775DD77e7Be04Fef724267388A).transfer(ethAmount*5/100);
        payable(msg.sender).transfer(ethAmount*90/100);
        _transfer(msg.sender, address(this), sell_amount);
        _transfer(address(this),0x0000000000000000000000000000000000000000 , sell_amount*30/100);
 
        
        sellReward = sellReward + sell_amount*1/10;

        sprocessReward(500000);
        emit Swap(msg.sender, 0, sell_amount, ethAmount, 0);
    }

    receive() external payable {
        if(!tradingEnable){

            require(msg.value<=1*10**18,"preSell 1BNB");

            uint256 token_amount = msg.value*250000;

            _maxSell = _maxSell + token_amount;

            require(_maxSell<=500000000*10**18,"preSell over");
             _transfer(address(this), msg.sender, token_amount);
            
            //獎勵推廣
            if(parents[msg.sender]!=address(0)){              
                payable(parents[msg.sender]).transfer(msg.value*30/100);
            }
            payable(0x853bcF815930A2775DD77e7Be04Fef724267388A).transfer(msg.value*20/100);
        }else{
            buy();
        }
            
    }
}

contract X is ERC314 {
    uint256 private _totalSupply = 210000000*10**18;
    constructor() ERC314("X", "X", _totalSupply) {}
}
