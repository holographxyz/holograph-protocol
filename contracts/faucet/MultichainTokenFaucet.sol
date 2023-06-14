//// SPDX-License-Identifier: UNLICENSED
/*

                         ┌───────────┐
                         │ HOLOGRAPH │
                         └───────────┘
╔═════════════════════════════════════════════════════════════╗
║                                                             ║
║                            / ^ \                            ║
║                            ~~*~~            ¸               ║
║                         [ '<>:<>' ]         │░░░            ║
║               ╔╗           _/"\_           ╔╣               ║
║             ┌─╬╬─┐          """          ┌─╬╬─┐             ║
║          ┌─┬┘ ╠╣ └┬─┐       \_/       ┌─┬┘ ╠╣ └┬─┐          ║
║       ┌─┬┘ │  ╠╣  │ └┬─┐           ┌─┬┘ │  ╠╣  │ └┬─┐       ║
║    ┌─┬┘ │  │  ╠╣  │  │ └┬─┐     ┌─┬┘ │  │  ╠╣  │  │ └┬─┐    ║
║ ┌─┬┘ │  │  │  ╠╣  │  │  │ └┬┐ ┌┬┘ │  │  │  ╠╣  │  │  │ └┬─┐ ║
╠┬┘ │  │  │  │  ╠╣  │  │  │  │└¤┘│  │  │  │  ╠╣  │  │  │  │ └┬╣
║│  │  │  │  │  ╠╣  │  │  │  │   │  │  │  │  ╠╣  │  │  │  │  │║
╠╩══╩══╩══╩══╩══╬╬══╩══╩══╩══╩═══╩══╩══╩══╩══╬╬══╩══╩══╩══╩══╩╣
╠┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╬╬┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╬╬┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╣
║               ╠╣                           ╠╣               ║
║               ╠╣                           ╠╣               ║
║    ,          ╠╣     ,        ,'      *    ╠╣               ║
║~~~~~^~~~~~~~~┌╬╬┐~~~^~~~~~~~~^^~~~~~~~~^~~┌╬╬┐~~~~~~~^~~~~~~║
╚══════════════╩╩╩╩═════════════════════════╩╩╩╩══════════════╝
     - one protocol, one bridge = infinite possibilities -


 ***************************************************************

 DISCLAIMER: U.S Patent Pending

 LICENSE: Holograph Limited Public License (H-LPL)

 https://holograph.xyz/licenses/h-lpl/1.0.0

 This license governs use of the accompanying software. If you
 use the software, you accept this license. If you do not accept
 the license, you are not permitted to use the software.

 1. Definitions

 The terms "reproduce," "reproduction," "derivative works," and
 "distribution" have the same meaning here as under U.S.
 copyright law. A "contribution" is the original software, or
 any additions or changes to the software. A "contributor" is
 any person that distributes its contribution under this
 license. "Licensed patents" are a contributor’s patent claims
 that read directly on its contribution.

 2. Grant of Rights

 A) Copyright Grant- Subject to the terms of this license,
 including the license conditions and limitations in sections 3
 and 4, each contributor grants you a non-exclusive, worldwide,
 royalty-free copyright license to reproduce its contribution,
 prepare derivative works of its contribution, and distribute
 its contribution or any derivative works that you create.
 B) Patent Grant- Subject to the terms of this license,
 including the license conditions and limitations in section 3,
 each contributor grants you a non-exclusive, worldwide,
 royalty-free license under its licensed patents to make, have
 made, use, sell, offer for sale, import, and/or otherwise
 dispose of its contribution in the software or derivative works
 of the contribution in the software.

 3. Conditions and Limitations

 A) No Trademark License- This license does not grant you rights
 to use any contributors’ name, logo, or trademarks.
 B) If you bring a patent claim against any contributor over
 patents that you claim are infringed by the software, your
 patent license from such contributor is terminated with
 immediate effect.
 C) If you distribute any portion of the software, you must
 retain all copyright, patent, trademark, and attribution
 notices that are present in the software.
 D) If you distribute any portion of the software in source code
 form, you may do so only under this license by including a
 complete copy of this license with your distribution. If you
 distribute any portion of the software in compiled or object
 code form, you may only do so under a license that complies
 with this license.
 E) The software is licensed “as-is.” You bear all risks of
 using it. The contributors give no express warranties,
 guarantees, or conditions. You may have additional consumer
 rights under your local laws which this license cannot change.
 To the extent permitted under your local laws, the contributors
 exclude all implied warranties, including those of
 merchantability, fitness for a particular purpose and
 non-infringement.

 4. (F) Platform Limitation- The licenses granted in sections
 2.A & 2.B extend only to the software or derivative works that
 you create that run on a Holograph system product.

 ***************************************************************

*/

//pragma solidity 0.8.13;

// import "../abstract/GenericH.sol";
//
// import "../interface/HolographGenericInterface.sol";

/**
 * @title Sample ERC-20 token that is bridgeable via Holograph
 * @author Holograph Foundation
 * @notice A smart contract for minting and managing Holograph Bridgeable ERC20 Tokens.
 * @dev The entire logic and functionality of the smart contract is self-contained.
 */
// contract MultichainTokenFaucet is GenericH {
//   /**
//    * @dev bytes32(uint256(keccak256('eip1967.Holograph.messagingModule')) - 1)
//    */
//   bytes32 constant _messagingModuleSlot = 0x54176250282e65985d205704ffce44a59efe61f7afd99e29fda50f55b48c061a;
//   /**
//    * @dev bytes32(uint256(keccak256('eip1967.Holograph.lZEndpoint')) - 1)
//    */
//   bytes32 constant _lZEndpointSlot = 0x56825e447adf54cdde5f04815fcf9b1dd26ef9d5c053625147c18b7c13091686;
//   /**
//    * @dev bytes32(uint256(keccak256('eip1967.Holograph.jobNonce')) - 1)
//    */
//   bytes32 constant _jobNonceSlot = 0x1cda64803f3b43503042e00863791e8d996666552d5855a78d53ee1dd4b3286d;
//
//   /**
//    * @dev Constructor is left empty and init is used instead
//    */
//   constructor() {}
//
//   /**
//    * @notice Used internally to initialize the contract instead of through a constructor
//    * @dev This function is called by the deployer/factory when creating a contract
//    * @param initPayload abi encoded payload to use for contract initilaization
//    */
//   function init(bytes memory initPayload) external override returns (bytes4) {
//     // do your own custom logic here
//     address contractOwner = abi.decode(initPayload, (address));
//     _setOwner(contractOwner);
//     // run underlying initializer logic
//     return _init(initPayload);
//   }
//
//   function bridgeIn(
//     uint32 /* _chainId*/,
//     address _to,
//     uint256 _amount,
//     bytes calldata /* _data*/
//   ) external override onlyHolographer returns (bool) {
//     // move all native token balance from holographer into source
//     HolographGenericInterface(_holographer()).sourceWithdraw(address(this));
//     // send amount to address
//     payable(_to).transfer(_amount);
//     return true;
//   }
//
//   function bridgeOut(
//     uint32 /* _chainId*/,
//     address /* _to*/,
//     uint256 /* _amount*/
//   ) external override onlyHolographer returns (bytes memory _data) {
//     uint256 jobNonce = _jobNonce();
//     _data = abi.encode(jobNonce, block.chainid);
//   }
//
//   function getCrossChainNativeTokens(
//     uint256[] calldata chainIds,
//     uint256[] calldata nativeTokenAmounts
//   ) external payable {
//     LayerZeroOverrides lZEndpoint;
//     assembly {
//       lZEndpoint := sload(_lZEndpointSlot)
//     }
//     uint256 jobNonce;
//     for (uint256 i = 0; i < chainIds.length; i++) {
//       jobNonce = _jobNonce();
//       bytes memory encodedData = abi.encode(jobNonce, block.chainid);
//       lZEndpoint.send{value: address(this).balance}(
//         uint16(_chainIdMap[ChainIdType.EVM][chainIds[i]][ChainIdType.LAYERZERO]),
//         abi.encodePacked(address(this), address(this)),
//         encodedData,
//         payable(address(this)),
//         address(this),
//         abi.encodePacked(
//           uint16(2), // version uint16
//           uint256(200_000), // gasAmount uint256
//           uint256(nativeTokenAmounts[i]), // nativeForDst uint256
//           tx.origin // addressOnDst address
//         )
//       );
//       emit CrossChainMessageSent(keccak256(encodedData));
//     }
//   }
//
//   function _tupleToDstPrice(
//     LayerZeroOverrides relayer,
//     uint16 lzDestChain
//   ) internal view returns (LayerZeroOverrides.DstPrice memory) {
//     (uint128 dstPriceRatio, uint128 dstGasPriceInWei) = relayer.dstPriceLookup(lzDestChain);
//     return LayerZeroOverrides.DstPrice({dstPriceRatio: dstPriceRatio, dstGasPriceInWei: dstGasPriceInWei});
//   }
//
//   function _tupleToDstConfig(
//     LayerZeroOverrides relayer,
//     uint16 lzDestChain,
//     uint16 outboundProofType
//   ) internal view returns (LayerZeroOverrides.DstConfig memory) {
//     (uint128 dstNativeAmtCap, uint64 baseGas, uint64 gasPerByte) = relayer.dstConfigLookup(
//       lzDestChain,
//       outboundProofType
//     );
//     return LayerZeroOverrides.DstConfig({dstNativeAmtCap: dstNativeAmtCap, baseGas: baseGas, gasPerByte: gasPerByte});
//   }
//
//   function getNativeTokenLimits(
//     uint256[] calldata chainIds
//   ) external view returns (uint256[] memory nativeTokenAmounts) {
//     nativeTokenAmounts = new uint256[](chainIds.length);
//     uint256 l = chainIds.length;
//     LayerZeroOverrides lz;
//     assembly {
//       lz := sload(_lZEndpointSlot)
//     }
//     uint16 lzDestChain;
//     LayerZeroOverrides relayer;
//     LayerZeroOverrides.ApplicationConfiguration memory appConfig;
//     LayerZeroOverrides.DstConfig memory dstConfig;
//     for (uint256 i = 0; i < l; i++) {
//       lzDestChain = uint16(_chainIdMap[ChainIdType.EVM][chainIds[i]][ChainIdType.LAYERZERO]);
//       appConfig = LayerZeroOverrides(lz.defaultSendLibrary()).getAppConfig(lzDestChain, address(this));
//       relayer = LayerZeroOverrides(appConfig.relayer);
//       dstConfig = _tupleToDstConfig(relayer, lzDestChain, appConfig.outboundProofType);
//       nativeTokenAmounts[i] = dstConfig.dstNativeAmtCap;
//     }
//   }
//
//   function getNativeTokenPrices(
//     uint256 nativeTokenInput,
//     uint256[] calldata chainIds,
//     uint256[] calldata bps
//   ) external view returns (uint256[] memory nativeTokenAmounts, uint256[] memory nativeTokenPrices) {
//     require(chainIds.length == bps.length, "HOLOGRAPH: array size missmatch");
//     {
//       uint256 bpTotal = 0;
//       for (uint256 i = 0; i < chainIds.length; i++) {
//         bpTotal += bps[i];
//       }
//       require(bpTotal < 10001, "HOLOGRAPH: bps total over 10000");
//     }
//     LayerZeroOverrides lz;
//     assembly {
//       lz := sload(_lZEndpointSlot)
//     }
//     ChainPricing memory data = ChainPricing({
//       lzSrcChain: 0,
//       lzDestChain: 0,
//       l: 0,
//       relayer: LayerZeroOverrides(address(0)),
//       appConfig: LayerZeroOverrides.ApplicationConfiguration({
//         inboundProofLibraryVersion: 0,
//         inboundBlockConfirmations: 0,
//         relayer: address(0),
//         outboundProofType: 0,
//         outboundBlockConfirmations: 0,
//         oracle: address(0)
//       }),
//       dstConfig: LayerZeroOverrides.DstConfig({dstNativeAmtCap: 0, baseGas: 0, gasPerByte: 0}),
//       localPrice: LayerZeroOverrides.DstPrice({dstPriceRatio: 0, dstGasPriceInWei: 0}),
//       dstPrice: LayerZeroOverrides.DstPrice({dstPriceRatio: 0, dstGasPriceInWei: 0})
//     });
//     nativeTokenAmounts = new uint256[](chainIds.length);
//     nativeTokenPrices = new uint256[](chainIds.length);
//     data.lzSrcChain = uint16(_chainIdMap[ChainIdType.EVM][block.chainid][ChainIdType.LAYERZERO]);
//     data.appConfig = LayerZeroOverrides(lz.defaultSendLibrary()).getAppConfig(data.lzSrcChain, address(this));
//     data.relayer = LayerZeroOverrides(data.appConfig.relayer);
//     data.localPrice = _tupleToDstPrice(data.relayer, data.lzSrcChain);
//     for (uint256 i = 0; i < chainIds.length; i++) {
//       data.lzDestChain = uint16(_chainIdMap[ChainIdType.EVM][chainIds[i]][ChainIdType.LAYERZERO]);
//       data.appConfig = LayerZeroOverrides(lz.defaultSendLibrary()).getAppConfig(data.lzDestChain, address(this));
//       data.relayer = LayerZeroOverrides(data.appConfig.relayer);
//       data.dstConfig = _tupleToDstConfig(data.relayer, data.lzDestChain, data.appConfig.outboundProofType);
//       data.dstPrice = _tupleToDstPrice(data.relayer, data.lzDestChain);
//       uint256 inputAmount = (nativeTokenInput / 10000) * bps[i];
//       nativeTokenAmounts[i] = (inputAmount * (10 ** 10)) / (data.dstPrice.dstPriceRatio);
//       if (nativeTokenAmounts[i] > data.dstConfig.dstNativeAmtCap) {
//         nativeTokenAmounts[i] = data.dstConfig.dstNativeAmtCap;
//         nativeTokenPrices[i] = (nativeTokenAmounts[i] * data.dstPrice.dstPriceRatio) / (10 ** 10);
//       } else {
//         nativeTokenPrices[i] = inputAmount;
//       }
//     }
//   }
//
//   /**
//    * @notice Get the address of the approved LayerZero Endpoint
//    * @dev All lzReceive function calls allow only requests from this address
//    */
//   function getLZEndpoint() external view returns (address lZEndpoint) {
//     assembly {
//       lZEndpoint := sload(_lZEndpointSlot)
//     }
//   }
//
//   /**
//    * @notice Update the approved LayerZero Endpoint address
//    * @param lZEndpoint address of the LayerZero Endpoint to use
//    */
//   function setLZEndpoint(address lZEndpoint) external onlyAdmin {
//     assembly {
//       sstore(_lZEndpointSlot, lZEndpoint)
//     }
//   }
//
//   /**
//    * @dev Internal nonce, that increments on each call, used for randomness
//    */
//   function _jobNonce() private returns (uint256 jobNonce) {
//     assembly {
//       jobNonce := add(sload(_jobNonceSlot), 0x0000000000000000000000000000000000000000000000000000000000000001)
//       sstore(_jobNonceSlot, jobNonce)
//     }
//   }
//
// }
