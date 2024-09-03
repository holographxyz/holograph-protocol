// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

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
import {CxipERC721} from "src/token/CxipERC721.sol";
import {TokenUriType} from "src/enum/TokenUriType.sol";

contract LayerZeroModuleV2Script is Script {
  // Admin address
  address admin;
  // Arbitrum sepolia chain id
  uint256 arbSepoliaChainId = 421614;
  // Arbitrum sepolia endpoint id
  uint256 arbSepoliaEndpointId = 40231;
  // Arbitrum messaginf module address
  address arbSepoliaMessagingModule = address(0x4fbB6A2674De9d54684a4c78e6a3118A31347A53);

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
  // Current layerZeroModule
  LayerZeroModuleV2 currentLayerZeroModuleV2 = LayerZeroModuleV2(payable(0x64d76c3c8c5D14080ffbDfD947b5bC08e06926e1));

  // LayerZeroV2Module
  LayerZeroModuleV2 layerZeroV2ModuleImplementation;
  // LayerZeroV2Module
  LayerZeroModuleV2 layerZeroV2Module;

  function run() external {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER");
    address deployerAddress = vm.addr(deployerPrivateKey);
    vm.startBroadcast(deployerPrivateKey);

    admin = deployerAddress;

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
    peers[0] = EndpointPeer({peer: arbSepoliaMessagingModule, eid: uint32(arbSepoliaEndpointId)});

    bytes memory initCode = abi.encode(
      address(layerZeroV2ModuleImplementation),
      abi.encode(
        address(holographBridge),
        address(holographInterfaces),
        address(holographOperator),
        address(optimismGasPriceOracle),
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
    vm.label(_layerZeroV2Module.getLayerZeroModule(), "layerZeroV2Module implementation");

    // Cast to LayerZeroModuleV2 type
    layerZeroV2Module = LayerZeroModuleV2(payable(address(_layerZeroV2Module)));

    console.log("admin: %s", address(holographOperator.admin()));  

    // Set messaging module to the new LayerZeroModuleV2
    holographOperator.setMessagingModule(address(layerZeroV2Module));

    // Update holographInterface chainId map
    holographInterfaces.updateChainIdMap(
      ChainIdType.HOLOGRAPH,
      arbSepoliaChainId,
      ChainIdType.LAYERZERO,
      arbSepoliaEndpointId
    );

    vm.stopBroadcast();
  }

  function mintAndBridgeOut() public {
    uint256 deployerPrivateKey = vm.envUint("ERC721_OWNER");
    vm.startBroadcast(deployerPrivateKey);

    uint256 nextTokenId = 8;
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
  }

  function bridgeOutRequest() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER");
    vm.startBroadcast(deployerPrivateKey);

    holographBridge.bridgeOutRequest{value: 0.002 ether}(
      uint32(421614),
      erc721,
      13314000,
      40000000001,
      abi.encode(erc721Owner, erc721Owner, erc721TokenId)
    );

    vm.stopBroadcast();
  }
}
