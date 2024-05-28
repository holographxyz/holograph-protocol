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

pragma solidity 0.8.13;

import "../enum/ChainIdType.sol";
import "../enum/InterfaceType.sol";
import "../enum/TokenUriType.sol";

interface HolographInterfacesInterface {
  /// @notice Generates a URI for a given contract
  /// @param name The name of the contract
  /// @param imageURL The URL of the contract's image
  /// @param externalLink An external link associated with the contract
  /// @param bps The basis points for the contract
  /// @param contractAddress The address of the contract
  /// @return A string representing the contract URI
  function contractURI(
    string calldata name,
    string calldata imageURL,
    string calldata externalLink,
    uint16 bps,
    address contractAddress
  ) external pure returns (string memory);

  /// @notice Retrieves the URI prepend for a given token URI type
  /// @param uriType The type of the token URI
  /// @return prepend The prepend string for the given URI type
  function getUriPrepend(TokenUriType uriType) external view returns (string memory prepend);

  /// @notice Updates the URI prepend for a given token URI type
  /// @param uriType The type of the token URI
  /// @param prepend The new prepend string to set
  function updateUriPrepend(TokenUriType uriType, string calldata prepend) external;

  /// @notice Updates the URI prepends for multiple token URI types
  /// @param uriTypes The array of token URI types
  /// @param prepends The array of new prepend strings to set
  function updateUriPrepends(TokenUriType[] calldata uriTypes, string[] calldata prepends) external;

  /// @notice Get the chain ID for a given chain type and chain ID
  /// @param fromChainType The type of chain ID to convert from
  /// @param fromChainId The actual chain ID to convert from
  /// @param toChainType The type of chain ID to convert to
  /// @return toChainId The chain ID in the converted chain type
  function getChainId(
    ChainIdType fromChainType,
    uint256 fromChainId,
    ChainIdType toChainType
  ) external view returns (uint256 toChainId);

  /// @notice Updates the chain ID mapping for a given chain type and chain ID
  /// @param fromChainType The type of chain ID to convert from
  /// @param fromChainId The actual chain ID to convert from
  /// @param toChainType The type of chain ID to convert to
  /// @param toChainId The chain ID in the converted chain type
  function updateChainIdMap(
    ChainIdType fromChainType,
    uint256 fromChainId,
    ChainIdType toChainType,
    uint256 toChainId
  ) external;

  /// @notice Updates the chain ID mappings for multiple chain types and chain IDs
  /// @param fromChainType The array of types of chain IDs to convert from
  /// @param fromChainId The array of actual chain IDs to convert from
  /// @param toChainType The array of types of chain IDs to convert to
  /// @param toChainId The array of chain IDs in the converted chain type
  function updateChainIdMaps(
    ChainIdType[] calldata fromChainType,
    uint256[] calldata fromChainId,
    ChainIdType[] calldata toChainType,
    uint256[] calldata toChainId
  ) external;

  /// @notice Checks if an interface is supported
  /// @param interfaceType The type of interface to check
  /// @param interfaceId The ID of the interface to check
  /// @return True if the interface is supported, false otherwise
  function supportsInterface(InterfaceType interfaceType, bytes4 interfaceId) external view returns (bool);

  /// @notice Updates the support status of an interface
  /// @param interfaceType The type of interface to update
  /// @param interfaceId The ID of the interface to update
  /// @param supported The support status to set
  function updateInterface(InterfaceType interfaceType, bytes4 interfaceId, bool supported) external;

  /// @notice Updates the support status of multiple interfaces
  /// @param interfaceType The type of interfaces to update
  /// @param interfaceIds The array of IDs of the interfaces to update
  /// @param supported The support status to set for all interfaces
  function updateInterfaces(InterfaceType interfaceType, bytes4[] calldata interfaceIds, bool supported) external;
}
