// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "../abstract/Admin.sol";
import "../abstract/Initializable.sol";

contract LayerZeroModuleProxyV2 is Admin, Initializable {
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.layerZeroModuleV2')) - 1)
   */
  bytes32 constant _layerZeroModuleV2Slot = 0x928de58955d10fd78410a0a6aa3c5832b103908613a6ceb2ee3933da510fb06c;

  constructor() {}

  function init(bytes memory data) external override returns (bytes4) {
    require(!_isInitialized(), "HOLOGRAPH: already initialized");
    (address layerZeroModule, bytes memory initCode) = abi.decode(data, (address, bytes));
    assembly {
      sstore(_adminSlot, origin())
      sstore(_layerZeroModuleV2Slot, layerZeroModule)
    }
    (bool success, bytes memory returnData) = layerZeroModule.delegatecall(
      abi.encodeWithSignature("init(bytes)", initCode)
    );
    bytes4 selector = abi.decode(returnData, (bytes4));
    require(success && selector == Initializable.init.selector, "initialization failed");
    _setInitialized();
    return Initializable.init.selector;
  }

  function getLayerZeroModule() external view returns (address layerZeroModule) {
    assembly {
      layerZeroModule := sload(_layerZeroModuleV2Slot)
    }
  }

  function setLayerZeroModule(address layerZeroModule) external onlyAdmin {
    assembly {
      sstore(_layerZeroModuleV2Slot, layerZeroModule)
    }
  }

  receive() external payable {}

  fallback() external payable {
    assembly {
      let layerZeroModule := sload(_layerZeroModuleV2Slot)
      calldatacopy(0, 0, calldatasize())
      let result := delegatecall(gas(), layerZeroModule, 0, calldatasize(), 0, 0)
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
