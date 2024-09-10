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
import {LayerZeroModuleV2} from "src/module/LayerZeroModuleV2.sol";

import {Logger} from "./utils/Logger.sol";
import {bytesSlicer, ReturnType} from "./utils/BytesSlicer.sol";
import {ForkHelper} from "./utils/ForkHelper.sol";

contract LogModuleScript is Script, Logger {
  using stdJson for string;
  using bytesSlicer for bytes;

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
            unicode": \n    👉 ",
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
            unicode": \n    👉 ",
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
            unicode": \n    👉 ",
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
            unicode": \n    👉 ",
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
    bytes32 bridgeOutTxHash = json.readBytes32(".transactions[1].hash");

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
      try vm.parseJsonString(lzJson, ".data[0].status.name") returns (string memory status) {
        crossChainMessageStatus = status;
      } catch {
        crossChainMessageStatus = "";
      }

      // Increment the iteration count
      maxIterations--;

      if (maxIterations == 0) {
        break;
      }

      // Sleep for 5 seconds
      vm.sleep(5000);
    }

    string memory statusEmoji = keccak256(abi.encode(crossChainMessageStatus)) == keccak256(abi.encode("DELIVERED"))
      ? unicode"✅"
      : keccak256(abi.encode(crossChainMessageStatus)) == keccak256(abi.encode("INFLIGHT"))
      ? unicode"🛫"
      : unicode"❌";

    if (maxIterations == 0) {
      console.log(yellow("Cross chain message is still pending... Time out reached"));
      string memory sourceChainTxLink = ForkHelper.getTxLink(fromChainId, bridgeOutTxHash);
      console.log(
        string(
          abi.encodePacked(
            "\n",
            yellow(ForkHelper.getChainName(fromChainId)),
            unicode" transaction: \n    👉 ",
            cyan(sourceChainTxLink)
          )
        )
      );

      return;
    }

    crossChainMessageStatus = keccak256(abi.encode(crossChainMessageStatus)) == keccak256(abi.encode("DELIVERED"))
      ? green("DELIVERED")
      : keccak256(abi.encode(crossChainMessageStatus)) == keccak256(abi.encode("INFLIGHT"))
      ? magenta("INFLIGHT")
      : red("BLOCKED");

    // Log the cross chain message status
    logFrame(string(abi.encodePacked("Cross chain message status: ", statusEmoji, "  ", crossChainMessageStatus)));

    // Decode the transaction hashes
    bytes32 sourceChainTxHash = lzJson.readBytes32(".data[0].source.tx.txHash");
    bytes32 destinationChainTxHash = lzJson.readBytes32(".data[0].destination.tx.txHash");

    // Log the transactions links
    string memory sourceChainTxLink = ForkHelper.getTxLink(fromChainId, sourceChainTxHash);
    string memory destinationChainTxLink = ForkHelper.getTxLink(toChainId, destinationChainTxHash);

    // Log layer zero scan link
    console.log(
      string(
        abi.encodePacked(
          "\n",
          magenta("LayerZero"),
          unicode" scan: \n    👉 ",
          cyan(ForkHelper.getTxLink(0, bridgeOutTxHash)),
          "\n"
        )
      )
    );

    // Log the source chain transaction link
    console.log(
      string(
        abi.encodePacked(
          "\n",
          yellow(ForkHelper.getChainName(fromChainId)),
          unicode" transaction: \n    👉 ",
          cyan(sourceChainTxLink)
        )
      )
    );

    // Log the destination chain transaction link
    console.log(
      string(
        abi.encodePacked(
          "\n",
          yellow(ForkHelper.getChainName(toChainId)),
          unicode" transaction: \n    👉 ",
          cyan(destinationChainTxLink)
        )
      )
    );

    /* -------------------------------------------------------------------------- */
    /*                        Decode available job payload                        */
    /* -------------------------------------------------------------------------- */

    // cast receipt 0xd974491ef297c66272977507091a7bb45f1994ba1f7deecedaf19b9a9829f81e --rpc-url $ARBITRUM_TESTNET_SEPOLIA_RPC_URL -j

    // Fetch the destination chain transaction receipt
    string[] memory castInputs = new string[](6);
    castInputs[0] = "cast";
    castInputs[1] = "receipt";
    castInputs[2] = vm.toString(destinationChainTxHash);
    castInputs[3] = "--rpc-url";
    castInputs[4] = ForkHelper.getRpcUrl(toChainId);
    castInputs[5] = "-j";
    string memory receiptJson = string(vm.ffi(castInputs));

    // Decode the available job payload
    bytes memory logData = receiptJson.readBytes(".logs[0].data");

    (bytes32 jobHash, bytes memory payload) = abi.decode(logData, (bytes32, bytes));

    // Decode abi encoded and packed payload
    (bytes32 _selector, , , ) = payload.slice(0, 4, ReturnType.BYTES32);
    bytes4 selector = bytes4(_selector);
    (, uint256 nonce, , ) = payload.slice(4, 36, ReturnType.UINT256);
    (, uint256 holographChainId, , ) = payload.slice(36, 68, ReturnType.UINT256);
    (, , address holographableContract, ) = payload.slice(80, 100, ReturnType.ADDRESS);
    (, , address htoken, ) = payload.slice(112, 132, ReturnType.ADDRESS);
    (, uint256 hlgFee, , ) = payload.slice(132, 164, ReturnType.UINT256);
    (, uint256 _preventRevert, , ) = payload.slice(164, 196, ReturnType.UINT256);
    (, , , bytes memory bridgeOutPayload) = payload.slice(196, payload.length, ReturnType.BYTES);
    bool preventRevert = _preventRevert == 1;

    console.log("\n\n");
    logFrame(string(abi.encodePacked(
      "          ",
      magenta(ForkHelper.getChainName(toChainId)),
      "Available job payload          "
    )));
    console.log(string(abi.encodePacked("\nJob hash: ", cyan(vm.toString(jobHash)))));
    console.log(string(abi.encodePacked("Selector: ", blue(vm.toString(selector)))));
    console.log(string(abi.encodePacked("Nonce: ", yellow(vm.toString(nonce)))));
    console.log(string(abi.encodePacked("Holograph chain id: ", yellow(vm.toString(holographChainId)))));
    console.log(string(abi.encodePacked("Holographable contract: ", green(vm.toString(holographableContract)))));
    console.log(string(abi.encodePacked("Htoken: ", green(vm.toString(htoken)))));
    console.log(string(abi.encodePacked("Hlg fee: ", yellow(vm.toString(hlgFee)))));
    console.log(string(abi.encodePacked("Prevent revert: ", blue(vm.toString(_preventRevert)))));
    console.log(string(abi.encodePacked("Bridge out payload: ", gray(vm.toString(bridgeOutPayload)))));
  }
}
