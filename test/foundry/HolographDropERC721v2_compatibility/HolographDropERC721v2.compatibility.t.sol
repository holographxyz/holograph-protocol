// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Holograph} from "src/Holograph.sol";
import {HolographFactory} from "src/HolographFactory.sol";
import {HolographRegistry} from "src/HolographRegistry.sol";
import {HolographDropERC721} from "src/drops/token/HolographDropERC721.sol";
import {HolographDropERC721V2} from "src/drops/token/HolographDropERC721V2.sol";
import {HolographDropERC721Proxy} from "src/drops/proxy/HolographDropERC721Proxy.sol";
import {DeploymentConfig} from "src/struct/DeploymentConfig.sol";
import {Verification} from "src/struct/Verification.sol";
import {DropsInitializer} from "src/drops/struct/DropsInitializer.sol";
import {DropsInitializerV2} from "src/drops/struct/DropsInitializerV2.sol";
import {SalesConfiguration} from "src/drops/struct/SalesConfiguration.sol";
import {IHolographERC721Errors} from "src/interface/IHolographERC721Errors.sol";
import {DropsMetadataRenderer} from "src/drops/metadata/DropsMetadataRenderer.sol";

import {Utils} from "test/foundry/utils/Utils.sol";
import {Constants} from "test/foundry/HolographDropERC721v2_compatibility/utils/Constants.sol";
import {DummyMetadataRenderer} from "test/foundry/HolographDropERC721v2_compatibility/utils/DummyMetadataRenderer.sol";

import {Test, Vm} from "forge-std/Test.sol";

contract HolographDropERC721V2CompatibilityTest is Test, IHolographERC721Errors {
  /* --------------------------- Protocol contracts --------------------------- */
  Holograph public holograph;
  HolographFactory public factory;
  HolographRegistry public registry;

  address v1Address;
  address v2Address;

  HolographDropERC721 public holographDropERC721;
  HolographDropERC721V2 public holographDropErc721V2;
  DropsMetadataRenderer public dropsMetadataRenderer;
  DummyMetadataRenderer public dummyMetadataRenderer;

  /* ----------------------------- Tests constants ---------------------------- */
  address public constant DEFAULT_OWNER_ADDRESS = address(0x1);
  address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS = payable(address(0x2));
  address payable public constant HOLOGRAPH_TREASURY_ADDRESS = payable(address(0x3));
  address payable constant TEST_ACCOUNT = payable(address(0x888));
  address public constant MEDIA_CONTRACT = address(0x666);
  address public ALICE; // Not constant because it need to be set in the setUp

  uint256 public constant FIRST_TOKEN_ID =
    115792089183396302089269705419353877679230723318366275194376439045705909141505; // large 256 bit number due to chain id prefix

  modifier updateHolographDropERC721ImplementationToV2() {
    address registryAdmin = registry.getAdmin();

    vm.startPrank(registryAdmin);
    registry.setReservedContractTypeAddress(Utils.stringToBytes32("HolographERC721"), true);
    registry.setContractTypeAddress(Utils.stringToBytes32("HolographERC721"), address(holographDropErc721V2));

    _;
  }

  function setUp() public {
    uint256 forkId = vm.createFork("https://eth.llamarpc.com/");
    vm.selectFork(forkId);

    ALICE = vm.addr(1);

    holograph = Holograph(payable(Constants.getHolograph()));
    factory = HolographFactory(payable(Constants.getHolographFactoryProxy()));
    registry = HolographRegistry(payable(holograph.getRegistry()));
    holographDropERC721 = HolographDropERC721(
      payable(registry.getContractTypeAddress(Utils.stringToBytes32("HolographERC721")))
    );
    holographDropErc721V2 = new HolographDropERC721V2();
    v2Address = address(holographDropErc721V2);

    // Metadata renderers
    dropsMetadataRenderer = new DropsMetadataRenderer();
    dummyMetadataRenderer = new DummyMetadataRenderer();

    // Wrap in brackets to remove from stack in functions that use this modifier
    // Avoids stack to deep errors
    {
      // Setup sale config for edition
      SalesConfiguration memory saleConfig = SalesConfiguration({
        publicSaleStart: 0, // starts now
        publicSaleEnd: type(uint64).max, // never ends
        presaleStart: 0, // never starts
        presaleEnd: 0, // never ends
        publicSalePrice: 10 * 10 ** 6, // 100 USDC (6 decimals)
        maxSalePurchasePerAddress: 0, // no limit
        presaleMerkleRoot: bytes32(0) // no presale
      });

      DropsInitializer memory initializer = DropsInitializer({
        erc721TransferHelper: address(0x1234),
        marketFilterAddress: address(0x0),
        initialOwner: DEFAULT_OWNER_ADDRESS,
        fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
        editionSize: 2000,
        royaltyBPS: 800,
        enableOpenSeaRoyaltyRegistry: true,
        salesConfiguration: saleConfig,
        metadataRenderer: address(dummyMetadataRenderer),
        metadataRendererInit: ""
      });

      // Get deployment config, hash it, and then sign it
      DeploymentConfig memory config = getV1DeploymentConfig(
        "Test NFT", // contractName
        "TNFT", // contractSymbol
        1000, // contractBps
        Constants.getDropsEventConfig(), // eventConfig
        false, // skipInit
        initializer
      );
      bytes32 hash = keccak256(
        abi.encodePacked(
          config.contractType,
          config.chainType,
          config.salt,
          keccak256(config.byteCode),
          keccak256(config.initCode),
          ALICE
        )
      );

      (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hash);
      Verification memory signature = Verification(r, s, v);

      // Deploy the drop / edition
      vm.recordLogs();
      factory.deployHolographableContract(config, signature, ALICE); // Pass the payload hash, with the signature, and signer's address
      Vm.Log[] memory entries = vm.getRecordedLogs();

      // Extract the new drop address from the correct log entry and topic
      address newDropAddress = address(uint160(uint256(entries[2].topics[1])));
      HolographDropERC721Proxy proxy = HolographDropERC721Proxy(payable(address(newDropAddress)));
      v1Address = proxy.getHolographDropERC721Source();

      // Connect the drop implementation to the drop proxy address
      holographDropERC721 = HolographDropERC721(payable(newDropAddress));
    }
  }

  function test_FFI_V1() public view {
    HolographDropERC721Proxy proxy = HolographDropERC721Proxy(payable(address(holographDropERC721)));
    assertEq(address(proxy.getHolographDropERC721Source()), v1Address);
  }

  function test_FFI_V2() public updateHolographDropERC721ImplementationToV2 {
    HolographDropERC721Proxy proxy = HolographDropERC721Proxy(payable(address(holographDropERC721)));
    assertEq(address(proxy.getHolographDropERC721Source()), v2Address);
  }

  /* ---------------------------- Private functions --------------------------- */

  function getV1DeploymentConfig(
    string memory contractName,
    string memory contractSymbol,
    uint16 contractBps,
    uint256 eventConfig,
    bool skipInit,
    DropsInitializer memory initializer
  ) public view returns (DeploymentConfig memory) {
    bytes memory bytecode = abi.encodePacked(vm.getCode("HolographDropERC721Proxy.sol:HolographDropERC721Proxy"));
    bytes memory initCode = abi.encode(
      Utils.stringToBytes32("HolographDropERC721"), // Source contract type HolographDropERC721
      address(registry), // address of registry (to get source contract address from)
      abi.encode(initializer) // actual init code for source contract (HolographDropERC721)
    );

    return
      DeploymentConfig({
        contractType: Utils.stringToBytes32("HolographERC721"), // HolographERC721
        chainType: 1338, // holograph.getChainId(),
        salt: 0x0000000000000000000000000000000000000000000000000000000000000001, // random salt from user
        byteCode: bytecode, // custom contract bytecode
        initCode: abi.encode(contractName, contractSymbol, contractBps, eventConfig, skipInit, initCode) // init code is used to initialize the HolographERC721 enforcer
      });
  }
}
