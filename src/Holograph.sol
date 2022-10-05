/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

import "./abstract/Admin.sol";
import "./abstract/Initializable.sol";

import "./interface/IInitializable.sol";
import "./interface/IHolograph.sol";

/**
 * @title Holograph
 * @author https://github.com/holographxyz
 * @notice This is the primary Holograph Protocol smart contract.
 * @dev This contract stores a reference to all the primary modules and variables of the protocol.
 */
contract Holograph is Admin, Initializable, IHolograph {
  bytes32 constant _bridgeSlot = precomputeslot("eip1967.Holograph.bridge");
  bytes32 constant _chainIdSlot = precomputeslot("eip1967.Holograph.chainId");
  bytes32 constant _factorySlot = precomputeslot("eip1967.Holograph.factory");
  bytes32 constant _holographChainIdSlot = precomputeslot("eip1967.Holograph.holographChainId");
  bytes32 constant _interfacesSlot = precomputeslot("eip1967.Holograph.interfaces");
  bytes32 constant _operatorSlot = precomputeslot("eip1967.Holograph.operator");
  bytes32 constant _registrySlot = precomputeslot("eip1967.Holograph.registry");
  bytes32 constant _treasurySlot = precomputeslot("eip1967.Holograph.treasury");

  /**
   * @dev Constructor is left empty and init is used instead.
   */
  constructor() {}

  function init(bytes memory data) external override returns (bytes4) {
    require(!_isInitialized(), "HOLOGRAPH: already initialized");
    (
      uint32 holographChainId,
      address bridge,
      address factory,
      address interfaces,
      address operator,
      address registry,
      address treasury
    ) = abi.decode(data, (uint32, address, address, address, address, address, address));
    assembly {
      sstore(_adminSlot, origin())
      sstore(_bridgeSlot, bridge)
      sstore(_chainIdSlot, chainid())
      sstore(_factorySlot, factory)
      sstore(_holographChainIdSlot, holographChainId)
      sstore(_interfacesSlot, interfaces)
      sstore(_operatorSlot, operator)
      sstore(_registrySlot, registry)
      sstore(_treasurySlot, treasury)
    }
    _setInitialized();
    return IInitializable.init.selector;
  }

  function getBridge() external view returns (address bridge) {
    assembly {
      bridge := sload(_bridgeSlot)
    }
  }

  function setBridge(address bridge) external onlyAdmin {
    assembly {
      sstore(_bridgeSlot, bridge)
    }
  }

  /**
   * @dev Returns the chain id. Useful for checking if/when a hard fork occurs.
   */
  function getChainId() external view returns (uint256 chainId) {
    assembly {
      chainId := sload(_chainIdSlot)
    }
  }

  /**
   * @dev Allow the chain id to be changed. Useful for updating once a hard fork has been mitigated.
   */
  function setChainId(uint256 chainId) external onlyAdmin {
    assembly {
      sstore(_chainIdSlot, chainId)
    }
  }

  function getFactory() external view returns (address factory) {
    assembly {
      factory := sload(_factorySlot)
    }
  }

  function setFactory(address factory) external onlyAdmin {
    assembly {
      sstore(_factorySlot, factory)
    }
  }

  function getHolographChainId() external view returns (uint32 holographChainId) {
    assembly {
      holographChainId := sload(_holographChainIdSlot)
    }
  }

  function setHolographChainId(uint32 holographChainId) external onlyAdmin {
    assembly {
      sstore(_holographChainIdSlot, holographChainId)
    }
  }

  function getInterfaces() external view returns (address interfaces) {
    assembly {
      interfaces := sload(_interfacesSlot)
    }
  }

  function setInterfaces(address interfaces) external onlyAdmin {
    assembly {
      sstore(_interfacesSlot, interfaces)
    }
  }

  function getOperator() external view returns (address operator) {
    assembly {
      operator := sload(_operatorSlot)
    }
  }

  function setOperator(address operator) external onlyAdmin {
    assembly {
      sstore(_operatorSlot, operator)
    }
  }

  function getRegistry() external view returns (address registry) {
    assembly {
      registry := sload(_registrySlot)
    }
  }

  function setRegistry(address registry) external onlyAdmin {
    assembly {
      sstore(_registrySlot, registry)
    }
  }

  function getTreasury() external view returns (address treasury) {
    assembly {
      treasury := sload(_treasurySlot)
    }
  }

  function setTreasury(address treasury) external onlyAdmin {
    assembly {
      sstore(_treasurySlot, treasury)
    }
  }

  receive() external payable {
    revert();
  }

  fallback() external payable {
    revert();
  }
}
