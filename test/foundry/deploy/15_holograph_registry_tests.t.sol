// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Constants, ErrorConstants} from "../utils/Constants.sol";
import {RandomAddress} from "../utils/Utils.sol";
import {Holograph} from "../../../src/Holograph.sol";
import {Holographer} from "../../../src/enforcer/Holographer.sol";
import {HolographRegistry} from "../../../src/HolographRegistry.sol";
import {MockExternalCall} from "../../../src/mock/MockExternalCall.sol";
import {HolographERC721} from "../../../src/enforcer/HolographERC721.sol";
import {HolographERC20} from "../../../src/enforcer/HolographERC20.sol";
import {DeploymentConfig} from "../../../src/struct/DeploymentConfig.sol";
import {HelperDeploymentConfig} from "../utils/HelperDeploymentConfig.sol";

/**
 * @title Testing the Holograph Registry
 * @notice Suite of unit tests for the Holograph Registry contract
 * @dev Translation of a suite of Hardhat tests found in test/15_holograph_registry_test.ts
 */

contract HolographRegistryTests is Test {
  uint256 localHostFork;
  string LOCALHOST_RPC_URL = vm.envString("LOCALHOST_RPC_URL");
  Holograph holograph;
  HolographRegistry holographRegistry;
  HolographRegistry holographRegistryNew;
  HolographRegistry registryDeployedByScript;
  MockExternalCall mockExternalCall;
  HolographERC721 holographERC721;
  HolographERC20 holographERC20;
  Holographer sampleErc721Holographer;

  address deployer = Constants.getDeployer();
  address zeroAddress = Constants.zeroAddress;
  address origin = Constants.originAddress;
  address constant mockAddress = 0xeB721f3E4C45a41fBdF701c8143E52665e67c76b;
  address constant utilityTokenAddress = 0x4b02422DC46bb21D657A701D02794cD3Caeb17d0;
  address constant hTokenAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
  uint32 constant validChainId = 5;
  uint32 constant invalidChainId = 0;
  uint16 constant expectedHolographableContractsCount = 6;
  bytes32 contractHash = keccak256(abi.encodePacked("HolographERC721"));
  bytes32 erc721ConfigHash;

  /**
   * @notice Set up the testing environment for the Holograph Registry tests.
   * @dev This function is called before each test is executed to prepare the necessary setup for the tests.
   * It performs the following actions:
   * 1. Deploys new instances of HolographRegistry and MockExternalCall contracts.
   * 2. Creates a fork of the local host RPC URL and selects the forked chain.
   * 3. Retrieves instances of the Holograph, HolographRegistry, HolographERC721 and HolographERC20 contracts
   * using the Constants contract and assigns them to the corresponding variables.
   * 4. Initializes the HolographRegistry contract with the provided initialization code.
   * 5. Calculates the erc721ConfigHash using the HelperDeploymentConfig contract and the deployConfig variables.
   */
  function setUp() public {
    //deploy
    holographRegistry = new HolographRegistry();
    mockExternalCall = new MockExternalCall();

    localHostFork = vm.createFork(LOCALHOST_RPC_URL);
    vm.selectFork(localHostFork);
    holograph = Holograph(payable(Constants.getHolograph()));
    registryDeployedByScript = HolographRegistry(payable(holograph.getRegistry()));
    holographERC721 = HolographERC721(payable(Constants.getHolographERC721()));
    holographERC20 = HolographERC20(payable(Constants.getHolographERC20()));
    sampleErc721Holographer = Holographer(payable(Constants.getSampleERC721()));

    // init
    bytes32[] memory emptyBytes32Array;
    bytes memory initCode = abi.encode(deployer, emptyBytes32Array);
    holographRegistry.init(initCode);

    // configHash
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getERC721(
      Constants.getHolographIdL1(),
      vm.getCode("SampleERC721.sol:SampleERC721"),
      Constants.eventConfig,
      true
    );
    erc721ConfigHash = HelperDeploymentConfig.getDeployConfigHash(deployConfig, deployer);
  }

  /* -------------------------------------------------------------------------- */
  /*                                 CONSTRUCTOR                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the successful deployment of the HolographRegistry contract.
   * @dev This test verifies that the address of the deployed HolographRegistry contract is not equal to the zero address.
   * Refers to the hardhat test with the description 'should successfully deploy'
   */
  function testSuccessfullyDeploy() public view {
    assertNotEq(address(holographRegistry), zeroAddress);
  }

  /* -------------------------------------------------------------------------- */
  /*                                   INIT()                                   */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the successful initialization of the HolographRegistry contract once.
   * @dev This test initializes the HolographRegistry contract with the provided deployment address and an empty bytes32 array.
   * It then calls the init function of the contract.
   * Refers to the hardhat test with the description 'should successfully be initialized once'
   */
  function testSuccessfullyInitializedOnce() public {
    holographRegistryNew = new HolographRegistry();
    bytes32[] memory emptyBytes32Array;
    bytes memory initCode = abi.encode(deployer, emptyBytes32Array);
    holographRegistryNew.init(initCode);
  }

  /**
   * @notice Test the failure of initializing the HolographRegistry contract twice.
   * @dev This test attempts to initialize the HolographRegistry contract twice with the same initialization code.
   * The first initialization (in setUp() function) is successful, and the second initialization is expected to revert
   * with the message 'HOLOGRAPH: already initialized'.
   * Refers to the hardhat test with the description 'should fail be initialized twice'
   */
  function testInitializedTwiceFail() public {
    bytes32[] memory emptyBytes32Array;
    bytes memory initCode = abi.encode(deployer, emptyBytes32Array);
    vm.expectRevert(bytes(ErrorConstants.ALREADY_INITIALIZED_ERROR_MSG));
    holographRegistry.init(initCode);
  }

  /* -------------------------------------------------------------------------- */
  /*                          setHolographedHashAddress                         */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the revert behavior when trying to set a holographed hash address without a factory.
   * @dev This test attempts to set a holographed hash address for the 'HolographERC721' contract type using the deployer address.
   * It expects a revert with the message 'HOLOGRAPH: factory only function' when calling the setHolographedHashAddress function.
   * Refers to the hardhat test with the description 'Should return fail to add contract because it does not have a factory'
   */
  function testSetHolographedHashAddressNoFactoryRevert() public {
    vm.expectRevert(bytes(ErrorConstants.FACTORY_ONLY_ERROR_MSG));
    vm.prank(deployer);
    registryDeployedByScript.setHolographedHashAddress(contractHash, address(holographERC721));
  }

  /* -------------------------------------------------------------------------- */
  /*                          getHolographableContracts                         */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the return of valid holographable contracts from the registry.
   * @dev This test verifies that the registry returns a list of valid holographable contracts.
   * It checks that the length of the returned list matches the expected count and that the list includes a specific contract address.
   * Refers to the hardhat test with the description 'Should return valid contracts'
   */
  function testReturnValidHolographableContract() public view {
    address[] memory contracts = registryDeployedByScript.getHolographableContracts(
      0,
      expectedHolographableContractsCount
    );
    assertEq(contracts.length, expectedHolographableContractsCount);
    address hashAddress = address(registryDeployedByScript.getHolographedHashAddress(erc721ConfigHash));
    bool found = false;
    for (uint i = 0; i < contracts.length; i++) {
      if (contracts[i] == hashAddress) {
        found = true;
        break;
      }
    }
    assertTrue(found, "Expected contract address not found");
  }

  /**
   * @notice Test allowing an external contract to call the getHolographableContracts function.
   * @dev This test verifies that an external contract can successfully call the getHolographableContracts function
   * of the registry contract with the parameters 0 and 1.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallGetHolographableContracts() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getHolographableContracts(uint256,uint256)", 0, 1);
    mockExternalCall.callExternalFn(address(registryDeployedByScript), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                       getHolographableContractsLength                      */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the validity of the length of holographable contracts returned by the registry.
   * @dev This test verifies that the length of the list of holographable contracts returned by the registry
   * matches the expected count of 5.
   * Refers to the hardhat test with the description 'Should return valid _holographableContracts length'
   */
  function testReturnValidHolographableContractsLength() public view {
    uint256 length = registryDeployedByScript.getHolographableContractsLength();
    assertEq(length, expectedHolographableContractsCount);
  }

  /**
   * @notice Test allowing an external contract to call the getHolographableContractsLength function.
   * @dev This test verifies that an external contract can successfully call the getHolographableContractsLength function
   * of the registry contract.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallGetHolographableContractsLength() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getHolographableContractsLength()");
    mockExternalCall.callExternalFn(address(registryDeployedByScript), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                            isHolographedContract                           */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the validation of a smart contract as a valid holographed contract.
   * @dev This test checks if the smart contract at the address of sampleErc721Holographer
   * is considered a valid holographed contract by the registry.
   * It verifies that the function returns true for a valid holographed contract.
   * Refers to the hardhat test with the description 'Should return true if smartContract is valid'
   */
  function testReturnTrueIfSmartContractIsValid() public view {
    //assertTrue(registryDeployedByScript.isHolographedContract(address(sampleErc721Holographer)));
    assertTrue(
      registryDeployedByScript.isHolographedContract(
        address(registryDeployedByScript.getHolographedHashAddress(erc721ConfigHash))
      )
    );
  }

  /**
   * @notice Test the validation of an invalid smart contract as a holographed contract.
   * @dev This test checks if the registry correctly identifies a smart contract at the address of mockAddress
   * as an invalid holographed contract.
   * It verifies that the function returns false for an invalid holographed contract.
   * Refers to the hardhat test with the description 'Should return false if smartContract is INVALID'
   */
  function testReturnFalseIfSmartContractIsInvalid() public {
    vm.prank(deployer);
    assertFalse(registryDeployedByScript.isHolographedContract(address(mockAddress)));
  }

  /**
   * @notice Test allowing an external contract to call the isHolographedContract function.
   * @dev This test verifies that an external contract can successfully call the isHolographedContract function
   * of the registry contract with the address of mockAddress as a parameter.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCalIsHolographableContract() public {
    bytes memory encodeSignature = abi.encodeWithSignature("isHolographedContract(address)", mockAddress);
    mockExternalCall.callExternalFn(address(registryDeployedByScript), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                          isHolographedHashDeployed                         */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the validation of a contract hash as a valid holographed contract hash.
   * @dev This test checks if the contract hash of sampleErc721Holographer
   * is considered a valid holographed contract hash by the registry.
   * It verifies that the function returns true for a valid holographed contract hash.
   * Refers to the hardhat test with the description 'Should return true if hash is valid'
   */
  function testReturnTrueIfHashIsValid() public {
    assertTrue(registryDeployedByScript.isHolographedHashDeployed(erc721ConfigHash));
  }

  /**
   * @notice Test the validation of an invalid contract hash as a deployed holographed contract hash.
   * @dev This test checks if the registry correctly identifies an invalid contract hash
   * as not being deployed as a holographed contract.
   * It verifies that the function returns false for an invalid holographed contract hash.
   * Refers to the hardhat test with the description 'should return false if hash is INVALID'
   */
  function testReturnFalseIfHashIsInvalid() public view {
    assertFalse(registryDeployedByScript.isHolographedHashDeployed(contractHash));
  }

  /**
   * @notice Test allowing an external contract to call the isHolographedHashDeployed function.
   * @dev This test verifies that an external contract can successfully call the isHolographedHashDeployed function
   * of the registry contract with the hash of sampleERC721Hash as a parameter.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCalIsHolographableHashDeployed() public {
    bytes memory encodeSignature = abi.encodeWithSignature("isHolographedHashDeployed(bytes32)", erc721ConfigHash);
    mockExternalCall.callExternalFn(address(registryDeployedByScript), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                          getHolographedHashAddress                         */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the validity of the holographed contracts hash map in the registry.
   * @dev This test checks if the registry correctly maps the hash of sampleErc721Holographer
   * to the address of the sampleErc721Holographer contract.
   * It verifies that the function returns the correct address for a given holographed contract hash.
   * Refers to the hardhat test with the description 'Should return valid _holographedContractsHashMap'
   */
  function testReturnValidHolographedContractsHashMap() public {
    address hashAddress = registryDeployedByScript.getHolographedHashAddress(erc721ConfigHash);
    assertEq(hashAddress, address(registryDeployedByScript.getHolographedHashAddress(erc721ConfigHash)));
  }

  /**
   * @notice Test the return of the zero address for an invalid holographed contract hash.
   * @dev This test checks if the registry correctly returns the zero address
   * when queried for the address of an invalid holographed contract hash.
   * It verifies that the function returns the zero address for an invalid hash.
   * Refers to the hardhat test with the description 'should return 0x0 for invalid hash'
   */
  function testReturn0x0ForInvalidHash() public view {
    address hashAddress = registryDeployedByScript.getHolographedHashAddress(contractHash);
    assertEq(hashAddress, zeroAddress);
  }

  /**
   * @notice Test allowing an external contract to call the getHolographedHashAddress function.
   * @dev This test verifies that an external contract can successfully call the getHolographedHashAddress function
   * of the registry contract with the hash of sampleERC721Hash as a parameter.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCalGetHolographedHashAddress() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getHolographedHashAddress(bytes32)", erc721ConfigHash);
    mockExternalCall.callExternalFn(address(registryDeployedByScript), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                       setReservedContractTypeAddress                       */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test allowing an admin to set a contract type address in the registry.
   * @dev This test verifies that an admin can successfully set a reserved contract type address
   * in the registry for the contract type 'HolographERC721'.
   * It simulates the admin (deployer) calling the setReservedContractTypeAddress function with the contract type hash and a boolean value.
   * Refers to the hardhat test with the description 'should allow admin to set contract type address'
   */
  function testAllowAdminToSetContractTypeAddress() public {
    vm.prank(deployer);
    registryDeployedByScript.setReservedContractTypeAddress(contractHash, true);
  }

  /**
 * @notice Test the revert when a random user tries to alter a contract type address in the registry.
 * @dev This test verifies that a random user (not an admin) cannot set a reserved contract type address
 * in the registry for the contract type 'HolographERC721'.
 * It simulates a random user calling the setReservedContractTypeAddress function with the contract type hash and a boolean value.
 * The test expects the function call to revert due to insufficient permissions.
 * Refers to the hardhat test with the description 'should fail to allow rand user to alter contract type address'

 */
  function testAllowRandUserToAlterContractTypeAddressRevert() public {
    address randUser = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(randUser);
    registryDeployedByScript.setReservedContractTypeAddress(contractHash, true);
  }

  /* -------------------------------------------------------------------------- */
  /*                       getReservedContractTypeAddress                       */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the return of the expected contract type address from the registry.
   * @dev This test verifies that the registry correctly stores and returns the expected contract type address
   * for the contract type 'HolographERC721' after setting it as a reserved contract type address.
   * It simulates setting the reserved contract type address and the contract type address in the registry,
   * then retrieves the stored contract type address and compares it with the expected address.
   * Refers to the hardhat test with the description 'should return expected contract type address'
   */
  function testReturnExpectedContractTypeAddress() public {
    vm.startPrank(deployer);
    registryDeployedByScript.setReservedContractTypeAddress(contractHash, true);
    registryDeployedByScript.setContractTypeAddress(contractHash, address(holographERC721));
    vm.stopPrank();
    address contractAddress = registryDeployedByScript.getReservedContractTypeAddress(contractHash);
    assertEq(contractAddress, address(holographERC721));
  }

  /* -------------------------------------------------------------------------- */
  /*                           setContractTypeAddress                           */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test allowing an admin to alter and set a contract type address in the registry.
   * @dev This test verifies that an admin can successfully alter and set a contract type address
   * in the registry for the contract type 'HolographERC721' after setting it as a reserved contract type address.
   * It simulates the admin (deployer) setting the reserved contract type address and then updating it with a new address,
   * and checks if the registry correctly stores and returns the updated contract type address.
   * Refers to the hardhat test with the description 'should allow admin to alter setContractTypeAddress'
   */
  function testAllowAdminToAlterSetContractTypeAddress() public {
    // TODO It is not a unit test
    address contractAddress = RandomAddress.randomAddress();
    vm.startPrank(deployer);
    registryDeployedByScript.setReservedContractTypeAddress(contractHash, true);
    registryDeployedByScript.setContractTypeAddress(contractHash, contractAddress);
    vm.stopPrank();
    assertEq(registryDeployedByScript.getReservedContractTypeAddress(contractHash), contractAddress);
  }

  /**
   * @notice Test the revert when a random user tries to set a contract type address in the registry.
   * @dev This test verifies that a random user (not an admin) cannot set a contract type address
   * in the registry for the contract type 'HolographERC721' after it has been set as a reserved contract type address.
   * It simulates the deployer setting the reserved contract type address, and then a random user attempting to update the contract type address.
   * The test expects the function call to revert due to insufficient permissions.
   * It also checks that the stored contract type address remains unchanged after the failed attempt.
   * Refers to the hardhat test with the description 'should fail to allow rand user to alter setContractTypeAddress'
   */
  function testAllowRandUserToAlterSetContractTypeAddressRevert() public {
    // TODO It is not a unit test
    address contractAddress = RandomAddress.randomAddress();
    vm.prank(deployer);
    registryDeployedByScript.setReservedContractTypeAddress(contractHash, true);
    vm.prank(RandomAddress.randomAddress());
    vm.expectRevert();
    registryDeployedByScript.setContractTypeAddress(contractHash, contractAddress);
    assertNotEq(registryDeployedByScript.getReservedContractTypeAddress(contractHash), contractAddress);
  }

  /* -------------------------------------------------------------------------- */
  /*                           getContractTypeAddress                           */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the return of a valid contract type address from the registry.
   * @dev This test verifies that the registry correctly stores and returns the expected contract type address
   * for the contract type 'HolographERC721' after it has been set by an admin.
   * It simulates the admin (deployer) setting the reserved contract type address and then setting the contract type address,
   * and checks if the registry correctly returns the stored contract type address.
   * Refers to the hardhat test with the description 'Should return valid _contractTypeAddresses'
   */
  function testReturnValidContractTypeAddresses() public {
    address contractAddress = RandomAddress.randomAddress();
    vm.startPrank(deployer);
    registryDeployedByScript.setReservedContractTypeAddress(contractHash, true);
    registryDeployedByScript.setContractTypeAddress(contractHash, contractAddress);
    vm.stopPrank();
    assertEq(registryDeployedByScript.getContractTypeAddress(contractHash), contractAddress);
  }

  /**
   * @notice Test allowing an external contract to call the getContractTypeAddress function.
   * @dev This test verifies that an external contract can successfully call the getContractTypeAddress function
   * of the registry contract with the contract type hash of 'HolographERC721' as a parameter.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnGetContractTypeAddress() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getContractTypeAddress(bytes32)", contractHash);
    mockExternalCall.callExternalFn(address(registryDeployedByScript), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                        referenceContractTypeAddress                        */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the return of a valid address from the registry.
   * @dev This test verifies that the registry correctly references the address of the holographERC20 contract.
   * It calls the referenceContractTypeAddress function in the registry with the address of the holographERC20 contract.
   * Refers to the hardhat test with the description 'should return valid address'
   */
  function testReturnValidAddress() public {
    registryDeployedByScript.referenceContractTypeAddress(address(holographERC20));
  }

  /**
   * @notice Test the revert when trying to reference an empty contract in the registry.
   * @dev This test verifies that the registry reverts with the message 'HOLOGRAPH: empty contract'
   * when attempting to reference an empty contract address.
   * It simulates calling the referenceContractTypeAddress function in the registry with a random empty contract address.
   * Refers to the hardhat test with the description 'should fail if contract is empty'
   */
  function testIfContractIsEmptyRevert() public {
    address contractAddress = RandomAddress.randomAddress();
    vm.expectRevert(bytes(ErrorConstants.EMPTY_CONTRACT_ERROR_MSG));
    registryDeployedByScript.referenceContractTypeAddress(contractAddress);
  }

  /**
   * @notice Test the revert when trying to reference an already set contract in the registry.
   * @dev This test verifies that the registry reverts with the message 'HOLOGRAPH: contract already set'
   * when attempting to reference a contract that has already been set in the registry.
   * It first references the address of the holographERC20 contract, then simulates trying to reference it again.
   * Refers to the hardhat test with the description 'should fail if contract is already set'
   */
  function testIfContractIsAlreadySetRevert() public {
    registryDeployedByScript.referenceContractTypeAddress(address(holographERC20));
    vm.expectRevert(bytes(ErrorConstants.CONTRACT_ALREADY_SET_ERROR_MSG));
    registryDeployedByScript.referenceContractTypeAddress(address(holographERC20));
  }

  /**
   * @notice Test allowing an external contract to call the referenceContractTypeAddress function.
   * @dev This test verifies that an external contract can successfully call the referenceContractTypeAddress function
   * of the registry contract with the address of the holographERC20 contract as a parameter.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnReferenceContractTypeAddress() public {
    bytes memory encodeSignature = abi.encodeWithSignature(
      "referenceContractTypeAddress(address)",
      address(holographERC20)
    );
    mockExternalCall.callExternalFn(address(registryDeployedByScript), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                               setHolograph()                               */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test allowing an admin to alter the holograph slot in the registry.
   * @dev This test verifies that an admin can successfully update the holograph slot
   * in the registry with a new address.
   * It simulates the admin calling the setHolograph function with a mock address,
   * and then checks if the registry correctly stores and returns the updated holograph address.
   * Refers to the hardhat test with the description 'should allow admin to alter _holographSlot'
   */
  function testAllowAdminToAlterHolographSlot() public {
    vm.prank(origin);
    holographRegistry.setHolograph(address(mockAddress));
    assertEq(holographRegistry.getHolograph(), mockAddress);
  }

  /**
   * @notice Test the revert when a random user tries to alter the holograph slot in the registry.
   * @dev This test verifies that the registry reverts with the message 'HOLOGRAPH: admin only function'
   * when a random user (not the admin) attempts to alter the holograph slot.
   * It simulates a random user calling the setHolograph function with a mock address.
   * Refers to the hardhat tests with descriptions 'should fail to allow owner to alter _holographSlot'
   * and 'should fail to allow non-owner to alter _holographSlot'
   */
  function testAllowRandUserToAlterHolographSlotFail() public {
    vm.prank(RandomAddress.randomAddress());
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holographRegistry.setHolograph(address(mockAddress));
  }

  /* -------------------------------------------------------------------------- */
  /*                               getHolograph()                               */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test allowing an external contract to call the getHolograph function.
   * @dev This test verifies that an external contract can successfully call the getHolograph function
   * of the registry contract without any parameters.
   * It simulates an external contract calling the getHolograph function in the registry.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnGetHolograph() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getHolograph()");
    mockExternalCall.callExternalFn(address(registryDeployedByScript), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                                 setHToken()                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test allowing an admin to alter the hTokens mapping in the registry.
   * @dev This test verifies that an admin can successfully update the hToken address for a specific chain ID
   * in the registry with a new address.
   * It simulates the admin calling the setHToken function with a valid chain ID and hToken address,
   * and then checks if the registry correctly stores and returns the updated hToken address for the chain ID.
   */
  function testAllowAdminToAlterHTokens() public {
    vm.prank(origin);
    holographRegistry.setHToken(validChainId, hTokenAddress);
    assertEq(holographRegistry.getHToken(validChainId), hTokenAddress);
  }

  /**
   * @notice Test the revert when a non-admin user tries to alter the hTokens mapping in the registry.
   * @dev This test verifies that the registry reverts with the message 'HOLOGRAPH: admin only function'
   * when a non-admin user attempts to alter the hToken address for a specific chain ID.
   * It simulates a random user calling the setHToken function with a valid chain ID and hToken address.
   * Refers to the hardhat tests with the descriptions 'should fail to allow owner to alter _hTokens'
   * and 'should fail to allow non-owner to alter _hTokens'
   */
  function testAllowNonOwnerToAlterHTokensReturn() public {
    vm.prank(RandomAddress.randomAddress());
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holographRegistry.setHToken(validChainId, hTokenAddress);
  }

  /* -------------------------------------------------------------------------- */
  /*                                 getHToken()                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the return of a valid hToken address from the registry.
   * @dev This test verifies that the registry correctly returns the expected hToken address
   * for a specific chain ID after it has been set by an admin.
   * It first calls the testAllowAdminToAlterHTokens test to set the hToken address,
   * then checks if the registry correctly returns the stored hToken address for the chain ID.
   * Refers to the hardhat test with the description 'Should return valid _hTokens'
   */

  function testReturnValidHTokens() public {
    testAllowAdminToAlterHTokens();
    address hTokenAddr = holographRegistry.getHToken(validChainId);
    assertEq(hTokenAddr, hTokenAddress);
  }

  /**
   * @notice Test the return of 0x0 for an invalid chain ID from the registry.
   * @dev This test verifies that the registry returns 0x0 (zero address) when querying for an hToken address
   * with an invalid chain ID (0) that does not exist in the mapping.
   * It checks if the registry correctly returns 0x0 for the hToken address associated with the invalid chain ID.
   * Refers to the hardhat test with the description 'should return 0x0 for invalid chainId'
   */
  function testReturn0x0ForInvalidChainId() public view {
    assertEq(holographRegistry.getHToken(invalidChainId), zeroAddress);
  }

  /**
   * @notice Test allowing an external contract to call the getHToken function.
   * @dev This test verifies that an external contract can successfully call the getHToken function
   * of the registry contract with a valid chain ID as a parameter.
   * It simulates an external contract calling the getHToken function in the registry with a valid chain ID.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnGetHToken() public {
    bytes memory encodeSignature = abi.encodeWithSignature("getHToken(uint32)", validChainId);
    mockExternalCall.callExternalFn(address(registryDeployedByScript), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                              setUtilityToken()                             */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test allowing an admin to alter the utility token slot in the registry.
   * @dev This test verifies that an admin can successfully update the utility token slot
   * in the registry with a new address.
   * It simulates the admin calling the setUtilityToken function with a utility token address,
   * and then checks if the registry correctly stores and returns the updated utility token address.
   * Refers to the hardhat test with the description 'should allow admin to alter _utilityTokenSlot'
   */
  function testAllowAdminToAlterUtilityTokenSlot() public {
    vm.prank(origin);
    holographRegistry.setUtilityToken(utilityTokenAddress);
    assertEq(holographRegistry.getUtilityToken(), utilityTokenAddress);
  }

  /**
   * @notice Test the revert when a random user tries to alter the utility token slot in the registry.
   * @dev This test verifies that the registry reverts with the message 'HOLOGRAPH: admin only function'
   * when a random user (not the admin) attempts to alter the utility token slot.
   * It simulates a random user calling the setUtilityToken function with a utility token address.
   * Refers to the hardhat tests with the description 'should fail to allow owner to alter _utilityTokenSlot'
   * and 'should fail to allow non-owner to alter _utilityTokenSlot'
   */
  function testAllowRandUserToAlterUtilityTokenSlotRevert() public {
    vm.prank(RandomAddress.randomAddress());
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holographRegistry.setUtilityToken(utilityTokenAddress);
  }
}
