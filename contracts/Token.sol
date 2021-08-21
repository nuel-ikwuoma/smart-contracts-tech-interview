pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  // IERC20

  mapping (address => mapping( address => uint256)) public allowances;

  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    require(balanceOf[_msgSender()] >= value, "Token::transfer - Insufficient balance");
    balanceOf[_msgSender()] = balanceOf[_msgSender()].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _addHolder(to);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    allowances[_msgSender()][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(allowances[from][_msgSender()] >= value, "Token::transferFrom - Insufficient allowance");
    require(balanceOf[from] >= value, "Token::transferFrom - Insufficient balance");
    allowances[from][_msgSender()] = allowances[from][_msgSender()].sub(value);
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _addHolder(to);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    uint256 amountToMint = msg.value;
    require(amountToMint > 0, "Token::mint - No ETH supplied");
    balanceOf[_msgSender()] = balanceOf[_msgSender()].add(amountToMint);
    _addHolder(_msgSender());
    totalSupply = totalSupply.add(amountToMint);
  }

  function burn(address payable dest) external override {
    uint256 amountToBurn = balanceOf[_msgSender()];
    balanceOf[_msgSender()] = 0;
    require(amountToBurn > 0, "Token::burn - Balance is zero");
    (bool sent, bytes memory data) = dest.call{value: amountToBurn}("");
    require(sent, "Token::mint - Failed to send Ether");
    totalSupply = totalSupply.sub(amountToBurn);
  }

  // Helper
  function _msgSender() internal returns(address) {
    return msg.sender;
  }

  // IDividends

  uint256 dividend;       // current dividend value
  address[] allHolders;   // array of all token holders
  uint256 holdersCount;
  mapping(address => bool) isAHolder;
  mapping(address => uint256) holdersDividend;

  uint256 constant scaleFactor = 10**6;

  function _addHolder(address _newHolder) private {
    if(!isAHolder[_newHolder]) {
      // holders[holdersCount++] = _newHolder;
      allHolders.push(_newHolder);
      isAHolder[_newHolder] = true;
      holdersCount++;
    }
  }

  function recordDividend() external override payable {
    uint256 dividend = msg.value;
    require(dividend > 0, "Token::recordDividend - No ETH supplied");
    for(uint256 i = 0; i < holdersCount; i++) {
      address tokenHolder = allHolders[i];
      uint256 holderBalance = balanceOf[tokenHolder];
      uint256 holderDividend = (holderBalance * dividend) / totalSupply;
      holdersDividend[tokenHolder] = holdersDividend[tokenHolder].add(holderDividend);
    }
  }

  function getWithdrawableDividend(address payee) external override view returns (uint256) {
    return (holdersDividend[payee]);
  }

  function withdrawDividend(address payable dest) external override {
    uint256 callerDividend = holdersDividend[_msgSender()];
    holdersDividend[_msgSender()] = 0;
    require(callerDividend > 0, "Token::withdrawDividend - No dividend to withdraw");
    // send dividend ETH to 'dest'
    (bool sent, bytes memory data) = dest.call{value: callerDividend}("");
    require(sent, "Token::withdrawDividend - Failed to send Ether");
  }
}