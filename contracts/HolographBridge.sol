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

import "./abstract/Admin.sol";
import "./abstract/Initializable.sol";

import "./enum/ChainIdType.sol";

import "./interface/ERC20Holograph.sol";
import "./interface/ERC721Holograph.sol";
import "./interface/HolographableEnforcer.sol";
import "./interface/IHolograph.sol";
import "./interface/IHolographBridge.sol";
import "./interface/IHolographFactory.sol";
import "./interface/IHolographOperator.sol";
import "./interface/IHolographRegistry.sol";
import "./interface/IInitializable.sol";
import "./interface/IInterfaces.sol";

import "./struct/DeploymentConfig.sol";
import "./struct/Verification.sol";

/**
 * @dev This smart contract contains the actual core bridging logic.
 */
contract HolographBridge is Admin, Initializable, IHolographBridge {
  bytes32 constant _factorySlot = 0xa49f20855ba576e09d13c8041c8039fa655356ea27f6c40f1ec46a4301cd5b23;
  bytes32 constant _holographSlot = 0xb4107f746e9496e8452accc7de63d1c5e14c19f510932daa04077cd49e8bd77a;
  bytes32 constant _interfacesSlot = 0xbd3084b8c09da87ad159c247a60e209784196be2530cecbbd8f337fdd1848827;
  bytes32 constant _jobNonceSlot = 0x1cda64803f3b43503042e00863791e8d996666552d5855a78d53ee1dd4b3286d;
  bytes32 constant _operatorSlot = 0x7caba557ad34138fa3b7e43fb574e0e6cc10481c3073e0dffbc560db81b5c60f;
  bytes32 constant _registrySlot = 0xce8e75d5c5227ce29a4ee170160bb296e5dea6934b80a9bd723f7ef1e7c850e7;

  /**
   * @dev Constructor is left empty and only the admin address is set.
   */
  constructor() {}

  modifier onlyBridge() {
    require(msg.sender == address(this), "HOLOGRAPH: bridge only call");
    _;
  }

  modifier onlyOperator() {
    assembly {
      switch eq(sload(_operatorSlot), caller())
      case 0 {
        mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0xa0, 0x0000002000000000000000000000000000000000000000000000000000000000)
        mstore(0xc0, 0x00000018484f4c4f47524150483a206f70657261746f72206f6e6c7900000000)
        mstore(0xe0, 0x0000000000000000000000000000000000000000000000000000000000000000)
        revert(0x80, 0xc4)
      }
    }
    _;
  }

  function init(bytes memory data) external override returns (bytes4) {
    require(!_isInitialized(), "HOLOGRAPH: already initialized");
    (address factory, address holograph, address interfaces, address operator, address registry) = abi.decode(
      data,
      (address, address, address, address, address)
    );
    assembly {
      sstore(_adminSlot, origin())

      sstore(_factorySlot, factory)
      sstore(_holographSlot, holograph)
      sstore(_interfacesSlot, interfaces)
      sstore(_operatorSlot, operator)
      sstore(_registrySlot, registry)
    }
    _setInitialized();
    return IInitializable.init.selector;
  }

  function executeJob(bytes calldata _payload) external onlyOperator {
    assembly {
      calldatacopy(0, _payload.offset, _payload.length)
      let result := callcode(gas(), address(), callvalue(), 0, _payload.length, 0, 0)
      if eq(result, 0) {
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
    }
  }

  function bridgeInRequest(
    uint256, /* nonce*/
    uint32 fromChain,
    address holographableContract,
    address hToken,
    address hTokenRecipient,
    uint256 hTokenValue,
    bytes calldata data
  ) external onlyOperator {
    require(_registry().isHolographedContract(holographableContract), "HOLOGRAPH: not holographed");
    (bytes4 selector) = HolographableEnforcer(holographableContract).bridgeIn(fromChain, data);
    require(selector == HolographableEnforcer.bridgeIn.selector, "HOLOGRAPH: bridge in failed");
    if (hTokenValue > 0) {
      // provide operator with hToken value for executing bridge job
      require(
        ERC20Holograph(hToken).holographBridgeMint(hTokenRecipient, hTokenValue) ==
          ERC20Holograph.holographBridgeMint.selector,
        "HOLOGRAPH: hToken mint failed"
      );
    }
  }

  function bridgeOutRequest(
    uint32 toChain,
    address holographableContract,
    uint256 gasLimit,
    uint256 gasPrice,
    bytes calldata data
  ) external payable {
    require(_registry().isHolographedContract(holographableContract), "HOLOGRAPH: not holographed");
    (bytes4 selector, bytes memory payload) = HolographableEnforcer(holographableContract).bridgeOut(toChain, msg.sender, data);
    require(selector == HolographableEnforcer.bridgeOut.selector, "HOLOGRAPH: bridge out failed");
    bytes memory encodedData = abi.encodeWithSelector(
      HolographableEnforcer.bridgeIn.selector,
      _jobNonce(),
      _holograph().getChainType(),
      holographableContract,
      _registry().getHToken(_holograph().getChainType()),
      address(0),
      0,
      payload
    );
    _operator().send{value: msg.value}(
      gasLimit,
      gasPrice,
      toChain,
      msg.sender,
      encodedData
    );
  }
//
//   function erc721in(
//     uint256, /* nonce*/
//     uint32 fromChain,
//     address collection,
//     address from,
//     address to,
//     uint256 tokenId,
//     bytes calldata data,
//     address hTokenRecipient,
//     uint256 hTokenValue
//   ) external onlyBridge {
//     require(_registry().isHolographedContract(collection), "HOLOGRAPH: not holographed");
//     require(
//       ERC721Holograph(collection).holographBridgeIn(fromChain, from, to, tokenId, data) ==
//         ERC721Holograph.holographBridgeIn.selector,
//       "HOLOGRAPH: bridge in failed"
//     );
//     if (hTokenValue > 0) {
//       // provide operator with hToken value for executing bridge job
//       require(
//         ERC20Holograph(_registry().getHToken(fromChain)).holographBridgeMint(hTokenRecipient, hTokenValue) ==
//           ERC20Holograph.holographBridgeMint.selector,
//         "HOLOGRAPH: hToken mint failed"
//       );
//     }
//   }
//
//   function erc721out(
//     uint32 toChain,
//     address collection,
//     address from,
//     address to,
//     uint256 tokenId
//   ) external payable {
//     require(_registry().isHolographedContract(collection), "HOLOGRAPH: not holographed");
//     ERC721Holograph erc721 = ERC721Holograph(collection);
//     require(erc721.exists(tokenId), "HOLOGRAPH: token doesn't exist");
//     address tokenOwner = erc721.ownerOf(tokenId);
//     require(
//       tokenOwner == msg.sender ||
//         erc721.getApproved(tokenId) == msg.sender ||
//         erc721.isApprovedForAll(tokenOwner, msg.sender),
//       "HOLOGRAPH: not approved/owner"
//     );
//     require(to != address(0), "HOLOGRAPH: zero address");
//     (bytes4 selector, bytes memory data) = erc721.holographBridgeOut(toChain, from, to, tokenId);
//     require(selector == 0xde8b1ef1, "HOLOGRAPH: bridge out failed");
//     _operator().send{value: msg.value}(
//       toChain,
//       msg.sender,
//       abi.encodeWithSignature(
//         "erc721in(uint256,uint32,address,address,address,uint256,bytes,address,uint256)",
//         _jobNonce(),
//         _holograph().getChainType(),
//         collection,
//         from,
//         to,
//         tokenId,
//         data,
//         address(0),
//         0
//       )
//     );
//   }
//
  function erc20in(
    uint256, /* nonce*/
    uint32 fromChain,
    address token,
    address from,
    address to,
    uint256 amount,
    bytes calldata data,
    address hTokenRecipient,
    uint256 hTokenValue
  ) external onlyBridge {
    require(_registry().isHolographedContract(token), "HOLOGRAPH: not holographed");
    require(
      ERC20Holograph(token).holographBridgeIn(fromChain, from, to, amount, data) ==
        ERC20Holograph.holographBridgeIn.selector,
      "HOLOGRAPH: bridge in failed"
    );
    if (hTokenValue > 0) {
      // provide operator with hToken value for executing bridge job
      require(
        ERC20Holograph(_registry().getHToken(fromChain)).holographBridgeMint(hTokenRecipient, hTokenValue) ==
          ERC20Holograph.holographBridgeMint.selector,
        "HOLOGRAPH: hToken mint failed"
      );
    }
  }

  function erc20out(
    uint32 toChain,
    address token,
    address from,
    address to,
    uint256 amount
  ) external payable {
    require(_registry().isHolographedContract(token), "HOLOGRAPH: not holographed");
    ERC20Holograph erc20 = ERC20Holograph(token);
    require(erc20.balanceOf(from) >= amount, "HOLOGRAPH: not enough tokens");
    (bytes4 selector, bytes memory data) = erc20.holographBridgeOut(toChain, msg.sender, from, to, amount);
    require(selector == ERC20Holograph.holographBridgeOut.selector, "HOLOGRAPH: bridge out failed");
    _operator().send{value: msg.value}(
      0,
      0,
      toChain,
      msg.sender,
      abi.encodeWithSignature(
        "erc20in(uint256,uint32,address,address,address,uint256,bytes,address,uint256)",
        _jobNonce(),
        _holograph().getChainType(),
        token,
        from,
        to,
        amount,
        data,
        address(0),
        0
      )
    );
  }

  function deployIn(
    uint256, /* nonce*/
    uint32 fromChain,
    bytes calldata data,
    address hTokenRecipient,
    uint256 hTokenValue
  ) external onlyBridge {
    (DeploymentConfig memory config, Verification memory signature, address signer) = abi.decode(
      data,
      (DeploymentConfig, Verification, address)
    );
    _factory().deployHolographableContract(config, signature, signer);
    if (hTokenValue > 0) {
      // provide operator with hToken value for executing bridge job
      require(
        ERC20Holograph(_registry().getHToken(fromChain)).holographBridgeMint(hTokenRecipient, hTokenValue) ==
          ERC20Holograph.holographBridgeMint.selector,
        "HOLOGRAPH: hToken mint failed"
      );
    }
  }

  function deployOut(
    uint32 toChain,
    DeploymentConfig calldata config,
    Verification calldata signature,
    address signer
  ) external payable {
    _operator().send{value: msg.value}(
      0,
      0,
      toChain,
      msg.sender,
      abi.encodeWithSignature(
        "deployIn(uint256,uint32,bytes,address,uint256)",
        _jobNonce(),
        _holograph().getChainType(),
        abi.encode(config, signature, signer),
        address(0),
        0
      )
    );
  }
//
//   function erc721out(
//     uint32 toChain,
//     address collection,
//     address from,
//     address to,
//     uint256 tokenId,
//     uint256 gas,
//     uint256 gasPrice
//   ) external payable {
//     uint32 chain = _holograph().getChainType();
//     _registry().getHToken(chain).call{ value: gas * gasPrice}("");
//     require(_registry().isHolographedContract(collection), "HOLOGRAPH: not holographed");
//     (bytes4 selector, bytes memory data) = ERC721Holograph(collection).holographBridgeOut(toChain, msg.sender, from, to, tokenId);
//     require(selector == 0x8b591bab, "HOLOGRAPH: bridge out failed");
//     _operator().send{value: msg.value}(
//       toChain,
//       msg.sender,
//       abi.encodeWithSignature(
//         "erc721in(uint256,uint32,address,address,address,uint256,bytes,address,uint256)",
//         _jobNonce(),
//         chain,
//         collection,
//         from,
//         to,
//         tokenId,
//         data,
//         address(0),
//         0
//       )
//     );
//   }
//
  /**
   * @dev Internal nonce used for randomness.
   *      We increment it on each return.
   */
  function _jobNonce() private returns (uint256 jobNonce) {
    assembly {
      jobNonce := add(sload(_jobNonceSlot), 0x0000000000000000000000000000000000000000000000000000000000000001)
      sstore(_jobNonceSlot, jobNonce)
    }
  }

  function _factory() private view returns (IHolographFactory factory) {
    assembly {
      factory := sload(_factorySlot)
    }
  }

  function _holograph() private view returns (IHolograph holograph) {
    assembly {
      holograph := sload(_holographSlot)
    }
  }

  function _interfaces() private view returns (IInterfaces interfaces) {
    assembly {
      interfaces := sload(_interfacesSlot)
    }
  }

  function _operator() private view returns (IHolographOperator operator) {
    assembly {
      operator := sload(_operatorSlot)
    }
  }

  function _registry() private view returns (IHolographRegistry registry) {
    assembly {
      registry := sload(_registrySlot)
    }
  }

  function getJobNonce() external view returns (uint256 jobNonce) {
    assembly {
      jobNonce := sload(_jobNonceSlot)
    }
  }

  function getFactory() external view returns (address factory) {
    assembly {
      factory := sload(_factorySlot)
    }
  }

  function setFactory(address factory) external onlyAdmin {
    assembly {
      sstore(_factorySlot, factory)
    }
  }

  function getHolograph() external view returns (address holograph) {
    assembly {
      holograph := sload(_holographSlot)
    }
  }

  function setHolograph(address holograph) external onlyAdmin {
    assembly {
      sstore(_holographSlot, holograph)
    }
  }

  function getInterfaces() external view returns (address interfaces) {
    assembly {
      interfaces := sload(_interfacesSlot)
    }
  }

  function setInterfaces(address interfaces) external onlyAdmin {
    assembly {
      sstore(_interfacesSlot, interfaces)
    }
  }

  function getOperator() external view returns (address operator) {
    assembly {
      operator := sload(_operatorSlot)
    }
  }

  function setOperator(address operator) external onlyAdmin {
    assembly {
      sstore(_operatorSlot, operator)
    }
  }

  function getRegistry() external view returns (address registry) {
    assembly {
      registry := sload(_registrySlot)
    }
  }

  function setRegistry(address registry) external onlyAdmin {
    assembly {
      sstore(_registrySlot, registry)
    }
  }
}
