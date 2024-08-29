// SPDX-License-Identifier: UNLICENSED
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

pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MessagingParams, MessagingFee, MessagingReceipt} from "../interface/ILayerZeroEndpointV2.sol";
import {OAppCore} from "./OAppCore.sol";

/**
 * @title OAppSender
 * @dev Abstract contract implementing the OAppSender functionality for sending messages to a LayerZero endpoint.
 */
abstract contract OAppSender is OAppCore {
  using SafeERC20 for IERC20;

  // Custom error messages
  error NotEnoughNative(uint256 msgValue);
  error LzTokenUnavailable();

  // @dev The version of the OAppSender implementation.
  // @dev Version is bumped when changes are made to this contract.
  uint64 internal constant SENDER_VERSION = 1;

  /**
   * @notice Retrieves the OApp version information.
   * @return senderVersion The version of the OAppSender.sol contract.
   * @return receiverVersion The version of the OAppReceiver.sol contract.
   *
   * @dev Providing 0 as the default for OAppReceiver version. Indicates that the OAppReceiver is not implemented.
   * ie. this is a SEND only OApp.
   * @dev If the OApp uses both OAppSender and OAppReceiver, then this needs to be override returning the correct versions
   */
  function oAppVersion() public view virtual returns (uint64 senderVersion, uint64 receiverVersion) {
    return (SENDER_VERSION, 0);
  }

  /**
   * @dev Internal function to interact with the LayerZero EndpointV2.quote() for fee calculation.
   * @param _dstEid The destination endpoint ID.
   * @param _message The message payload.
   * @param _options Additional options for the message.
   * @param _payInLzToken Flag indicating whether to pay the fee in LZ tokens.
   * @return fee The calculated MessagingFee for the message.
   *      - nativeFee: The native fee for the message.
   *      - lzTokenFee: The LZ token fee for the message.
   */
  function _quote(
    uint32 _dstEid,
    bytes memory _message,
    bytes memory _options,
    bool _payInLzToken
  ) internal view virtual returns (MessagingFee memory fee) {
    return
      endpoint.quote(
        MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, _payInLzToken),
        address(this)
      );
  }

  /**
   * @dev Internal function to interact with the LayerZero EndpointV2.send() for sending a message.
   * @param _dstEid The destination endpoint ID.
   * @param _message The message payload.
   * @param _options Additional options for the message.
   * @param _fee The calculated LayerZero fee for the message.
   *      - nativeFee: The native fee.
   *      - lzTokenFee: The lzToken fee.
   * @param _refundAddress The address to receive any excess fee values sent to the endpoint.
   * @return receipt The receipt for the sent message.
   *      - guid: The unique identifier for the sent message.
   *      - nonce: The nonce of the sent message.
   *      - fee: The LayerZero fee incurred for the message.
   */
  function _lzSend(
    uint32 _dstEid,
    bytes memory _message,
    bytes memory _options,
    MessagingFee memory _fee,
    address _refundAddress
  ) internal virtual returns (MessagingReceipt memory receipt) {
    // @dev Push corresponding fees to the endpoint, any excess is sent back to the _refundAddress from the endpoint.
    uint256 messageValue = _payNative(_fee.nativeFee);
    if (_fee.lzTokenFee > 0) _payLzToken(_fee.lzTokenFee);

    return
      // solhint-disable-next-line check-send-result
      endpoint.send{value: messageValue}(
        MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, _fee.lzTokenFee > 0),
        _refundAddress
      );
  }

  /**
   * @dev Internal function to pay the native fee associated with the message.
   * @param _nativeFee The native fee to be paid.
   * @return nativeFee The amount of native currency paid.
   *
   * @dev If the OApp needs to initiate MULTIPLE LayerZero messages in a single transaction,
   * this will need to be overridden because msg.value would contain multiple lzFees.
   * @dev Should be overridden in the event the LayerZero endpoint requires a different native currency.
   * @dev Some EVMs use an ERC20 as a method for paying transactions/gasFees.
   * @dev The endpoint is EITHER/OR, ie. it will NOT support both types of native payment at a time.
   */
  function _payNative(uint256 _nativeFee) internal virtual returns (uint256 nativeFee) {
    if (msg.value != _nativeFee) revert NotEnoughNative(msg.value);
    return _nativeFee;
  }

  /**
   * @dev Internal function to pay the LZ token fee associated with the message.
   * @param _lzTokenFee The LZ token fee to be paid.
   *
   * @dev If the caller is trying to pay in the specified lzToken, then the lzTokenFee is passed to the endpoint.
   * @dev Any excess sent, is passed back to the specified _refundAddress in the _lzSend().
   */
  function _payLzToken(uint256 _lzTokenFee) internal virtual {
    // @dev Cannot cache the token because it is not immutable in the endpoint.
    address lzToken = endpoint.lzToken();
    if (lzToken == address(0)) revert LzTokenUnavailable();

    // Pay LZ token fee by sending tokens to the endpoint.
    IERC20(lzToken).safeTransferFrom(msg.sender, address(endpoint), _lzTokenFee);
  }
}
