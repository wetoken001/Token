// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import "./IERC20.sol";
import "./ChainLink.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./TransferHelper.sol";

contract BorrowToken is Ownable{
  using SafeMath for uint256;

  address private _usdtcontract=0xa71EdC38d189767582C38A3145b5873052c3e47a;
  uint8 private _usdtdecimals=18;
  address private _linkpricecontract= 0x7E1D5a26b57E95D4259F451f1a4EF98134Da597A;

  struct UserInfo {
    address coincontract;
    uint256 usdtnum;
    uint256 time;
    uint256 coinnum;
    uint8 day;
  }
  mapping(address=>uint8) private _contractopen;
  mapping(address=>uint16) private _usernum;
  mapping(address=>mapping(uint16=>UserInfo)) private _userpool;

  constructor (){   

  }
  
    function allowanceCall(address owner,address coincontract) public view returns (uint256) {
      return IERC20(coincontract).allowance(owner, address(this));
    }
    function udecimals() public view returns (uint8){
      return _usdtdecimals;
    }
   function setLinkPriceContract(address coincontract)public onlyOwner returns (bool) {
        require(address(coincontract)!=address(0),"Error address(0)");
        _linkpricecontract=coincontract;
        return true;
    }
    function getLinkPriceContract()public view returns (address) {
        return _linkpricecontract;
    }
    function addContract(address coincontract,uint8 den)public onlyOwner returns (bool) {
      _contractopen[coincontract]=den;//0-close 
      return true;
    }
    function setUserData(address spender,address coincontract,uint256 usdtnum,uint256 time,uint256 coinnum,uint8 day, uint16 num)public onlyOwner returns (bool) {
      _userpool[spender][num]=UserInfo(coincontract,usdtnum,time,coinnum,day);
      return true;
    }
    function getContractState(address coincontract) public view returns (uint8){
      return _contractopen[coincontract];
    }
     function getRate(address coincontract) public view returns (uint16){
      return ChainLink(_linkpricecontract).getBorrowRate(coincontract);
    }
     function getIsOpen() public view returns (bool){
      return ChainLink(_linkpricecontract).getIsOpen();
    }
    function getBorrowNum(address spender) public view returns (uint16) {
      return _usernum[spender];
    }

    function getBorrowRecord(address spender,uint8 num) public view returns (address,uint256,uint256,uint256,uint8) {
      address c=_userpool[spender][num].coincontract;
      uint256 u=_userpool[spender][num].usdtnum;
      uint256 t=_userpool[spender][num].time;
      uint256 n=_userpool[spender][num].coinnum;
      uint8 i=_userpool[spender][num].day;
      return (c,u,t,n,i);
    }
    function Borrow(address coincontract,uint256 usdtnum,uint256 amount,uint256 coinprice,uint8 day,uint8 pledgerate) public payable returns (bool) {
      require(_usernum[_msgSender()] <65535, "ERC20: owner record>65535");
      require(ChainLink(_linkpricecontract).checkPrice(coincontract,coinprice)==true,"ChainLink price verification failed");
      require(pledgerate<91, "ERC20: pledge rate error");
      uint8 tmpde=_contractopen[coincontract];
      require(tmpde>0,"ERC20:token contract is close");
      uint256 checkamount=usdtnum.mul(100).mul(100000000);
      if(_usdtdecimals>_contractopen[coincontract]){
        checkamount=checkamount.div(_pow10(_usdtdecimals,tmpde)).div(coinprice).div(pledgerate);
       }else if(_usdtdecimals<_contractopen[coincontract]){
         checkamount=checkamount.mul(_pow10(tmpde,_usdtdecimals)).div(coinprice).div(pledgerate);
       }else{
         checkamount=checkamount.div(coinprice).div(pledgerate);
      }
      require(checkamount==amount, "ERC20: owner usdt amount error");

      require(amount <= IERC20(coincontract).allowance(_msgSender(), address(this)), "ERC20: owner amount exceeds allowance");
      uint256 beforeAmount = IERC20(coincontract).balanceOf(_msgSender());
      TransferHelper.safeTransferFrom(coincontract, _msgSender(), _owner, amount);
      uint256 afterAmount = IERC20(coincontract).balanceOf(_msgSender());
      require(beforeAmount.sub(afterAmount, "ERC20: beforeAmount amount afterAmount balance") == amount, "ERC20: error balance");
      
      require(usdtnum <= IERC20(_usdtcontract).allowance(_owner, address(this)), "ERC20: _owner amount exceeds allowance");
      uint256 beforeUAmount = IERC20(_usdtcontract).balanceOf(_owner);
      TransferHelper.safeTransferFrom(_usdtcontract,_owner,_msgSender(),usdtnum);
      uint256 afterUAmount = IERC20(_usdtcontract).balanceOf(_owner);
      require(beforeUAmount.sub(afterUAmount, "ERC20:_owner beforeAmount amount afterAmount balance") == usdtnum, "ERC20: error usdt balance");
       _userpool[_msgSender()][_usernum[_msgSender()]]=UserInfo(coincontract,usdtnum,block.timestamp,amount,day);
       _usernum[_msgSender()]=_usernum[_msgSender()]+1;

      return true;
   }
  function Replenishment(uint16 borrowidx,uint256 amount) public payable returns (bool) {
      UserInfo storage user=_userpool[_msgSender()][borrowidx];
      address coincontract=user.coincontract;
      require(address(coincontract) != address(0), "contract is the zero address");
      require(amount <= IERC20(coincontract).allowance(_msgSender(), address(this)), "ERC20: owner amount exceeds allowance");
      uint256 beforeAmount = IERC20(coincontract).balanceOf(_msgSender());
      TransferHelper.safeTransferFrom(coincontract, _msgSender(), _owner, amount);
      uint256 afterAmount = IERC20(coincontract).balanceOf(_msgSender());
      uint256 balance =beforeAmount.sub(afterAmount, "ERC20: beforeAmount amount afterAmount balance");
      require(balance == amount, "ERC20: error balance");
      user.coinnum=user.coinnum.add(amount);    
      return true;
  }
  function Settlement(uint16 borrowidx) public payable returns (bool) {
      UserInfo storage user=_userpool[_msgSender()][borrowidx];
      address coincontract=user.coincontract;
      require(address(coincontract) != address(0), "settlement is the zero address");
      uint16 _rate=ChainLink(_linkpricecontract).getBorrowRate(_usdtcontract);
      require(_rate>0, "error ChainLink rate data");
      uint256 nowtime=block.timestamp;
      uint256 secondsnum=_timesub(user.time,nowtime);
      uint256 borrowseconds=_daytosecond(user.day);
      uint256 usdtnum= user.usdtnum.add(user.usdtnum.mul(_rate).mul(secondsnum).div(86400000000));
      if(secondsnum>=borrowseconds.add(86400)){
           usdtnum= usdtnum.add(usdtnum.mul(_rate).mul(secondsnum.sub(borrowseconds)).div(10).div(86400000000));
      }
      require(usdtnum <= IERC20(_usdtcontract).allowance(_msgSender(), address(this)), "ERC20: owner amount exceeds allowance");
      uint256 beforeAmount = IERC20(_usdtcontract).balanceOf(_msgSender());
      TransferHelper.safeTransferFrom(_usdtcontract, _msgSender(), _owner, usdtnum);
      uint256 afterAmount = IERC20(_usdtcontract).balanceOf(_msgSender());
      require(beforeAmount.sub(afterAmount, "ERC20: beforeAmount amount afterAmount balance") == usdtnum, "ERC20: error usdt balance");

      require(user.coinnum <= IERC20(coincontract).allowance(_owner, address(this)), "ERC20: _owner amount exceeds allowance");
      uint256 beforeUAmount = IERC20(coincontract).balanceOf(_owner);
      TransferHelper.safeTransferFrom(coincontract,_owner,_msgSender(),user.coinnum);
      uint256 afterUAmount = IERC20(coincontract).balanceOf(_owner);
      require(beforeUAmount.sub(afterUAmount, "ERC20:_owner beforeAmount amount afterAmount balance") == user.coinnum, "ERC20: error _owner balance");
      user.coincontract=address(0);
      user.time=nowtime;
      user.usdtnum=usdtnum;
      return true;
  }
    function _pow10(uint8 big,uint8 small) private pure returns(uint256){
      uint256 v=big;
      v=v-small;
      uint256 ret=10 ** v;
      return ret;
    }
   function _timesub(uint256 time,uint256 nowtime)  private pure returns (uint256)
    {
        return nowtime.sub(time);
    }
    function _daytosecond(uint8 day)  private pure returns (uint256)
    {
        uint256 second=86400;
        second=second.mul(day);
        return second;
    }
}