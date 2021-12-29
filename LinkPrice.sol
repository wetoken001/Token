// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this;
        // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}
abstract contract Ownable is Context {
    address public _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor ()  {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract LinkPrice is Ownable{
    AggregatorV3Interface internal priceFeed;

    using SafeMath for uint256;

    struct Rate {
        uint16 r1;
        uint16 r2;
        uint16 r3;
        uint16 r4;
        uint16 r5;
    }
  mapping(address=>Rate) private _coinrate;
  mapping(address=>string) private _coinlist;
  mapping(string=>uint256) private _coinprice;
  mapping(address=>bool) private _openuser;
  mapping(address=>uint16) private _coinborrowrate;
  constructor (){
       _coinprice["USDT"]=100000;
      _coinlist[0x66a79D23E58475D2738179Ca52cd0b41d73f0BEa]="BTC";
      _coinrate[0x66a79D23E58475D2738179Ca52cd0b41d73f0BEa]=Rate(170,300,700,1800,3000);
      priceFeed = AggregatorV3Interface(0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf);
  }
   
    function getThePrice() public view returns (int) {
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }

    function setContract(address coincontract,string memory symbol,uint256 price)public onlyOwner returns (bool) {
        require(address(coincontract)!=address(0),"Error address(0)");
        _coinlist[coincontract]=symbol;
        _coinprice[symbol]=price;
        return true;
    }
    function addUser(address coincontract,bool isopen)public onlyOwner returns (bool) {
        _openuser[coincontract]=isopen;
        return true;
    }
    function setRate(address coincontract,uint16 r1,uint16 r2,uint16 r3,uint16 r4,uint16 r5)public onlyOwner returns (bool) {
        _coinrate[coincontract]=Rate(r1,r2,r3,r4,r5);
        return true;
    }
    function setBorrowRate(address coincontract,uint16 rate)public onlyOwner returns (bool) {
        _coinborrowrate[coincontract]=rate;
        return true;
    }
    function setPrice(uint256 p1)public onlyOwner returns (bool) {
        _coinprice["BTC"]=p1;
        return true;
    }
    function setPrice(address coincontract,uint256 price)public onlyOwner returns (bool) {
        require(address(coincontract)!=address(0),"Error address(0)");
        require(_compareStr(_coinlist[coincontract],"")==false,"Error contract");
        _coinprice[_coinlist[coincontract]]=price;
        return true;
    }
    function setPrice(string memory symbol,uint256 price)public onlyOwner returns (bool) {
        _coinprice[symbol]=price;
        return true;
    }
     function getSymbol(address coincontract) public view returns(string memory){
        return  _coinlist[coincontract];
    }
    function getPrice(string memory symbol) public view returns(uint256){
        uint256 cPrice = getThePrice();
        uint256 sPrice = _coinprice[symbol];
        uint256 peroff=sPrice.div(3);

        if(cPrice>sPrice && cPrice<=sPrice.add(peroff) || cPrice<sPrice && cPrice>=sPrice.sub(peroff) || cPrice==sPrice){
            return sPrice;
        } else {
            return cPrice;
        }
    }
    function getIsOpen() public view returns(bool){
        bool isopenuser= _openuser[msg.sender];
        return isopenuser;
    }
    function checkPrice(address coincontract,uint256 price)public view returns (bool) {
        bool isopenuser= _openuser[msg.sender];
        if(isopenuser==true && _compareStr(_coinlist[coincontract],"")==false){
            uint256 saveprice=_coinprice[_coinlist[coincontract]];
            uint256 peroff=saveprice.div(3);
            if(saveprice>price && saveprice<=price.add(peroff) || saveprice<price && saveprice>=price.sub(peroff) || saveprice==price){
                 return true;
            }
        }
        return false;
    }
    function checkPrice(string memory symbol,uint256 price)public view returns (bool) {
        bool isopenuser= _openuser[msg.sender];
        if(isopenuser==true && _compareStr(symbol,"")==false){
            uint256 saveprice=_coinprice[symbol];
            uint256 peroff=saveprice.div(3);
            if(saveprice>price && saveprice<=price.add(peroff) || saveprice<price && saveprice>=price.sub(peroff) || saveprice==price){
                 return true;
            }
        }
        return false;
    }
    function getRate(address coincontract) public view returns (uint16,uint16,uint16,uint16,uint16){
        Rate memory _r= _coinrate[coincontract];
        return(_r.r1,_r.r2,_r.r3,_r.r4,_r.r5);
    }
    function getBorrowRate(address coincontract) public view returns (uint16){
        return _coinborrowrate[coincontract];
    }
    function _compareStr(string memory _str1, string memory _str2) public pure returns(bool) {
        if(bytes(_str1).length == bytes(_str2).length){
            if(keccak256(abi.encodePacked(_str1)) == keccak256(abi.encodePacked(_str2))) {
                return true;
            }
        }
        return false;
    }
}
