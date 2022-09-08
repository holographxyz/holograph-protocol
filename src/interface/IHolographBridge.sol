/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

import "../struct/DeploymentConfig.sol";
import "../struct/Verification.sol";

interface IHolographBridge {
  function bridgeInRequest(uint256 nonce, uint32 fromChain, address holographableContract, address hToken, address hTokenRecipient, uint256 hTokenValue, bytes calldata data) external;

  function bridgeOutRequest(uint32 toChain, address holographableContract, uint256 gasLimit, uint256 gasPrice, bytes calldata data) external payable;

  function deployIn(
    uint256 nonce,
    uint32 fromChain,
    bytes calldata data,
    address hTokenRecipient,
    uint256 hTokenValue
  ) external;

  function deployOut(
    uint32 toChain,
    DeploymentConfig calldata config,
    Verification calldata signature,
    address signer
  ) external payable;
}
