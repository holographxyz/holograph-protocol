// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ICustomERC721Errors} from "test/foundry/interface/ICustomERC721Errors.sol";
import {CustomERC721Fixture} from "test/foundry/fixtures/CustomERC721Fixture.t.sol";

import {Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {DEFAULT_START_DATE, DEFAULT_MAX_SUPPLY, DEFAULT_MINT_INTERVAL, EVENT_CONFIG, HOLOGRAPH_REGISTRY_PROXY} from "test/foundry/CustomERC721/utils/Constants.sol";

import {ICustomERC721} from "src/interface/ICustomERC721.sol";
import {CustomERC721} from "src/token/CustomERC721.sol";
import {Strings} from "src/library/Strings.sol";
import {CustomERC721SalesConfiguration} from "src/struct/CustomERC721SalesConfiguration.sol";
import {CustomERC721Initializer} from "src/struct/CustomERC721Initializer.sol";
import {LazyMintConfiguration} from "src/struct/LazyMintConfiguration.sol";
import {HolographERC721} from "src/enforcer/HolographERC721.sol";

contract CustomERC721DeploymentTest is CustomERC721Fixture, ICustomERC721Errors {
  using Strings for uint256;

  constructor() {}

  function setUp() public override {
    super.setUp();
  }

  function test_DeployHolographCustomERC721() public {
    super.deployAndSetupProtocol(DEFAULT_MAX_SUPPLY, false);
    assertEq(customErc721.version(), 1);
    assertEq(customErc721.currentTheoricalMaxSupply(), DEFAULT_MAX_SUPPLY);
    assertEq(customErc721.START_DATE(), DEFAULT_START_DATE, "Wrong start date");
    assertEq(customErc721.MINT_INTERVAL(), DEFAULT_MINT_INTERVAL, "Wrong mint interval");
    assertEq(customErc721.INITIAL_MAX_SUPPLY(), DEFAULT_MAX_SUPPLY, "Wrong initial max supply");
    assertEq(
      customErc721.END_DATE(),
      DEFAULT_START_DATE + DEFAULT_MINT_INTERVAL * DEFAULT_MAX_SUPPLY,
      "Wrong initial end date"
    );
    assertEq(
      customErc721.INITIAL_END_DATE(),
      DEFAULT_START_DATE + DEFAULT_MINT_INTERVAL * DEFAULT_MAX_SUPPLY,
      "Wrong initial end date"
    );
  }

  function test_init() public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) {
    assertEq(customErc721.owner(), DEFAULT_OWNER_ADDRESS, "Default owner set wrong");
    assertEq(customErc721.FUNDS_RECIPIENT(), payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS), "FundsRecipient is wrong");

    // Setup sale config
    CustomERC721SalesConfiguration memory salesConfig = CustomERC721SalesConfiguration({
      publicSalePrice: 0,
      maxSalePurchasePerAddress: 0
    });

    HolographERC721 customErc721 = HolographERC721(payable(address(customErc721)));

    string memory name = customErc721.name();
    string memory symbol = customErc721.symbol();
    assertEq(name, "Contract Name", "Name is wrong");
    assertEq(symbol, "SYM", "Symbol is wrong");

    string memory contractName = "";
    string memory contractSymbol = "";
    uint16 contractBps = 1000;
    bool skipInit = false;

    vm.expectRevert("HOLOGRAPHER: already initialized");

    // Setup lazy mint config
    LazyMintConfiguration[] memory lazyMintsConfigurations = new LazyMintConfiguration[](2);
    lazyMintsConfigurations[0] = LazyMintConfiguration({
      _amount: DEFAULT_MAX_SUPPLY / 2,
      _baseURIForTokens: "https://placeholder-uri1.com/",
      _data: "0x00000000000000000000000000000000000000000000000000000000000000406fb73a8c26bf89ea9a8fa8c927042b0c602dc7dffb4614376384cbe15ebc45b40000000000000000000000000000000000000000000000000000000000000014d74bef972bcac96c0d83b64734870bfe84912893000000000000000000000000"
    });

    lazyMintsConfigurations[1] = LazyMintConfiguration({
      _amount: DEFAULT_MAX_SUPPLY / 2,
      _baseURIForTokens: "https://placeholder-uri2.com/",
      _data: "0x00000000000000000000000000000000000000000000000000000000000000406fb73a8c26bf89ea9a8fa8c927042b0c602dc7dffb4614376384cbe15ebc45b40000000000000000000000000000000000000000000000000000000000000014d74bef972bcac96c0d83b64734870bfe84912893000000000000000000000000"
    });

    CustomERC721Initializer memory initializer = CustomERC721Initializer({
      startDate: DEFAULT_START_DATE,
      initialMaxSupply: DEFAULT_MAX_SUPPLY,
      mintInterval: DEFAULT_MINT_INTERVAL,
      initialOwner: payable(DEFAULT_OWNER_ADDRESS),
      initialMinter: payable(DEFAULT_MINTER_ADDRESS),
      fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
      contractURI: "https://example.com/metadata.json",
      salesConfiguration: salesConfig,
      lazyMintsConfigurations: lazyMintsConfigurations
    });

    bytes memory initCode = abi.encode(
      bytes32(0x0000000000000000000000486f6c6f677261706844726f704552433732315632), // Source contract type HolographDropERC721V2
      HOLOGRAPH_REGISTRY_PROXY, // address of registry (to get source contract address from)
      abi.encode(initializer) // actual init code for source contract (HolographDropERC721V2)
    );

    customErc721.init(abi.encode(contractName, contractSymbol, contractBps, EVENT_CONFIG, skipInit, initCode));
  }
}
