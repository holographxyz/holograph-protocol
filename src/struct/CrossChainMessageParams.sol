/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

import "./GasParameters.sol";

struct CrossChainMessageParams {
  uint256 gasLimit;
  uint256 gasPrice;
  uint256 msgValue;
  uint256 dstNativeAmount;
  address msgSender;
  address dstNativeAddress;
  uint32 toChain;
  GasParameters gasParameters;
  bytes crossChainPayload;
  bytes adapterParams;
}
