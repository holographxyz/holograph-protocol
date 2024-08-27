// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {RandomAddress} from "../utils/Utils.sol";
import {Constants, ErrorConstants} from "../utils/Constants.sol";
import {MockExternalCall} from "../../../src/mock/MockExternalCall.sol";
import {HolographTreasury} from "../../../src/HolographTreasury.sol";

/**
 * @title Testing the Holograph Treasury
 * @notice Suite of unit tests for the Holograph Treasury contract
 * @dev Translation of a suite of Hardhat tests found in test/16_holograph_treasury_tests.ts
 */

contract HolographTreasuryTests is Test {
  address bridgeMock = RandomAddress.randomAddress();
  address holographMock = RandomAddress.randomAddress();
  address operatorMock = RandomAddress.randomAddress();
  address registryMock = RandomAddress.randomAddress();
  address newBridgeAdd = RandomAddress.randomAddress();
  address newHolographAdd = RandomAddress.randomAddress();
  address newOperatorAdd = RandomAddress.randomAddress();
  address newRegistryAdd = RandomAddress.randomAddress();
  address commonUser = RandomAddress.randomAddress();
  address origin = Constants.originAddress;
  HolographTreasury holographTreasury;
  HolographTreasury holographTreasuryInit;
  HolographTreasury holographTreasuryInitExternal;
  MockExternalCall mockExternalCall;
  bytes initPayload = abi.encode(bridgeMock, holographMock, operatorMock, registryMock);

  /**
   * @notice Sets up the initial state for the tests
   * @dev This function initializes the necessary contracts and variables for the tests to run.
   * It performs the following actions:
   * 1. Deploys a new instance of  HolographTreasury and MockExternalCall contracts.
   * 2. Initializes the HolographTreasury contract with the `initPayload`.
   */
  function setUp() public {
    holographTreasury = new HolographTreasury();
    mockExternalCall = new MockExternalCall();
    vm.prank(origin);
    holographTreasury.init(initPayload);
  }

  /* -------------------------------------------------------------------------- */
  /*                                    INIT                                    */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests that the `HolographTreasury` contract is successfully initialized once
   * @dev This test verifies that the `HolographTreasury` contract is correctly initialized
   * with the provided `initPayload`.
   * Refers to the hardhat test with the description 'should successfully be initialized once'
   */
  function testSuccessfullyInitialiceOnce() public {
    holographTreasuryInit = new HolographTreasury();
    holographTreasuryInit.init(initPayload);
  }

  /**
   * @notice Tests that the `init` function reverts if the contract is already initialized
   * @dev This test verifies that the `init` function of the `HolographTreasury` contract
   * reverts when called on a contract that has already been initialized.
   * Refers to the hardhat test with the description 'should fail if already initialized'
   */
  function testIfAlreadyInitializedRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ALREADY_INITIALIZED_ERROR_MSG));
    holographTreasury.init(initPayload);
  }

  /**
   * @notice Tests that an external contract can call the `init` function of the HolographTreasury contract
   * @dev This test verifies that an external contract (in this case, the `mockExternalCall` contract) can
   * successfully call the `init` function of the HolographTreasury contract. It first deploys a new instance
   * of the HolographTreasury contract, encodes the `init` function call with the `initPayload`, and then
   * calls the `init` function through the `mockExternalCall` contract. Finally, it asserts that the contract's
   * state variables (Holograph, Operator, Registry, and Bridge) are correctly set.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFn() public {
    holographTreasuryInitExternal = new HolographTreasury();
    bytes memory encodedFunctionData = abi.encodeWithSignature("init(bytes)", initPayload);
    mockExternalCall.callExternalFn(address(holographTreasuryInitExternal), encodedFunctionData);
    assertEq(holographTreasury.getHolograph(), holographMock);
    assertEq(holographTreasury.getOperator(), operatorMock);
    assertEq(holographTreasury.getRegistry(), registryMock);
    assertEq(holographTreasury.getBridge(), bridgeMock);
  }

  /* -------------------------------------------------------------------------- */
  /*                              AFTER INITIALIZED                             */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests that the `_bridge` function is private
   * @dev This test verifies that the `_bridge` function of the `HolographTreasury` contract reverts
   * when called from outside the contract. It encodes the function call using `abi.encodeWithSignature`
   *  and expects the call to revert.
   * Refers to the hardhat test with the description `_bridge()`
   */
  function testIfIsPrivateBridge() public {
    bytes memory encodedFunctionData = abi.encodeWithSignature("_bridge()");
    vm.expectRevert();
    address(holographTreasury).call(encodedFunctionData);
  }

  /**
   * @notice Tests that the `_holograph` function is private
   * @dev This test verifies that the `_holograph` function of the `HolographTreasury` contract reverts
   * when called from outside the contract. It encodes the function call using `abi.encodeWithSignature`
   *  and expects the call to revert.
   * Refers to the hardhat test with the description `_holograph()`
   */
  function testIfIsPrivateHolograph() public {
    bytes memory encodedFunctionData = abi.encodeWithSignature("_holograph()");
    vm.expectRevert();
    address(holographTreasury).call(encodedFunctionData);
  }

  /**
   * @notice Tests that the `_operator` function is private
   * @dev This test verifies that the `_operator` function of the `HolographTreasury` contract reverts
   * when called from outside the contract. It encodes the function call using `abi.encodeWithSignature`
   *  and expects the call to revert.
   * Refers to the hardhat test with the description `_operator()`
   */
  function testIfIsPrivateOperator() public {
    bytes memory encodedFunctionData = abi.encodeWithSignature("_operator()");
    vm.expectRevert();
    address(holographTreasury).call(encodedFunctionData);
  }

  /**
   * @notice Tests that the `_registry` function is private
   * @dev This test verifies that the `_registry` function of the `HolographTreasury` contract reverts
   * when called from outside the contract. It encodes the function call using `abi.encodeWithSignature`
   *  and expects the call to revert.
   * Refers to the hardhat test with the description `_registry()`
   */
  function testIfIsPrivateRegistry() public {
    bytes memory encodedFunctionData = abi.encodeWithSignature("_registry()");
    vm.expectRevert();
    address(holographTreasury).call(encodedFunctionData);
  }

  /* -------------------------------------------------------------------------- */
  /*                                 getBridge()                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests that the `getBridge` function returns a valid bridge slot
   * @dev This test verifies that the `getBridge` function of the `HolographTreasury`
   * contract returns the expected bridge slot.
   * Refers to the hardhat test with the description 'Should return valid _bridgeSlot'
   */
  function testReturnValidBridgeSlot() public view {
    assertEq(holographTreasury.getBridge(), bridgeMock);
  }

  /**
   * @notice Tests that an external contract can call the `getBridge` function
   * @dev This test verifies that an external contract (in this case, the `mockExternalCall` contract)
   * can successfully call the `getBridge` function of the `HolographTreasury` contract.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnGetBridge() public {
    holographTreasuryInitExternal = new HolographTreasury();
    bytes memory encodedFunctionData = abi.encodeWithSignature("getBridge()");
    mockExternalCall.callExternalFn(address(holographTreasuryInitExternal), encodedFunctionData);
  }

  /* -------------------------------------------------------------------------- */
  /*                                 setBridge()                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests that an admin can alter the bridge slot
   * @dev This test verifies that an admin can successfully alter the bridge slot by
   * calling the `setBridge` function.
   * Refers to the hardhat test with the description 'should allow admin to alter _bridgeSlot'
   */
  function testAllowAdminToAlterBridgeSlot() public {
    vm.prank(origin);
    holographTreasury.setBridge(newBridgeAdd);
    assertEq(holographTreasury.getBridge(), newBridgeAdd);
  }

  /**
   * @notice Tests that a non-admin cannot alter the bridge slot
   * @dev This test verifies that a non-admin cannot alter the bridge slot by calling the `setBridge`
   * function. It expects the function to revert with an error message indicating that the function
   * is only accessible to admins.
   * Refers to the hardhat test with the description 'should fail to allow non-admin to alter _bridgeSlot'
   */
  function testAllowNonAdminToAlterBridgeSlotRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(commonUser);
    holographTreasury.setBridge(newBridgeAdd);
  }

  /* -------------------------------------------------------------------------- */
  /*                               getHolograph()                               */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests that the `getHolograph` function returns a valid holograph slot
   * @dev This test verifies that the `getHolograph` function of the `HolographTreasury`
   * contract returns the expected holograph slot.
   * Refers to the hardhat test with the description 'Should return valid _holographSlot'
   */
  function testReturnValidHolographSlot() public view {
    assertEq(holographTreasury.getHolograph(), holographMock);
  }

  /**
   * @notice Tests that an external contract can call the `getHolograph` function
   * @dev This test verifies that an external contract (in this case, the `mockExternalCall` contract)
   * can successfully call the `getHolograph` function of the `HolographTreasury` contract.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnGetHolograph() public {
    holographTreasuryInitExternal = new HolographTreasury();
    bytes memory encodedFunctionData = abi.encodeWithSignature("getHolograph()");
    mockExternalCall.callExternalFn(address(holographTreasuryInitExternal), encodedFunctionData);
  }

  /* -------------------------------------------------------------------------- */
  /*                               setHolograph()                               */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests that an admin can alter the holograph slot
   * @dev This test verifies that an admin can successfully alter the holograph slot by
   * calling the `setHolograph` function.
   * Refers to the hardhat test with the description 'should allow admin to alter _holographSlot'
   */
  function testAllowAdminToAlterHolographSlot() public {
    vm.prank(origin);
    holographTreasury.setHolograph(newHolographAdd);
    assertEq(holographTreasury.getHolograph(), newHolographAdd);
  }

  /**
   * @notice Tests that a non-admin cannot alter the holograph slot
   * @dev This test verifies that a non-admin cannot alter the holograph slot by calling the `setHolograph`
   * function. It expects the function to revert with an error message indicating that the function
   * is only accessible to admins.
   * Refers to the hardhat test with the description 'should fail to allow non-admin to alter _holographSlot'
   */
  function testAllowNonAdminToAlterHolographSlotRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(commonUser);
    holographTreasury.setHolograph(newHolographAdd);
  }

  /* -------------------------------------------------------------------------- */
  /*                                getOperator()                               */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests that the `getOperator` function returns a valid operator slot
   * @dev This test verifies that the `getOperator` function of the `HolographTreasury`
   * contract returns the expected operator slot.
   * Refers to the hardhat test with the description 'Should return valid _operatorSlot'
   */
  function testReturnValidOperatorSlot() public view {
    assertEq(holographTreasury.getOperator(), operatorMock);
  }

  /**
   * @notice Tests that an external contract can call the `getOperator` function
   * @dev This test verifies that an external contract (in this case, the `mockExternalCall` contract)
   * can successfully call the `getOperator` function of the `HolographTreasury` contract.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnGetOperator() public {
    holographTreasuryInitExternal = new HolographTreasury();
    bytes memory encodedFunctionData = abi.encodeWithSignature("getOperator()");
    mockExternalCall.callExternalFn(address(holographTreasuryInitExternal), encodedFunctionData);
  }

  /* -------------------------------------------------------------------------- */
  /*                               setOperator()                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests that an admin can alter the operator slot
   * @dev This test verifies that an admin can successfully alter the operator slot by
   * calling the `getOperator` function.
   * Refers to the hardhat test with the description 'should allow admin to alter _operatorSlot'
   */
  function testAllowAdminToAlterOperatorSlot() public {
    vm.prank(origin);
    holographTreasury.setOperator(newOperatorAdd);
    assertEq(holographTreasury.getOperator(), newOperatorAdd);
  }

  /**
   * @notice Tests that a non-admin cannot alter the operator slot
   * @dev This test verifies that a non-admin cannot alter the operator slot by calling the `setOperator`
   * function. It expects the function to revert with an error message indicating that the function
   * is only accessible to admins.
   * Refers to the hardhat test with the description 'should fail to allow non-admin to alter _operatorSlot'
   */
  function testAllowNonAdminToAlterOperatorSlotRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(commonUser);
    holographTreasury.setOperator(newOperatorAdd);
  }

  /* -------------------------------------------------------------------------- */
  /*                                getRegistry()                               */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests that the `getRegistry` function returns a valid registry slot
   * @dev This test verifies that the `getRegistry` function of the `HolographTreasury`
   * contract returns the expected registry slot.
   * Refers to the hardhat test with the description 'Should return valid _registrySlot'
   */

  function testReturnValidRegistrySlot() public view {
    assertEq(holographTreasury.getRegistry(), registryMock);
  }

  /**
   * @notice Tests that an external contract can call the `getRegistry` function
   * @dev This test verifies that an external contract (in this case, the `mockExternalCall` contract)
   * can successfully call the `getRegistry` function of the `HolographTreasury` contract.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnGetRegistry() public {
    holographTreasuryInitExternal = new HolographTreasury();
    bytes memory encodedFunctionData = abi.encodeWithSignature("getRegistry()");
    mockExternalCall.callExternalFn(address(holographTreasuryInitExternal), encodedFunctionData);
  }

  /* -------------------------------------------------------------------------- */
  /*                               setRegistry()                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests that an admin can alter the registry slot
   * @dev This test verifies that an admin can successfully alter the registry slot by
   * calling the `setRegistry` function.
   * Refers to the hardhat test with the description 'should allow admin to alter _registrySlot'
   */
  function testAtllowAdminToAlterRegistrySlot() public {
    vm.prank(origin);
    holographTreasury.setRegistry(newRegistryAdd);
    assertEq(holographTreasury.getRegistry(), newRegistryAdd);
  }

  /**
   * @notice Tests that a non-admin cannot alter the registry slot
   * @dev This test verifies that a non-admin cannot alter the registry slot by calling the `setRegistry`
   * function. It expects the function to revert with an error message indicating that the function
   * is only accessible to admins.
   * Refers to the hardhat test with the description 'should fail to allow non-admin to alter _registrySlot'
   */
  function testAllowNonAdminToAlterRegistrySlotRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(commonUser);
    holographTreasury.setRegistry(newRegistryAdd);
  }
}
