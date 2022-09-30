/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

interface ERC20 {
  event Transfer(address indexed from, address indexed to, uint256 value);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address to, uint256 value) external returns (bool);
}

contract Faucet {
  address public owner;
  ERC20 public token;

  uint256 public faucetDripAmount = 100 ether;
  uint256 public faucetCooldown = 24 hours;

  mapping(address => uint256) lastAccessTime;

  constructor(address tokenInstance_) {
    require(tokenInstance_ != address(0));
    token = ERC20(tokenInstance_);
    owner = msg.sender;
  }

  /// @notice Get tokens from faucet's own balance. Rate limited.
  function requestTokens() external {
    require(isAllowedToWithdraw(msg.sender), 'Come back later');
    require(token.balanceOf(address(this)) >= faucetDripAmount, "Faucet is empty");
    lastAccessTime[msg.sender] = block.timestamp;
    token.transfer(msg.sender, faucetDripAmount);
  }

  /// @notice Grant tokens to receiver from faucet's own balance. Not rate limited.
  function grantTokens(address address_) external onlyOwner {
    require(token.balanceOf(address(this)) >= faucetDripAmount, "Faucet is empty");
    token.transfer(address_, faucetDripAmount);
  }

  function grantTokens(address address_, uint256 amountWei_) external onlyOwner {
    require(token.balanceOf(address(this)) >= amountWei_, "Insufficient funds");
    token.transfer(address_, amountWei_);
  }

  /// @notice Withdraw funds from the faucet.
  function withdrawTokens(address receiver_) external onlyOwner {
    token.transfer(receiver_, token.balanceOf(address(this)));
  }

  function withdrawTokens(address receiver_, uint256 amountWei_) external onlyOwner {
    require(token.balanceOf(address(this)) >= amountWei_, "Insufficient funds");
    token.transfer(receiver_, amountWei_);
  }

  /// @notice Configure the time between two drip requests. Time is in seconds.
  function setWithdrawCooldown(uint256 waitTimeSeconds_) external onlyOwner {
    faucetCooldown = waitTimeSeconds_;
  }

  /// @notice Configure the drip request amount. Amount is in wei.
  function setWithdrawAmount(uint256 amountWei_) external onlyOwner {
    faucetDripAmount = amountWei_;
  }

  /// @notice Check whether an address can request drip and is not on cooldown.
  function isAllowedToWithdraw(address address_) public view returns (bool) {
    if(lastAccessTime[address_] == 0) {
      return true;
    } else if(block.timestamp >= lastAccessTime[address_] + faucetCooldown) {
      return true;
    }
    return false;
  }

  modifier onlyOwner(){
    require(msg.sender == owner, "Caller is not the owner");
    _;
  }
}
