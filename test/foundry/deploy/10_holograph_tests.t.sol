// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Constants, ErrorConstants} from "../utils/Constants.sol";
import {RandomAddress} from "../utils/Utils.sol";
import {Holograph} from "../../../src/Holograph.sol";
import {MockExternalCall} from "../../../src/mock/MockExternalCall.sol";

/**
 * @title Contract Test - Holograph
 * @notice This contract contains a series of tests to verify the functionality of the Holograph contract.
 * The tests cover the initialization process, getter functions, and setter functions.
 * @dev The tests include verifying initialization, admin functions, revert behaviors, and external contract interactions.
 * The tests check the validity of various contract slots like bridge, chainId, factory, interfaces, operator, registry,
 * treasury, and utilityToken.
 * The tests also verify that only the admin can alter certain contract slots, while non-owners trigger revert behaviors.
 * Translation of a suite of Hardhat tests found in test/10_holograph_tests.ts
 */

contract HolographTests is Test {
  address admin = vm.addr(1);
  address user = vm.addr(2);
  address origin = Constants.originAddress; //default address origin in foundry
  address deployer = Constants.getDeployer();
  bytes initCode;
  uint32 holographChainId;
  address bridge;
  address factory;
  address interfaces;
  address operator;
  address registry;
  address treasury;
  address utilityToken;
  Holograph holograph;
  MockExternalCall mockExternalCall;

  function setUp() public {
    // Deploy contracts
    vm.startPrank(deployer);
    holograph = new Holograph();
    mockExternalCall = new MockExternalCall();
    vm.stopPrank();

    holographChainId = 1;
    bridge = RandomAddress.randomAddress();
    factory = RandomAddress.randomAddress();
    interfaces = RandomAddress.randomAddress();
    operator = RandomAddress.randomAddress();
    registry = RandomAddress.randomAddress();
    treasury = RandomAddress.randomAddress();
    utilityToken = RandomAddress.randomAddress();

    bytes memory initCode = abi.encode(
      holographChainId,
      bridge,
      factory,
      interfaces,
      operator,
      registry,
      treasury,
      utilityToken
    );
    holograph.init(initCode);
  }

  /* -------------------------------------------------------------------------- */
  /*                                   INIT()                                   */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the initialization of the Holograph contract.
   * @dev This is a basic test to ensure the initialization process works as expected.
   * This test deploys a new instance of the Holograph contract, generates initialization code,
   * and initializes the contract with the provided parameters.
   * Refers to the hardhat test with the description 'should successfully init once'
   */
  function testInit() public {
    Holograph holographTest;
    holographTest = new Holograph();
    bytes memory initCode = abi.encode(
      holographChainId,
      bridge,
      factory,
      interfaces,
      operator,
      registry,
      treasury,
      utilityToken
    );
    holographTest.init(initCode);
  }

  /**
   * @notice Test the setAdmin function of the Holograph contract.
   * @dev This test is designed to verify the functionality of setting a new admin address in the contract.
   * The test performs a prank operation on the admin address using the VM and
   * sets a new admin address to the contract using the `setAdmin()` function.
   * This ensures that the admin address is updated as expected.
   * Refers to the hardhat test with the description 'should successfully init once'
   */
  function testSetAdmin() public {
    vm.prank(origin);
    holograph.setAdmin(admin);
    assertEq(holograph.getAdmin(), admin);
  }

  /**
   * @notice Test the revert behavior when trying to initialize an already initialized Holograph contract.
   * @dev This test is designed to verify that the contract reverts as expected when the contract has already been initialized.
   * This test expects a revert with the message 'HOLOGRAPH: already initialized' when trying to initialize
   * a Holograph contract that is already initialized.
   * Refers to the hardhat test with the description 'should fail to init if already initialized'
   */
  function testInitAlreadyInitializedRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ALREADY_INITIALIZED_ERROR_MSG));
    holograph.init(initCode);
  }

  /* -------------------------------------------------------------------------- */
  /*                                 GET BRIDGE                                 */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the validity of the bridge slot in the Holograph contract.
   * @dev This test is designed to ensure the correct functionality of the bridge slot in the contract.
   * This test verifies that the value returned by `getBridge()` in the Holograph contract
   * matches the expected `bridge` address.
   * Refers to the hardhat test with the description 'Should return valid _bridgeSlot'
   */
  function testReturnValidBridgeSlot() public view {
    assertEq(holograph.getBridge(), bridge);
  }

  /**
   * @notice Test the ability of an external contract to call the getBridge function in the Holograph contract.
   * @dev This test is designed to verify that an external contract can successfully call the getBridge
   * function in the Holograph contract.
   * This test encodes the signature of the getBridge function and calls it from an external contract
   * using mockExternalCall.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallGetBridge() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getBridge()");
    mockExternalCall.callExternalFn(address(holograph), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                                 SET BRIDGE                                 */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the ability of the admin to alter the bridge slot in the Holograph contract.
   * @dev This test is designed to verify that the admin can alter the bridge slot in the contract.
   * This test performs a prank operation on the current admin address of the Holograph contract,
   * and then sets a new random address as the bridge in the contract.
   * This ensures that the bridge is updated as expected.
   * Refers to the hardhat test with the description 'should allow admin to alter _bridgeSlot'
   */
  function testAllowAdminAlterBridgeSlot() public {
    address random = RandomAddress.randomAddress();
    vm.prank(origin);
    holograph.setBridge(random);
    assertEq(holograph.getBridge(), random);
  }

  /**
   * @notice Test the revert behavior when the owner tries to alter the bridge slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the bridge slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when the owner attempts to
   * alter the bridge slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow owner to alter _bridgeSlot'
   */
  function testAllowOwnerToAlterBridgeSlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holograph.setBridge(random);
  }

  /**
   * @notice Test the revert behavior when a non-owner tries to alter the bridge slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the bridge slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when a non-owner attempts to
   * alter the bridge slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow non-owner to alter _bridgeSlot'
   */
  function testAllowNonOwnerToAlterBridgeSlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(user);
    holograph.setBridge(random);
  }

  /* -------------------------------------------------------------------------- */
  /*                                 GET CHAINID                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the validity of the chainId slot in the Holograph contract.
   * @dev This test is designed to ensure the correct functionality of the chainId slot in the contract.
   * This test verifies that the value for chainId is correctly set in the initialization.
   * Refers to the hardhat test with the description 'Should return valid _chainIdSlot'
   */
  function testReturnValidChainIdSlot() public view {
    assertNotEq(holograph.getChainId(), 0);
  }

  /**
   * @notice Test the ability of an external contract to call the getChainId function in the Holograph contract.
   * @dev This test is designed to verify that an external contract can successfully call the getChainId
   * function in the Holograph contract.
   * This test encodes the signature of the getChainId function and calls it from an external contract
   * using mockExternalCall.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallGetChainID() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getChainId()");
    mockExternalCall.callExternalFn(address(holograph), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                                 GET CHAINID                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the ability of the admin to alter the chainId slot in the Holograph contract.
   * @dev This test is designed to verify that the admin can alter the chainId slot in the contract.
   * This test performs a prank operation on the current admin address of the Holograph contract,
   * and then sets a new random address as the chainId in the contract.
   * This ensures that the chainId is updated as expected.
   * Refers to the hardhat test with the description 'should allow admin to alter _chainIdSlot'
   */
  function testAllowAdminAlterChainIdSlot() public {
    vm.prank(origin);
    holograph.setChainId((2));
    assertEq(holograph.getChainId(), 2);
  }

  /**
   * @notice Test the revert behavior when the owner tries to alter the chainId slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the chainId slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when the owner attempts to
   * alter the chainId slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow owner to alter _chainIdSlot'
   */
  function testAllowOwnerAlterChainIdSlotRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holograph.setChainId(3);
  }

  /**
   * @notice Test the revert behavior when a non-owner tries to alter the chainId slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the chainId slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when a non-owner attempts to
   * alter the chainId slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow non-owner to alter _chainIdSlot'
   */
  function testAllowNonOwnerAlterChainIdSlotRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(user);
    holograph.setChainId(4);
  }

  /* -------------------------------------------------------------------------- */
  /*                                 GET FACTORY                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the validity of the factory slot in the Holograph contract.
   * @dev This test is designed to ensure the correct functionality of the factory slot in the contract.
   * This test verifies that the value returned by `getFactory()` in the Holograph contract
   * matches the expected `factory` address.
   * Refers to the hardhat test with the description 'Should return valid _factorySlot'
   */
  function testReturnValidFactorySlot() public view {
    assertEq(holograph.getFactory(), factory);
  }

  /**
   * @notice Test the ability of an external contract to call the getFactory function in the Holograph contract.
   * @dev This test is designed to verify that an external contract can successfully call the getFactory
   * function in the Holograph contract.
   * This test encodes the signature of the getFactory function and calls it from an external contract
   * using mockExternalCall.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'a
   */
  function testAllowExternalContractToCallGetFactory() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getFactory()");
    mockExternalCall.callExternalFn(address(holograph), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                                 SET FACTORY                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the ability of the admin to alter the factory slot in the Holograph contract.
   * @dev This test is designed to verify that the admin can alter the factory slot in the contract.
   * This test performs a prank operation on the current admin address of the Holograph contract,
   * and then sets a new random address as the factory in the contract.
   * This ensures that the factory is updated as expected.
   * Refers to the hardhat test with the description 'should allow admin to alter _factorySlot'
   */
  function testAllowAdminAlterFactorySlot() public {
    address random = RandomAddress.randomAddress();
    vm.prank(origin);
    holograph.setFactory(random);
    assertEq(holograph.getFactory(), random);
  }

  /**
   * @notice Test the revert behavior when the owner tries to alter the factory slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the factory slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when the owner attempts to
   * alter the factory slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow owner to alter _factorySlot'
   */
  function testAllowOwnerAlterFactorySlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holograph.setFactory(random);
  }

  /**
   * @notice Test the revert behavior when a non-owner tries to alter the factory slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the factory slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when a non-owner attempts to
   * alter the factory slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow non-owner to alter _factorySlot',
   */
  function testAllowNonOwnerAlterFactorySlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(user);
    holograph.setFactory(random);
  }

  /* -------------------------------------------------------------------------- */
  /*                            GET HOLOGRAPH CHAINID                           */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the validity of the holographChainId slot in the Holograph contract.
   * @dev This test is designed to ensure the correct functionality of the holographChainId slot in the contract.
   * This test verifies that the value returned by `getHolographChainId()` in the Holograph contract
   * matches the expected `holographChainId` address.
   * Refers to the hardhat test with the description 'Should return valid _holographChainIdSlot'
   */
  function testReturnValidHolographChainIdSlot() public view {
    assertEq(holograph.getHolographChainId(), holographChainId);
  }

  /**
   * @notice Test the ability of an external contract to call the getHolographChainId function in the Holograph contract.
   * @dev This test is designed to verify that an external contract can successfully call the getHolographChainId
   * function in the Holograph contract.
   * This test encodes the signature of the getHolographChainId function and calls it from an external contract
   * using mockExternalCall.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallGetHolographChainId() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getHolographChainId()");
    mockExternalCall.callExternalFn(address(holograph), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                            SET HOLOGRAPH CHAINID                           */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the ability of the admin to alter the holographChainId slot in the Holograph contract.
   * @dev This test is designed to verify that the admin can alter the holographChainId slot in the contract.
   * This test performs a prank operation on the current admin address of the Holograph contract,
   * and then sets a new random address as the holographChainId in the contract.
   * This ensures that the holograph chanId is updated as expected.
   * Refers to the hardhat test with the description 'should allow admin to alter _holographChainIdSlot'
   */
  function testAllowAdminAlterHolographChainIdSlot() public {
    vm.prank(origin);
    holograph.setHolographChainId(2);
    assertEq(holograph.getHolographChainId(), 2);
  }

  /**
   * @notice Test the revert behavior when the owner tries to alter the holographChainId slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the holographChainId slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when the owner attempts to
   * alter the holographChainId slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow owner to alter _holographChainIdSlot'
   */
  function testAllowOwnerAlterHolographChainIdSlotRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holograph.setHolographChainId(3);
  }

  /**
   * @notice Test the revert behavior when a non-owner tries to alter the holographChainId slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the holographChainId slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when a non-owner attempts to
   * alter the holographChainId slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow non-owner to alter _holographChainIdSlot'
   */
  function testAllowNonOwnerAlterHolographChainIdSlotRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(user);
    holograph.setHolographChainId(4);
  }

  /* -------------------------------------------------------------------------- */
  /*                               GET INTERFACES                               */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the validity of the interfaces slot in the Holograph contract.
   * @dev This test is designed to ensure the correct functionality of the interfaces slot in the contract.
   * This test verifies that the value returned by `getInterfaces()` in the Holograph contract
   * matches the expected `interfaces` address.
   * Refers to the hardhat test with the description 'Should return valid _interfacesSlot'
   */
  function testReturnValidInterfacesSlot() public view {
    assertEq(holograph.getInterfaces(), interfaces);
  }

  /**
   * @notice Test the ability of an external contract to call the getInterfaces function in the Holograph contract.
   * @dev This test is designed to verify that an external contract can successfully call the getInterfaces
   * function in the Holograph contract.
   * This test encodes the signature of the getInterfaces function and calls it from an external contract
   * using mockExternalCall.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallGetInterfaces() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getInterfaces()");
    mockExternalCall.callExternalFn(address(holograph), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                               SET INTERFACES                               */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the ability of the admin to alter the interfaces slot in the Holograph contract.
   * @dev This test is designed to verify that the admin can alter the interfaces slot in the contract.
   * This test performs a prank operation on the current admin address of the Holograph contract,
   * and then sets a new random address as the interfaces in the contract.
   * This ensures that the interfaces is updated as expected.
   * Refers to the hardhat test with the description 'should allow admin to alter _interfacesSlot'
   */
  function testAllowAdminAlterInterfacesSlot() public {
    address random = RandomAddress.randomAddress();
    vm.prank(origin);
    holograph.setInterfaces(random);
    assertEq(holograph.getInterfaces(), random);
  }

  /**
   * @notice Test the revert behavior when the owner tries to alter the interfaces slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the interfaces slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when the owner attempts to
   * alter the interfaces slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow owner to alter _interfacesSlot'
   */
  function testAllowOwnerAlterInterfacesSlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holograph.setInterfaces(random);
  }

  /**
   * @notice Test the revert behavior when a non-owner tries to alter the interfaces slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the interfaces slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when a non-owner attempts to
   * alter the interfaces slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow non-owner to alter _interfacesSlot'
   */
  function testAllowNonOwnerAlterInterfacesSlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(user);
    holograph.setInterfaces(random);
  }

  /* -------------------------------------------------------------------------- */
  /*                                GET OPERATOR                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the validity of the operator slot in the Holograph contract.
   * @dev This test is designed to ensure the correct functionality of the operator slot in the contract.
   * This test verifies that the value returned by `getOperator()` in the Holograph contract
   * matches the expected `operator` address.
   * Refers to the hardhat test with the description 'Should return valid _operatorSlot'
   */
  function testReturnValidOperatorSlot() public view {
    assertEq(holograph.getOperator(), operator);
  }

  /**
   * @notice Test the ability of an external contract to call the getOperator function in the Holograph contract.
   * @dev This test is designed to verify that an external contract can successfully call the getOperator
   * function in the Holograph contract.
   * This test encodes the signature of the getOperator function and calls it from an external contract
   * using mockExternalCall.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallGetOperator() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getOperator()");
    mockExternalCall.callExternalFn(address(holograph), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                                SET OPERATOR                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the ability of the admin to alter the operator slot in the Holograph contract.
   * @dev This test is designed to verify that the admin can alter the operator slot in the contract.
   * This test performs a prank operation on the current admin address of the Holograph contract,
   * and then sets a new random address as the operator in the contract.
   * This ensures that the operator is updated as expected.
   * Refers to the hardhat test with the description 'should allow admin to alter _operatorSlot'
   */
  function testAllowAdminAlterOperatorSlot() public {
    address random = RandomAddress.randomAddress();
    vm.prank(origin);
    holograph.setOperator(random);
    assertEq(holograph.getOperator(), random);
  }

  /**
   * @notice Test the revert behavior when the owner tries to alter the operator slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the operator slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when the owner attempts to
   * alter the operator slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow owner to alter _operatorSlot'
   */
  function testAllowOwnerAlterOperatorSlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holograph.setOperator(random);
  }

  /**
   * @notice Test the revert behavior when a non-owner tries to alter the operator slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the operator slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when a non-owner attempts to
   * alter the operator slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow non-owner to alter _operatorSlot'
   */
  function testAllowNonOwnerAlterOperatorSlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(user);
    holograph.setOperator(random);
  }

  /* -------------------------------------------------------------------------- */
  /*                                GET REGISTRY                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the validity of the registry slot in the Holograph contract.
   * @dev This test is designed to ensure the correct functionality of the registry slot in the contract.
   * This test verifies that the value returned by `getRegistry()` in the Holograph contract
   * matches the expected `registry` address.
   * Refers to the hardhat test with the description 'Should return valid _registrySlot'
   */
  function testReturnValidRegistrySlot() public view {
    assertEq(holograph.getRegistry(), registry);
  }

  /**
   * @notice Test the ability of an external contract to call the getRegistry function in the Holograph contract.
   * @dev This test is designed to verify that an external contract can successfully call the getRegistry
   * function in the Holograph contract.
   * This test encodes the signature of the getRegistry function and calls it from an external contract
   * using mockExternalCall.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallGetRegistry() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getRegistry()");
    mockExternalCall.callExternalFn(address(holograph), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                                SET REGISTRY                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the ability of the admin to alter the registry slot in the Holograph contract.
   * @dev This test is designed to verify that the admin can alter the registry slot in the contract.
   * This test performs a prank operation on the current admin address of the Holograph contract,
   * and then sets a new random address as the registry in the contract.
   * This ensures that the registry is updated as expected.
   * Refers to the hardhat test with the description 'should allow admin to alter _registrySlot'
   */
  function testAllowAdminAlterRegistrySlot() public {
    address random = RandomAddress.randomAddress();
    vm.prank(origin);
    holograph.setRegistry(random);
    assertEq(holograph.getRegistry(), random);
  }

  /**
   * @notice Test the revert behavior when the owner tries to alter the registry slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the registry slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when the owner attempts to
   * alter the registry slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow owner to alter _registrySlot'
   */
  function testAllowOwnerAlterRegistrySlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holograph.setRegistry(random);
  }

  /**
   * @notice Test the revert behavior when a non-owner tries to alter the registry slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the registry slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when a non-owner attempts to
   * alter the registry slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow non-owner to alter _registrySlot'
   */
  function testAllowNonOwnerAlterRegistrySlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(user);
    holograph.setRegistry(random);
  }

  /* -------------------------------------------------------------------------- */
  /*                                GET TREASURY                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the validity of the treasury slot in the Holograph contract.
   * @dev This test is designed to ensure the correct functionality of the treasury slot in the contract.
   * This test verifies that the value returned by `getTreasury()` in the Holograph contract
   * matches the expected `treasury` address.
   * Refers to the hardhat test with the description 'Should return valid _treasurySlot'
   */
  function testReturnValidTreasurySlot() public view {
    assertEq(holograph.getTreasury(), treasury);
  }

  /**
   * @notice Test the ability of an external contract to call the getTreasury function in the Holograph contract.
   * @dev This test is designed to verify that an external contract can successfully call the getTreasury
   * function in the Holograph contract.
   * This test encodes the signature of the getTreasury function and calls it from an external contract
   * using mockExternalCall.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallGetTreasury() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getTreasury()");
    mockExternalCall.callExternalFn(address(holograph), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                                SET TREASURY                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the ability of the admin to alter the treasury slot in the Holograph contract.
   * @dev This test is designed to verify that the admin can alter the treasury slot in the contract.
   * This test performs a prank operation on the current admin address of the Holograph contract,
   * and then sets a new random address as the treasury in the contract.
   * This ensures that the treasury is updated as expected.
   * Refers to the hardhat test with the description 'should allow admin to alter _treasurySlot'
   */
  function testAllowAdminAlterTreasurySlot() public {
    address random = RandomAddress.randomAddress();
    vm.prank(origin);
    holograph.setTreasury(random);
    assertEq(holograph.getTreasury(), random);
  }

  /**
   * @notice Test the revert behavior when the owner tries to alter the treasury slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the treasury slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when the owner attempts to
   * alter the treasury slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow owner to alter _treasurySlot'
   */
  function testAllowOwnerAlterTreasurySlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holograph.setTreasury(random);
  }

  /**
   * @notice Test the revert behavior when a non-owner tries to alter the treasury slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the treasury slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when a non-owner attempts to
   * alter the treasury slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow non-owner to alter _treasurySlot'
   */
  function testAllowNonOwnerAlterTreasurySlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(user);
    holograph.setTreasury(random);
  }

  /* -------------------------------------------------------------------------- */
  /*                              GET UTILITY TOKEN                             */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the validity of the utilityToken slot in the Holograph contract.
   * @dev This test is designed to ensure the correct functionality of the utilityToken slot in the contract.
   * This test verifies that the value returned by `getUtilityToken()` in the Holograph contract
   * matches the expected `utilityToken` address.
   * Refers to the hardhat test with the description 'Should return valid _utilityTokenSlot'
   */
  function testReturnValidUtilityTokenSlot() public view {
    assertEq(holograph.getUtilityToken(), utilityToken);
  }

  /**
   * @notice Test the ability of an external contract to call the getUtilityToken function in the Holograph contract.
   * @dev This test is designed to verify that an external contract can successfully call the getUtilityToken
   * function in the Holograph contract.
   * This test encodes the signature of the getUtilityToken function and calls it from an external contract
   * using mockExternalCall.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallGetUtilityToken() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getUtilityToken()");
    mockExternalCall.callExternalFn(address(holograph), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                              SET UTILITY TOKEN                             */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the ability of the admin to alter the utilityToken slot in the Holograph contract.
   * @dev This test is designed to verify that the admin can alter the utilityToken slot in the contract.
   * This test performs a prank operation on the current admin address of the Holograph contract,
   * and then sets a new random address as the utilityToken in the contract.
   * This ensures that the utility token is updated as expected.
   * Refers to the hardhat test with the description 'should allow admin to alter _utilityTokenSlot'
   */
  function testAllowAdminAlterUtilityTokenSlot() public {
    address random = RandomAddress.randomAddress();
    vm.prank(origin);
    holograph.setUtilityToken(random);
    assertEq(holograph.getUtilityToken(), random);
  }

  /**
   * @notice Test the revert behavior when the owner tries to alter the utilityToken slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the utilityToken slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when the owner attempts to
   * alter the utilityToken slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow owner to alter _utilityTokenSlot'
   */
  function testAllowOwnerAlterUtilityTokenSlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holograph.setUtilityToken(random);
  }

  /**
   * @notice Test the revert behavior when a non-owner tries to alter the utilityToken slot in the Holograph contract.
   * @dev This test is designed to verify that only the admin can alter the utilityToken slot in the contract.
   * This test expects a revert with the message 'HOLOGRAPH: admin only function' when a non-owner attempts to
   * alter the utilityToken slot in the Holograph contract.
   * Refers to the hardhat test with the description 'should fail to allow non-owner to alter _utilityTokenSlot'
   */
  function testAllowNonOwnerAlterUtilityTokenSlotRevert() public {
    address random = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(user);
    holograph.setUtilityToken(random);
  }
}
