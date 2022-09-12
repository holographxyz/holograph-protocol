/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

import "./abstract/Admin.sol";
import "./abstract/Initializable.sol";

import "./enum/ChainIdType.sol";

import "./interface/IHolograph.sol";
import "./interface/IHolographBridge.sol";
import "./interface/IHolographOperator.sol";
import "./interface/IHolographRegistry.sol";
import "./interface/IInitializable.sol";
import "./interface/IInterfaces.sol";
import "./interface/ILayerZeroEndpoint.sol";

import "./struct/OperatorJob.sol";

/**
 * @dev This smart contract contains the actual core operator logic.
 */
contract HolographOperator is Admin, Initializable, IHolographOperator {
  bytes32 constant _bridgeSlot = precomputeslot("eip1967.Holograph.bridge");
  bytes32 constant _deadAddressSlot = precomputeslot("eip1967.Holograph.deadAddress");
  bytes32 constant _holographSlot = precomputeslot("eip1967.Holograph.holograph");
  bytes32 constant _interfacesSlot = precomputeslot("eip1967.Holograph.interfaces");
  bytes32 constant _jobNonceSlot = precomputeslot("eip1967.Holograph.jobNonce");
  bytes32 constant _lZEndpointSlot = precomputeslot("eip1967.Holograph.lZEndpoint");
  bytes32 constant _registrySlot = precomputeslot("eip1967.Holograph.registry");

  /**
   * @dev Internal number (in seconds), used for defining a window for operator to execute the job.
   */
  uint256 private _blockTime;

  /**
   * @dev Minimum amount of tokens needed for bonding.
   */
  uint256 private _baseBondAmount;

  /**
   * @dev The multiplier used for calculating bonding amount for pods.
   */
  uint256 private _podMultiplier;

  /**
   * @dev Internal mapping of operator job details for a specific job hash.
   */
  mapping(bytes32 => uint256) private _operatorJobs;

  /**
   * @dev Internal mapping of operator addresses, used for temp storage when defining an operator job.
   */
  mapping(uint256 => address) private _operatorTempStorage;

  /**
   * @dev Internal index used for storing/referencing operator temp storage.
   */
  uint32 private _operatorTempStorageCounter;

  /**
   * @dev Multi-dimensional array of available operators.
   */
  address[][] private _operatorPods;

  /**
   * @dev Internal mapping of bonded operators, to prevent double bonding.
   */
  mapping(address => uint256) private _bondedOperators;

  /**
   * @dev Internal mapping of bonded operator amounts.
   */
  mapping(address => uint256) private _bondedAmounts;

  /**
   * @dev Event is emitted for every time that a valid job is available.
   */
  event AvailableOperatorJob(bytes32 jobHash, bytes payload);

  modifier onlyBridge() {
    require(msg.sender == _bridge(), "HOLOGRAPH: bridge only call");
    _;
  }

  modifier onlyLZ() {
    assembly {
      // check if lzEndpoint
      switch eq(sload(_lZEndpointSlot), caller())
      case 0 {
        // check if operator is calling self, used for job estimations
        switch eq(address(), caller())
        case 0 {
          mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
          mstore(0xa0, 0x0000002000000000000000000000000000000000000000000000000000000000)
          mstore(0xc0, 0x0000001b484f4c4f47524150483a204c5a206f6e6c7920656e64706f696e7400)
          mstore(0xe0, 0x0000000000000000000000000000000000000000000000000000000000000000)
          revert(0x80, 0xc4)
        }
      }
    }
    _;
  }

  /**
   * @dev Constructor is left empty and only the admin address is set.
   */
  constructor() {}

  function init(bytes memory data) external override returns (bytes4) {
    require(!_isInitialized(), "HOLOGRAPH: already initialized");
    (address bridge, address holograph, address interfaces, address registry) = abi.decode(
      data,
      (address, address, address, address)
    );
    assembly {
      // sstore(_deadAddressSlot, 0x000000000000000000000000000000000000000000000000000000000000dead)
      sstore(_adminSlot, origin())

      sstore(_bridgeSlot, bridge)
      sstore(_holographSlot, holograph)
      sstore(_interfacesSlot, interfaces)
      sstore(_registrySlot, registry)
    }
    _blockTime = 10; // 10 blocks allowed for execution
    unchecked {
      _baseBondAmount = 10**18; // one single token unit
    }
    _podMultiplier = 4; // 1, 4, 16, 64
    // set first operator for each pod as zero address
    _operatorPods = [[address(0)]];
    // mark zero address as bonded operator, to prevent abuse
    _bondedOperators[address(0)] = 1;
    _setInitialized();
    return IInitializable.init.selector;
  }

  function lzReceive(
    uint16, /* _srcChainId*/
    bytes calldata _srcAddress,
    uint64, /* _nonce*/
    bytes calldata _payload
  ) external payable onlyLZ {
    assembly {
      let ptr := mload(0x40)
      calldatacopy(add(ptr, 0x0c), _srcAddress.offset, _srcAddress.length)
      switch eq(mload(ptr), address())
      case 0 {
        mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0xa0, 0x0000002000000000000000000000000000000000000000000000000000000000)
        mstore(0xc0, 0x0000001e484f4c4f47524150483a20756e617574686f72697a65642073656e64)
        mstore(0xe0, 0x6572000000000000000000000000000000000000000000000000000000000000)
        revert(0x80, 0xc4)
      }
    }
    // would be a good idea to check payload gas price here and if it is significantly lower than current amount, to set zero address as operator to not lock-up an operator unnecessarily
    unchecked {
      bytes32 jobHash = keccak256(_payload);
      ++_operatorTempStorageCounter;
      // use job hash, job nonce, block number, and block timestamp for generating a random number
      uint256 random = uint256(keccak256(abi.encodePacked(jobHash, _jobNonce(), block.number, block.timestamp)));
      // divide by total number of pods, use modulus/remainder
      uint256 pod = random % _operatorPods.length;
      // identify the total number of available operators in pod
      uint256 podSize = _operatorPods[pod].length;
      // select a primary operator
      uint256 operatorIndex = random % podSize;
      // If operator index is 0, then it's open season! Anyone can execute this job. First come first serve.
      // pop operator to ensure that they cannot be selected for any other job until this one completes
      // decrease pod size to accomodate popped operator
      _operatorTempStorage[_operatorTempStorageCounter] = _operatorPods[pod][operatorIndex];
      _popOperator(pod, operatorIndex);
      podSize--;
      _operatorJobs[jobHash] = uint256(
        (pod << 248) |
          (uint256(_operatorTempStorageCounter) << 216) |
          (block.number << 176) |
          (_RBH(random, podSize, 1) << 160) |
          (_RBH(random, podSize, 2) << 144) |
          (_RBH(random, podSize, 3) << 128) |
          (_RBH(random, podSize, 4) << 112) |
          (_RBH(random, podSize, 5) << 96) |
          0
      ); // 80 next available bit position && so far 176 bits used with only 128 left
      emit AvailableOperatorJob(jobHash, _payload);
    }
  }

  function executeJob(bytes calldata _payload) external payable {
    // we do our operator logic here
    // we will also manage gas/value here
    bytes32 hash = keccak256(_payload);
    require(_operatorJobs[hash] > 0, "HOLOGRAPH: invalid job");
    uint256 gasLimit = 0;
    uint256 gasPrice = 0;
    assembly {
      gasLimit := calldataload(sub(add(_payload.offset, _payload.length), 0x40))
      gasPrice := calldataload(sub(add(_payload.offset, _payload.length), 0x20))
    }
    OperatorJob memory job = getJobDetails(hash);
    // first check if not default operator, or if zero address operator selected
    if (job.operator != address(0)) {
      if (job.operator != msg.sender) {
        // then check if time is still within limits
        uint256 elapsedTime = block.timestamp - uint256(job.startBlock);
        require(elapsedTime > job.blockTimes, "HOLOGRAPH: operator has time");
        // we are at a point where operator failed to execute
        // we need to check if gas price was a variable
        uint256 timeDifference = tx.gasprice / gasPrice;
        require(timeDifference < 2, "HOLOGRAPH: gas spike detected");
        // at this point an operator failed to execute in given amount of time
        // we now need to check if next operator is allowed
        if (timeDifference < 6) {
          address fallbackOperator = _operatorPods[job.pod][uint256(job.fallbackOperators[timeDifference - 1])];
          require(fallbackOperator == address(0) || fallbackOperator == msg.sender, "HOLOGRAPH: invalid fallback");
        }
        // reward the current operator
        uint256 amount = (_podMultiplier**job.pod) * _baseBondAmount;
        // this is where we slash default operator for missing the job
        // for simplicity at this point, slashing pod base fee
        _bondedAmounts[job.operator] -= amount;
        // amount gets sent to msg.sender
        _bondedAmounts[msg.sender] += amount;
        // operator does not get re-instated
      } else {
        // put operator back in
        _operatorPods[job.pod].push(msg.sender);
        _bondedOperators[msg.sender] = job.pod + 1;
      }
    }
    //// we need to decide on a reward for operating here
    // uint256 reward = ???;
    //// operator gets sent the reward
    // _bondedOperators[msg.sender] += reward;
    // check that we have enough gas from operator to execute
    require(gasleft() > gasLimit, "HOLOGRAPH: not enough gas left");
    // now execute job
    assembly {
      calldatacopy(0, _payload.offset, sub(_payload.length, 0x40))
      let result := call(gasLimit, sload(_bridgeSlot), callvalue(), 0, sub(_payload.length, 0x40), 0, 0)
      if eq(result, 0) {
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
    }
    delete _operatorJobs[hash];
  }

  function jobEstimator(bytes calldata _payload) external payable {
    assembly {
      switch eq(sload(_deadAddressSlot), caller())
      case 0 {
        mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0xa0, 0x0000002000000000000000000000000000000000000000000000000000000000)
        mstore(0xc0, 0x000000484f4c4f47524150483a2074657374206f6e6c792063616c6c00000000)
        mstore(0xe0, 0x0000000000000000000000000000000000000000000000000000000000000000)
        revert(0x80, 0xc4)
      }
      let result := call(gas(), sload(_bridgeSlot), callvalue(), 0, sub(_payload.length, 0x40), 0, 0)
      if eq(result, 0) {
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
    }
  }

  function send(
    uint256 gasLimit,
    uint256 gasPrice,
    uint32 toChain,
    address msgSender,
    bytes calldata _payload
  ) external payable onlyBridge {
    ILayerZeroEndpoint lZEndpoint;
    assembly {
      lZEndpoint := sload(_lZEndpointSlot)
    }
    lZEndpoint.send{value: msg.value}(
      uint16(_interfaces().getChainId(ChainIdType.HOLOGRAPH, uint256(toChain), ChainIdType.LAYERZERO)),
      abi.encodePacked(address(this)),
      abi.encodePacked(_payload, gasLimit, gasPrice),
      payable(msgSender),
      address(this),
      abi.encodePacked(uint16(1), uint256(52000 + (_payload.length * 25)))
    );
  }

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

  function _popOperator(uint256 pod, uint256 operatorIndex) private {
    if (operatorIndex > 0) {
      unchecked {
        address operator = _operatorPods[pod][operatorIndex];
        // remove operator pod reference
        _bondedOperators[operator] = 0;
        uint256 lastIndex = _operatorPods[pod].length - 1;
        if (lastIndex != operatorIndex) {
          _operatorPods[pod][operatorIndex] = _operatorPods[pod][lastIndex];
        }
        delete _operatorPods[pod][lastIndex];
        _operatorPods[pod].pop();
      }
    }
  }

  function _bridge() private view returns (address bridge) {
    assembly {
      bridge := sload(_bridgeSlot)
    }
  }

  function _holograph() private view returns (address holograph) {
    assembly {
      holograph := sload(_holographSlot)
    }
  }

  function _interfaces() private view returns (IInterfaces interfaces) {
    assembly {
      interfaces := sload(_interfacesSlot)
    }
  }

  function _registry() private view returns (address registry) {
    assembly {
      registry := sload(_registrySlot)
    }
  }

  function _RBH(
    uint256 random,
    uint256 podSize,
    uint256 n
  ) private view returns (uint256) {
    unchecked {
      return (random + uint256(blockhash(block.number - n))) % podSize;
    }
  }

  function getLZEndpoint() external view returns (address lZEndpoint) {
    assembly {
      lZEndpoint := sload(_lZEndpointSlot)
    }
  }

  function setLZEndpoint(address lZEndpoint) external onlyAdmin {
    assembly {
      sstore(_lZEndpointSlot, lZEndpoint)
    }
  }

  function getBridge() external view returns (address bridge) {
    assembly {
      bridge := sload(_bridgeSlot)
    }
  }

  function setBridge(address bridge) external onlyAdmin {
    assembly {
      sstore(_bridgeSlot, bridge)
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

  function getJobDetails(bytes32 jobHash) public view returns (OperatorJob memory) {
    uint256 packed = _operatorJobs[jobHash];
    return
      OperatorJob(
        uint8(packed >> 248),
        uint16(_blockTime),
        _operatorTempStorage[uint32(packed >> 216)],
        uint40(packed >> 176),
        [
          uint16(packed >> 160),
          uint16(packed >> 144),
          uint16(packed >> 128),
          uint16(packed >> 112),
          uint16(packed >> 96)
        ]
      );
  }

  function getPodOperators(uint256 pod) external view returns (address[] memory) {
    return _operatorPods[pod];
  }

  function getPodBondAmount(uint256 pod) external view returns (uint256) {
    return (_podMultiplier**pod) * _baseBondAmount;
  }

  function bondUtilityToken(
    address operator,
    uint256 amount,
    uint256 pod
  ) external {
    require(_bondedOperators[operator] == 0, "HOLOGRAPH: operator is bonded");
    unchecked {
      require(((_podMultiplier**pod) * _baseBondAmount) <= amount, "HOLOGRAPH: bond amount too small");
      // subtract difference and only keep bond amount
      if (_operatorPods.length < pod + 1) {
        for (uint256 i = _operatorPods.length; i < pod + 1; i++) {
          _operatorPods.push([address(0)]);
        }
      }
      require(_operatorPods[pod].length < type(uint16).max, "HOLOGRAPH: too many operators");
      _operatorPods[pod].push(operator);
      _bondedOperators[operator] = pod + 1;
      _bondedAmounts[operator] = amount;
    }
  }
}
