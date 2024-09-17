// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../abstract/Admin.sol";
import "../abstract/Initializable.sol";
import "../abstract/layerzero/OApp.sol";
import "../abstract/layerzero/OptionsBuilder.sol";

import "../enum/ChainIdType.sol";

import "../interface/HolographOperatorInterface.sol";
import "../interface/InitializableInterface.sol";
import "../interface/HolographInterfacesInterface.sol";
import "../interface/LayerZeroOverrides.sol";
import "../interface/ILayerZeroPriceFeed.sol";
import "../interface/IWorker.sol";
import "../interface/ILayerZeroEndpointV2.sol";

import "../struct/GasParameters.sol";

import "./OVM_GasPriceOracle.sol";

/**
 * @title Holograph LayerZero Module
 * @author https://github.com/holographxyz
 * @notice Holograph module for enabling LayerZero cross-chain messaging
 * @dev This contract abstracts all of the LayerZero specific logic into an isolated module
 */
contract LayerZeroModuleV2 is OApp, Admin, Initializable {
  using OptionsBuilder for bytes;

  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.bridge')) - 1)
   */
  bytes32 constant _bridgeSlot = 0xeb87cbb21687feb327e3d58c6c16d552231d12c7a0e8115042a4165fac8a77f9;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.interfaces')) - 1)
   */
  bytes32 constant _interfacesSlot = 0xbd3084b8c09da87ad159c247a60e209784196be2530cecbbd8f337fdd1848827;
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
   * @dev mapping of trusted remote chains to their respective LayerZero Endpoint addresses
   */
  mapping(uint16 => bytes) public trustedRemoteLookup;

  /**
   * @dev Constructor is left empty and init is used instead
   */
  constructor() OApp(address(0), address(0xdead)) {}

  /* -------------------------------------------------------------------------- */
  /*                             External functions                             */
  /* -------------------------------------------------------------------------- */

  /* -------------------- State changing External functions ------------------- */

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
      address lzEndpoint,
      address lzExecutor,
      address delegate,
      uint32[] memory chainIds,
      GasParameters[] memory gasParameters,
      EndpointPeer[] memory peers
    ) = abi.decode(
        initPayload,
        (address, address, address, address, address, address, address, uint32[], GasParameters[], EndpointPeer[])
      );

    require(chainIds.length == gasParameters.length, "HOLOGRAPH: wrong array lengths");
    require(lzEndpoint != address(0), "HOLOGRAPH: invalid endpoint");

    // Set the initial values for the contract
    assembly {
      sstore(_adminSlot, origin())
      sstore(_bridgeSlot, bridge)
      sstore(_interfacesSlot, interfaces)
      sstore(_operatorSlot, operator)
      sstore(_optimismGasPriceOracleSlot, optimismGasPriceOracle)
      sstore(_enpointSlot, lzEndpoint)
      sstore(_lzExecutorSlot, lzExecutor)
    }

    _setDelegate(delegate);

    // Set the gas parameters for the default chain and any additional chains
    for (uint256 i = 0; i < chainIds.length; i++) {
      _setGasParameters(chainIds[i], gasParameters[i]);
    }

    // Set the trusted peers
    for (uint256 i = 0; i < peers.length; i++) {
      _setPeer(peers[i].eid, bytes32(uint256(uint160(peers[i].peer))));
    }

    _setInitialized();
    return InitializableInterface.init.selector;
  }

  /**
   * @notice Send a cross-chain message using LayerZero
   * @dev This function is only callable by the Holograph Operator
   * @param gasLimit the gas limit to use for the cross-chain message
   * @param /gasPrice The gas price to use for the cross-chain message
   * @param toChain the chain ID to send the message to
   * @param msgSender the address of the sender of the message
   * @param msgValue the value to send with the message
   * @param crossChainPayload the payload to send to the destination chain
   */
  function send(
    uint256 gasLimit,
    uint256 /* gasPrice */,
    uint32 toChain,
    address msgSender,
    uint256 msgValue,
    bytes calldata crossChainPayload
  ) external payable {
    require(msg.sender == address(_operator()), "HOLOGRAPH: operator only call");

    /// @dev Build a message execution option for the LZ receive function
    /// @dev first uint128 is the gasLimit used on the lzReceive() function in the OApp.
    /// @dev second uint128 is the msg.value passed to the lzReceive() function in the OApp.
    bytes memory msgExecutionOption = OptionsBuilder.newOptions().addExecutorLzReceiveOption(uint128(gasLimit), 0);

    _lzSend(
      uint16(_interfaces().getChainId(ChainIdType.HOLOGRAPH, uint256(toChain), ChainIdType.LAYERZEROV2)),
      crossChainPayload,
      msgExecutionOption,
      // Fee in native gas and ZRO token.
      MessagingFee(msgValue, 0),
      // Refund address in case of failed source message.
      payable(msgSender)
    );
  }

  /* ------------------------- External view functions ------------------------ */

  /**
   * @notice Get the message fee for sending a cross-chain message
   * @param toChain The destination chain ID
   * @param gasLimit The gas limit to use for the cross-chain message
   * @param gasPrice The gas price to use for the cross-chain message
   * @param crossChainPayload The payload to send to the destination chain
   * @return hlgFee The Holograph fee
   * @return msgFee The native fee
   * @return dstGasPrice The destination chain gas price
   */
  function getMessageFee(
    uint32 toChain,
    uint256 gasLimit,
    uint256 gasPrice,
    bytes calldata crossChainPayload
  ) external view returns (uint256 hlgFee, uint256 msgFee, uint256 dstGasPrice) {
    uint16 lzEidV1 = uint16(_interfaces().getChainId(ChainIdType.HOLOGRAPH, uint256(toChain), ChainIdType.LAYERZEROV2));
    uint16 lzEidV2 = lzEidV1 + 30000; // Convert LZ V2 eid to LZ V1 eid
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
    MessagingFee memory msgFees = _quote(lzEidV2, crossChainPayload, options, false);
    hlgFee = ((gasPrice * totalGas) * price.priceRatio) / (10 ** 20);

    if (toChain == uint32(7) || toChain == uint32(4000000074)) {
      hlgFee += (_optimismGasPriceOracle().getL1Fee(crossChainPayload) * price.priceRatio) / (10 ** 20);
    }

    msgFee = msgFees.nativeFee;
    dstGasPrice = (price.gasPriceInUnit * price.priceRatio) / (10 ** 20);
  }

  /**
   * @notice Get the default or chain-specific GasParameters
   * @param chainId the Holograph ChainId to get gas parameters for, set to 0 for default
   */
  function getGasParameters(uint32 chainId) external view returns (GasParameters memory gasParameters) {
    return _gasParameters(chainId);
  }

  /* --------------------------------- Getters -------------------------------- */

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
   * @notice Get the address of the Holograph Interfaces module
   * @dev Holograph uses this contract to store data that needs to be accessed by a large portion of the modules
   */
  function getInterfaces() external view returns (address interfaces) {
    assembly {
      interfaces := sload(_interfacesSlot)
    }
  }

  /**
   * @notice Get the address of the approved LayerZero Endpoint
   * @dev All lzReceive function calls allow only requests from this address
   */
  function getLZEndpoint() external view returns (address lZEndpoint) {
    assembly {
      lZEndpoint := sload(_enpointSlot)
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
   * @notice Get the address of the Holograph Operator module
   * @dev All cross-chain Holograph Bridge beams are handled by the Holograph Operator module
   */
  function getOperator() external view returns (address operator) {
    assembly {
      operator := sload(_operatorSlot)
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

  /* -------------------------------------------------------------------------- */
  /*                             Internal functions                             */
  /* -------------------------------------------------------------------------- */

  /* ------------------------- Internal view function ------------------------- */

  /**
   * @notice Get the price feed for a specific LayerZero endpoint
   * @param lzEidV1 the LayerZero endpoint ID to get the price feed for
   * @return lzPriceFeed the LayerZero Price Feed contract
   * @return price the price feed for the specified endpoint
   */
  function _getPriceFeed(uint16 lzEidV1) internal view returns (ILayerZeroPriceFeed, ILayerZeroPriceFeed.Price memory) {
    IWorker lzExecutor;
    assembly {
      lzExecutor := sload(_lzExecutorSlot)
    }
    ILayerZeroPriceFeed lzPriceFeed = ILayerZeroPriceFeed(lzExecutor.priceFeed());
    return (lzPriceFeed, lzPriceFeed.getPrice(lzEidV1));
  }

  /**
   * @notice Get the LayerZero overrides for the current contract
   */
  function _getLayerZeroOverrides() internal view returns (LayerZeroOverrides lz) {
    assembly {
      lz := sload(_enpointSlot)
    }
  }

  /**
   * @notice Get the price feed for a specific LayerZero endpoint
   * @param lzEidV1 the LayerZero endpoint ID to get the price feed for
   */
  function _getPrice(uint16 lzEidV1) internal view returns (ILayerZeroPriceFeed.Price memory price) {
    (, price) = _getPriceFeed(lzEidV1);
  }

  /**
   * @notice Get the gas parameters for a specific chain
   * @param toChain the destination chain ID to get the gas parameters for
   */
  function _getGasParameters(uint32 toChain) internal view returns (GasParameters memory gasParameters) {
    return _gasParameters(toChain);
  }

  /**
   * @notice Get the Holograph fee for sending a cross-chain message
   * @param toChain The destination chain ID
   * @param gasLimit The gas limit to use for the cross-chain message
   * @param gasPrice The gas price to use for the cross-chain message
   * @param crossChainPayload The payload to send to the destination chain
   */
  function getHlgFee(
    uint32 toChain,
    uint256 gasLimit,
    uint256 gasPrice,
    bytes calldata crossChainPayload
  ) external view returns (uint256 hlgFee) {
    uint16 lzEidV1 = uint16(_interfaces().getChainId(ChainIdType.HOLOGRAPH, uint256(toChain), ChainIdType.LAYERZEROV2));

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

  /* ------------------------- Internal pure functions ------------------------ */

  /**
   * @notice Create the options for the cross-chain message
   * @param gasParameters the gas parameters to use for the cross-chain message
   * @param crossChainPayload the payload to send to the destination chain
   */
  function _createOptions(
    GasParameters memory gasParameters,
    bytes calldata crossChainPayload
  ) internal pure returns (bytes memory options) {
    options = abi.encodePacked(
      uint16(1),
      uint256(gasParameters.msgBaseGas + (crossChainPayload.length * gasParameters.msgGasPerByte))
    );
  }

  /* --------------------------- Internal overrides --------------------------- */

  /**
   * @notice Receive cross-chain message from LayerZero
   * @dev This function only allows calls from the configured LayerZero endpoint address
   */
  function _lzReceive(Origin calldata, bytes32, bytes calldata _payload, address, bytes calldata) internal override {
    /**
     * @dev if validation has passed, submit payload to Holograph Operator for converting into an operator job
     */
    _operator().crossChainMessage(_payload);
  }

  /* -------------------------------------------------------------------------- */
  /*                              Private functions                             */
  /* -------------------------------------------------------------------------- */

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

  /* ------------------------- Private view functions ------------------------- */

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

  /* -------------------------------------------------------------------------- */
  /*                            Only admin functions                            */
  /* -------------------------------------------------------------------------- */

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
   * @notice Update the Holograph Interfaces module address
   * @param interfaces address of the Holograph Interfaces smart contract to use
   */
  function setInterfaces(address interfaces) external onlyAdmin {
    assembly {
      sstore(_interfacesSlot, interfaces)
    }
  }

  /**
   * @notice Update the approved LayerZero Endpoint address
   * @param lZEndpoint address of the LayerZero Endpoint to use
   */
  function setLZEndpoint(address lZEndpoint) external onlyAdmin {
    assembly {
      sstore(_enpointSlot, lZEndpoint)
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
   * @notice Update the Holograph Operator module address
   * @param operator address of the Holograph Operator smart contract to use
   */
  function setOperator(address operator) external onlyAdmin {
    assembly {
      sstore(_operatorSlot, operator)
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
   * @notice Sets the peer address (OApp instance) for a corresponding endpoint.
   * @param _eid The endpoint ID.
   * @param _peer The address of the peer to be associated with the corresponding endpoint.
   */
  function setPeer(uint32 _eid, bytes32 _peer) external onlyAdmin {
    _setPeer(_eid, _peer);
  }

  /**
   * @notice Sets the delegate address for the OApp Core.
   * @param _delegate The address of the delegate to be set.
   */
  function setDelegate(address _delegate) external onlyAdmin {
    _setDelegate(_delegate);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Fallbacks functions                            */
  /* -------------------------------------------------------------------------- */

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
}
