/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

import "../struct/DeploymentConfig.sol";
import "../struct/Verification.sol";

interface IHolographBridge {
  function executeJob(bytes calldata _payload) external;

  function erc20in(
    uint256 nonce,
    uint32 fromChain,
    address token,
    address from,
    address to,
    uint256 amount,
    bytes calldata data,
    address hTokenRecipient,
    uint256 hTokenValue
  ) external;

  function erc20out(
    uint32 toChain,
    address token,
    address from,
    address to,
    uint256 amount
  ) external payable;

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
