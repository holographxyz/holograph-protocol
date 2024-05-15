// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ICustomERC721Errors} from "test/foundry/interface/ICustomERC721Errors.sol";
import {CountdownERC721Fixture} from "test/foundry/fixtures/CountdownERC721Fixture.t.sol";

import {Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {DEFAULT_START_DATE, DEFAULT_MAX_SUPPLY, DEFAULT_MINT_INTERVAL, EVENT_CONFIG, HOLOGRAPH_REGISTRY_PROXY} from "test/foundry/CountdownERC721/utils/Constants.sol";

import {ICountdownERC721} from "src/interface/ICountdownERC721.sol";
import {CountdownERC721} from "src/token/CountdownERC721.sol";
import {Strings} from "src/library/Strings.sol";
import {CustomERC721SalesConfiguration} from "src/struct/CustomERC721SalesConfiguration.sol";
import {CustomERC721Initializer} from "src/struct/CustomERC721Initializer.sol";
import {LazyMintConfiguration} from "src/struct/LazyMintConfiguration.sol";
import {HolographERC721} from "src/enforcer/HolographERC721.sol";

contract CountdownERC721DeploymentTest is CountdownERC721Fixture, ICustomERC721Errors {
  using Strings for uint256;

  constructor() {}

  function setUp() public override {
    super.setUp();
  }

  function test_DeployHolographCountdownERC721() public {
    super.deployAndSetupProtocol(DEFAULT_MAX_SUPPLY);
    assertEq(countdownErc721.version(), 1);
    assertEq(countdownErc721.currentTheoricalMaxSupply(), DEFAULT_MAX_SUPPLY);
    assertEq(countdownErc721.START_DATE(), DEFAULT_START_DATE, "Wrong start date");
    assertEq(countdownErc721.MINT_INTERVAL(), DEFAULT_MINT_INTERVAL, "Wrong mint interval");
    assertEq(countdownErc721.INITIAL_MAX_SUPPLY(), DEFAULT_MAX_SUPPLY, "Wrong initial max supply");
    assertEq(
      countdownErc721.endDate(),
      DEFAULT_START_DATE + DEFAULT_MINT_INTERVAL * DEFAULT_MAX_SUPPLY,
      "Wrong initial end date"
    );
    assertEq(
      countdownErc721.INITIAL_END_DATE(),
      DEFAULT_START_DATE + DEFAULT_MINT_INTERVAL * DEFAULT_MAX_SUPPLY,
      "Wrong initial end date"
    );
  }

  function test_init() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    assertEq(countdownErc721.owner(), DEFAULT_OWNER_ADDRESS, "Default owner set wrong");
    // assertEq(countdownErc721.FUNDS_RECIPIENT(), payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS), "FundsRecipient is wrong");

    // Setup sale config
    CustomERC721SalesConfiguration memory salesConfig = CustomERC721SalesConfiguration({
      publicSalePrice: 0,
      maxSalePurchasePerAddress: 0
    });

    HolographERC721 countdownErc721 = HolographERC721(payable(address(countdownErc721)));

    string memory name = countdownErc721.name();
    string memory symbol = countdownErc721.symbol();
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

    countdownErc721.init(abi.encode(contractName, contractSymbol, contractBps, EVENT_CONFIG, skipInit, initCode));
  }

  function test_DefaultValues() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    uint256 expectedEndDate = DEFAULT_START_DATE + DEFAULT_MAX_SUPPLY * DEFAULT_MINT_INTERVAL;

    /* -------------------------- Not updatable values -------------------------- */
    assertEq(countdownErc721.START_DATE(), DEFAULT_START_DATE, "Wrong start date");
    assertEq(countdownErc721.INITIAL_MAX_SUPPLY(), DEFAULT_MAX_SUPPLY, "Wrong initial max supply");
    assertEq(countdownErc721.MINT_INTERVAL(), DEFAULT_MINT_INTERVAL, "Wrong mint interval");
    assertEq(countdownErc721.INITIAL_END_DATE(), expectedEndDate, "Wrong initial end date");
    assertEq(countdownErc721.DESCRIPTION(), DEFAULT_DESCRIPTION, "Wrong description");

    /* ---------------------------- Updatable values ---------------------------- */
    assertEq(countdownErc721.fundsRecipient(), DEFAULT_FUNDS_RECIPIENT_ADDRESS, "Wrong funds recipient");
    assertEq(countdownErc721.endDate(), expectedEndDate, "Wrong end date");
    assertEq(countdownErc721.minter(), DEFAULT_MINTER_ADDRESS, "Wrong minter");
    assertEq(countdownErc721.contractURI(), DEFAULT_CONTRACT_URI, "Wrong contract URI");
  }
}
