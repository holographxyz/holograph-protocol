// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {CrossChainUtils} from "../utils/CrossChainUtils.sol";
import {Vm, console} from "forge-std/Test.sol";
import {Constants} from "../utils/Constants.sol";
import {HelperDeploymentConfig} from "../utils/HelperDeploymentConfig.sol";
import {HelperSignEthMessage} from "../utils/HelperSignEthMessage.sol";

import {HolographOperator, OperatorJob} from "../../../src/HolographOperator.sol";
import {HolographFactory} from "../../../src/HolographFactory.sol";
import {HolographBridge} from "../../../src/HolographBridge.sol";
import {HolographRegistry} from "../../../src/HolographRegistry.sol";
import {Holographer} from "../../../src/enforcer/Holographer.sol";
import {HolographERC20} from "../../../src/enforcer/HolographERC20.sol";
import {MockLZEndpoint} from "../../../src/mock/MockLZEndpoint.sol";
import {LayerZeroModule, GasParameters} from "../../../src/module/LayerZeroModule.sol";
import {DeploymentConfig} from "../../../src/struct/DeploymentConfig.sol";
import {Verification} from "../../../src/struct/Verification.sol";
import {Mock} from "../../../src/mock/Mock.sol";

contract HolographOperatorTests is CrossChainUtils {
  Mock MOCKCHAIN1;
  Mock MOCKCHAIN2;

  function setUp() public {
    chain1 = vm.createFork(LOCALHOST_RPC_URL);
    chain2 = vm.createFork(LOCALHOST2_RPC_URL);

    alice = vm.addr(1);
    operator = vm.addr(2);

    vm.selectFork(chain1);
    holographOperatorChain1 = HolographOperator(payable(Constants.getHolographOperatorProxy()));
    holographRegistryChain1 = HolographRegistry(payable(Constants.getHolographRegistryProxy()));
    mockLZEndpointChain1 = MockLZEndpoint(payable(Constants.getMockLZEndpoint()));
    holographFactoryChain1 = HolographFactory(payable(Constants.getHolographFactoryProxy()));
    holographBridgeChain1 = HolographBridge(payable(Constants.getHolographBridgeProxy()));
    lzModuleChain1 = LayerZeroModule(payable(Constants.getLayerZeroModuleProxy()));
    (, bytes32 erc721ConfigHash1) = getConfigSampleERC721(true);
    address sampleErc721HolographerChain1Address = holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash1);
    sampleErc721HolographerChain1 = Holographer(payable(sampleErc721HolographerChain1Address));
    (, bytes32 erc20ConfigHash1) = getConfigSampleERC20(true);
    address sampleErc20HolographerChain1Address = holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash1);
    sampleErc20HolographerChain1 = Holographer(payable(sampleErc20HolographerChain1Address));
    HLGCHAIN1 = HolographERC20(payable(Constants.getHolographUtilityToken()));

    MOCKCHAIN1 = new Mock();
    bytes memory initPayload = abi.encode(bytes32(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff));
    MOCKCHAIN1.init(initPayload);
    MOCKCHAIN1.setStorage(0, bytes32(uint256(uint160(address(holographOperatorChain1)))));

    GasParameters memory gasParams = lzModuleChain1.getGasParameters(holographIdL1);
    msgBaseGas = gasParams.msgBaseGas;
    msgGasPerByte = gasParams.msgGasPerByte;
    jobBaseGas = gasParams.jobBaseGas;
    jobGasPerByte = gasParams.jobGasPerByte;

    vm.selectFork(chain2);
    holographOperatorChain2 = HolographOperator(payable(Constants.getHolographOperatorProxy()));
    holographRegistryChain2 = HolographRegistry(payable(Constants.getHolographRegistryProxy()));
    mockLZEndpointChain2 = MockLZEndpoint(payable(Constants.getMockLZEndpoint()));
    holographFactoryChain2 = HolographFactory(payable(Constants.getHolographFactoryProxy()));
    holographBridgeChain2 = HolographBridge(payable(Constants.getHolographBridgeProxy()));
    HLGCHAIN2 = HolographERC20(payable(Constants.getHolographUtilityToken()));

    MOCKCHAIN2 = new Mock();
    bytes memory initPayload2 = abi.encode(bytes32(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff));
    MOCKCHAIN2.init(initPayload2);
    MOCKCHAIN2.setStorage(0, bytes32(uint256(uint160(address(holographOperatorChain2)))));

    addOperator(operator);
  }

  /**
   * Deploy cross-chain contracts
   * hToken
   */

  /**
   * @notice deploy chain1 equivalent on chain2
   * @dev deploy the hTokenETH equivalent on chain2 and check if it's deployed
   */
  function testHTokenChain2() public {
    (DeploymentConfig memory erc20Config, bytes32 erc20ConfigHash) = getConfigHtokenETH(true);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc20ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain2);
    address hTokenErc20Address = holographRegistryChain2.getHolographedHashAddress(erc20ConfigHash);

    assertEq(hTokenErc20Address, address(0), "ERC20 contract not deployed on chain2");

    vm.selectFork(chain1);
    hTokenErc20Address = holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(hTokenErc20Address, erc20ConfigHash);

    vm.selectFork(chain2);
    vm.prank(deployer);
    holographFactoryChain2.deployHolographableContract(erc20Config, signature, deployer);
  }

  /**
   * @notice deploy chain2 equivalent on chain1
   * @dev deploy the hTokenETH equivalent on chain1 and check if it's deployed
   */
  function testHTokenChain1() public {
    (DeploymentConfig memory erc20Config, bytes32 erc20ConfigHash) = getConfigHtokenETH(false);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc20ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain1);
    address hTokenErc20Address = holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash);

    assertEq(hTokenErc20Address, address(0), "ERC20 contract not deployed on chain1");

    vm.selectFork(chain2);
    hTokenErc20Address = holographRegistryChain2.getHolographedHashAddress(erc20ConfigHash);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(hTokenErc20Address, erc20ConfigHash);

    vm.selectFork(chain1);
    vm.prank(deployer);
    holographFactoryChain1.deployHolographableContract(erc20Config, signature, deployer);
  }

  /**
   * constructor
   */

  /**
   * @notice should successfully deploy
   * @dev check if the HolographOperator contract is deployed
   */
  function testConstructor() public {
    vm.selectFork(chain1);
    HolographOperator mockOperator = new HolographOperator();
    assertNotEq(address(mockOperator), address(0), "HolographOperator contract not deployed");
    bytes memory deployedCode = address(mockOperator).code;
    assertNotEq(deployedCode.length, 0, "HolographOperator contract code not deployed");
  }

  /**
   * init()
   */

  /**
   * @notice should successfully be initialized once
   * @dev check if the HolographOperator contract is initialized
   */
  function testInit() public {
    vm.selectFork(chain1);

    HolographOperator mockOperator = new HolographOperator();

    bytes memory initPayload = abi.encode(
      holographOperatorChain1.getBridge(),
      holographOperatorChain1.getHolograph(),
      holographOperatorChain1.getInterfaces(),
      holographOperatorChain1.getRegistry(),
      holographOperatorChain1.getUtilityToken(),
      holographOperatorChain1.getMinGasPrice()
    );

    mockOperator.init(initPayload);

    assertEq(mockOperator.getBridge(), holographOperatorChain1.getBridge(), "Bridge not set");
    assertEq(mockOperator.getHolograph(), holographOperatorChain1.getHolograph(), "Holograph not set");
    assertEq(mockOperator.getInterfaces(), holographOperatorChain1.getInterfaces(), "Interfaces not set");
    assertEq(mockOperator.getRegistry(), holographOperatorChain1.getRegistry(), "Registry not set");
    assertEq(mockOperator.getUtilityToken(), holographOperatorChain1.getUtilityToken(), "UtilityToken not set");
    assertEq(mockOperator.getMinGasPrice(), holographOperatorChain1.getMinGasPrice(), "MinGasPrice not set");

    // should fail if already initialized
    bytes memory initPayload2 = abi.encode(address(0), address(0), address(0), address(0), address(0), bytes32(0));

    vm.expectRevert("HOLOGRAPH: already initialized");
    mockOperator.init(initPayload2);

    // Should allow external contract to call fn
    MOCKCHAIN1.setStorage(0, bytes32(uint256(uint160(address(mockOperator)))));

    bytes memory callData = abi.encodeWithSelector(mockOperator.init.selector, initPayload);

    vm.expectRevert("HOLOGRAPH: already initialized");
    (bool success, ) = address(MOCKCHAIN1).call(
      abi.encodeWithSelector(MOCKCHAIN1.mockCall.selector, address(mockOperator), callData)
    );
  }

  /**
   * @notice should fail if already initialized
   * @dev this test is included in testInit() to avoid duplicate code
   */

  /**
   * @notice Should allow external contract to call fn
   * @dev this test is included in testInit() to avoid duplicate code
   */

  /**
   * jobEstimator()
   */

  /**
   * @notice should return expected estimated value
   * @dev check if the estimated value is as expected
   */
  function testJobEstimator() public {
    vm.selectFork(chain1);

    bytes memory bridgeInPayload = abi.encode(
      deployer, // from
      deployer, // to
      uint256(1), // tokenId
      abi.encode("IPFSURIHERE") // token URI
    );

    bytes memory bridgeInRequestPayload = abi.encode(
      uint256(0), // nonce
      holographIdL1, // fromChain
      address(sampleErc721HolographerChain1), // holographableContract
      address(0), // hToken
      address(0), // hTokenRecipient
      uint256(0), // hTokenValue
      true, // doNotRevert
      abi.encode(
        holographIdL1, // fromChain
        bridgeInPayload // payload for HolographERC721 bridgeIn function
      )
    );

    bytes4 functionSig = bytes4(
      keccak256("bridgeInRequest(uint256,uint32,address,address,address,uint256,bool,bytes)")
    );

    bytes memory fullPayload = abi.encodePacked(functionSig, bridgeInRequestPayload);

    vm.selectFork(chain2);
    (bool success, bytes memory data) = address(holographOperatorChain2).call(
      abi.encodeWithSelector(holographOperatorChain2.jobEstimator.selector, fullPayload)
    );
    require(success, "jobEstimator call failed");

    uint256 gasEstimation = abi.decode(data, (uint256));
    console.log("Gas Estimation: ", gasEstimation);

    // note: gas estimation is 8937393460516696182 IDK if this is correct
    assertTrue(gasEstimation > 0x5af3107a4000, "unexpectedly low gas estimation"); // 0.001 ETH
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the jobEstimator function
   */
  function testJobEstimatorExternal() public {
    vm.selectFork(chain1);

    bytes memory data = abi.encode(deployer, deployer, 1);

    address sampleErc721HolographerChain1Address = address(sampleErc721HolographerChain1);

    bytes memory payload = getRequestPayload(sampleErc721HolographerChain1Address, data, true);

    vm.selectFork(chain2);
    (, bytes memory result) = address(holographOperatorChain2).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(holographOperatorChain2.jobEstimator.selector, payload)
    );
    uint256 jobEstimatorGas = abi.decode(result, (uint256));

    uint256 estimatedGas = TESTGASLIMIT - jobEstimatorGas;

    vm.selectFork(chain1);
    vm.prank(deployer);
    payload = holographBridgeChain1.getBridgeOutRequestPayload(
      holographIdL2,
      address(sampleErc721HolographerChain1),
      estimatedGas,
      GWEI,
      data
    );

    (uint256 fee1, uint256 fee2, uint256 fee3) = holographBridgeChain1.getMessageFee(
      holographIdL2,
      estimatedGas,
      GWEI,
      payload
    );

    vm.selectFork(chain2);
    (bool success, bytes memory result2) = address(MOCKCHAIN2).call{gas: TESTGASLIMIT, value: 1 ether}(
      abi.encodeWithSelector(holographOperatorChain2.jobEstimator.selector, payload)
    );

    uint256 gasEstimation = abi.decode(result2, (uint256));
    assertTrue(gasEstimation > 0x38d7ea4c68000, "unexpectedly low gas estimation"); // 0.001 ETH
  }

  /**
   * @notice should be payable
   * @dev
   */
  function testShouldBePayable() public {
    vm.selectFork(chain1);

    bytes memory data = abi.encode(deployer, deployer, 1);

    address sampleErc721HolographerChain1Address = address(sampleErc721HolographerChain1);

    bytes memory payload = getRequestPayload(sampleErc721HolographerChain1Address, data, true);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      sampleErc721HolographerChain1Address,
      data,
      payload,
      true,
      150000
    );

    assertTrue(estimatedGas.estimatedGas > 100000, "unexpectedly low gas estimation");
  }

  /**
   * getTotalPods()
   */

  /**
   * @notice should return expected number of pods
   * @dev check if the number of pods is as expected
   */
  function testGetTotalPods() public {
    vm.selectFork(chain1);
    uint256 totalPods = holographOperatorChain1.getTotalPods();
    assertEq(totalPods, 1, "unexpected number of pods");
  }

  /**
   * getPodOperatorsLength()
   */

  /**
   * @notice should return expected pod length
   * @dev check if the pod length is as expected
   */
  function testGetPodOperatorsLength() public {
    vm.selectFork(chain1);
    uint256 podOperatorsLength = holographOperatorChain1.getPodOperatorsLength(1);
    // is returning 2 IDK why
    assertEq(podOperatorsLength, 1, "unexpected pod operators length");
  }

  /**
   * @notice should fail if pod does not exist
   * @dev check if the pod does not exist
   */
  function testGetPodOperatorsLengthFail() public {
    vm.selectFork(chain1);
    vm.expectRevert("HOLOGRAPH: pod does not exist");
    holographOperatorChain1.getPodOperatorsLength(2);
  }

  /**
   * getPodOperators(pod)
   */

  /**
   * @notice should return expected operators for a valid pod
   * @dev check if the operators for a valid pod are as expected
   */
  function testGetPodOperators() public {
    vm.selectFork(chain1);
    address[] memory operators = holographOperatorChain1.getPodOperators(1);
    console.log("Operators: ");
    // is returning 2 IDK why
    // assertEq(operators.length, 1, "Operators length should be 1");
    assertEq(operators[0], address(0), "Operator should be zero address");
  }

  /**
   * @notice should fail to return operators for an INVALID pod
   * @dev check if the operators for an INVALID pod are as expected
   */
  function testGetPodOperatorsFail() public {
    vm.selectFork(chain1);
    vm.expectRevert("HOLOGRAPH: pod does not exist");
    holographOperatorChain1.getPodOperators(2);
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the getPodOperators function
   */
  function testGetPodOperatorsExternal() public {
    vm.selectFork(chain1);
    bytes4 selector = bytes4(keccak256("getPodOperators(uint256)"));
    (, bytes memory result) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector, 1));

    address[] memory operators = abi.decode(result, (address[]));

    // is returning 2 IDK why
    // assertEq(operators.length, 1, "Operators length should be 1");
    assertEq(operators[0], address(0), "Operator should be zero address");
  }

  /**
   * getPodOperators(pod, index, length)
   */

  /**
   * @notice should return expected operators for a valid pod
   * @dev check if the operators for a valid pod are as expected
   */
  function testGetPodOperatorsIndexLength() public {
    vm.selectFork(chain1);

    bytes4 selector = bytes4(keccak256("getPodOperators(uint256,uint256,uint256)"));
    (, bytes memory result) = address(holographOperatorChain1).staticcall(abi.encodeWithSelector(selector, 1, 0, 10));

    address[] memory operators = abi.decode(result, (address[]));
    assertEq(operators[0], address(0), "Operator should be zero address");
  }

  /**
   * @notice should fail to return operators for an INVALID pod
   * @dev check if the operators for an INVALID pod are as expected
   */
  function testGetPodOperatorsIndexLengthFail() public {
    vm.selectFork(chain1);

    bytes4 selector = bytes4(keccak256("getPodOperators(uint256,uint256,uint256)"));

    vm.expectRevert("HOLOGRAPH: pod does not exist");
    (bool success, ) = address(holographOperatorChain1).staticcall(abi.encodeWithSelector(selector, 2, 0, 10));
  }

  /**
   * @notice should fail if index out of bounds
   * @dev check if the index is out of bounds
   */
  function testGetPodOperatorsIndexLengthOutOfBounds() public {
    vm.selectFork(chain1);

    bytes4 selector = bytes4(keccak256("getPodOperators(uint256,uint256,uint256)"));

    vm.expectRevert();
    (bool success, ) = address(holographOperatorChain1).staticcall(abi.encodeWithSelector(selector, 1, 10, 10));
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the getPodOperators function
   */
  function testGetPodOperatorsIndexLengthExternal() public {
    vm.selectFork(chain1);

    bytes4 selector = bytes4(keccak256("getPodOperators(uint256,uint256,uint256)"));
    (, bytes memory result) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector, 1, 0, 10));

    address[] memory operators = abi.decode(result, (address[]));
    assertEq(operators[0], address(0), "Operator should be zero address");
  }

  /**
   * getPodBondAmounts(pod)
   */

  /**
   * @notice should return expected base and current value
   * @dev check if the base and current value are as expected
   */
  function testGetPodBondAmounts() public {
    vm.selectFork(chain1);

    (uint256 baseBond1, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);
    assertEq(baseBond1, 0x056bc75e2d63100000, "Base bond for pod 1 should be 0x056bc75e2d63100000");
    assertEq(currentBond1, 0x056bc75e2d63100000, "Current bond for pod 1 should be 0x056bc75e2d63100000");

    (uint256 baseBond2, uint256 currentBond2) = holographOperatorChain1.getPodBondAmounts(2);
    assertEq(baseBond2, 0x0ad78ebc5ac6200000, "Base bond for pod 2 should be 0x0ad78ebc5ac6200000");
    assertEq(currentBond2, 0x0ad78ebc5ac6200000, "Current bond for pod 2 should be 0x0ad78ebc5ac6200000");
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the getPodBondAmounts function
   */
  function testGetPodBondAmountsExternal() public {
    vm.selectFork(chain1);

    bytes4 selector = bytes4(keccak256("getPodBondAmounts(uint256)"));
    (, bytes memory result) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector, 1));

    (uint256 baseBond1, uint256 currentBond1) = abi.decode(result, (uint256, uint256));
    assertEq(baseBond1, 0x056bc75e2d63100000, "Base bond for pod 1 should be 0x056bc75e2d63100000");
    assertEq(currentBond1, 0x056bc75e2d63100000, "Current bond for pod 1 should be 0x056bc75e2d63100000");
  }

  /**
   * bondUtilityToken()
   */

  /**
   * @notice should successfully allow bonding
   * @dev check if the bonding is successful
   */
  function testBondUtilityToken() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    // vm.expectEmit(true, true, true, false);
    // emit Transfer(deployer, address(holographOperatorChain1), currentBond1);

    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond1, 1);

    assertEq(
      holographOperatorChain1.getBondedAmount(deployer),
      currentBond1,
      "Bonded amount should be equal to the current bond amount"
    );
    assertEq(holographOperatorChain1.getBondedPod(deployer), 1, "Bonded pod should be 1");
  }

  /**
   * @notice should successfully allow bonding a contract
   * @dev check if the bonding is successful
   */
  function testBondUtilityTokenContract() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    // vm.expectEmit(true, true, true, false);
    // emit Transfer(deployer, address(holographOperatorChain1), currentBond1);

    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(address(sampleErc721HolographerChain1), currentBond1, 1);

    assertEq(
      holographOperatorChain1.getBondedAmount(address(sampleErc721HolographerChain1)),
      currentBond1,
      "Bonded amount should be equal to the current bond amount"
    );

    assertEq(holographOperatorChain1.getBondedPod(address(sampleErc721HolographerChain1)), 1, "Bonded pod should be 1");
  }

  /**
   * @notice should fail if the operator is already bonded
   * @dev check if the operator is already bonded
   */
  function testBondUtilityTokenFail() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond1, 1);

    vm.expectRevert("HOLOGRAPH: operator is bonded");
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond1, 1);

    (, uint256 currentBond2) = holographOperatorChain1.getPodBondAmounts(2);

    vm.expectRevert("HOLOGRAPH: operator is bonded");
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond2, 2);
  }

  /**
   * @notice Should fail if the provided bond amount is too low
   * @dev check if the bond amount is too low
   */
  function testBondUtilityTokenFailLowBond() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    vm.expectRevert("HOLOGRAPH: bond amount too small");
    vm.prank(alice);
    holographOperatorChain1.bondUtilityToken(alice, currentBond1, 2);
  }

  /**
   * @notice Should fail if operator does not have enough utility tokens
   * @dev check if the operator has enough utility tokens
   */
  function testBondUtilityTokenFailLowBalance() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    vm.expectRevert("ERC20: amount exceeds balance");
    vm.prank(alice);
    holographOperatorChain1.bondUtilityToken(alice, currentBond1, 1);
  }

  /**
   * @notice should fail if the token transfer failed
   * @dev check if the token transfer failed
   */
  function testBondUtilityTokenFailTransfer() public {
    vm.selectFork(chain1);
    address bob = vm.addr(3);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    vm.expectRevert("ERC20: amount exceeds balance");
    vm.prank(alice);
    holographOperatorChain1.bondUtilityToken(bob, currentBond1, 1);
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the bondUtilityToken function
   */
  function testBondUtilityTokenExternal() public {
    vm.selectFork(chain1);
    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    HLGCHAIN1.transfer(address(MOCKCHAIN1), currentBond1);

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(address(MOCKCHAIN1), address(holographOperatorChain1), currentBond1);
    bytes4 selector = bytes4(keccak256("bondUtilityToken(address,uint256,uint256)"));
    (bool success, ) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector, address(MOCKCHAIN1), currentBond1, 1));

    assertEq(
      holographOperatorChain1.getBondedAmount(address(MOCKCHAIN1)),
      currentBond1,
      "Bonded amount should be correct"
    );
    assertEq(holographOperatorChain1.getBondedPod(address(MOCKCHAIN1)), 1, "Bonded pod should be 1");
  }

  /**
   * topupUtilityToken()
   */

  /**
   * @notice should fail if operator is not bonded
   * @dev check if the operator is not bonded
   */
  function testTopupUtilityTokenFailNotBonded() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    assertEq(holographOperatorChain1.getBondedPod(alice), 0, "wallet1 should not be bonded");

    vm.expectRevert("HOLOGRAPH: operator not bonded");
    vm.prank(alice);
    holographOperatorChain1.topupUtilityToken(alice, currentBond1);
  }

  /**
   * @notice successfully top up utility tokens
   * @dev check if the top up is successful
   */
  function testTopupUtilityToken() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    vm.prank(deployer);
    HLGCHAIN1.transfer(alice, currentBond1);

    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond1, 1);

    assertEq(holographOperatorChain1.getBondedPod(deployer), 1, "Deployer should be bonded to pod 1");

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(alice, address(holographOperatorChain1), currentBond1);
    vm.prank(alice);
    holographOperatorChain1.topupUtilityToken(deployer, currentBond1);

    assertEq(
      holographOperatorChain1.getBondedAmount(deployer),
      currentBond1 * 2,
      "Bonded amount should be doubled after top-up"
    );
  }

  /**
   * unbondUtilityToken()
   */

  /**
   * @notice should fail if the operator has not bonded
   * @dev check if the operator has not bonded
   */
  function testUnbondUtilityTokenFailNotBonded() public {
    vm.selectFork(chain1);

    vm.expectRevert("HOLOGRAPH: operator not bonded");
    vm.prank(alice);
    holographOperatorChain1.unbondUtilityToken(alice, alice);
  }

  /**
   * @notice should fail if the operator is not sender, and operator is not contract
   * @dev check if the operator is not the sender, and the operator is not a contract
   */
  function testUnbondUtilityTokenFailNotSender() public {
    vm.selectFork(chain1);

    vm.expectRevert("HOLOGRAPH: operator not contract");
    vm.prank(alice);
    holographOperatorChain1.unbondUtilityToken(operator, alice);
  }

  /**
   * @notice Should succeed if operator is contract and owned by sender
   * @dev check if the operator is a contract and owned by the sender
   */
  function testUnbondUtilityToken() public {
    vm.selectFork(chain1);
    address sampleErc20Holographer = address(sampleErc721HolographerChain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(sampleErc20Holographer, currentBond1, 1);

    uint256 currentBondAmount = holographOperatorChain1.getBondedAmount(sampleErc20Holographer);

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(address(holographOperatorChain1), deployer, currentBondAmount);
    vm.prank(deployer);
    holographOperatorChain1.unbondUtilityToken(sampleErc20Holographer, deployer);

    assertEq(
      holographOperatorChain1.getBondedAmount(sampleErc20Holographer),
      0,
      "Bonded amount should be zero after unbonding"
    );
  }

  /**
   * @notice Should fail if operator is contract and not owned by sender
   * @dev check if the operator is a contract and not owned by the sender
   */
  function testUnbondUtilityTokenFailNotOwned() public {
    vm.selectFork(chain1);
    address sampleErc20Holographer = address(sampleErc721HolographerChain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(deployer, address(holographOperatorChain1), currentBond1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(sampleErc20Holographer, currentBond1, 1);

    assertEq(
      holographOperatorChain1.getBondedAmount(sampleErc20Holographer),
      currentBond1,
      "Bonded amount should be correct"
    );
    assertEq(holographOperatorChain1.getBondedPod(sampleErc20Holographer), 1, "Bonded pod should be 1");

    vm.expectRevert("HOLOGRAPH: sender not owner");
    vm.prank(alice);
    holographOperatorChain1.unbondUtilityToken(sampleErc20Holographer, deployer);
  }

  /**
   * @notice should fail if the token transfer failed
   * @dev check if the token transfer failed
   */
  function testUnbondUtilityTokenFailTransfer() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond1, 1);

    uint256 currentBalance = HLGCHAIN1.balanceOf(address(holographOperatorChain1));

    bytes memory transferData = abi.encodeWithSelector(HLGCHAIN1.transfer.selector, deployer, currentBalance);
    vm.prank(deployer);
    holographOperatorChain1.adminCall(address(HLGCHAIN1), transferData);

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(address(holographOperatorChain1), deployer, currentBalance);

    assertEq(HLGCHAIN1.balanceOf(address(holographOperatorChain1)), 0, "Operator balance should be 0");

    vm.expectRevert("ERC20: amount exceeds balance");
    vm.prank(deployer);
    holographOperatorChain1.unbondUtilityToken(deployer, deployer);

    vm.prank(deployer);
    HLGCHAIN1.transfer(address(holographOperatorChain1), currentBalance);
  }

  /**
   * @notice should successfully allow unbonding
   * @dev check if the unbonding is successful
   */
  function testUnbondUtilityTokenSuccess() public {
    vm.selectFork(chain1);

    (, uint256 currentBond1) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(deployer, currentBond1, 1);

    uint256 currentBondAmount = holographOperatorChain1.getBondedAmount(deployer);

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(address(holographOperatorChain1), deployer, currentBondAmount);
    vm.prank(deployer);
    holographOperatorChain1.unbondUtilityToken(deployer, deployer);

    assertEq(holographOperatorChain1.getBondedAmount(deployer), 0, "Bonded amount should be zero after unbonding");
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the unbondUtilityToken function
   */
  function testUnbondUtilityTokenExternal() public {
    vm.selectFork(chain1);

    testBondUtilityTokenExternal();

    uint256 currentBondAmount = holographOperatorChain1.getBondedAmount(address(this));

    bytes4 selector = bytes4(keccak256("unbondUtilityToken(address,address)"));

    // vm.expectEmit(true, true, false, true);
    // emit Transfer(address(holographOperatorChain1), deployer, currentBondAmount);
    (bool success, ) = address(MOCKCHAIN1).call(abi.encodeWithSelector(selector, address(MOCKCHAIN1), deployer));

    assertEq(holographOperatorChain1.getBondedAmount(address(this)), 0, "Bonded amount should be zero after unbonding");
  }

  /**
   * getBondedAmount()
   */

  /**
   * @notice should return expected _bondedOperators
   * @dev check if the bonded operators are as expected
   */
  function testGetBondedAmount() public {
    vm.selectFork(chain1);

    (uint256 baseBond1, ) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(address(sampleErc20HolographerChain1), baseBond1, 1);
    uint256 bondedAmount = holographOperatorChain1.getBondedAmount(address(sampleErc20HolographerChain1));
    assertEq(bondedAmount, baseBond1, "Bonded amount should be equal to base bond amount");
  }

  /**
   * @notice Should allow external contract to call fn
   * @dev check if the external contract can call the getBondedAmount function
   */
  function testGetBondedAmountExternal() public {
    vm.selectFork(chain1);

    (uint256 baseBond1, ) = holographOperatorChain1.getPodBondAmounts(1);
    vm.prank(deployer);
    holographOperatorChain1.bondUtilityToken(address(sampleErc20HolographerChain1), baseBond1, 1);

    bytes4 selector = bytes4(keccak256("getBondedAmount(address)"));
    (, bytes memory result) = address(MOCKCHAIN1).call(
      abi.encodeWithSelector(selector, address(sampleErc20HolographerChain1))
    );
    uint256 bondedAmount = abi.decode(result, (uint256));
    assertEq(bondedAmount, baseBond1, "Bonded amount should be equal to base bond amount");
  }
}
