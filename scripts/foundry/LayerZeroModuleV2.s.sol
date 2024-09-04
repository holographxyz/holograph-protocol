// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {HolographBridge} from "src/HolographBridge.sol";
import {HolographInterfaces} from "src/HolographInterfaces.sol";
import {HolographFactory} from "src/HolographFactory.sol";
import {HolographOperator} from "src/HolographOperator.sol";
import {LayerZeroModuleProxyV2} from "src/module/LayerZeroModuleProxyV2.sol";
import {LayerZeroModuleV2} from "src/module/LayerZeroModuleV2.sol";
import {GasParameters} from "src/struct/GasParameters.sol";
import {EndpointPeer} from "src/interface/ILayerZeroEndpointV2.sol";
import {ChainIdType} from "src/enum/ChainIdType.sol";
import {CxipERC721} from "src/token/CxipERC721.sol";
import {TokenUriType} from "src/enum/TokenUriType.sol";
import {DeploymentConfig} from "src/struct/DeploymentConfig.sol";
import {Verification} from "src/struct/Verification.sol";
import {Colors} from "./utils/Colors.sol";

contract LayerZeroModuleV2Script is Script, Colors {
  // Admin address
  address admin;

  // Destination chain data
  uint256 destinationChainChainId;
  uint256 destinationChainEndpointId;
  address destinationChainMessagingModule;

  // Layer zero endpoint v2
  address lzEndpoint;
  address lzExecutor;

  // Deployed Cxip ERC721
  address erc721;
  address erc721Owner;
  uint256 erc721TokenIdToBridge;

  // Protocol contracts
  HolographBridge holographBridge;
  HolographFactory holographFactory;
  HolographOperator holographOperator;
  HolographInterfaces holographInterfaces;
  LayerZeroModuleV2 previousLayerZeroModuleV2;

  // Gas price oracle
  address gasPriceOracle;

  // New layer zero module deployment
  LayerZeroModuleV2 layerZeroV2ModuleImplementation;
  LayerZeroModuleV2 layerZeroV2Module;

  /**
   * @dev Print the usage of the script
   */
  function run() public {
    console.log(blue("\n== You need to specify a signature (--sig) to run the script you want==\n"));
    console.log("  Supported signatures:");
    console.log(
      string(
        abi.encodePacked(
          "    - ",
          yellow("deployLzModuleAndUpdateOperator"),
          "(",
          green("uint256"),
          ")",
          magenta(" ==> "),
          green("uint256"),
          " ",
          cyan("destinationChainId")
        )
      )
    );
    console.log(string(abi.encodePacked("    - ", yellow("deployHolographableCxipErc721Contract"), "()")));
    console.log(
      string(
        abi.encodePacked(
          "    - ",
          yellow("mintAndBridgeOut"),
          "(",
          green("uint256"),
          ")",
          magenta(" ==> "),
          green("uint256"),
          " ",
          cyan("destinationChainId")
        )
      )
    );
    console.log(
      string(
        abi.encodePacked(
          "    - ",
          yellow("bridgeOutRequest"),
          "(",
          green("uint256"),
          ")",
          magenta(" ==> "),
          green("uint256"),
          " ",
          cyan("destinationChainId")
        )
      )
    );
    console.log(
      string(
        abi.encodePacked(
          "    - ",
          yellow("setPeer"),
          "(",
          green("uint32"),
          ",",
          green("address"),
          ")",
          magenta(" ==> "),
          green("uint32"),
          " ",
          cyan("eid"),
          ", ",
          green("address"),
          " ",
          cyan("peer")
        )
      )
    );

    console.log(blue("\n\n== Usage =="));
    console.log(
      string(
        abi.encodePacked(
          "pnpm ",
          green("forge:layerZeroModuleV2"),
          " ",
          yellow("[...FUNC_ARGS]"),
          " --sig ",
          magenta("[FUNC_SIG]"),
          ""
        )
      )
    );

    console.log(blue("\n== Example =="));
    console.log(
      string(
        abi.encodePacked(
          "pnpm ",
          green("forge:layerZeroModuleV2"),
          " ",
          yellow("421614"),
          " --sig ",
          magenta('"deployLzModuleAndUpdateOperator(uint256)"')
        )
      )
    );
  }

  /**
   * Deploy a LayerZeroModuleV2Proxy with the new LayerZeroModuleV2 implementation and update the operator's messaging module
   * @dev You still need to set the peers after this deployment
   * @param _destinationChainId The chain id of the destination chain
   */
  function deployLzModuleAndUpdateOperator(uint256 _destinationChainId) external {
    destinationChainChainId = _destinationChainId;
    loadEnvWithDestinationChain(_destinationChainId);

    // Broadcast transaction with deployer private key
    uint256 deployerPrivateKey = vm.envUint("PROTOCOL_ADMIN");
    admin = vm.addr(deployerPrivateKey);
    vm.startBroadcast(deployerPrivateKey);


    // Deploy layerZeroV2ModuleImplementation
    layerZeroV2ModuleImplementation = new LayerZeroModuleV2();

    // Deploy layerZeroV2Module
    LayerZeroModuleProxyV2 _layerZeroV2Module = new LayerZeroModuleProxyV2();

    // Chains ids
    uint32[] memory chainIds = new uint32[](1);
    chainIds[0] = uint32(destinationChainChainId);

    // Gas parameters
    GasParameters[] memory gasParameters = new GasParameters[](1);
    gasParameters[0] = GasParameters({
      msgBaseGas: 110000,
      msgGasPerByte: 25,
      jobBaseGas: 160000,
      jobGasPerByte: 25,
      minGasPrice: 40000000000,
      maxGasLimit: 15000000
    });

    // Empty peers during deployment
    EndpointPeer[] memory peers = new EndpointPeer[](0);

    // Encode Layer zero module proxy init code
    bytes memory initCode = abi.encode(
      address(layerZeroV2ModuleImplementation),
      abi.encode(
        address(holographBridge),
        address(holographInterfaces),
        address(holographOperator),
        address(gasPriceOracle),
        lzEndpoint,
        lzExecutor,
        admin,
        chainIds,
        gasParameters,
        peers
      )
    );

    // Init LayerZeroV2Module proxy
    _layerZeroV2Module.init(initCode);

    // Label the new layerZeroV2Module
    vm.label(_layerZeroV2Module.getLayerZeroModule(), "layerZeroV2Module implementation");

    // Cast to LayerZeroModuleV2 type
    layerZeroV2Module = LayerZeroModuleV2(payable(address(_layerZeroV2Module)));

    // Set operator's messaging module to the new LayerZeroModuleV2
    holographOperator.setMessagingModule(address(layerZeroV2Module));

    // Update holographInterface chainId map
    holographInterfaces.updateChainIdMap(
      ChainIdType.HOLOGRAPH,
      destinationChainChainId,
      ChainIdType.LAYERZERO,
      destinationChainEndpointId
    );

    console.log(
      string(
        abi.encodePacked(yellow("New LayerZeroModuleV2 deployed at: "), green(vm.toString(address(layerZeroV2Module))))
      )
    );

    // Stop broadcast
    vm.stopBroadcast();
  }

  /**
   * Deploy a CXIP ERC721 holographable contract as the ERC721 owner
   */
  function deployHolographableCxipErc721Contract() public {
    loadEnv();

    uint256 erc721OwnerPrivateKey = vm.envUint("ERC721_OWNER");
    erc721Owner = vm.addr(erc721OwnerPrivateKey);
    vm.startBroadcast(erc721Owner);

    bytes32 contractType = 0x0000000000000000000000000000000000486f6c6f6772617068455243373231;
    uint32 chainType = 11155420;
    bytes32 salt = 0x0000000000000000000000000000000000000000000000000000019167b7184c;
    bytes
      memory byteCode = hex"608060405234801561001057600080fd5b50610b32806100206000396000f3fe6080604052600436106100695760003560e01c8063704b6c0211610043578063704b6c0214610166578063bf64a82d14610186578063f851a4401461019957610070565b806342809873146100a25780634ddf47d4146100e15780636e9960c31461013257610070565b3661007057005b600061007a6101ae565b90503660008037600080366000845af43d6000803e80801561009b573d6000f35b3d6000fd5b005b3480156100ae57600080fd5b506100b76101ae565b60405173ffffffffffffffffffffffffffffffffffffffff90911681526020015b60405180910390f35b3480156100ed57600080fd5b506101016100fc366004610845565b61028d565b6040517fffffffff0000000000000000000000000000000000000000000000000000000090911681526020016100d8565b34801561013e57600080fd5b507f3f106594dc74eeef980dae234cde8324dc2497b13d27a0c59e55bd2ca10a07c9546100b7565b34801561017257600080fd5b506100a06101813660046108ea565b6105a2565b6100a061019436600461090e565b61067c565b3480156101a557600080fd5b506100b7610752565b7fce8e75d5c5227ce29a4ee170160bb296e5dea6934b80a9bd723f7ef1e7c850e7547f0b671eb65810897366dd82c4cbb7d9dff8beda8484194956e81e89b8a361d9c7546040517fcc2913f900000000000000000000000000000000000000000000000000000000815260048101829052600092919073ffffffffffffffffffffffffffffffffffffffff83169063cc2913f990602401602060405180830381865afa158015610262573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906102869190610993565b9250505090565b60006102b77f4e5f991bca30eca2d4643aaefa807e88f96a4a97398933d572a3c0d973004a015490565b15610323576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601e60248201527f484f4c4f47524150483a20616c726561647920696e697469616c697a6564000060448201526064015b60405180910390fd5b60008060008480602001905181019061033c91906109e0565b925092509250827f0b671eb65810897366dd82c4cbb7d9dff8beda8484194956e81e89b8a361d9c755817fce8e75d5c5227ce29a4ee170160bb296e5dea6934b80a9bd723f7ef1e7c850e7556000806103936101ae565b73ffffffffffffffffffffffffffffffffffffffff16836040516024016103ba9190610a76565b604080517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08184030181529181526020820180517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff167f4ddf47d4000000000000000000000000000000000000000000000000000000001790525161043b9190610ac7565b600060405180830381855af49150503d8060008114610476576040519150601f19603f3d011682016040523d82523d6000602084013e61047b565b606091505b50915091506000818060200190518101906104969190610ae3565b90508280156104e657507fffffffff0000000000000000000000000000000000000000000000000000000081167f4ddf47d400000000000000000000000000000000000000000000000000000000145b61054c576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601560248201527f696e697469616c697a6174696f6e206661696c65640000000000000000000000604482015260640161031a565b61057560017f4e5f991bca30eca2d4643aaefa807e88f96a4a97398933d572a3c0d973004a0155565b507f4ddf47d400000000000000000000000000000000000000000000000000000000979650505050505050565b7f3f106594dc74eeef980dae234cde8324dc2497b13d27a0c59e55bd2ca10a07c95473ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614610658576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601e60248201527f484f4c4f47524150483a2061646d696e206f6e6c792066756e6374696f6e0000604482015260640161031a565b7f3f106594dc74eeef980dae234cde8324dc2497b13d27a0c59e55bd2ca10a07c955565b7f3f106594dc74eeef980dae234cde8324dc2497b13d27a0c59e55bd2ca10a07c95473ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614610732576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601e60248201527f484f4c4f47524150483a2061646d696e206f6e6c792066756e6374696f6e0000604482015260640161031a565b808260003760008082600034875af13d6000803e80801561009b573d6000f35b600061077c7f3f106594dc74eeef980dae234cde8324dc2497b13d27a0c59e55bd2ca10a07c95490565b905090565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b604051601f82017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016810167ffffffffffffffff811182821017156107f7576107f7610781565b604052919050565b600067ffffffffffffffff82111561081957610819610781565b50601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01660200190565b60006020828403121561085757600080fd5b813567ffffffffffffffff81111561086e57600080fd5b8201601f8101841361087f57600080fd5b803561089261088d826107ff565b6107b0565b8181528560208385010111156108a757600080fd5b81602084016020830137600091810160200191909152949350505050565b73ffffffffffffffffffffffffffffffffffffffff811681146108e757600080fd5b50565b6000602082840312156108fc57600080fd5b8135610907816108c5565b9392505050565b60008060006040848603121561092357600080fd5b833561092e816108c5565b9250602084013567ffffffffffffffff8082111561094b57600080fd5b818601915086601f83011261095f57600080fd5b81358181111561096e57600080fd5b87602082850101111561098057600080fd5b6020830194508093505050509250925092565b6000602082840312156109a557600080fd5b8151610907816108c5565b60005b838110156109cb5781810151838201526020016109b3565b838111156109da576000848401525b50505050565b6000806000606084860312156109f557600080fd5b835192506020840151610a07816108c5565b604085015190925067ffffffffffffffff811115610a2457600080fd5b8401601f81018613610a3557600080fd5b8051610a4361088d826107ff565b818152876020838501011115610a5857600080fd5b610a698260208301602086016109b0565b8093505050509250925092565b6020815260008251806020840152610a958160408501602087016109b0565b601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0169190910160400192915050565b60008251610ad98184602087016109b0565b9190910192915050565b600060208284031215610af557600080fd5b81517fffffffff000000000000000000000000000000000000000000000000000000008116811461090757600080fdfea164736f6c634300080d000a";
    bytes
      memory initCode = hex"00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000000a45524337323154657374000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003545354000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000043786970455243373231000000000000000000000000c0768aa301fa733e45b2de64657f952407ec564b00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000020000000000000000000000000983dd3402bf68da001dd08c955d33a824cf22cb0";

    DeploymentConfig memory deploymentConfig = DeploymentConfig(contractType, chainType, salt, byteCode, initCode);

    bytes32 messageToSign = keccak256(
      abi.encodePacked(contractType, chainType, salt, keccak256(byteCode), keccak256(initCode), erc721Owner)
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(erc721OwnerPrivateKey, messageToSign);

    Verification memory verification = Verification(r, s, v);

    holographFactory.deployHolographableContract(deploymentConfig, verification, erc721Owner);

    console.log(string(abi.encodePacked(yellow("New CxipERC721 contract deployed at: "), green(vm.toString(erc721)))));
  }

  /**
   * Mint a new ERC721 token and bridge it out to the destination chain
   */
  function mintAndBridgeOut(uint256 _destinationChainChainId) public {
    destinationChainChainId = _destinationChainChainId;
    loadEnvWithDestinationChain(destinationChainChainId);

    uint256 deployerPrivateKey = vm.envUint("ERC721_OWNER");
    vm.startBroadcast(deployerPrivateKey);

    // Psuedo random token id in range [0, 1_000_000)
    uint256 nextTokenId = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 1_000_000;
    uint256 chainPrepend = uint256(0xee6b284a00000000000000000000000000000000000000000000000000000000);
    uint256 prefixedTokenId = chainPrepend + uint256(nextTokenId);

    // Mint ERC721 token
    CxipERC721(payable(erc721)).cxipMint(
      uint224(nextTokenId),
      TokenUriType.HTTPS,
      "https://www.alter-a.com/wp-content/uploads/2019/07/Test-Logo-Small-Black-transparent-1.png"
    );

    // Bridge out request
    holographBridge.bridgeOutRequest{value: 0.002 ether}(
      uint32(421614),
      erc721,
      13314000,
      40000000001,
      abi.encode(erc721Owner, erc721Owner, prefixedTokenId)
    );

    console.log(
      string(
        abi.encodePacked(
          yellow("Minted ERC721 token with id: "),
          green(vm.toString(nextTokenId)),
          "\n",
          yellow("prefixed id: "),
          green(vm.toString(prefixedTokenId)),
          "\n",
          yellow("Bridged it out to the destination chain("),
          magenta(vm.toString(destinationChainChainId)),
          yellow(")")
        )
      )
    );
  }

  /**
   * Bridge out an existing ERC721 token to the destination chain
   */
  function bridgeOutRequest(uint256 _destinationChainChainId) public {
    destinationChainChainId = _destinationChainChainId;
    loadEnvWithDestinationChain(destinationChainChainId);

    uint256 deployerPrivateKey = vm.envUint("PROTOCOL_ADMIN");
    vm.startBroadcast(deployerPrivateKey);

    holographBridge.bridgeOutRequest{value: 0.002 ether}(
      uint32(421614),
      erc721,
      13314000,
      40000000001,
      abi.encode(erc721Owner, erc721Owner, erc721TokenIdToBridge)
    );

    vm.stopBroadcast();
  }

  /**
   * Set LayerZeroModuleV2 peers
   * @param eid The endpoint id
   * @param peer The peer
   */
  function setPeer(uint32 eid, address peer) public {
    uint256 deployerPrivateKey = vm.envUint("PROTOCOL_ADMIN");
    vm.startBroadcast(deployerPrivateKey);

    string memory currentChainPrefix = getChainEnvPrefix(block.chainid);
    layerZeroV2Module = LayerZeroModuleV2(
      payable(vm.envAddress(string(abi.encodePacked(currentChainPrefix, "MODULE_V2"))))
    );

    layerZeroV2Module.setPeer(eid, bytes32(uint256(uint160(peer))));

    console.log(
      string(
        abi.encodePacked(
          yellow("Set peer for endpoint id: "),
          green(vm.toString(eid)),
          yellow(" to: "),
          green(vm.toString(peer))
        )
      )
    );

    vm.stopBroadcast();
  }

  /**
   * Execute a job on the Holograph operator
   */
  function executeJob() public {
    loadEnv();

    uint256 deployerPrivateKey = vm.envUint("PROTOCOL_ADMIN");
    vm.startBroadcast(deployerPrivateKey);

    bytes memory jobPayload = vm.envBytes("JOB_PAYLOAD");

    holographOperator.executeJob(jobPayload);

    vm.stopBroadcast();
  }

  /* -------------------------------------------------------------------------- */
  /*                              Private functions                             */
  /* -------------------------------------------------------------------------- */

  /**
   * Overload loadEnv to load the environment variables for the destination chain
   */
  function loadEnv() private {
    loadEnvWithDestinationChain(0);
  }

  /**
   * Load the environment variables for the current chain and the destination chain
   * @param destinationChainId The chain id of the destination chain
   */
  function loadEnvWithDestinationChain(uint256 destinationChainId) private {
    /* -------------------------------------------------------------------------- */
    /*                         Load environment variables                         */
    /* -------------------------------------------------------------------------- */

    holographBridge = HolographBridge(payable(vm.envAddress("BRIDGE_ADDRESS")));
    holographFactory = HolographFactory(payable(vm.envAddress("FACTORY_ADDRESS")));
    holographOperator = HolographOperator(payable(vm.envAddress("OPERATOR_ADDRESS")));
    holographInterfaces = HolographInterfaces(payable(vm.envAddress("INTERFACES_ADDRESS")));

    previousLayerZeroModuleV2 = LayerZeroModuleV2(payable(holographOperator.getMessagingModule()));

    /* -------------------------- Destination chain env ------------------------- */

    if (destinationChainId != 0) {
      string memory destinationChainPrefix = getChainEnvPrefix(destinationChainId);
      destinationChainEndpointId = vm.envUint(string(abi.encodePacked(destinationChainPrefix, "LZ_ENDPOINT_ID")));
      destinationChainMessagingModule = vm.envAddress(string(abi.encodePacked(destinationChainPrefix, "MODULE_V2")));
    }

    /* ---------------------------- Source chain env ---------------------------- */

    string memory sourceChainPrefix = getChainEnvPrefix(block.chainid);
    lzEndpoint = vm.envAddress(string(abi.encodePacked(sourceChainPrefix, "LZ_ENDPOINT_ADDRESS")));
    lzExecutor = vm.envAddress(string(abi.encodePacked(sourceChainPrefix, "LZ_EXECUTOR_ADDRESS")));

    gasPriceOracle = vm.envAddress(string(abi.encodePacked(sourceChainPrefix, "GAS_PRICE_ORACLE")));

    erc721 = vm.envAddress(string(abi.encodePacked(sourceChainPrefix, "ERC721_CONTRACT")));
    (, bytes memory owner) = erc721.call(abi.encodeWithSignature("owner()"));
    erc721Owner = abi.decode(owner, (address));
    erc721TokenIdToBridge = vm.envUint(string(abi.encodePacked(sourceChainPrefix, "ERC721_TOKEN_ID")));

    /* -------------------------------------------------------------------------- */
    /*                         Print environment variables                        */
    /* -------------------------------------------------------------------------- */

    string memory promptMessage = string(
      abi.encodePacked(
        green("\n====== CURRENT CHAIN: "),
        red(vm.toString(block.chainid)),
        " / ",
        yellow(sourceChainPrefix),
        green(" ======"),
        blue("\n\n== Loaded environment ==\n"),
        cyan("\n  Protocol addresses:"),
        string(
          abi.encodePacked("\n    ", yellow("HolographBridge"), ":", " ", green(vm.toString(address(holographBridge))))
        ),
        string(
          abi.encodePacked(
            "\n    ",
            yellow("HolographFactory"),
            ":",
            " ",
            green(vm.toString(address(holographFactory)))
          )
        ),
        string(
          abi.encodePacked(
            "\n    ",
            yellow("HolographOperator"),
            ":",
            " ",
            green(vm.toString(address(holographOperator)))
          )
        ),
        string(
          abi.encodePacked(
            "\n    ",
            yellow("HolographInterfaces"),
            ":",
            " ",
            green(vm.toString(address(holographInterfaces)))
          )
        ),
        string(
          abi.encodePacked(
            "\n    ",
            yellow("Previous LayerZeroModuleV2"),
            ":",
            " ",
            green(vm.toString(address(previousLayerZeroModuleV2)))
          )
        ),
        cyan("\n\n  Destination chain:"),
        string(
          abi.encodePacked(
            "\n    ",
            yellow("Destination chain endpoint id"),
            ":",
            " ",
            green(vm.toString(destinationChainEndpointId))
          )
        ),
        string(
          abi.encodePacked(
            "\n    ",
            yellow("Destination chain messaging module"),
            ":",
            " ",
            green(vm.toString(destinationChainMessagingModule))
          )
        ),
        cyan("\n\n  Layer zero addresses:"),
        string(abi.encodePacked("\n    ", yellow("LayerZeroEndpoint"), ":", " ", green(vm.toString(lzEndpoint)))),
        string(abi.encodePacked("\n    ", yellow("LayerZeroExecutor"), ":", " ", green(vm.toString(lzExecutor)))),
        cyan("\n\n  CxipERC721 contract:"),
        string(abi.encodePacked("\n    ", yellow("ERC721 contract"), ":", " ", green(vm.toString(erc721)))),
        string(abi.encodePacked("\n    ", yellow("ERC721 owner"), ":", " ", green(vm.toString(erc721Owner)))),
        string(
          abi.encodePacked(
            "\n    ",
            yellow("ERC721 token id to bridge"),
            ":",
            " ",
            green(vm.toString(erc721TokenIdToBridge))
          )
        ),
        string(abi.encodePacked("\n\nDo you want to proceed? (", green("y"), "/", red("N"), ")"))
      )
    );

    /* -------------------------------------------------------------------------- */
    /*                             Prompt confirmation                            */
    /* -------------------------------------------------------------------------- */

    string memory input = vm.prompt(promptMessage);
    if (
      keccak256(abi.encodePacked(input)) != keccak256(abi.encodePacked("y")) &&
      keccak256(abi.encodePacked(input)) != keccak256(abi.encodePacked("Y"))
    ) {
      revert(red("Script execution aborted"));
    }
  }

  /**
   * Get the chain environment prefix based on the chain id
   * @param chainId The chain id
   */
  function getChainEnvPrefix(uint256 chainId) private pure returns (string memory) {
    /* -------------------------------- Mainnets -------------------------------- */
    if (chainId == 1) {
      return "ETH_";
    } else if (chainId == 137) {
      return "POLYGON_";
    } else if (chainId == 43114) {
      return "AVALANCHE_";
    } else if (chainId == 56) {
      return "BSC_";
    } else if (chainId == 10) {
      return "OP_";
    } else if (chainId == 42161) {
      return "ARBITRUM_";
    } else if (chainId == 7777777) {
      return "ZORA_";
    } else if (chainId == 5000) {
      return "MANTLE_";
    } else if (chainId == 8453) {
      return "BASE_";
    } else if (chainId == 59144) {
      return "LINEA_";
    }
    /* -------------------------------- Testnets -------------------------------- */
    else if (chainId == 11155111) {
      return "SEPOLIA_";
    } else if (chainId == 80001) {
      return "MUMBAI_";
    } else if (chainId == 43113) {
      return "FUJI_";
    } else if (chainId == 97) {
      return "BSC_TESTNET_";
    } else if (chainId == 11155420) {
      return "OP_SEPOLIA_";
    } else if (chainId == 421614) {
      return "ARB_SEPOLIA_";
    } else if (chainId == 999999999) {
      return "ZORA_SEPOLIA_";
    } else if (chainId == 5003) {
      return "MANTLE_SEPOLIA_";
    } else if (chainId == 84532) {
      return "BASE_SEPOLIA_";
    } else if (chainId == 59141) {
      return "LINEA_SEPOLIA_";
    } else {
      return "DEFAULT_";
    }
  }
}
