/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

struct DataERC20 {
  uint256 _balance;
  uint256 _nonce;
  mapping(address => mapping(address => uint256)) _allowance;
}
