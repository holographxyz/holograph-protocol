// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ICustomERC721Errors} from "test/foundry/interface/ICustomERC721Errors.sol";
import {CountdownERC721Fixture} from "test/foundry/fixtures/CountdownERC721Fixture.t.sol";

import {Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {DEFAULT_BASE_URI, DEFAULT_PLACEHOLDER_URI, DEFAULT_START_DATE, DEFAULT_ENCRYPT_DECRYPT_KEY, DEFAULT_MAX_SUPPLY, DEFAULT_MINT_INTERVAL} from "test/foundry/CountdownERC721/utils/Constants.sol";

import {ICountdownERC721} from "src/interface/ICountdownERC721.sol";
import {Strings} from "src/library/Strings.sol";
import {NFTMetadataRenderer} from "src/library/NFTMetadataRenderer.sol";
import {HolographERC721} from "src/enforcer/HolographERC721.sol";
import {CustomERC721SaleDetails} from "src/struct/CustomERC721SaleDetails.sol";

contract CountdownERC721ViewsTest is CountdownERC721Fixture, ICustomERC721Errors {
  using Strings for uint256;

  uint32 public constant SMALL_MAX_SUPPLY = 1000;

  constructor() {}

  function setUp() public override {
    super.setUp();
  }

  function test_endDate() public setupTestCountdownErc721(10) {
    uint256 expectedEndDate = DEFAULT_START_DATE + 10 * DEFAULT_MINT_INTERVAL;
    assertEq(countdownErc721.endDate(), expectedEndDate, "Wrong end date");
  }

  function test_fundsRecipient() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    assertEq(countdownErc721.fundsRecipient(), DEFAULT_FUNDS_RECIPIENT_ADDRESS, "Wrong funds recipient");

    vm.prank(DEFAULT_OWNER_ADDRESS);
    countdownErc721.setFundsRecipient(payable(address(0xffffff)));

    assertEq(countdownErc721.fundsRecipient(), address(0xffffff), "FundsRecipient is wrong");
  }

  function test_minter() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    assertEq(countdownErc721.minter(), DEFAULT_MINTER_ADDRESS, "Wrong minter");

    vm.prank(DEFAULT_OWNER_ADDRESS);
    countdownErc721.setMinter(address(0xffffff));

    assertEq(countdownErc721.minter(), address(0xffffff), "Minter is wrong");
  }

  function test_salesConfig() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    (uint104 publicSalePrice, uint24 maxSalePurchasePerAddress) = countdownErc721.salesConfig();
    assertEq(publicSalePrice, mintEthPrice, "Wrong public sale price");
    assertEq(maxSalePurchasePerAddress, 0, "Wrong max sale purchase per address");

    vm.prank(DEFAULT_OWNER_ADDRESS);
    countdownErc721.setSaleConfiguration(101010, 101010);

    (publicSalePrice, maxSalePurchasePerAddress) = countdownErc721.salesConfig();
    assertEq(publicSalePrice, 101010, "Wrong public sale price");
    assertEq(maxSalePurchasePerAddress, 101010, "Wrong max sale purchase per address");
  }

  function test_ownerEnforcerLevel() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    address payable _countdownErc721 = payable(address(countdownErc721));

    vm.prank(HolographERC721(_countdownErc721).getOwner());
    HolographERC721(_countdownErc721).setOwner(address(0xffffff));

    assertEq(HolographERC721(_countdownErc721).getOwner(), address(0xffffff));
  }

  function test_isAdmin() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    assertTrue(countdownErc721.isAdmin(DEFAULT_OWNER_ADDRESS), "Owner is not admin");
  }

  function test_currentTheoricalMaxSupply() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    uint256 elapsedInterval = DEFAULT_MAX_SUPPLY / 2;
    vm.warp(DEFAULT_START_DATE + elapsedInterval * DEFAULT_MINT_INTERVAL);

    assertEq(
      countdownErc721.currentTheoricalMaxSupply(),
      DEFAULT_MAX_SUPPLY - elapsedInterval,
      "Wrong currentTheoricalMaxSupply"
    );
  }

  function test_totalMinted() public setupTestCountdownErc721(SMALL_MAX_SUPPLY) setUpPurchase {
    for (uint256 i = 0; i < SMALL_MAX_SUPPLY; i++) {
      vm.prank(address(TEST_ACCOUNT));
      vm.deal(address(TEST_ACCOUNT), mintEthPrice);
      uint256 tokenId = countdownErc721.purchase{value: mintEthPrice}(1);

      assertEq(countdownErc721.totalMinted(), i + 1, "Wrong total minted");
    }
  }

  function test_saleDetails() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    CustomERC721SaleDetails memory salesDetails = countdownErc721.saleDetails();

    assertEq(salesDetails.publicSaleActive, false, "Wrong public sale active");
    assertEq(salesDetails.publicSalePrice, mintEthPrice, "Wrong public sale price");
    assertEq(salesDetails.publicSaleStart, DEFAULT_START_DATE, "Wrong public sale start");
    assertEq(salesDetails.maxSalePurchasePerAddress, 0, "Wrong max sale purchase per address");
    assertEq(salesDetails.totalMinted, 0, "Wrong total minted");
    assertEq(salesDetails.maxSupply, DEFAULT_MAX_SUPPLY, "Wrong max supply");

    _setUpPurchase();
    salesDetails = countdownErc721.saleDetails();

    assertEq(salesDetails.publicSaleActive, true, "Wrong public sale active");
    assertEq(salesDetails.publicSalePrice, mintEthPrice, "Wrong public sale price");
    assertEq(salesDetails.publicSaleStart, DEFAULT_START_DATE, "Wrong public sale start");
    assertEq(salesDetails.maxSalePurchasePerAddress, 0, "Wrong max sale purchase per address");
    assertEq(salesDetails.totalMinted, 0, "Wrong total minted");
    assertEq(salesDetails.maxSupply, DEFAULT_MAX_SUPPLY, "Wrong max supply");
  }

  function test_totalMintsByAddress() public setupTestCountdownErc721(SMALL_MAX_SUPPLY) setUpPurchase {
    for (uint256 i = 0; i < SMALL_MAX_SUPPLY / 2; i++) {
      address account = address(uint160(uint256(keccak256(abi.encodePacked(i)))));

      vm.prank(account);
      vm.deal(account, mintEthPrice);
      uint256 tokenId = countdownErc721.purchase{value: mintEthPrice}(1);

      assertEq(countdownErc721.totalMintsByAddress(account), 1, "Wrong total minted");
    }

    for (uint256 i = 0; i < SMALL_MAX_SUPPLY / 2; i++) {
      vm.prank(TEST_ACCOUNT);
      vm.deal(TEST_ACCOUNT, mintEthPrice);
      uint256 tokenId = countdownErc721.purchase{value: mintEthPrice}(1);

      assertEq(countdownErc721.totalMintsByAddress(TEST_ACCOUNT), i + 1, "Wrong total minted");
    }
  }
}
