// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IOAppCore} from "../../interface/IOAppCore.sol";
import {ILayerZeroEndpointV2} from "../../interface/ILayerZeroEndpointV2.sol";

/**
 * @title OAppCore
 * @dev Abstract contract implementing the IOAppCore interface with basic OApp configurations.
 */
abstract contract OAppCore is IOAppCore {
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.lZEndpoint')) - 1)
   */
  bytes32 constant _enpointSlot = 0xeaca2d84e379be6c2262b0d6c3185528c336571fedeb1961096c6f42216d1c00;

  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.layerzero.peers')) - 1)
   */
  bytes32 constant _peersSlot = 0xc8ad0a399c48547df15e0ee3cb45c5e4b9975477e146d611eff091a394cc6ce0;

  /**
   * @dev Constructor to initialize the OAppCore with the provided endpoint and delegate.
   * @param _endpoint The address of the LOCAL Layer Zero endpoint.
   * @param _delegate The delegate capable of making OApp configurations inside of the endpoint.
   *
   * @dev The delegate typically should be set as the owner of the contract.
   */
  constructor(address _endpoint, address _delegate) {
    assembly {
      sstore(_enpointSlot, _endpoint)
    }

    if (_delegate == address(0)) revert InvalidDelegate();
    _setDelegate(_delegate);
  }

  /* -------------------------------------------------------------------------- */
  /*                              Public functions                              */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Retrieves the LayerZero endpoint associated with the OApp.
   * @return iEndpoint The LayerZero endpoint as an interface.
   */
  function endpoint() public view returns (ILayerZeroEndpointV2 iEndpoint) {
    assembly {
      iEndpoint := sload(_enpointSlot)
    }
  }

  /**
   * @notice Retrieves the peer (OApp) associated with a corresponding endpoint.
   * @param _eid The endpoint ID.
   * @return peer The peer address (OApp instance) associated with the corresponding endpoint.
   */
  function peers(uint32 _eid) public view returns (bytes32 peer) {
    bytes32 peerSlot = keccak256(abi.encodePacked(_peersSlot, _eid));
    assembly {
      peer := sload(peerSlot)
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                             Internal functions                             */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Sets the peer address (OApp instance) for a corresponding endpoint.
   * @param _eid The endpoint ID.
   * @param _peer The address of the peer to be associated with the corresponding endpoint.
   *
   * @dev Only the owner/admin of the OApp can call this function.
   * @dev Indicates that the peer is trusted to send LayerZero messages to this OApp.
   * @dev Set this to bytes32(0) to remove the peer address.
   * @dev Peer is a bytes32 to accommodate non-evm chains.
   */
  function _setPeer(uint32 _eid, bytes32 _peer) internal virtual {
    bytes32 peerSlot = keccak256(abi.encodePacked(_peersSlot, _eid));
    assembly {
      sstore(peerSlot, _peer)
    }
    emit PeerSet(_eid, _peer);
  }

  /**
   * @notice Internal function to get the peer address associated with a specific endpoint; reverts if NOT set.
   * ie. the peer is set to bytes32(0).
   * @param _eid The endpoint ID.
   * @return peer The address of the peer associated with the specified endpoint.
   */
  function _getPeerOrRevert(uint32 _eid) internal view virtual returns (bytes32 peer) {
    bytes32 peerSlot = keccak256(abi.encodePacked(_peersSlot, _eid));
    assembly {
      peer := sload(peerSlot)
    }
    if (peer == bytes32(0)) revert NoPeer(_eid);
  }

  /**
   * @notice Sets the delegate address for the OApp.
   * @param _delegate The address of the delegate to be set.
   *
   * @dev Only the owner/admin of the OApp can call this function.
   * @dev Provides the ability for a delegate to set configs, on behalf of the OApp, directly on the Endpoint contract.
   */
  function _setDelegate(address _delegate) internal virtual {
    address _endpoint = address(endpoint());
    if (_endpoint != address(0)) ILayerZeroEndpointV2(endpoint()).setDelegate(_delegate);
  }

  /**
   *
   */
  function _getDelegate() internal view virtual returns (ILayerZeroEndpointV2 _endpoint) {
    assembly {
      _endpoint := sload(_enpointSlot)
    }
  }
}
