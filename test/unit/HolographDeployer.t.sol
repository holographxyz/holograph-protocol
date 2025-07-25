// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../src/deployment/HolographDeployer.sol";

/**
 * @title HolographDeployerTest
 * @notice Comprehensive test suite for HolographDeployer contract
 */
contract HolographDeployerTest is Test {
    HolographDeployer public deployer;
    
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    
    // Test contract for deployment
    bytes public testContractBytecode = type(TestContract).creationCode;
    
    event ContractDeployed(
        address indexed deployed,
        address indexed deployer,
        bytes32 salt,
        bytes32 creationCodeHash
    );
    
    event ContractDeployedAndInitialized(
        address indexed deployed,
        address indexed deployer,
        bytes32 salt,
        bytes32 creationCodeHash,
        bytes initData
    );
    
    function setUp() public {
        deployer = new HolographDeployer();
    }
    
    /* -------------------------------------------------------------------------- */
    /*                            Basic Deployment Tests                          */
    /* -------------------------------------------------------------------------- */
    
    function test_deploy_success() public {
        bytes32 salt = _generateValidSalt(alice);
        
        vm.prank(alice);
        address deployed = deployer.deploy(testContractBytecode, salt);
        
        assertTrue(deployed != address(0), "Deployment failed");
        assertTrue(deployed.code.length > 0, "No code at deployed address");
    }
    
    function test_deploy_emitsEvent() public {
        bytes32 salt = _generateValidSalt(alice);
        bytes32 creationCodeHash = keccak256(testContractBytecode);
        
        vm.expectEmit(true, true, true, true);
        emit ContractDeployed(
            deployer.computeAddress(testContractBytecode, salt),
            alice,
            salt,
            creationCodeHash
        );
        
        vm.prank(alice);
        deployer.deploy(testContractBytecode, salt);
    }
    
    function test_deploy_revertInvalidSalt() public {
        // Salt with wrong address in first 20 bytes
        bytes32 invalidSalt = bytes32(uint256(uint160(bob))) | bytes32(uint256(1) << 160);
        
        vm.expectRevert(HolographDeployer.InvalidSalt.selector);
        vm.prank(alice);
        deployer.deploy(testContractBytecode, invalidSalt);
    }
    
    function test_deploy_revertAlreadyDeployed() public {
        bytes32 salt = _generateValidSalt(alice);
        
        // First deployment succeeds
        vm.prank(alice);
        deployer.deploy(testContractBytecode, salt);
        
        // Second deployment with same salt fails
        vm.expectRevert(HolographDeployer.ContractAlreadyDeployed.selector);
        vm.prank(alice);
        deployer.deploy(testContractBytecode, salt);
    }
    
    /* -------------------------------------------------------------------------- */
    /*                          Deploy and Call Tests                             */
    /* -------------------------------------------------------------------------- */
    
    function test_deployAndCall_success() public {
        bytes32 salt = _generateValidSalt(alice);
        bytes memory initData = abi.encodeWithSignature("initialize(uint256)", 42);
        
        vm.prank(alice);
        address deployed = deployer.deployAndCall(testContractBytecode, salt, initData);
        
        TestContract testContract = TestContract(deployed);
        assertEq(testContract.value(), 42, "Initialization failed");
    }
    
    function test_deployAndCall_emitsEvent() public {
        bytes32 salt = _generateValidSalt(alice);
        bytes memory initData = abi.encodeWithSignature("initialize(uint256)", 42);
        
        vm.expectEmit(true, true, true, true);
        emit ContractDeployedAndInitialized(
            deployer.computeAddress(testContractBytecode, salt),
            alice,
            salt,
            keccak256(testContractBytecode),
            initData
        );
        
        vm.prank(alice);
        deployer.deployAndCall(testContractBytecode, salt, initData);
    }
    
    function test_deployAndCall_revertInitializationFailed() public {
        bytes32 salt = _generateValidSalt(alice);
        // Invalid function selector
        bytes memory invalidInitData = abi.encodeWithSignature("nonExistent()");
        
        vm.expectRevert(HolographDeployer.InitializationFailed.selector);
        vm.prank(alice);
        deployer.deployAndCall(testContractBytecode, salt, invalidInitData);
    }
    
    /* -------------------------------------------------------------------------- */
    /*                          SafeCreate2 Tests                                */
    /* -------------------------------------------------------------------------- */
    
    function test_safeCreate2_success() public {
        bytes32 salt = _generateValidSalt(alice);
        address expectedAddress = deployer.computeAddress(testContractBytecode, salt);
        
        vm.prank(alice);
        address deployed = deployer.safeCreate2(testContractBytecode, salt, expectedAddress);
        
        assertEq(deployed, expectedAddress, "Deployed address mismatch");
    }
    
    function test_safeCreate2_revertPreDeploymentMismatch() public {
        bytes32 salt = _generateValidSalt(alice);
        address wrongExpectedAddress = makeAddr("wrong");
        address computedAddress = deployer.computeAddress(testContractBytecode, salt);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                HolographDeployer.PreDeploymentAddressMismatch.selector,
                wrongExpectedAddress,
                computedAddress
            )
        );
        vm.prank(alice);
        deployer.safeCreate2(testContractBytecode, salt, wrongExpectedAddress);
    }
    
    function test_safeCreate2AndCall_success() public {
        bytes32 salt = _generateValidSalt(alice);
        address expectedAddress = deployer.computeAddress(testContractBytecode, salt);
        bytes memory initData = abi.encodeWithSignature("initialize(uint256)", 100);
        
        vm.prank(alice);
        address deployed = deployer.safeCreate2AndCall(
            testContractBytecode,
            salt,
            expectedAddress,
            initData
        );
        
        assertEq(deployed, expectedAddress, "Deployed address mismatch");
        assertEq(TestContract(deployed).value(), 100, "Initialization failed");
    }
    
    /* -------------------------------------------------------------------------- */
    /*                          Address Computation Tests                         */
    /* -------------------------------------------------------------------------- */
    
    function test_computeAddress_consistency() public {
        bytes32 salt = _generateValidSalt(alice);
        
        address computed1 = deployer.computeAddress(testContractBytecode, salt);
        address computed2 = deployer.computeAddress(testContractBytecode, salt);
        
        assertEq(computed1, computed2, "Address computation not consistent");
    }
    
    function test_computeAddress_differentSalts() public {
        bytes32 salt1 = _generateValidSalt(alice);
        bytes32 salt2 = bytes32(uint256(salt1) + 1);
        
        address addr1 = deployer.computeAddress(testContractBytecode, salt1);
        address addr2 = deployer.computeAddress(testContractBytecode, salt2);
        
        assertTrue(addr1 != addr2, "Different salts should produce different addresses");
    }
    
    /* -------------------------------------------------------------------------- */
    /*                          Verification Tests                                */
    /* -------------------------------------------------------------------------- */
    
    function test_verifyDeployment_success() public {
        bytes32 salt = _generateValidSalt(alice);
        
        vm.prank(alice);
        address deployed = deployer.deploy(testContractBytecode, salt);
        
        bool verified = deployer.verifyDeployment(deployed, testContractBytecode, salt);
        assertTrue(verified, "Deployment verification failed");
    }
    
    function test_verifyDeployment_failsForWrongCode() public {
        bytes32 salt = _generateValidSalt(alice);
        
        vm.prank(alice);
        address deployed = deployer.deploy(testContractBytecode, salt);
        
        bytes memory wrongCode = hex"1234";
        bool verified = deployer.verifyDeployment(deployed, wrongCode, salt);
        assertFalse(verified, "Verification should fail for wrong code");
    }
    
    function test_verifyDeploymentAddress_success() public {
        address expected = makeAddr("expected");
        address actual = expected;
        
        // Should not revert
        deployer.verifyDeploymentAddress(expected, actual);
    }
    
    function test_verifyDeploymentAddress_revert() public {
        address expected = makeAddr("expected");
        address actual = makeAddr("actual");
        
        vm.expectRevert(
            abi.encodeWithSelector(
                HolographDeployer.PostDeploymentAddressMismatch.selector,
                expected,
                actual
            )
        );
        deployer.verifyDeploymentAddress(expected, actual);
    }
    
    /* -------------------------------------------------------------------------- */
    /*                          Edge Case Tests                                   */
    /* -------------------------------------------------------------------------- */
    
    function test_deploy_emptyInitData() public {
        bytes32 salt = _generateValidSalt(alice);
        bytes memory emptyData = "";
        
        vm.prank(alice);
        address deployed = deployer.deployAndCall(testContractBytecode, salt, emptyData);
        
        assertTrue(deployed != address(0), "Deployment with empty init data failed");
    }
    
    function testFuzz_deploy_differentSalts(uint256 saltNum) public {
        vm.assume(saltNum < type(uint96).max); // Leave room for address prefix
        bytes32 salt = bytes32(uint256(uint160(alice)) << 96 | saltNum);
        
        vm.prank(alice);
        address deployed = deployer.deploy(testContractBytecode, salt);
        
        assertTrue(deployed != address(0), "Deployment failed");
    }
    
    /* -------------------------------------------------------------------------- */
    /*                              Helper Functions                              */
    /* -------------------------------------------------------------------------- */
    
    function _generateValidSalt(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)) << 96);
    }
}

/**
 * @notice Simple test contract for deployment testing
 */
contract TestContract {
    uint256 public value;
    
    function initialize(uint256 _value) external {
        value = _value;
    }
}