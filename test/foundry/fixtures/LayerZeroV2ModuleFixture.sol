// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {HolographBridge} from "src/HolographBridge.sol";
import {HolographInterfaces} from "src/HolographInterfaces.sol";
import {HolographFactory} from "src/HolographFactory.sol";
import {HolographOperator} from "src/HolographOperator.sol";
import {HolographRegistry} from "src/HolographRegistry.sol";
import {HolographTreasury} from "src/HolographTreasury.sol";
import {LayerZeroModuleProxyV2} from "src/module/LayerZeroModuleProxyV2.sol";
import {LayerZeroModuleV2} from "src/module/LayerZeroModuleV2.sol";
import {GasParameters} from "src/struct/GasParameters.sol";
import {EndpointPeer} from "src/interface/ILayerZeroEndpointV2.sol";
import {ChainIdType} from "src/enum/ChainIdType.sol";

import {Utils} from "../utils/Utils.sol";

contract LayerZeroV2ModuleFixture is Test {
  // Admin address
  address admin;
  // Arbitrum sepolia chain id
  uint256 arbSepoliaChainId = 421614;
  // Arbitrum sepolia endpoint id
  uint256 arbSepoliaEndpointId = 40231;

  // Layer zero endpoint v2
  address lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
  // Layer zero executor
  address lzExecutor = address(0xDc0D68899405673b932F0DB7f8A49191491A5bcB);

  // Deployed Cxip ERC721
  address erc721 = address(0x73e4d61F5C2b325EbE0ef33a0fd7089898556B83);
  // An owner of a Cxip ERC721 token
  address erc721Owner = address(0x983DD3402BF68Da001dd08c955D33A824CF22cB0);
  // A Cxip ERC721 token id owned by erc721Owner
  uint256 erc721TokenId = uint256(0xee6b284a00000000000000000000000000000000000000000000000000000001);

  // holographBridge proxy
  HolographBridge holographBridge = HolographBridge(payable(0xbe2B3b95927a4260CAc28Ec78a3EE33150F6eae9));
  // holographBridge proxy
  HolographInterfaces holographInterfaces = HolographInterfaces(payable(0x5d8Ec7806cF835628935b659fE046Be7b5d7b60C));
  // holographFactory proxy
  HolographFactory holographFactory = HolographFactory(payable(0x1dB08CabD0aE756D473052361d0706F5030E1Fa2));
  // holographOperator proxy
  HolographOperator holographOperator = HolographOperator(payable(0x9f411c719DCBD22716ff1B78f0dDFbd8C214f11B));
  // holographRegistry proxy
  HolographRegistry holographRegistry = HolographRegistry(payable(0xb41F36CA99BC7cfd7681b969c6E29EB5949A49a6));
  // holographTreasury proxy
  HolographTreasury holographTreasury = HolographTreasury(payable(0x0CFA0c4ADC6deA2e03C118C46293b62aDF0cAfD5));
  // Current layerZeroModule
  LayerZeroModuleV2 currentLayerZeroModuleV2 = LayerZeroModuleV2(payable(0x64d76c3c8c5D14080ffbDfD947b5bC08e06926e1));

  // LayerZeroV2Module
  LayerZeroModuleV2 layerZeroV2ModuleImplementation;
  // LayerZeroV2Module
  LayerZeroModuleV2 layerZeroV2Module;

  constructor() {}

  function setUp() public virtual {
    string memory forkUrl = vm.envString("OPTIMISM_TESTNET_SEPOLIA_RPC_URL");
    uint256 forkId = vm.createFork(forkUrl);
    vm.selectFork(forkId);

    admin = holographOperator.admin();
    vm.deal(admin, 10000 ether);
    vm.startPrank(admin);

    // Deploy layerZeroV2ModuleImplementation
    layerZeroV2ModuleImplementation = new LayerZeroModuleV2();

    // Deploy layerZeroV2Module
    LayerZeroModuleProxyV2 _layerZeroV2Module = new LayerZeroModuleProxyV2();

    // Get the gas price oracle
    address optimismGasPriceOracle = currentLayerZeroModuleV2.getOptimismGasPriceOracle();

    // Chains ids
    uint32[] memory chainIds = new uint32[](1);
    chainIds[0] = 421614; // arbitrum sepolia

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

    // Peers
    EndpointPeer[] memory peers = new EndpointPeer[](1);
    peers[0] = EndpointPeer({peer: address(holographBridge), eid: uint32(arbSepoliaEndpointId)});

    bytes memory initCode = abi.encode(
      address(layerZeroV2ModuleImplementation),
      abi.encode(
        address(holographBridge),
        address(holographInterfaces),
        address(holographOperator),
        address(optimismGasPriceOracle),
        lzEndpoint,
        admin,
        chainIds,
        gasParameters,
        peers
      )
    );

    // Init LayerZeroV2Module proxy
    _layerZeroV2Module.init(initCode);
    vm.label(_layerZeroV2Module.getLayerZeroModule(), "layerZeroV2Module implementation");

    // Cast to LayerZeroModuleV2 type
    layerZeroV2Module = LayerZeroModuleV2(payable(address(_layerZeroV2Module)));

    // Set lzExecutor
    vm.stopPrank();
    vm.prank(layerZeroV2Module.admin());
    layerZeroV2Module.setLZExecutor(lzExecutor);
    vm.startPrank(admin);

    // Set messaging module to the new LayerZeroModuleV2
    holographOperator.setMessagingModule(address(layerZeroV2Module));

    // Update holographInterface chainId map
    holographInterfaces.updateChainIdMap(
      ChainIdType.HOLOGRAPH,
      arbSepoliaChainId,
      ChainIdType.LAYERZERO,
      arbSepoliaEndpointId
    );

    /* -------------------------------------------------------------------------- */
    /*                               Label addresses                              */
    /* -------------------------------------------------------------------------- */

    // Label layerZeroV2ModuleImplementation
    vm.label(
      address(layerZeroV2ModuleImplementation),
      string(
        abi.encodePacked("layerZeroV2ModuleImplementation(", vm.toString(address(layerZeroV2ModuleImplementation)), ")")
      )
    );

    // Label layerZeroV2Module
    vm.label(
      address(layerZeroV2Module),
      string(abi.encodePacked("layerZeroV2Module(", vm.toString(address(layerZeroV2Module)), ")"))
    );

    // Label holographBridge
    vm.label(
      address(holographBridge),
      string(abi.encodePacked("holographBridge(", vm.toString(address(holographBridge)), ")"))
    );

    // Label holographInterfaces
    vm.label(
      address(holographInterfaces),
      string(abi.encodePacked("holographInterfaces(", vm.toString(address(holographInterfaces)), ")"))
    );

    // Label holographFactory
    vm.label(
      address(holographFactory),
      string(abi.encodePacked("holographFactory(", vm.toString(address(holographFactory)), ")"))
    );

    // Label holographOperator
    vm.label(
      address(holographOperator),
      string(abi.encodePacked("holographOperator(", vm.toString(address(holographOperator)), ")"))
    );

    // Label holographRegistry
    vm.label(
      address(holographRegistry),
      string(abi.encodePacked("holographRegistry(", vm.toString(address(holographRegistry)), ")"))
    );

    // Label holographTreasury
    vm.label(
      address(holographTreasury),
      string(abi.encodePacked("holographTreasury(", vm.toString(address(holographTreasury)), ")"))
    );

    // Label currentLayerZeroModuleV2
    vm.label(
      address(currentLayerZeroModuleV2),
      string(abi.encodePacked("currentLayerZeroModuleV2(", vm.toString(address(currentLayerZeroModuleV2)), ")"))
    );

    // Label admin
    vm.label(admin, string(abi.encodePacked("admin(", vm.toString(address(admin)), ")")));

    // Label erc721
    vm.label(erc721, string(abi.encodePacked("erc721(", vm.toString(address(erc721)), ")")));

    // Label erc721Owner
    vm.label(erc721Owner, string(abi.encodePacked("erc721Owner(", vm.toString(address(erc721Owner)), ")")));

    // Label lzEndpoint
    vm.label(lzEndpoint, string(abi.encodePacked("lzEndpoint(", vm.toString(address(lzEndpoint)), ")")));

    // Label optimismGasPriceOracle
    vm.label(
      optimismGasPriceOracle,
      string(abi.encodePacked("optimismGasPriceOracle(", vm.toString(address(optimismGasPriceOracle)), ")"))
    );
  }

  function test_bridgeOutRequest() public {
    holographBridge.bridgeOutRequest{value: 1 ether}(
      uint32(421614),
      erc721,
      13314000,
      40000000001,
      abi.encode(erc721Owner, erc721Owner, erc721TokenId)
    );
  }
}