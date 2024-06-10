// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "../abstract/Admin.sol";
import "../abstract/Initializable.sol";

import "../enum/ChainIdType.sol";

import "../interface/CrossChainMessageInterface.sol";
import "../interface/HolographOperatorInterface.sol";
import "../interface/InitializableInterface.sol";
import "../interface/HolographInterfacesInterface.sol";
import "../interface/LayerZeroModuleInterface.sol";
import "../interface/LayerZeroOverrides.sol";
import "../interface/ILayerZeroPriceFeed.sol";
import "../interface/IWorker.sol";

import "../struct/GasParameters.sol";

import "./OVM_GasPriceOracle.sol";

/**
 * @title Holograph LayerZero Module
 * @author https://github.com/holographxyz
 * @notice Holograph module for enabling LayerZero cross-chain messaging
 * @dev This contract abstracts all of the LayerZero specific logic into an isolated module
 */
contract LayerZeroModuleV2 is Admin, Initializable, CrossChainMessageInterface, LayerZeroModuleInterface {
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.bridge')) - 1)
   */
  bytes32 constant _bridgeSlot = 0xeb87cbb21687feb327e3d58c6c16d552231d12c7a0e8115042a4165fac8a77f9;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.interfaces')) - 1)
   */
  bytes32 constant _interfacesSlot = 0xbd3084b8c09da87ad159c247a60e209784196be2530cecbbd8f337fdd1848827;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.lZEndpoint')) - 1)
   */
  bytes32 constant _lZEndpointSlot = 0x56825e447adf54cdde5f04815fcf9b1dd26ef9d5c053625147c18b7c13091686;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.lzExecutor')) - 1)
   */
  bytes32 constant _lzExecutorSlot = 0x5418c0677489e4391269fdb0d577e7ea7ccb07075c2c66748ef879ea504777e0;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.operator')) - 1)
   */
  bytes32 constant _operatorSlot = 0x7caba557ad34138fa3b7e43fb574e0e6cc10481c3073e0dffbc560db81b5c60f;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.gasParameters')) - 1)
   */
  bytes32 constant _gasParametersSlot = 0x15eee82a0af3c04e4b65c3842105c973a6b0fb2a68728bf035809e13b38ce8cf;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.gasParameters')) - 1)
   */
  bytes32 constant _optimismGasPriceOracleSlot = 0x46043c284a96474ab4a54c741ea0d0fce54e98eea878b99d4b85808fa6f71a5f;

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
    require(!_isInitialized(), "HOLOGRAPH: already initialized");
    (
      address bridge,
      address interfaces,
      address operator,
      address optimismGasPriceOracle,
      uint32[] memory chainIds,
      GasParameters[] memory gasParameters
    ) = abi.decode(initPayload, (address, address, address, address, uint32[], GasParameters[]));
    assembly {
      sstore(_adminSlot, origin())
      sstore(_bridgeSlot, bridge)
      sstore(_interfacesSlot, interfaces)
      sstore(_operatorSlot, operator)
      sstore(_optimismGasPriceOracleSlot, optimismGasPriceOracle)
    }
    require(chainIds.length == gasParameters.length, "HOLOGRAPH: wrong array lengths");
    for (uint256 i = 0; i < chainIds.length; i++) {
      _setGasParameters(chainIds[i], gasParameters[i]);
    }
    _setInitialized();
    return InitializableInterface.init.selector;
  }

  /**
   * @notice Receive cross-chain message from LayerZero
   * @dev This function only allows calls from the configured LayerZero endpoint address
   */
  function lzReceive(
    uint16 /* _srcChainId*/,
    bytes calldata _srcAddress,
    uint64 /* _nonce*/,
    bytes calldata _payload
  ) external payable {
    assembly {
      /**
       * @dev check if msg.sender is LayerZero Endpoint
       */
      switch eq(sload(_lZEndpointSlot), caller())
      case 0 {
        /**
         * @dev this is the assembly version of -> revert("HOLOGRAPH: LZ only endpoint");
         */
        mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0xa0, 0x0000002000000000000000000000000000000000000000000000000000000000)
        mstore(0xc0, 0x0000001b484f4c4f47524150483a204c5a206f6e6c7920656e64706f696e7400)
        mstore(0xe0, 0x0000000000000000000000000000000000000000000000000000000000000000)
        revert(0x80, 0xc4)
      }
      let ptr := mload(0x40)
      calldatacopy(add(ptr, 0x0c), _srcAddress.offset, _srcAddress.length)
      /**
       * @dev check if LZ from address is same as address(this)
       */
      switch eq(mload(ptr), address())
      case 0 {
        /**
         * @dev this is the assembly version of -> revert("HOLOGRAPH: unauthorized sender");
         */
        mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0xa0, 0x0000002000000000000000000000000000000000000000000000000000000000)
        mstore(0xc0, 0x0000001e484f4c4f47524150483a20756e617574686f72697a65642073656e64)
        mstore(0xe0, 0x6572000000000000000000000000000000000000000000000000000000000000)
        revert(0x80, 0xc4)
      }
    }
    /**
     * @dev if validation has passed, submit payload to Holograph Operator for converting into an operator job
     */
    _operator().crossChainMessage(_payload);
  }

  /**
   * @dev Need to add an extra function to get LZ gas amount needed for their internal cross-chain message verification
   */
  function send(
    uint256 /* gasLimit*/,
    uint256 /* gasPrice*/,
    uint32 toChain,
    address msgSender,
    uint256 msgValue,
    bytes calldata crossChainPayload
  ) external payable {
    require(msg.sender == address(_operator()), "HOLOGRAPH: operator only call");
    LayerZeroOverrides lZEndpoint;
    assembly {
      lZEndpoint := sload(_lZEndpointSlot)
    }
    GasParameters memory gasParameters = _gasParameters(toChain);
    // need to recalculate the gas amounts for LZ to deliver message
    lZEndpoint.send{value: msgValue}(
      uint16(_interfaces().getChainId(ChainIdType.HOLOGRAPH, uint256(toChain), ChainIdType.LAYERZERO)),
      abi.encodePacked(address(this), address(this)),
      crossChainPayload,
      payable(msgSender),
      address(this),
      abi.encodePacked(
        uint16(1),
        uint256(gasParameters.msgBaseGas + (crossChainPayload.length * gasParameters.msgGasPerByte))
      )
    );
  }

  function _getPriceFeed(uint16 lzEidV1) internal view returns (ILayerZeroPriceFeed, ILayerZeroPriceFeed.Price memory) {
    IWorker lzExecutor;
    assembly {
      lzExecutor := sload(_lzExecutorSlot)
    }
    ILayerZeroPriceFeed lzPriceFeed = ILayerZeroPriceFeed(lzExecutor.priceFeed());
    return (lzPriceFeed, lzPriceFeed.getPrice(lzEidV1));
  }

  function getMessageFee(
    uint32 toChain,
    uint256 gasLimit,
    uint256 gasPrice,
    bytes calldata crossChainPayload
  ) external view returns (uint256 hlgFee, uint256 msgFee, uint256 dstGasPrice) {
    uint16 lzEidV2 = uint16(_interfaces().getChainId(ChainIdType.HOLOGRAPH, uint256(toChain), ChainIdType.LAYERZERO));
    uint16 lzEidV1 = lzEidV2 - 30000; // Convert LZ V2 eid to LZ V1 eid
    ILayerZeroPriceFeed.Price memory price = _getPrice(lzEidV1);

    if (gasPrice == 0) {
      gasPrice = price.gasPriceInUnit;
    }

    GasParameters memory gasParameters = _getGasParameters(toChain);
    require(gasPrice > gasParameters.minGasPrice, "HOLOGRAPH: gas price too low");

    uint256 totalGas = gasLimit + gasParameters.jobBaseGas + (crossChainPayload.length * gasParameters.jobGasPerByte);
    totalGas += totalGas / 10;
    require(totalGas < gasParameters.maxGasLimit, "HOLOGRAPH: gas limit over max");

    bytes memory options = _createOptions(gasParameters, crossChainPayload);
    (uint256 nativeFee, ) = _estimateFees(lzEidV2, crossChainPayload, options);
    hlgFee = ((gasPrice * totalGas) * price.priceRatio) / (10 ** 20);

    if (toChain == uint32(7) || toChain == uint32(4000000074)) {
      hlgFee += (_optimismGasPriceOracle().getL1Fee(crossChainPayload) * price.priceRatio) / (10 ** 20);
    }

    msgFee = nativeFee;
    dstGasPrice = (price.gasPriceInUnit * price.priceRatio) / (10 ** 20);
  }

  function _getLayerZeroOverrides() internal view returns (LayerZeroOverrides lz) {
    assembly {
      lz := sload(_lZEndpointSlot)
    }
  }

  function _getPrice(uint16 lzEidV1) internal view returns (ILayerZeroPriceFeed.Price memory price) {
    (, price) = _getPriceFeed(lzEidV1);
  }

  function _getGasParameters(uint32 toChain) internal view returns (GasParameters memory gasParameters) {
    return _gasParameters(toChain);
  }

  function _createOptions(
    GasParameters memory gasParameters,
    bytes calldata crossChainPayload
  ) internal pure returns (bytes memory options) {
    options = abi.encodePacked(
      uint16(1),
      uint256(gasParameters.msgBaseGas + (crossChainPayload.length * gasParameters.msgGasPerByte))
    );
  }

  function _estimateFees(
    uint16 lzEidV2,
    bytes calldata crossChainPayload,
    bytes memory options
  ) internal view returns (uint256 nativeFee, uint256 lzFee) {
    LayerZeroOverrides lz = _getLayerZeroOverrides();
    return lz.estimateFees(lzEidV2, address(this), crossChainPayload, false, options);
  }

  function getHlgFee(
    uint32 toChain,
    uint256 gasLimit,
    uint256 gasPrice,
    bytes calldata crossChainPayload
  ) external view returns (uint256 hlgFee) {
    uint16 lzEidV1 = uint16(_interfaces().getChainId(ChainIdType.HOLOGRAPH, uint256(toChain), ChainIdType.LAYERZERO));

    (, ILayerZeroPriceFeed.Price memory price) = _getPriceFeed(lzEidV1); // Use the LZ V1 eid for the price feed

    if (gasPrice == 0) {
      gasPrice = price.gasPriceInUnit;
    }

    GasParameters memory gasParameters = _gasParameters(toChain);
    require(gasPrice > gasParameters.minGasPrice, "HOLOGRAPH: gas price too low");

    uint256 totalGas = gasLimit + gasParameters.jobBaseGas + (crossChainPayload.length * gasParameters.jobGasPerByte);
    totalGas += totalGas / 10; // Add 10% buffer
    require(totalGas < gasParameters.maxGasLimit, "HOLOGRAPH: gas limit over max");

    hlgFee = ((gasPrice * totalGas) * price.priceRatio) / (10 ** 20);

    // Special handling for Optimism chains
    if (toChain == uint32(7) || toChain == uint32(4000000074)) {
      hlgFee += (_optimismGasPriceOracle().getL1Fee(crossChainPayload) * price.priceRatio) / (10 ** 20);
    }
  }

  /**
   * @notice Get the address of the Holograph Bridge module
   * @dev Used for beaming holographable assets cross-chain
   */
  function getBridge() external view returns (address bridge) {
    assembly {
      bridge := sload(_bridgeSlot)
    }
  }

  /**
   * @notice Update the Holograph Bridge module address
   * @param bridge address of the Holograph Bridge smart contract to use
   */
  function setBridge(address bridge) external onlyAdmin {
    assembly {
      sstore(_bridgeSlot, bridge)
    }
  }

  /**
   * @notice Get the address of the Holograph Interfaces module
   * @dev Holograph uses this contract to store data that needs to be accessed by a large portion of the modules
   */
  function getInterfaces() external view returns (address interfaces) {
    assembly {
      interfaces := sload(_interfacesSlot)
    }
  }

  /**
   * @notice Update the Holograph Interfaces module address
   * @param interfaces address of the Holograph Interfaces smart contract to use
   */
  function setInterfaces(address interfaces) external onlyAdmin {
    assembly {
      sstore(_interfacesSlot, interfaces)
    }
  }

  /**
   * @notice Get the address of the approved LayerZero Endpoint
   * @dev All lzReceive function calls allow only requests from this address
   */
  function getLZEndpoint() external view returns (address lZEndpoint) {
    assembly {
      lZEndpoint := sload(_lZEndpointSlot)
    }
  }

  /**
   * @notice Update the approved LayerZero Endpoint address
   * @param lZEndpoint address of the LayerZero Endpoint to use
   */
  function setLZEndpoint(address lZEndpoint) external onlyAdmin {
    assembly {
      sstore(_lZEndpointSlot, lZEndpoint)
    }
  }

  /**
   * @notice Get the address of the approved LayerZero Executor
   */
  function getLZExecutor() external view returns (address lzExecutor) {
    assembly {
      lzExecutor := sload(_lzExecutorSlot)
    }
  }

  /**
   * @notice Update the approved LayerZero Executor address
   * @param lzExecutor address of the LayerZero Executor to use
   */
  function setLZExecutor(address lzExecutor) external onlyAdmin {
    assembly {
      sstore(_lzExecutorSlot, lzExecutor)
    }
  }

  /**
   * @notice Get the address of the Holograph Operator module
   * @dev All cross-chain Holograph Bridge beams are handled by the Holograph Operator module
   */
  function getOperator() external view returns (address operator) {
    assembly {
      operator := sload(_operatorSlot)
    }
  }

  /**
   * @notice Update the Holograph Operator module address
   * @param operator address of the Holograph Operator smart contract to use
   */
  function setOperator(address operator) external onlyAdmin {
    assembly {
      sstore(_operatorSlot, operator)
    }
  }

  /**
   * @notice Get the address of the Optimism Gas Price Oracle module
   * @dev Allows to properly calculate the L1 security fee for Optimism bridge transactions
   */
  function getOptimismGasPriceOracle() external view returns (address optimismGasPriceOracle) {
    assembly {
      optimismGasPriceOracle := sload(_optimismGasPriceOracleSlot)
    }
  }

  /**
   * @notice Update the Optimism Gas Price Oracle module address
   * @param optimismGasPriceOracle address of the Optimism Gas Price Oracle smart contract to use
   */
  function setOptimismGasPriceOracle(address optimismGasPriceOracle) external onlyAdmin {
    assembly {
      sstore(_optimismGasPriceOracleSlot, optimismGasPriceOracle)
    }
  }

  /**
   * @dev Internal function used for getting the Holograph Bridge Interface
   */
  function _bridge() private view returns (address bridge) {
    assembly {
      bridge := sload(_bridgeSlot)
    }
  }

  /**
   * @dev Internal function used for getting the Holograph Interfaces Interface
   */
  function _interfaces() private view returns (HolographInterfacesInterface interfaces) {
    assembly {
      interfaces := sload(_interfacesSlot)
    }
  }

  /**
   * @dev Internal function used for getting the Holograph Operator Interface
   */
  function _operator() private view returns (HolographOperatorInterface operator) {
    assembly {
      operator := sload(_operatorSlot)
    }
  }

  /**
   * @dev Internal function used for getting the Optimism Gas Price Oracle Interface
   */
  function _optimismGasPriceOracle() private view returns (OVM_GasPriceOracle optimismGasPriceOracle) {
    assembly {
      optimismGasPriceOracle := sload(_optimismGasPriceOracleSlot)
    }
  }

  /**
   * @dev Purposefully reverts to prevent having any type of ether transfered into the contract
   */
  receive() external payable {
    revert();
  }

  /**
   * @dev Purposefully reverts to prevent any calls to undefined functions
   */
  fallback() external payable {
    revert();
  }

  /**
   * @notice Get the default or chain-specific GasParameters
   * @param chainId the Holograph ChainId to get gas parameters for, set to 0 for default
   */
  function getGasParameters(uint32 chainId) external view returns (GasParameters memory gasParameters) {
    return _gasParameters(chainId);
  }

  /**
   * @notice Update the default or chain-specific GasParameters
   * @param chainId the Holograph ChainId to set gas parameters for, set to 0 for default
   * @param gasParameters struct of all the gas parameters to set
   */
  function setGasParameters(uint32 chainId, GasParameters memory gasParameters) external onlyAdmin {
    _setGasParameters(chainId, gasParameters);
  }

  /**
   * @notice Update the default or chain-specific GasParameters
   * @param chainIds array of Holograph ChainId to set gas parameters for
   * @param gasParameters array of all the gas parameters to set
   */
  function setGasParameters(uint32[] memory chainIds, GasParameters[] memory gasParameters) external onlyAdmin {
    require(chainIds.length == gasParameters.length, "HOLOGRAPH: wrong array lengths");
    for (uint256 i = 0; i < chainIds.length; i++) {
      _setGasParameters(chainIds[i], gasParameters[i]);
    }
  }

  /**
   * @notice Internal function for setting the default or chain-specific GasParameters
   * @param chainId the Holograph ChainId to set gas parameters for, set to 0 for default
   * @param gasParameters struct of all the gas parameters to set
   */
  function _setGasParameters(uint32 chainId, GasParameters memory gasParameters) private {
    bytes32 slot = chainId == 0 ? _gasParametersSlot : keccak256(abi.encode(chainId, _gasParametersSlot));
    assembly {
      let pos := gasParameters
      for {
        let i := 0
      } lt(i, 6) {
        i := add(i, 1)
      } {
        sstore(add(slot, i), mload(pos))
        pos := add(pos, 32)
      }
    }
  }

  /**
   * @dev Internal function used for getting the default or chain-specific GasParameters
   * @param chainId the Holograph ChainId to get gas parameters for, set to 0 for default
   */
  function _gasParameters(uint32 chainId) private view returns (GasParameters memory gasParameters) {
    bytes32 slot = chainId == 0 ? _gasParametersSlot : keccak256(abi.encode(chainId, _gasParametersSlot));
    assembly {
      let pos := gasParameters
      for {
        let i := 0
      } lt(i, 6) {
        i := add(i, 1)
      } {
        mstore(pos, sload(add(slot, i)))
        pos := add(pos, 32)
      }
    }
  }

  /**
   * @dev function to set the LayerZero send MessageLib
   * @param _version the version of the messaging library
   */
  function setSendVersion(uint16 _version) external /* onlyOwner */ {
    LayerZeroOverrides lzEndpoint;
    assembly {
      lzEndpoint := sload(_lZEndpointSlot)
    }
    lzEndpoint.setSendVersion(_version);
  }

  /**
   * @dev function to set the LayerZero receive MessageLib
   * @param _version the version of the messaging library
   */
  function setReceiveVersion(uint16 _version) external /* onlyOwner */ {
    LayerZeroOverrides lzEndpoint;
    assembly {
      lzEndpoint := sload(_lZEndpointSlot)
    }
    lzEndpoint.setReceiveVersion(_version);
  }
}
