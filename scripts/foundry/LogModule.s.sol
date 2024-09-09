// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Holograph} from "src/Holograph.sol";
import {HolographGenesis} from "src/HolographGenesis.sol";
import {HolographBridge} from "src/HolographBridge.sol";
import {HolographInterfaces} from "src/HolographInterfaces.sol";
import {HolographFactory} from "src/HolographFactory.sol";
import {HolographOperator} from "src/HolographOperator.sol";
import {LayerZeroModuleProxyV2} from "src/module/LayerZeroModuleProxyV2.sol";
import {LayerZeroModuleV2} from "src/module/LayerZeroModuleV2.sol";
import {GasParameters} from "src/struct/GasParameters.sol";
import {EndpointPeer} from "src/interface/ILayerZeroEndpointV2.sol";
import {HolographERC721Interface} from "src/interface/HolographERC721Interface.sol";
import {ChainIdType} from "src/enum/ChainIdType.sol";
import {CxipERC721} from "src/token/CxipERC721.sol";
import {TokenUriType} from "src/enum/TokenUriType.sol";
import {DeploymentConfig} from "src/struct/DeploymentConfig.sol";
import {Verification} from "src/struct/Verification.sol";

import {Logger} from "./utils/Logger.sol";
import {ChainGasParameters} from "./utils/ChainGasParameters.sol";
import {ForkHelper} from "./utils/ForkHelper.sol";
import {DeploymentHelper} from "./utils/DeploymentHelper.sol";

contract LogModuleScript is Script, Logger {
  using stdJson for string;

  // Admin address
  address admin;

  // Layer zero endpoint v2
  address lzEndpoint;
  address lzExecutor;

  // Deployed Cxip ERC721
  address erc721;
  address erc721Owner;

  // Protocol contracts
  Holograph holograph;
  HolographGenesis holographGenesis;
  HolographBridge holographBridge;
  HolographFactory holographFactory;
  HolographOperator holographOperator;
  HolographInterfaces holographInterfaces;

  // Gas price oracle
  address gasPriceOracle = address(0xbc246E7F89d3964bFC1dAd24060333AC1705b701);

  // New layer zero module deployment
  LayerZeroModuleV2 layerZeroV2ModuleImplementation;
  LayerZeroModuleV2 layerZeroV2Module;

  /**
   * @dev Print the usage of the script
   */
  function run() public {
    console.log(red("This script should not be run directly"));
  }

  /**
   * Deploy LayerZeroModuleV2 on multiple chains and update operators
   * @param chainIds The chain ids to deploy the LayerZeroModuleV2
   */
  function deployLzModulesAndUpdateOperatorsMultiChain(uint256[] calldata chainIds) external {
    string
      memory path = "broadcast/multi/LayerZeroModuleV2.s.sol-latest/deployLzModulesAndUpdateOperatorsMultiChain.json";
    string memory json = vm.readFile(path);

    for (uint256 i = 0; i < chainIds.length; i++) {
      // Decode chain id
      uint256 chainId = json.readUint(string(abi.encodePacked(".deployments[", vm.toString(i), "].chain")));
      string memory chainName = ForkHelper.getChainName(chainId);

      logFrame(string(abi.encodePacked("      ", magenta(chainName), " transactions      ")));

      /* --------------------------- Decode transactions -------------------------- */

      // Decode layer zero module v2 deployment transaction
      bytes32 layerZeroModuleV2DeployTx = json.readBytes32(
        string(abi.encodePacked(".deployments[", vm.toString(i), "].transactions[0].hash"))
      );
      // Decode genesis protocol deployment transaction
      bytes32 genesisProtocolDeployTx = json.readBytes32(
        string(abi.encodePacked(".deployments[", vm.toString(i), "].transactions[1].hash"))
      );
      // Decode the set operator setMessagingModule call
      bytes32 setOperatorSetMessagingModuleTx = json.readBytes32(
        string(abi.encodePacked(".deployments[", vm.toString(i), "].transactions[2].hash"))
      );
      // Decode the set HolographInterfaces updateChainIdMap call
      bytes32 setHolographInterfacesUpdateChainIdMapTx = json.readBytes32(
        string(abi.encodePacked(".deployments[", vm.toString(i), "].transactions[3].hash"))
      );

      /* --------------------------- Log block scan url --------------------------- */

      // Log layer zero module v2 deployment transaction
      console.log(
        string(
          abi.encodePacked(
            "\n\u2022 LayerZeroModuleV2 ",
            green("deployment"),
            ": \n    => ",
            cyan(ForkHelper.getTxLink(chainId, layerZeroModuleV2DeployTx))
          )
        )
      );
      // Log genesis protocol deployment transaction
      console.log(
        string(
          abi.encodePacked(
            "\n\u2022 Genesis LayerZeroModuleV2Proxy ",
            green("deployment"),
            ": \n    => ",
            cyan(ForkHelper.getTxLink(chainId, genesisProtocolDeployTx))
          )
        )
      );
      // Log the set operator setMessagingModule call
      console.log(
        string(
          abi.encodePacked(
            "\n\u2022 Operator setMessagingModule ",
            green("call"),
            ": \n    => ",
            cyan(ForkHelper.getTxLink(chainId, setOperatorSetMessagingModuleTx))
          )
        )
      );
      // Log the set HolographInterfaces updateChainIdMap call
      console.log(
        string(
          abi.encodePacked(
            "\n\u2022 HolographInterfaces updateChainIdMap ",
            green("call"),
            ": \n    => ",
            cyan(ForkHelper.getTxLink(chainId, setHolographInterfacesUpdateChainIdMapTx))
          )
        )
      );
      console.log("\n\n\n");
    }
  }

  /**
   * Mint a new ERC721 token and bridge it out to the destination chain
   * @param fromChainId The chain id of the source chain
   * @param toChainId The chain id of the destination chain
   */
  function mintAndBridgeOut(uint256 fromChainId, uint256 toChainId) public {
    // Read the layer zero module v2 deployment transaction
    string memory path = string(
      abi.encodePacked("broadcast/LayerZeroModuleV2.s.sol/", vm.toString(fromChainId), "/mintAndBridgeOut-latest.json")
    );
    string memory json = vm.readFile(path);

    // Decode layer zero module v2 deployment transaction
    bytes32 bridgeOutTxHash = json.readBytes32(string(abi.encodePacked(".transactions[1].hash")));

    // Execute the layer zero module v2 deployment transaction
    string[] memory inputs = new string[](4);
    inputs[0] = "bash";
    inputs[1] = "scripts/layerZeroApiMessage.sh";
    inputs[2] = vm.toString(bridgeOutTxHash);
    inputs[3] = ForkHelper.isTestnet(fromChainId) ? "--testnet" : "";
    string memory crossChainMessageStatus;
    string memory lzJson;

    uint256 maxIterations = 10;
    while (keccak256(abi.encode(crossChainMessageStatus)) != keccak256(abi.encode("DELIVERED"))) {
      lzJson = string(vm.ffi(inputs));

      // Decode the cross chain message status
      crossChainMessageStatus = lzJson.readString(".data[0].status.name");

      // Increment the iteration count
      maxIterations--;

      if (maxIterations == 0) {
        break;
      }

      // Sleep for 5 seconds
      vm.sleep(5000);
    }

    if (maxIterations == 0) {
      console.log(red("Cross chain message is still pending... Max iterations reached"));
      return;
    }

    crossChainMessageStatus = keccak256(abi.encode(crossChainMessageStatus)) == keccak256(abi.encode("DELIVERED"))
      ? green("DELIVERED")
      : keccak256(abi.encode(crossChainMessageStatus)) == keccak256(abi.encode("INFLIGHT")) ?
        magenta("INFLIGHT") :
        red("BLOCKED");

    // Log the cross chain message status
    logFrame(string(abi.encodePacked("Cross chain message status: ", crossChainMessageStatus)));

    // Decode the transaction hashes
    bytes32 sourceChainTxHash = lzJson.readBytes32(string(abi.encodePacked(".data[0].source.txHash")));
    bytes32 destinationChainTxHash = lzJson.readBytes32(string(abi.encodePacked(".data[0].destination.txHash")));

    // Log the transactions links
    string memory sourceChainTxLink = ForkHelper.getTxLink(fromChainId, sourceChainTxHash);
    string memory destinationChainTxLink = ForkHelper.getTxLink(toChainId, destinationChainTxHash);

    // Log the source chain transaction link
    console.log(
      string(
        abi.encodePacked(
          "\n\u2022 ", 
          blue(ForkHelper.getChainName(fromChainId)),
          " transaction: \n    => ",
          cyan(sourceChainTxLink),
          "\n\n"
        )
      )
    );

    // Log the destination chain transaction link
    console.log(
      string(
        abi.encodePacked(
          "\n\u2022 ", 
          green(ForkHelper.getChainName(toChainId)),
          " transaction: \n    => ",
          cyan(destinationChainTxLink),
          "\n\n"
        )
      )
    );
  }
}
