/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

import "../struct/CrossChainMessageParams.sol";

interface CrossChainMessageInterface {
  function send(
    uint256 gasLimit,
    uint256 gasPrice,
    uint32 toChain,
    address msgSender,
    uint256 msgValue,
    bytes calldata crossChainPayload
  ) external payable;

  function getMessageFee(
    uint32 toChain,
    uint256 gasLimit,
    uint256 gasPrice,
    bytes calldata crossChainPayload
  ) external view returns (uint256 hlgFee, uint256 msgFee, uint256 dstGasPrice);

  function getHlgFee(
    uint32 toChain,
    uint256 gasLimit,
    uint256 gasPrice,
    bytes calldata crossChainPayload
  ) external view returns (uint256 hlgFee);

  function send(CrossChainMessageParams memory msgParams) external payable;

  function getMessageFee(CrossChainMessageParams memory msgParams) external view returns (uint256 hlgFee, uint256 msgFee, uint256 dstGasPrice);

  function getHlgFee(CrossChainMessageParams memory msgParams) external view returns (uint256 hlgFee);

}
