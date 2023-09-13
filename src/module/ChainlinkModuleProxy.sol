/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

import "../abstract/Admin.sol";
import "../abstract/Initializable.sol";

contract ChainlinkModuleProxy is Admin, Initializable {
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.chainlinkModule')) - 1)
   */
  bytes32 constant _chainlinkModuleSlot = precomputeslot("eip1967.Holograph.chainlinkModule");

  constructor() {}

  function init(bytes memory data) external override returns (bytes4) {
    require(!_isInitialized(), "HOLOGRAPH: already initialized");
    (address chainlinkModule, bytes memory initCode) = abi.decode(data, (address, bytes));
    assembly {
      sstore(_adminSlot, origin())
      sstore(_chainlinkModuleSlot, chainlinkModule)
    }
    (bool success, bytes memory returnData) = chainlinkModule.delegatecall(
      abi.encodeWithSignature("init(bytes)", initCode)
    );
    bytes4 selector = abi.decode(returnData, (bytes4));
    require(success && selector == Initializable.init.selector, "initialization failed");
    _setInitialized();
    return Initializable.init.selector;
  }

  function getChainlinkModule() external view returns (address chainlinkModule) {
    assembly {
      chainlinkModule := sload(_chainlinkModuleSlot)
    }
  }

  function setChainlinkModule(address chainlinkModule) external onlyAdmin {
    assembly {
      sstore(_chainlinkModuleSlot, chainlinkModule)
    }
  }

  receive() external payable {}

  fallback() external payable {
    assembly {
      let chainlinkModule := sload(_chainlinkModuleSlot)
      calldatacopy(0, 0, calldatasize())
      let result := delegatecall(gas(), chainlinkModule, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }
}
