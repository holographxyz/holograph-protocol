/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

import "../abstract/GenericH.sol";

import "../interface/HolographGenericInterface.sol";

/**
 * @title Sample ERC-20 token that is bridgeable via Holograph
 * @author Holograph Foundation
 * @notice A smart contract for minting and managing Holograph Bridgeable ERC20 Tokens.
 * @dev The entire logic and functionality of the smart contract is self-contained.
 */
contract MultichainTokenFaucet is GenericH {
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.messagingModule')) - 1)
   */
  bytes32 constant _messagingModuleSlot = precomputeslot("eip1967.Holograph.messagingModule");
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.lZEndpoint')) - 1)
   */
  bytes32 constant _lZEndpointSlot = precomputeslot("eip1967.Holograph.lZEndpoint");
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.jobNonce')) - 1)
   */
  bytes32 constant _jobNonceSlot = precomputeslot("eip1967.Holograph.jobNonce");

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
    // do your own custom logic here
    address contractOwner = abi.decode(initPayload, (address));
    _setOwner(contractOwner);
    // run underlying initializer logic
    return _init(initPayload);
  }

  function bridgeIn(
    uint32 /* _chainId*/,
    address _to,
    uint256 _amount,
    bytes calldata /* _data*/
  ) external override onlyHolographer returns (bool) {
    // move all native token balance from holographer into source
    HolographGenericInterface(_holographer()).sourceWithdraw(address(this));
    // send amount to address
    payable(_to).transfer(_amount);
    return true;
  }

  function bridgeOut(
    uint32 /* _chainId*/,
    address /* _to*/,
    uint256 /* _amount*/
  ) external override onlyHolographer returns (bytes memory _data) {
    uint256 jobNonce = _jobNonce();
    _data = abi.encode(jobNonce, block.chainid);
  }

  function getCrossChainNativeTokens(
    uint256[] calldata chainIds,
    uint256[] calldata nativeTokenAmounts
  ) external payable {
    LayerZeroOverrides lZEndpoint;
    assembly {
      lZEndpoint := sload(_lZEndpointSlot)
    }
    uint256 jobNonce;
    for (uint256 i = 0; i < chainIds.length; i++) {
      jobNonce = _jobNonce();
      bytes memory encodedData = abi.encode(jobNonce, block.chainid);
      lZEndpoint.send{value: address(this).balance}(
        uint16(_chainIdMap[ChainIdType.EVM][chainIds[i]][ChainIdType.LAYERZERO]),
        abi.encodePacked(address(this), address(this)),
        encodedData,
        payable(address(this)),
        address(this),
        abi.encodePacked(
          uint16(2), // version uint16
          uint256(200_000), // gasAmount uint256
          uint256(nativeTokenAmounts[i]), // nativeForDst uint256
          tx.origin // addressOnDst address
        )
      );
      emit CrossChainMessageSent(keccak256(encodedData));
    }
  }

  function _tupleToDstPrice(
    LayerZeroOverrides relayer,
    uint16 lzDestChain
  ) internal view returns (LayerZeroOverrides.DstPrice memory) {
    (uint128 dstPriceRatio, uint128 dstGasPriceInWei) = relayer.dstPriceLookup(lzDestChain);
    return LayerZeroOverrides.DstPrice({dstPriceRatio: dstPriceRatio, dstGasPriceInWei: dstGasPriceInWei});
  }

  function _tupleToDstConfig(
    LayerZeroOverrides relayer,
    uint16 lzDestChain,
    uint16 outboundProofType
  ) internal view returns (LayerZeroOverrides.DstConfig memory) {
    (uint128 dstNativeAmtCap, uint64 baseGas, uint64 gasPerByte) = relayer.dstConfigLookup(
      lzDestChain,
      outboundProofType
    );
    return LayerZeroOverrides.DstConfig({dstNativeAmtCap: dstNativeAmtCap, baseGas: baseGas, gasPerByte: gasPerByte});
  }

  function getNativeTokenLimits(
    uint256[] calldata chainIds
  ) external view returns (uint256[] memory nativeTokenAmounts) {
    nativeTokenAmounts = new uint256[](chainIds.length);
    uint256 l = chainIds.length;
    LayerZeroOverrides lz;
    assembly {
      lz := sload(_lZEndpointSlot)
    }
    uint16 lzDestChain;
    LayerZeroOverrides relayer;
    LayerZeroOverrides.ApplicationConfiguration memory appConfig;
    LayerZeroOverrides.DstConfig memory dstConfig;
    for (uint256 i = 0; i < l; i++) {
      lzDestChain = uint16(_chainIdMap[ChainIdType.EVM][chainIds[i]][ChainIdType.LAYERZERO]);
      appConfig = LayerZeroOverrides(lz.defaultSendLibrary()).getAppConfig(lzDestChain, address(this));
      relayer = LayerZeroOverrides(appConfig.relayer);
      dstConfig = _tupleToDstConfig(relayer, lzDestChain, appConfig.outboundProofType);
      nativeTokenAmounts[i] = dstConfig.dstNativeAmtCap;
    }
  }

  function getNativeTokenPrices(
    uint256 nativeTokenInput,
    uint256[] calldata chainIds,
    uint256[] calldata bps
  ) external view returns (uint256[] memory nativeTokenAmounts, uint256[] memory nativeTokenPrices) {
    require(chainIds.length == bps.length, "HOLOGRAPH: array size missmatch");
    {
      uint256 bpTotal = 0;
      for (uint256 i = 0; i < chainIds.length; i++) {
        bpTotal += bps[i];
      }
      require(bpTotal < 10001, "HOLOGRAPH: bps total over 10000");
    }
    LayerZeroOverrides lz;
    assembly {
      lz := sload(_lZEndpointSlot)
    }
    ChainPricing memory data = ChainPricing({
      lzSrcChain: 0,
      lzDestChain: 0,
      l: 0,
      relayer: LayerZeroOverrides(address(0)),
      appConfig: LayerZeroOverrides.ApplicationConfiguration({
        inboundProofLibraryVersion: 0,
        inboundBlockConfirmations: 0,
        relayer: address(0),
        outboundProofType: 0,
        outboundBlockConfirmations: 0,
        oracle: address(0)
      }),
      dstConfig: LayerZeroOverrides.DstConfig({dstNativeAmtCap: 0, baseGas: 0, gasPerByte: 0}),
      localPrice: LayerZeroOverrides.DstPrice({dstPriceRatio: 0, dstGasPriceInWei: 0}),
      dstPrice: LayerZeroOverrides.DstPrice({dstPriceRatio: 0, dstGasPriceInWei: 0})
    });
    nativeTokenAmounts = new uint256[](chainIds.length);
    nativeTokenPrices = new uint256[](chainIds.length);
    data.lzSrcChain = uint16(_chainIdMap[ChainIdType.EVM][block.chainid][ChainIdType.LAYERZERO]);
    data.appConfig = LayerZeroOverrides(lz.defaultSendLibrary()).getAppConfig(data.lzSrcChain, address(this));
    data.relayer = LayerZeroOverrides(data.appConfig.relayer);
    data.localPrice = _tupleToDstPrice(data.relayer, data.lzSrcChain);
    for (uint256 i = 0; i < chainIds.length; i++) {
      data.lzDestChain = uint16(_chainIdMap[ChainIdType.EVM][chainIds[i]][ChainIdType.LAYERZERO]);
      data.appConfig = LayerZeroOverrides(lz.defaultSendLibrary()).getAppConfig(data.lzDestChain, address(this));
      data.relayer = LayerZeroOverrides(data.appConfig.relayer);
      data.dstConfig = _tupleToDstConfig(data.relayer, data.lzDestChain, data.appConfig.outboundProofType);
      data.dstPrice = _tupleToDstPrice(data.relayer, data.lzDestChain);
      uint256 inputAmount = (nativeTokenInput / 10000) * bps[i];
      nativeTokenAmounts[i] = (inputAmount * (10 ** 10)) / (data.dstPrice.dstPriceRatio);
      if (nativeTokenAmounts[i] > data.dstConfig.dstNativeAmtCap) {
        nativeTokenAmounts[i] = data.dstConfig.dstNativeAmtCap;
        nativeTokenPrices[i] = (nativeTokenAmounts[i] * data.dstPrice.dstPriceRatio) / (10 ** 10);
      } else {
        nativeTokenPrices[i] = inputAmount;
      }
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
   * @dev Internal nonce, that increments on each call, used for randomness
   */
  function _jobNonce() private returns (uint256 jobNonce) {
    assembly {
      jobNonce := add(sload(_jobNonceSlot), 0x0000000000000000000000000000000000000000000000000000000000000001)
      sstore(_jobNonceSlot, jobNonce)
    }
  }

}
