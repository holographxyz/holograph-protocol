/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

import "./abstract/Admin.sol";
import "./abstract/Initializable.sol";

import "./interface/ERC20Holograph.sol";
import "./interface/ERC721Holograph.sol";
import "./interface/IHolograph.sol";
import "./interface/IHolographTreasury.sol";
import "./interface/IHolographFactory.sol";
import "./interface/IHolographOperator.sol";
import "./interface/IHolographRegistry.sol";
import "./interface/IInitializable.sol";

import "./struct/DeploymentConfig.sol";
import "./struct/Verification.sol";

/**
 * @dev This smart contract contains the actual core treasury logic.
 */
contract HolographTreasury is Admin, Initializable, IHolographTreasury {
  /**
   * @dev Constructor is left empty and only the admin address is set.
   */
  constructor() {}

  function init(bytes memory data) external override returns (bytes4) {
    require(!_isInitialized(), "HOLOGRAPH: already initialized");
    (address bridge, address holograph, address operator, address registry) = abi.decode(
      data,
      (address, address, address, address)
    );
    assembly {
      sstore(precomputeslot("eip1967.Holograph.Bridge.admin"), origin())

      sstore(precomputeslot("eip1967.Holograph.Bridge.bridge"), bridge)
      sstore(precomputeslot("eip1967.Holograph.Bridge.holograph"), holograph)
      sstore(precomputeslot("eip1967.Holograph.Bridge.operator"), operator)
      sstore(precomputeslot("eip1967.Holograph.Bridge.registry"), registry)
    }
    _setInitialized();
    return IInitializable.init.selector;
  }

  function _bridge() private view returns (address bridge) {
    assembly {
      bridge := sload(precomputeslot("eip1967.Holograph.Bridge.bridge"))
    }
  }

  function _holograph() private view returns (address holograph) {
    assembly {
      holograph := sload(precomputeslot("eip1967.Holograph.Bridge.holograph"))
    }
  }

  function _operator() private view returns (address operator) {
    assembly {
      operator := sload(precomputeslot("eip1967.Holograph.Bridge.operator"))
    }
  }

  function _registry() private view returns (address registry) {
    assembly {
      registry := sload(precomputeslot("eip1967.Holograph.Bridge.registry"))
    }
  }
}
