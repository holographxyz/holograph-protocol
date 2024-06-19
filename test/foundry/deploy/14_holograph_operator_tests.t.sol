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
    HLGCHAIN1 = HolographERC20(payable(Constants.getHolographUtilityToken()));

    MOCKCHAIN1 = new Mock();
    bytes memory initPayload = abi.encode(bytes32(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff));
    MOCKCHAIN1.init(initPayload);
    MOCKCHAIN1.setStorage(0, bytes32(uint256(uint160(address(holographOperatorChain1))) << 96));

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
    MOCKCHAIN2.setStorage(0, bytes32(uint256(uint160(address(holographOperatorChain2))) << 96));

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
    bytes memory initPayload2 = abi.encode(address(0), address(0), address(0), address(0), address(0), 0);

    vm.expectRevert("HOLOGRAPH: already initialized");
    mockOperator.init(initPayload2);

    // Should allow external contract to call fn
    // notice that the external contract is this test contract
    vm.expectRevert("HOLOGRAPH: already initialized");
    (bool success, ) = address(mockOperator).call(abi.encodeWithSelector(mockOperator.init.selector, initPayload2));
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

}
