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

contract HolographOperatorTests is CrossChainUtils {
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
    bytes memory initPayload2 = abi.encode(
        address(0),
        address(0),
        address(0),
        address(0),
        address(0),
        0
    );

    vm.expectRevert("HOLOGRAPH: already initialized");
    mockOperator.init(initPayload2);

    // Should allow external contract to call fn
    // notice that the external contract is this test contract
    vm.expectRevert("HOLOGRAPH: already initialized");
    (bool success,) = address(mockOperator).call(abi.encodeWithSelector(mockOperator.init.selector, initPayload2));
  }

  /**
   * @notice should fail if already initialized
   * @dev this test is included in testInit() to avoid duplicate code
   */

  /**
   * @notice Should allow external contract to call fn
   * @dev this test is included in testInit() to avoid duplicate code
   */


}
