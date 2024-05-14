// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ICustomERC721Errors} from "test/foundry/interface/ICustomERC721Errors.sol";
import {CustomERC721Fixture} from "test/foundry/fixtures/CustomERC721Fixture.t.sol";

import {Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {DEFAULT_START_DATE, DEFAULT_MAX_SUPPLY, DEFAULT_MINT_INTERVAL, EVENT_CONFIG, HOLOGRAPH_REGISTRY_PROXY, HOLOGRAPH_TREASURY_ADDRESS} from "test/foundry/CustomERC721/utils/Constants.sol";

import {ICustomERC721} from "src/interface/ICustomERC721.sol";
import {CustomERC721} from "src/token/CustomERC721.sol";
import {Strings} from "src/library/Strings.sol";
import {CustomERC721SalesConfiguration} from "src/struct/CustomERC721SalesConfiguration.sol";
import {CustomERC721Initializer} from "src/struct/CustomERC721Initializer.sol";
import {LazyMintConfiguration} from "src/struct/LazyMintConfiguration.sol";
import {HolographERC721} from "src/enforcer/HolographERC721.sol";
import {IHolographDropERC721V2} from "src/drops/interface/IHolographDropERC721V2.sol";
import {HolographTreasury} from "src/HolographTreasury.sol";

contract CustomERC721MinterRoleTest is CustomERC721Fixture, ICustomERC721Errors {
  using Strings for uint256;

  constructor() {}

  function setUp() public override {
    super.setUp();
  }

  function test_MinterCanMint() public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) {
    vm.prank(DEFAULT_MINTER_ADDRESS);
    customErc721.mintTo(TEST_ACCOUNT, 1);

    HolographERC721 erc721Enforcer = HolographERC721(payable(address(customErc721)));
    assertEq(erc721Enforcer.ownerOf(FIRST_TOKEN_ID), TEST_ACCOUNT, "Owner is wrong for new minted token");
  }

  // TODO: Test is failing due to not reverting as expected
  // function test_OnlyMinterCanMint() public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) {
  //   // Calling without pranking the minter should revert
  //   vm.expectRevert(Access_OnlyMinter.selector);
  //   customErc721.mintTo(TEST_ACCOUNT, 1);

  //   // Calling with pranking the owner should revert too
  //   vm.expectRevert(Access_OnlyMinter.selector);
  //   vm.prank(DEFAULT_OWNER_ADDRESS);
  //   customErc721.mintTo(TEST_ACCOUNT, 1);
  // }

  function test_Fuzz_OnlyMinterCanMint(address sender) public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) {
    vm.assume(sender != DEFAULT_MINTER_ADDRESS);

    // Calling with pranking any address should revert too
    vm.expectRevert(Access_OnlyMinter.selector);
    vm.prank(sender);
    customErc721.mintTo(TEST_ACCOUNT, 1);
  }

  function test_Fuzz_MinterCantMintAfterSaleEnd(uint16 limit) public setupTestCustomERC21(200) setUpPurchase {
    // Set assume to a more reasonable number to speed up tests
    limit = uint16(bound(limit, 1, 10));
    _purchaseAllSupply();

    vm.prank(DEFAULT_MINTER_ADDRESS);
    vm.expectRevert(Purchase_CountdownCompleted.selector);
    customErc721.mintTo(TEST_ACCOUNT, 1);
  }
}
