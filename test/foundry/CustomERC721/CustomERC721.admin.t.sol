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

contract CustomERC721AdminTest is CustomERC721Fixture, ICustomERC721Errors {
  using Strings for uint256;

  constructor() {}

  function setUp() public override {
    super.setUp();
  }

  function test_OnlyAdminCanCallSyncLazyMint() public setupTestCustomERC21WithLazyMint(DEFAULT_MAX_SUPPLY) {
    vm.expectRevert("ERC721: owner only function");
    customErc721.syncLazyMint();

    vm.prank(DEFAULT_OWNER_ADDRESS);
    customErc721.syncLazyMint();
  }

  function test_Withdraw(uint128 amount) public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) {
    vm.assume(amount > 0.01 ether);
    vm.deal(address(customErc721), amount);
    vm.prank(DEFAULT_OWNER_ADDRESS);

    // withdrawnBy and withdrawnTo are indexed in the first two positions
    vm.expectEmit(true, true, false, false);
    uint256 leftoverFunds = amount - (amount * 1) / 20;
    emit FundsWithdrawn(DEFAULT_OWNER_ADDRESS, DEFAULT_FUNDS_RECIPIENT_ADDRESS, leftoverFunds);
    customErc721.withdraw();

    assertTrue(
      HOLOGRAPH_TREASURY_ADDRESS.balance < ((uint256(amount) * 1_000 * 5) / 100000) + 2 ||
        HOLOGRAPH_TREASURY_ADDRESS.balance > ((uint256(amount) * 1_000 * 5) / 100000) + 2
    );
    assertTrue(
      DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance > ((uint256(amount) * 1_000 * 95) / 100000) - 2 ||
        DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance < ((uint256(amount) * 1_000 * 95) / 100000) + 2
    );
  }

  function test_SetSalesConfiguration() public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) {
    uint104 price = usd10;
    vm.prank(DEFAULT_OWNER_ADDRESS);
    customErc721.setSaleConfiguration({
      publicSalePrice: price,
      maxSalePurchasePerAddress: 10
    });

    (uint104 publicSalePrice, uint24 maxSalePurchasePerAddress) = customErc721.salesConfig();
    assertEq(publicSalePrice, price);
    assertEq(maxSalePurchasePerAddress, 10);

    vm.startPrank(DEFAULT_OWNER_ADDRESS);
    customErc721.setSaleConfiguration({
      publicSalePrice: price*2,
      maxSalePurchasePerAddress: 5
    });

    (publicSalePrice, maxSalePurchasePerAddress) = customErc721.salesConfig();
    assertEq(publicSalePrice, price*2);
    assertEq(maxSalePurchasePerAddress, 5);
  }

  function test_WithdrawNotAllowed() public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) {
    vm.expectRevert(IHolographDropERC721V2.Access_WithdrawNotAllowed.selector);
    customErc721.withdraw();
  }
}
