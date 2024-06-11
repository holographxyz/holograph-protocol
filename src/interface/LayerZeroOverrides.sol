// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

struct MessagingParams {
  uint32 dstEid;
  bytes32 receiver;
  bytes message;
  bytes options;
  bool payInLzToken;
}

interface LayerZeroOverrides {
  // @dev defaultAppConfig struct
  struct ApplicationConfiguration {
    uint16 inboundProofLibraryVersion;
    uint64 inboundBlockConfirmations;
    address relayer;
    uint16 outboundProofType;
    uint64 outboundBlockConfirmations;
    address oracle;
  }

  struct DstPrice {
    uint128 dstPriceRatio; // 10^10
    uint128 dstGasPriceInWei;
  }

  struct DstConfig {
    uint128 dstNativeAmtCap;
    uint64 baseGas;
    uint64 gasPerByte;
  }

  // @dev using this to retrieve UltraLightNodeV2 address
  function defaultSendLibrary() external view returns (address);

  // @dev using this to extract defaultAppConfig
  function getAppConfig(
    uint16 destinationChainId,
    address userApplicationAddress
  ) external view returns (ApplicationConfiguration memory);

  // @dev using this to extract defaultAppConfig directly from storage slot
  function defaultAppConfig(
    uint16 destinationChainId
  )
    external
    view
    returns (
      uint16 inboundProofLibraryVersion,
      uint64 inboundBlockConfirmations,
      address relayer,
      uint16 outboundProofType,
      uint64 outboundBlockConfirmations,
      address oracle
    );

  // @dev access the mapping to get base price fee
  function dstPriceLookup(
    uint16 destinationChainId
  ) external view returns (uint128 dstPriceRatio, uint128 dstGasPriceInWei);

  // @dev access the mapping to get base gas and gas per byte
  function dstConfigLookup(
    uint16 destinationChainId,
    uint16 outboundProofType
  ) external view returns (uint128 dstNativeAmtCap, uint64 baseGas, uint64 gasPerByte);

  // NOTE: This is the V1 version of the send function
  // @dev send message to LayerZero Endpoint
  function send(
    uint16 _dstChainId,
    bytes calldata _destination,
    bytes calldata _payload,
    address payable _refundAddress,
    address _zroPaymentAddress,
    bytes calldata _adapterParams
  ) external payable;

  // @dev send message to LayerZero Endpoint
  function send(MessagingParams calldata _params, address _refundAddress) external payable;

  // NOTE: This is the V1 version of the estimateFees function
  // @dev estimate LayerZero message cost
  // function estimateFees(
  //   uint16 _dstChainId,
  //   address _userApplication,
  //   bytes calldata _payload,
  //   bool _payInZRO,
  //   bytes calldata _adapterParam
  // ) external view returns (uint256 nativeFee, uint256 zroFee);

  function estimateFees(
    uint16 _dstEid,
    address _sender,
    bytes calldata _message,
    bool _payInLzToken,
    bytes calldata _options
  ) external view returns (uint256 nativeFee, uint256 lzTokenFee);

  // @notice set the configuration of the LayerZero messaging library of the specified version
  // @param _version - messaging library version
  // @param _chainId - the chainId for the pending config change
  // @param _configType - type of configuration. every messaging library has its own convention.
  // @param _config - configuration in the bytes. can encode arbitrary content.
  function setConfig(uint16 _version, uint16 _chainId, uint _configType, bytes calldata _config) external;

  // @notice set the send() LayerZero messaging library version to _version
  // @param _version - new messaging library version
  function setSendVersion(uint16 _version) external;

  // @notice set the lzReceive() LayerZero messaging library version to _version
  // @param _version - new messaging library version
  function setReceiveVersion(uint16 _version) external;

  // @notice Only when the UA needs to resume the message flow in blocking mode and clear the stored payload
  // @param _srcChainId - the chainId of the source chain
  // @param _srcAddress - the contract address of the source contract at the source chain
  function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external;
}
