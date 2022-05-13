// SPDX-License-Identifier: UNLICENSED
/*

  ,,,,,,,,,,,
 [ HOLOGRAPH ]
  '''''''''''
  _____________________________________________________________
 |                                                             |
 |                            / ^ \                            |
 |                            ~~*~~            .               |
 |                         [ '<>:<>' ]         |=>             |
 |               __           _/"\_           _|               |
 |             .:[]:.          """          .:[]:.             |
 |           .'  []  '.        \_/        .'  []  '.           |
 |         .'|   []   |'.               .'|   []   |'.         |
 |       .'  |   []   |  '.           .'  |   []   |  '.       |
 |     .'|   |   []   |   |'.       .'|   |   []   |   |'.     |
 |   .'  |   |   []   |   |  '.   .'  |   |   []   |   |  '.   |
 |.:'|   |   |   []   |   |   |':'|   |   |   []   |   |   |':.|
 |___|___|___|___[]___|___|___|___|___|___|___[]___|___|___|___|
 |XxXxXxXxXxXxXxX[]XxXxXxXxXxXxXxXxXxXxXxXxXxX[]XxXxXxXxXxXxXxX|
 |^^^^^^^^^^^^^^^[]^^^^^^^^^^^^^^^^^^^^^^^^^^^[]^^^^^^^^^^^^^^^|
 |               []                           []               |
 |               []                           []               |
 |    ,          []     ,        ,'      *    []               |
 |~~~~~^~~~~~~~~/##\~~~^~~~~~~~~^^~~~~~~~~^~~/##\~~~~~~~^~~~~~~|
 |_____________________________________________________________|

             - one bridge, infinite possibilities -


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

pragma solidity 0.8.12;

import "./abstract/Admin.sol";
import "./abstract/Initializable.sol";

import "./interface/IHolograph.sol";
import "./interface/IInitializable.sol";

import "./library/ChainId.sol";

/*
 * @dev This smart contract stores the different source codes that have been prepared and can be used for bridging.
 * @dev We will store here the layer 1 for ERC721 and ERC1155 smart contracts.
 * @dev This way it can be super easy to upgrade/update the source code once, and have all smart contracts automatically updated.
 */
contract HolographRegistry is Admin, Initializable {

    /*
     * @dev A list of smart contracts that are guaranteed secure and holographable.
     */
    mapping(address => bool) private _holographedContracts;

    /*
     * @dev A list of hashes and the mapped out contract addresses.
     */
    mapping(bytes32 => address) private _holographedContractsHashMap;

    /*
     * @dev Storage slot for saving contract type to contract address references.
     */
    mapping(bytes32 => address) private _contractTypeAddresses;

    /*
     * @dev Reserved type addresses for Admin.
     *  Note: this is used for defining default contracts.
     */
    mapping(bytes32 => bool) private _reservedTypes;

    /*
     * @dev Mapping of all hTokens available for the different EVM chains
     */
    mapping(uint32 => address) private _hTokens;

    /*
     * @dev Constructor is left empty and only the admin address is set.
     */
    constructor() Admin(false) {}

    /*
     * @dev An array of initially reserved contract types for admin only to set.
     */
    function init(bytes memory data) external override returns (bytes4) {
        require(!_isInitialized(), "HOLOGRAPH: already initialized");
        (bytes32[] memory reservedTypes) = abi.decode(data, (bytes32[]));
        for (uint256 i = 0; i < reservedTypes.length; i++) {
            _reservedTypes[reservedTypes[i]] = true;
        }
        _setInitialized();
        return IInitializable.init.selector;
    }

    /*
     * @dev Allows to reference a deployed smart contract, and use it's code as reference inside of Holographers.
     */
    function referenceContractTypeAddress(address contractAddress) external returns (bytes32) {
        bytes32 contractType;
        assembly {
            contractType := extcodehash(contractAddress)
        }
        require((contractType != 0x0 && contractType != 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470), "HOLOGRAPH: empty contract");
        require(_contractTypeAddresses[contractType] == address(0), "HOLOGRAPH: contract already set");
        require(!_reservedTypes[contractType], "HOLOGRAPH: reserved address type");
        _contractTypeAddresses[contractType] = contractAddress;
        return contractType;
    }

    /*
     * @dev Allows Holograph Factory to register a deployed contract, referenced with deployment hash.
     */
    function factoryDeployedHash(bytes32 hash, address contractAddress) external {
       require(msg.sender == IHolograph(0x020be79e2D5a6a0204C07970F3586dc379d142e0).getFactory(), "HOLOGRAPH: factory only function");
        _holographedContractsHashMap[hash] = contractAddress;
        _holographedContracts[contractAddress] = true;
    }

    /*
     * @dev Sets the contract address for a contract type.
     */
    function setContractTypeAddress(bytes32 contractType, address contractAddress) external onlyAdmin {
        // For now we leave overriding as possible. need to think this through.
        //require(_contractTypeAddresses[contractType] == address(0), "HOLOGRAPH: contract already set");
        require(_reservedTypes[contractType], "HOLOGRAPH: not reserved type");
        _contractTypeAddresses[contractType] = contractAddress;
    }

    /*
     * @dev Sets the hToken address for a specific chain id.
     */
    function setHToken(uint32 chainId, address hToken) external onlyAdmin {
        _hTokens[chainId] = hToken;
    }

    /*
     * @dev Allows admin to update or toggle reserved types.
     */
    function updateReservedContractTypes(bytes32[] calldata hashes, bool[] calldata reserved) external onlyAdmin {
        for (uint256 i = 0; i < hashes.length; i++) {
            _reservedTypes[hashes[i]] = reserved[i];
        }
    }

    /*
     * @dev Returns the contract address for a contract type.
     */
    function getContractTypeAddress(bytes32 contractType) external view returns (address) {
        return _contractTypeAddresses[contractType];
    }

    /*
     * @dev Returns the hToken address for a given chain id.
     */
    function getHToken(uint32 chainId) external view returns (address) {
        return _hTokens[chainId];
    }

    function isHolographedContract(address smartContract) external view returns (bool) {
        return _holographedContracts[smartContract];
    }

    function isHolographedHashDeployed(bytes32 hash) external view returns (bool) {
        return _holographedContractsHashMap[hash] != address(0);
    }

}
