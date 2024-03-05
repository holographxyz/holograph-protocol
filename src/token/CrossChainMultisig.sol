/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

import "../abstract/GenericH.sol";

import "../interface/HolographGenericInterface.sol";
import "../interface/HolographInterface.sol";
import "../interface/HolographerInterface.sol";
import "../interface/Ownable.sol";

/**
 * @title Holograph Cross-chain secure packet controller.
 * @author CXIP-Labs
 * @notice A smart contract for connecting a single multisig crosschain.
 * @dev The entire logic and functionality of the smart contract is self-contained.
 */
contract CrossChainMultisig is GenericH {
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.multisig')) - 1)
   */
  bytes32 constant _multisigSlot = precomputeslot("eip1967.Holograph.multisig");
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.multisig')) - 1)
   */
  bytes32 constant _multisigChainSlot = precomputeslot("eip1967.Holograph.multisigChain");
  /**
   * @dev Counter of nonces used for creating packets. Only applicable on multisigChain.
   */
  uint256 private _nonce;
  /**
   * @dev Map of secure packets contained.
   */
  mapping(uint256 => bytes) private _securePackets;

  modifier onlyMultisig() {
    address sender = ((msg.sender == holographer()) ? msgSender() : msg.sender);
    require(sender == _multisig(), "HOLOGRAPH: multisig only call");
    _;
  }

  modifier onlyAuthorized() {
    address sender = ((msg.sender == holographer()) ? msgSender() : msg.sender);
    require(
      sender == _multisig() || sender == _getOwner() || sender == Ownable(holographer()).owner(),
      "HOLOGRAPH: unauthorized sender"
    );
    _;
  }

  /**
   * @dev Constructor is left empty and init is used instead
   */
  constructor() {}

  /**
   * @notice Used internally to initialize the contract instead of through a constructor
   * @dev This function is called by the deployer/factory when creating a contract
   * @param initPayload abi encoded payload to use for contract initilaization
   */
  function init(bytes memory initPayload) external override returns (bytes4) {
    _nonce = 0;
    (uint32 multisigChain, address multiSig) = abi.decode(initPayload, (uint32, address));
    assembly {
      sstore(_multisigChainSlot, multisigChain)
      sstore(_multisigSlot, multiSig)
    }
    // purposefully setting owner to source contract
    _setOwner(msg.sender);
    // run underlying initializer logic
    return _init(initPayload);
  }

  function bridgeIn(
    uint32, /* fromChain*/
    bytes calldata payload
  ) external onlyHolographer returns (bool) {
    (
      uint256 nonce,
      uint256 targetValue,
      uint32 targetChain,
      address targetContract,
      bytes4 targetFunction,
      bytes memory targetPayload,
      bool executeOnBridgeIn
    ) = abi.decode(payload, (uint256, uint256, uint32, address, bytes4, bytes, bool));
    if (executeOnBridgeIn) {
      if (nonce >= _nonce) {
        _nonce = nonce + 1;
      }
      _executeSecurePacket(targetValue, targetContract, targetFunction, targetPayload);
    } else {
      _createSecurePacket(nonce, targetValue, targetChain, targetContract, targetFunction, targetPayload);
    }
    return true;
  }

  function bridgeOut(
    uint32, /* toChain*/
    address sender,
    bytes calldata payload
  ) external onlyHolographer returns (bytes memory _data) {
    require(sender == _multisig(), "HOLOGRAPH: multisig only call");
    uint256 checkNonce = abi.decode(payload, (uint256));
    if (checkNonce == 0) {
      // expect data to be sent on the fly
      (
        uint256 nonce,
        uint256 targetValue,
        uint32 targetChain,
        address targetContract,
        bytes4 targetFunction,
        bytes memory targetPayload,
        bool executeOnBridgeIn
      ) = abi.decode(payload, (uint256, uint256, uint32, address, bytes4, bytes, bool));
      _data = abi.encode(
        nonce,
        targetValue,
        targetChain,
        targetContract,
        targetFunction,
        targetPayload,
        executeOnBridgeIn
      );
    } else {
      // extract data from nonce
      (uint256 nonce, bool executeOnBridgeIn) = abi.decode(payload, (uint256, bool));
      (
        uint256 targetValue,
        uint32 targetChain,
        address targetContract,
        bytes4 targetFunction,
        bytes memory targetPayload
      ) = abi.decode(_securePackets[nonce], (uint256, uint32, address, bytes4, bytes));
      _data = abi.encode(
        nonce,
        targetValue,
        targetChain,
        targetContract,
        targetFunction,
        targetPayload,
        executeOnBridgeIn
      );
      delete _securePackets[nonce];
    }
  }

  function createSecurePacket(
    uint256 nonce,
    uint256 targetValue,
    uint32 targetChain,
    address targetContract,
    bytes4 targetFunction,
    bytes calldata targetPayload
  ) external onlyMultisig {
    _createSecurePacket(nonce, targetValue, targetChain, targetContract, targetFunction, targetPayload);
  }

  function _createSecurePacket(
    uint256 nonce,
    uint256 targetValue,
    uint32 targetChain,
    address targetContract,
    bytes4 targetFunction,
    bytes memory targetPayload
  ) internal {
    require(nonce >= _nonce, "HOLOGRAPH: nonce too small");
    require(_chain() == _multisigChain(), "HOLOGRAPH: restricted chain");
    _nonce = nonce + 1;
    _securePackets[nonce] = abi.encode(targetValue, targetChain, targetContract, targetFunction, targetPayload);
  }

  function executeSecurePacket(uint256 nonce) external onlyAuthorized {
    (
      uint256 targetValue,
      uint32 targetChain,
      address targetContract,
      bytes4 targetFunction,
      bytes memory targetPayload
    ) = abi.decode(_securePackets[nonce], (uint256, uint32, address, bytes4, bytes));
    require(targetChain == _chain(), "HOLOGRAPH: incorrect chain id");
    require(targetContract != address(0), "HOLOGRAPH: empty target address");
    _executeSecurePacket(targetValue, targetContract, targetFunction, targetPayload);
    delete _securePackets[nonce];
  }

  function _executeSecurePacket(
    uint256 targetValue,
    address targetContract,
    bytes4 targetFunction,
    bytes memory targetPayload
  ) internal returns (bytes memory) {
    (bool success, bytes memory output) = payable(targetContract).call{value: targetValue}(
      abi.encodeWithSelector(targetFunction, targetPayload)
    );
    if (success) {
      return output;
    } else {
      revert("HOLOGRAPH: execute call failed");
    }
  }

  function removeSecurePacket(uint256 nonce) external onlyMultisig {
    delete _securePackets[nonce];
  }

  function getSecurePacket(uint256 nonce)
    external
    view
    returns (
      uint256 targetValue,
      uint32 targetChain,
      address targetContract,
      bytes4 targetFunction,
      bytes memory targetPayload
    )
  {
    return abi.decode(_securePackets[nonce], (uint256, uint32, address, bytes4, bytes));
  }

  function withdraw(address payable destinationAddress) external override onlyMultisig {
    if (holographer().balance > 0) {
      HolographGenericInterface(holographer()).sourceWithdraw(payable(address(this)));
    }
    destinationAddress.transfer(address(this).balance);
  }

  function _chain() internal view returns (uint32) {
    return HolographInterface(HolographerInterface(payable(address(this))).getHolograph()).getHolographChainId();
  }

  function _multisig() internal view returns (address multisig) {
    assembly {
      multisig := sload(_multisigSlot)
    }
  }

  function _multisigChain() internal view returns (uint32 multisigChain) {
    assembly {
      multisigChain := sload(_multisigChainSlot)
    }
  }
}
