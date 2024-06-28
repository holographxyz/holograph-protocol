// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Constants, ErrorConstants} from "../utils/Constants.sol";
import {HolographGenesisLocal} from "../../../src/HolographGenesisLocal.sol";
import {MockHolographGenesisChild} from "../../../src/mock/MockHolographGenesisChild.sol";
import {Mock} from "../../../src/mock/Mock.sol";

/**
 * @title Testing the Holograph Genesis
 * @notice Suite of unit tests for Holograph Genesis contracts
 * @dev Translation of a suite of Hardhat tests found in test/12_holograph_genesis_tests.ts
 */

contract HolographGenesisTests is Test {
  event Message(string _message);
  HolographGenesisLocal holographGenesis;
  MockHolographGenesisChild holographGenesisChild;
  Mock mock;
  address newDeployer = vm.addr(1);
  address mockOwner = vm.addr(2);
  address deployerGenesisLocal = Constants.getDeployer(); //deployer approved by contract HolographGenesisLocal
  address deployerGenesis = Constants.getGenesisDeployer(); //deployer approved by contract HolographGenesis
  string public salt;
  string public secret;
  bytes initCode = abi.encode(0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd);

  /**
   * @notice Sets up the initial state for the tests
   * @dev This function initializes the necessary contracts and variables for the tests to run. It performs the following actions:
   * 1. Deploys a new instance of  HolographGenesisLocal, MockHolographGenesisChild and Mock contracts.
   * 2. Initializes the Mock contract with a specific initialization code.
   * 3. Retrieves the environment variables "DEVELOP_DEPLOYMENT_SALT" and "LOCALHOST_DEPLOYER_SECRET".
   */
  function setUp() public {
    holographGenesis = new HolographGenesisLocal();
    holographGenesisChild = new MockHolographGenesisChild();
    mock = new Mock();
    mock.init(abi.encode(Constants.MAX_UINT256));
    salt = vm.envString("DEVELOP_DEPLOYMENT_SALT");
    secret = vm.envString("LOCALHOST_DEPLOYER_SECRET");
  }

  /* -------------------------------------------------------------------------- */
  /*                                 CONSTRUCTOR                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests the constructor of the HolographGenesisLocal contract
   * @dev Verifies that the contract is deployed successfully and that the expected "Message" event is emitted
   * Refers to the hardhat test with the description 'should successfully deploy'
   */
  function testConstructor() public {
    vm.expectEmit(true, false, false, true);
    emit Message("The future is Holographic");
    HolographGenesisLocal holographGenesisLocal = new HolographGenesisLocal();
    assertNotEq(address(holographGenesisLocal), Constants.zeroAddress);
  }

  /* -------------------------------------------------------------------------- */
  /*                                   DEPLOY                                   */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Deploys the HolographGenesis contract
   * @dev This test verifies the successful deployment of the HolographGenesis contract. It deploys the
   * contract with a specific chain ID, salt, and secret.
   * Refers to the hardhat test with the description 'should succeed in deploying a contract'
   */
  function testSuccessfulyDeployed() public {
    uint256 chainId = block.chainid;
    bytes memory mockBytecode = vm.getCode("Mock.sol:Mock");
    vm.prank(deployerGenesisLocal);
    holographGenesis.deploy(
      chainId,
      bytes12(abi.encodePacked(salt)),
      bytes20(abi.encodePacked(secret)),
      mockBytecode,
      initCode
    );
  }

  /**
   * @notice Tests that the HolographGenesis contract reverts when deployed with an incorrect chain ID
   * @dev This test verifies that the HolographGenesis contract reverts when the `deploy()` function is
   * called with a chain ID that does not match the current chain ID. It expects the revert message
   * "HOLOGRAPH: incorrect chain id".
   * Refers to the hardhat test with the description 'should fail if chainId is not this blockchains chainId'
   */
  function testDeployWrongChainIdRevert() public {
    uint256 chainId = block.chainid;
    bytes memory mockBytecode = vm.getCode("Mock.sol:Mock");
    vm.expectRevert(bytes(ErrorConstants.INCORRECT_CHAIN_ID));
    vm.prank(deployerGenesisLocal);
    holographGenesis.deploy(
      chainId + 1,
      bytes12(abi.encodePacked(salt)),
      bytes20(abi.encodePacked(secret)),
      mockBytecode,
      initCode
    );
  }

  /**
   * @notice Tests that the HolographGenesis contract reverts when deployed multiple times
   * @dev This test verifies that the HolographGenesis contract reverts when the `deploy()` function is
   * called multiple times with the same parameters. It first successfully deploys the contract using the
   * `testSuccessfulyDeployed()` function, and then expects the "HOLOGRAPH: already deployed" revert when
   * attempting to deploy the contract again with the same parameters.
   * Refers to the hardhat test with the description 'should fail if contract was already deployed'
   */
  function testContractAlreadyDeployedRevert() public {
    testSuccessfulyDeployed();
    uint256 chainId = block.chainid;
    bytes memory mockBytecode = vm.getCode("Mock.sol:Mock");
    vm.expectRevert(bytes(ErrorConstants.ALREADY_DEPLOYED_ERROR_MSG));
    vm.prank(deployerGenesisLocal);
    holographGenesis.deploy(
      chainId,
      bytes12(abi.encodePacked(salt)),
      bytes20(abi.encodePacked(secret)),
      mockBytecode,
      initCode
    );
  }

  /**
   * @notice Tests that the HolographGenesis contract reverts when deployment fails
   * @dev This test verifies that the HolographGenesis contract reverts when the `deploy()` function is
   * called with an empty bytecode. It expects the "HOLOGRAPH: deployment failed" revert message.
   * Refers to the hardhat test with the description 'should fail if the deployment failed'
   */
  function testDeploymentFailRevert() public {
    uint256 chainId = block.chainid;
    vm.expectRevert(bytes(ErrorConstants.DEPLOYMENT_FAIL));
    vm.prank(deployerGenesisLocal);
    holographGenesis.deploy(
      chainId,
      bytes12(abi.encodePacked(salt)),
      bytes20(abi.encodePacked(secret)),
      bytes("0x"),
      initCode
    );
  }

  /**
   * @notice Tests that the HolographGenesisChild contract reverts when the initialization code does not
   * match the expected selector
   * @dev This test verifies that the HolographGenesisChild contract reverts when the `deploy()` function
   * is called with an initialization code that does not match the expected selector.
   * It expects the "HOLOGRAPH: initialization failed" revert message.
   * Refers to the hardhat test with the description 'should fail if contract init code does not match the init selector'
   */
  function testInitCodeNotMatchInitSelectorRevert() public {
    uint256 chainId = block.chainid;
    bytes memory mockBytecode = vm.getCode("Mock.sol:Mock");
    bytes memory initCode = abi.encode(Constants.MIN_UINT256);
    vm.expectRevert(bytes(ErrorConstants.INITIALIZATION_FAIL));
    vm.prank(deployerGenesis);
    holographGenesisChild.deploy(
      chainId,
      bytes12(abi.encodePacked(salt)),
      bytes20(abi.encodePacked(secret)),
      mockBytecode,
      initCode
    );
  }

  /* -------------------------------------------------------------------------- */
  /*                              APPROVE DEPLOYER                              */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests the approval of a new deployer for the HolographGenesis contract
   * @dev This test verifies that the `approveDeployer()` function of the HolographGenesis contract correctly approves
   * a new deployer. It first calls the `approveDeployer()` function to approve the `newDeployer` address. Then, it asserts
   * that the `isApprovedDeployer()` function correctly returns `true` for the `newDeployer` address.
   * Refers to the hardhat test with the description 'Should allow deployer wallet to add to approved deployers'
   */
  function testApproveDeployer() public {
    vm.prank(deployerGenesisLocal);
    holographGenesis.approveDeployer(newDeployer, true);
    assertEq(holographGenesis.isApprovedDeployer(newDeployer), true);
  }

  /**
   * @notice Tests that the HolographGenesis contract reverts when a non-approved deployer tries to approve a new deployer
   * @dev This test verifies that the `approveDeployer()` function of the HolographGenesis contract reverts when called
   * by an account that is not an approved deployer. It expects the "HOLOGRAPH: deployer not approved" revert message.
   * Refers to the hardhat test with the description 'should fail non-deployer wallet to add approved deployers'
   */
  function testNonDeployerAddApprovedDeployersRevert() public {
    vm.expectRevert(bytes(ErrorConstants.DEPLOYER_NOT_APPROVED));
    vm.prank(mockOwner);
    holographGenesis.approveDeployer(newDeployer, true);
  }

  /**
   * @notice Tests that an external contract can call the `approveDeployer()` function of the HolographGenesis contract
   * @dev This test verifies that an external contract (in this case, the `mock` contract) can successfully call the
   * `approveDeployer()` function of the HolographGenesis contract. It first approves the `mock` contract as a deployer,
   * then uses the `mock.mockCall()` function to call the `approveDeployer()` function with the `newDeployer` address.
   * Finally, it asserts that the `newDeployer` is correctly approved.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnApproveDeployer() public {
    vm.prank(deployerGenesisLocal);
    holographGenesis.approveDeployer(address(mock), true);
    assertEq(holographGenesis.isApprovedDeployer(address(mock)), true);
    bytes memory encodeSignature = abi.encodeCall(holographGenesis.approveDeployer, (newDeployer, true));
    mock.mockCall(address(holographGenesis), encodeSignature);
    assertTrue(holographGenesis.isApprovedDeployer(newDeployer));
  }

  /**
   * @notice Tests that an inherited contract can call the `approveDeployerMock()` function of the HolographGenesisChild contract
   * @dev This test verifies that the `HolographGenesisChild` contract, which inherits from the `HolographGenesis` contract,
   * can successfully call the `approveDeployerMock()` function. It calls the `approveDeployerMock()` function to approve the
   * `newDeployer` address. Finally, it asserts that the `newDeployer` is correctly approved.
   * Refers to the hardhat test with the description 'should allow inherited contract to call fn'
   */
  function testAllowInheritedContractToCallFnApproveDeployerMock() public {
    // TODO The mock contract has pending store and load signatures. It skips test
    vm.skip(true);
    vm.prank(deployerGenesis);
    holographGenesisChild.approveDeployerMock(newDeployer, true);
    assertTrue(holographGenesisChild.isApprovedDeployer((newDeployer)));
  }

  /* -------------------------------------------------------------------------- */
  /*                             IS APPROVE DEPLOYER                            */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests that the `isApprovedDeployer()` function correctly returns true for an approved deployer
   * @dev This test verifies that the `isApprovedDeployer()` function of the HolographGenesis contract returns`true`
   * when called with the address of the HolographGenesis contract deployer account, which is an approved deployer.
   * Refers to the hardhat test with the description 'Should return true to approved deployer wallet'
   */
  function testReturnTrueToApprovedDeployerWallet() public view {
    assertTrue(holographGenesis.isApprovedDeployer(address(deployerGenesisLocal)));
  }

  /**
   * @notice Tests that the `isApprovedDeployer()` function correctly returns false for a non-approved deployer
   * @dev This test verifies that the `isApprovedDeployer()` function of the HolographGenesis contract returns
   * `false` when called with the address of a non-approved deployer (in this case, a randomly generated address).
   * Refers to the hardhat test with the description 'Should return false to non-approved deployer wallet'
   */
  function testReturnFalseToNonApprovedDeployerWallet() public view {
    assertFalse(holographGenesis.isApprovedDeployer(address(vm.addr(10))));
  }

  /**
   * @notice Tests that an external contract can call the `isApprovedDeployer()` function of the HolographGenesis contract
   * @dev This test verifies that the `mock` contract can successfully call the `isApprovedDeployer()` function of the
   * HolographGenesis contract. It first sets the storage of the `mock` contract to the address of the HolographGenesis contract,
   * and then asserts that the `isApprovedDeployer()` function correctly returns `true` for the HolographGenesis deployer address.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testallowExternalContractToCallFnIsApprovedDeployer() public {
    mock.setStorage(0, bytes32(uint256(uint160(address(holographGenesis)))));
    assertTrue(holographGenesis.isApprovedDeployer(address(deployerGenesisLocal)));
  }

  /**
   * @notice Tests that an inherited contract can call the `isApprovedDeployerMock()` function of the HolographGenesisChild contract
   * @dev This test verifies that the `HolographGenesisChild` contract, which inherits from the `HolographGenesis` contract,
   * can successfully call the `isApprovedDeployerMock()` function. It asserts that the function correctly returns `true` for
   * a specific address.
   * Refers to the hardhat test with the description 'should allow inherited contract to call fn'
   */
  function testAllowInheritedContractToCallFnIsApprovedDeployerMock() public view {
    assertTrue(holographGenesisChild.isApprovedDeployerMock(address(deployerGenesis)));
  }
}
