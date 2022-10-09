/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

import "./abstract/Admin.sol";
import "./abstract/Initializable.sol";

import "./interface/HolographERC20Interface.sol";
import "./interface/Holographable.sol";
import "./interface/HolographInterface.sol";
import "./interface/HolographBridgeInterface.sol";
import "./interface/HolographFactoryInterface.sol";
import "./interface/HolographOperatorInterface.sol";
import "./interface/HolographRegistryInterface.sol";
import "./interface/InitializableInterface.sol";

/**
 * @title Holograph Bridge
 * @author https://github.com/holographxyz
 * @notice Beam any holographable contracts and assets across blockchains
 * @dev The contract abstracts all the complexities of making bridge requests and uses a universal interface to bridge any type of holographable assets
 */
contract HolographBridge is Admin, Initializable, HolographBridgeInterface {
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.factory')) - 1)
   */
  bytes32 constant _factorySlot = precomputeslot("eip1967.Holograph.factory");
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.holograph')) - 1)
   */
  bytes32 constant _holographSlot = precomputeslot("eip1967.Holograph.holograph");
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.jobNonce')) - 1)
   */
  bytes32 constant _jobNonceSlot = precomputeslot("eip1967.Holograph.jobNonce");
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.operator')) - 1)
   */
  bytes32 constant _operatorSlot = precomputeslot("eip1967.Holograph.operator");
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.registry')) - 1)
   */
  bytes32 constant _registrySlot = precomputeslot("eip1967.Holograph.registry");

  /**
   * @dev Allow calls only from Holograph Operator contract
   */
  modifier onlyOperator() {
    require(msg.sender == address(_operator()), "HOLOGRAPH: operator only call");
    _;
  }

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
    require(!_isInitialized(), "HOLOGRAPH: already initialized");
    (address factory, address holograph, address operator, address registry) = abi.decode(
      initPayload,
      (address, address, address, address)
    );
    assembly {
      sstore(_adminSlot, origin())
      sstore(_factorySlot, factory)
      sstore(_holographSlot, holograph)
      sstore(_operatorSlot, operator)
      sstore(_registrySlot, registry)
    }
    _setInitialized();
    return InitializableInterface.init.selector;
  }

  /**
   * @notice Receive a beam from another chain
   * @dev This function can only be called by the Holograph Operator module
   * @param fromChain Holograph Chain ID where the brigeOutRequest was created
   * @param holographableContract address of the destination contract that the bridgeInRequest is targeted for
   * @param hToken address of the hToken contract that wrapped the origin chain native gas token
   * @param hTokenRecipient address of recipient for the hToken reward
   * @param hTokenValue exact amount of hToken reward in wei
   * @param doNotRevert boolean used to specify if the call should revert
   * @param bridgeInPayload actual abi encoded bytes of the data that the holographable contract bridgeIn function will receive
   */
  function bridgeInRequest(
    uint256, /* nonce*/
    uint32 fromChain,
    address holographableContract,
    address hToken,
    address hTokenRecipient,
    uint256 hTokenValue,
    bool doNotRevert,
    bytes calldata bridgeInPayload
  ) external payable onlyOperator {
    /**
     * @dev check that the target contract is either Holograph Factory or a deployed holographable contract
     */
    require(
      _registry().isHolographedContract(holographableContract) || address(_factory()) == holographableContract,
      "HOLOGRAPH: not holographed"
    );
    /**
     * @dev make a bridgeIn function call to the holographable contract
     */
    bytes4 selector = Holographable(holographableContract).bridgeIn(fromChain, bridgeInPayload);
    /**
     * @dev ensure returned selector is bridgeIn function signature, to guarantee that the function was called and succeeded
     */
    require(selector == Holographable.bridgeIn.selector, "HOLOGRAPH: bridge in failed");
    /**
     * @dev check if a specific reward amount was assigned to this request
     */
    if (hTokenValue > 0) {
      /**
       * @dev mint the specific hToken amount for hToken recipient
       *      this value is equivalent to amount that is deposited on origin chain's hToken contract
       *      recipient can beam the asset to origin chain and unwrap for native gas token at any time
       */
      require(
        HolographERC20Interface(hToken).holographBridgeMint(hTokenRecipient, hTokenValue) ==
          HolographERC20Interface.holographBridgeMint.selector,
        "HOLOGRAPH: hToken mint failed"
      );
    }
    /**
     * @dev allow the call to revert on demand, for example use case, look into the Holograph Operator's jobEstimator function
     */
    require(doNotRevert, "HOLOGRAPH: reverted");
  }

  /**
   * @notice Create a beam request for a destination chain
   * @dev This function works for deploying contracts and beaming supported holographable assets across chains
   * @param toChain Holograph Chain ID where the beam is being sent to
   * @param holographableContract address of the contract for which the bridge request is being made
   * @param gasLimit maximum amount of gas to spend for executing the beam on destination chain
   * @param gasPrice maximum amount of gas price (in destination chain native gas token) to pay on destination chain
   * @param bridgeOutPayload actual abi encoded bytes of the data that the holographable contract bridgeOut function will receive
   */
  function bridgeOutRequest(
    uint32 toChain,
    address holographableContract,
    uint256 gasLimit,
    uint256 gasPrice,
    bytes calldata bridgeOutPayload
  ) external payable {
    /**
     * @dev check that the target contract is either Holograph Factory or a deployed holographable contract
     */
    require(
      _registry().isHolographedContract(holographableContract) || address(_factory()) == holographableContract,
      "HOLOGRAPH: not holographed"
    );
    /**
     * @dev make a bridgeOut function call to the holographable contract
     */
    (bytes4 selector, bytes memory returnedPayload) = Holographable(holographableContract).bridgeOut(
      toChain,
      msg.sender,
      bridgeOutPayload
    );
    /**
     * @dev ensure returned selector is bridgeOut function signature, to guarantee that the function was called and succeeded
     */
    require(selector == Holographable.bridgeOut.selector, "HOLOGRAPH: bridge out failed");
    /**
     * @dev pass the request, along with all data, to Holograph Operator, to handle the cross-chain messaging logic
     */
    _operator().send{value: msg.value}(
      gasLimit,
      gasPrice,
      toChain,
      msg.sender,
      _jobNonce(),
      holographableContract,
      returnedPayload
    );
  }

  /**
   * @notice Do not call this function, it will always revert
   * @dev Used by getBridgeOutRequestPayload function
   *      It is purposefully inverted to always revert on a successful call
   *      Marked as external and not private to allow use inside try/catch of getBridgeOutRequestPayload function
   *      If this function does not revert and returns a string, it is the actual revert reason
   * @param sender address of actual sender that is planning to make a bridgeOutRequest call
   * @param toChain holograph chain id of destination chain
   * @param holographableContract address of the contract for which the bridge request is being made
   * @param bridgeOutPayload actual abi encoded bytes of the data that the holographable contract bridgeOut function will receive
   */
  function revertedBridgeOutRequest(
    address sender,
    uint32 toChain,
    address holographableContract,
    bytes calldata bridgeOutPayload
  ) external returns (string memory revertReason) {
    /**
     * @dev make a bridgeOut function call to the holographable contract inside of a try/catch
     */
    try Holographable(holographableContract).bridgeOut(toChain, sender, bridgeOutPayload) returns (
      bytes4 selector,
      bytes memory payload
    ) {
      /**
       * @dev ensure returned selector is bridgeOut function signature, to guarantee that the function was called and succeeded
       */
      if (selector != Holographable.bridgeOut.selector) {
        /**
         * @dev if selector does not match, then it means the request failed
         */
        return "HOLOGRAPH: bridge out failed";
      }
      assembly {
        /**
         * @dev the entire payload is sent back in a revert
         */
        revert(add(payload, 0x20), mload(payload))
      }
    } catch Error(string memory reason) {
      return reason;
    } catch {
      return "HOLOGRAPH: unknown error";
    }
  }

  /**
   * @notice Get the payload created by the bridgeOutRequest function
   * @dev Use this function to get the payload that will be generated by a bridgeOutRequest
   *      Only use this with a static call
   * @param toChain Holograph Chain ID where the beam is being sent to
   * @param holographableContract address of the contract for which the bridge request is being made
   * @param gasLimit maximum amount of gas to spend for executing the beam on destination chain
   * @param gasPrice maximum amount of gas price (in destination chain native gas token) to pay on destination chain
   * @param bridgeOutPayload actual abi encoded bytes of the data that the holographable contract bridgeOut function will receive
   * @return samplePayload bytes made up of the bridgeOutRequest payload
   */
  function getBridgeOutRequestPayload(
    uint32 toChain,
    address holographableContract,
    uint256 gasLimit,
    uint256 gasPrice,
    bytes calldata bridgeOutPayload
  ) external returns (bytes memory samplePayload) {
    /**
     * @dev check that the target contract is either Holograph Factory or a deployed holographable contract
     */
    require(
      _registry().isHolographedContract(holographableContract) || address(_factory()) == holographableContract,
      "HOLOGRAPH: not holographed"
    );
    bytes memory payload;
    /**
     * @dev the revertedBridgeOutRequest function is wrapped into a try/catch function
     */
    try this.revertedBridgeOutRequest(msg.sender, toChain, holographableContract, bridgeOutPayload) returns (
      string memory revertReason
    ) {
      /**
       * @dev a non reverted result is actually a revert
       */
      revert(revertReason);
    } catch (bytes memory realResponse) {
      /**
       * @dev a revert is actually success, so the return data is stored as payload
       */
      payload = realResponse;
    }
    uint256 jobNonce;
    assembly {
      jobNonce := sload(_jobNonceSlot)
    }
    /**
     * @dev the data is abi encoded into actual bridgeOutRequest payload bytes
     */
    bytes memory encodedData = abi.encodeWithSelector(
      HolographBridgeInterface.bridgeInRequest.selector,
      /**
       * @dev the latest job nonce is incremented by one
       */
      jobNonce + 1,
      _holograph().getHolographChainId(),
      holographableContract,
      _registry().getHToken(_holograph().getHolographChainId()),
      address(0),
      /**
       * @dev hToken value is set to zero since this value is not needed for jobEstimate calculations
       */
      0,
      true,
      payload
    );
    /**
     * @dev this abi encodes the data just like in Holograph Operator
     */
    samplePayload = abi.encodePacked(encodedData, gasLimit, gasPrice);
  }

  /**
   * @notice Get the address of the Holograph Factory module
   * @dev Used for deploying holographable smart contracts
   */
  function getFactory() external view returns (address factory) {
    assembly {
      factory := sload(_factorySlot)
    }
  }

  /**
   * @notice Update the Holograph Factory module address
   * @param factory address of the Holograph Factory smart contract to use
   */
  function setFactory(address factory) external onlyAdmin {
    assembly {
      sstore(_factorySlot, factory)
    }
  }

  /**
   * @notice Get the Holograph Protocol contract
   * @dev Used for storing a reference to all the primary modules and variables of the protocol
   */
  function getHolograph() external view returns (address holograph) {
    assembly {
      holograph := sload(_holographSlot)
    }
  }

  /**
   * @notice Update the Holograph Protocol contract address
   * @param holograph address of the Holograph Protocol smart contract to use
   */
  function setHolograph(address holograph) external onlyAdmin {
    assembly {
      sstore(_holographSlot, holograph)
    }
  }

  /**
   * @notice Get the latest job nonce
   * @dev You can use the job nonce as a way to calculate total amount of bridge requests that have been made
   */
  function getJobNonce() external view returns (uint256 jobNonce) {
    assembly {
      jobNonce := sload(_jobNonceSlot)
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
   * @notice Update the Holograph Operator module address
   * @param operator address of the Holograph Operator smart contract to use
   */
  function setOperator(address operator) external onlyAdmin {
    assembly {
      sstore(_operatorSlot, operator)
    }
  }

  /**
   * @notice Get the Holograph Registry module
   * @dev This module stores a reference for all deployed holographable smart contracts
   */
  function getRegistry() external view returns (address registry) {
    assembly {
      registry := sload(_registrySlot)
    }
  }

  /**
   * @notice Update the Holograph Registry module address
   * @param registry address of the Holograph Registry smart contract to use
   */
  function setRegistry(address registry) external onlyAdmin {
    assembly {
      sstore(_registrySlot, registry)
    }
  }

  /**
   * @dev Internal function used for getting the Holograph Factory Interface
   */
  function _factory() private view returns (HolographFactoryInterface factory) {
    assembly {
      factory := sload(_factorySlot)
    }
  }

  /**
   * @dev Internal function used for getting the Holograph Interface
   */
  function _holograph() private view returns (HolographInterface holograph) {
    assembly {
      holograph := sload(_holographSlot)
    }
  }

  /**
   * @dev Internal nonce used for randomness. We increment it on each call
   */
  function _jobNonce() private returns (uint256 jobNonce) {
    assembly {
      jobNonce := add(sload(_jobNonceSlot), 0x0000000000000000000000000000000000000000000000000000000000000001)
      sstore(_jobNonceSlot, jobNonce)
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
   * @dev Internal function used for getting the Holograph Registry Interface
   */
  function _registry() private view returns (HolographRegistryInterface registry) {
    assembly {
      registry := sload(_registrySlot)
    }
  }

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
