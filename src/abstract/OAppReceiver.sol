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

import { Origin } from "../interface/ILayerZeroEndpointV2.sol";
import { OAppCore } from "./OAppCore.sol";

/**
 * @title OAppReceiver
 * @dev Abstract contract implementing the ILayerZeroReceiver interface and extending OAppCore for OApp receivers.
 */
abstract contract OAppReceiver is OAppCore {
    // Custom error message for when the caller is not the registered endpoint/
    error OnlyEndpoint(address addr);

    // @dev The version of the OAppReceiver implementation.
    // @dev Version is bumped when changes are made to this contract.
    uint64 internal constant RECEIVER_VERSION = 1;

    /**
     * @notice Retrieves the OApp version information.
     * @return senderVersion The version of the OAppSender.sol contract.
     * @return receiverVersion The version of the OAppReceiver.sol contract.
     *
     * @dev Providing 0 as the default for OAppSender version. Indicates that the OAppSender is not implemented.
     * ie. this is a RECEIVE only OApp.
     * @dev If the OApp uses both OAppSender and OAppReceiver, then this needs to be override returning the correct versions.
     */
    function oAppVersion() public view virtual returns (uint64 senderVersion, uint64 receiverVersion) {
        return (0, RECEIVER_VERSION);
    }

    /**
     * @notice Retrieves the address responsible for 'sending' composeMsg's to the Endpoint.
     * @return sender The address responsible for 'sending' composeMsg's to the Endpoint.
     *
     * @dev Applications can optionally choose to implement a separate composeMsg sender that is NOT the bridging layer.
     * @dev The default sender IS the OApp implementer.
     */
    function composeMsgSender() public view virtual returns (address sender) {
        return address(this);
    }

    /**
     * @notice Checks if the path initialization is allowed based on the provided origin.
     * @param origin The origin information containing the source endpoint and sender address.
     * @return Whether the path has been initialized.
     *
     * @dev This indicates to the endpoint that the OApp has enabled msgs for this particular path to be received.
     * @dev This defaults to assuming if a peer has been set, its initialized.
     * Can be overridden by the OApp if there is other logic to determine this.
     */
    function allowInitializePath(Origin calldata origin) public view virtual returns (bool) {
        return peers[origin.srcEid] == origin.sender;
    }

    /**
     * @notice Retrieves the next nonce for a given source endpoint and sender address.
     * @dev _srcEid The source endpoint ID.
     * @dev _sender The sender address.
     * @return nonce The next nonce.
     *
     * @dev The path nonce starts from 1. If 0 is returned it means that there is NO nonce ordered enforcement.
     * @dev Is required by the off-chain executor to determine the OApp expects msg execution is ordered.
     * @dev This is also enforced by the OApp.
     * @dev By default this is NOT enabled. ie. nextNonce is hardcoded to return 0.
     */
    function nextNonce(uint32 /*_srcEid*/, bytes32 /*_sender*/) public view virtual returns (uint64 nonce) {
        return 0;
    }

    /**
     * @dev Entry point for receiving messages or packets from the endpoint.
     * @param _origin The origin information containing the source endpoint and sender address.
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address on the src chain.
     *  - nonce: The nonce of the message.
     * @param _guid The unique identifier for the received LayerZero message.
     * @param _message The payload of the received message.
     * @param _executor The address of the executor for the received message.
     * @param _extraData Additional arbitrary data provided by the corresponding executor.
     *
     * @dev Entry point for receiving msg/packet from the LayerZero endpoint.
     */
    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) public payable virtual {
        // Ensures that only the endpoint can attempt to lzReceive() messages to this OApp.
        if (address(endpoint) != msg.sender) revert OnlyEndpoint(msg.sender);

        // Ensure that the sender matches the expected peer for the source endpoint.
        if (_getPeerOrRevert(_origin.srcEid) != _origin.sender) revert OnlyPeer(_origin.srcEid, _origin.sender);

        // Call the internal OApp implementation of lzReceive.
        _lzReceive(_origin, _guid, _message, _executor, _extraData);
    }

    /**
     * @dev Internal function to implement lzReceive logic without needing to copy the basic parameter validation.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual;
}