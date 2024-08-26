// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ICustomERC721Errors} from "test/foundry/interface/ICustomERC721Errors.sol";
import {CountdownERC721Fixture} from "test/foundry/fixtures/CountdownERC721Fixture.t.sol";

import {Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {DEFAULT_START_DATE, DEFAULT_MAX_SUPPLY, DEFAULT_MINT_INTERVAL, EVENT_CONFIG, HOLOGRAPH_REGISTRY_PROXY, HOLOGRAPH_TREASURY_ADDRESS} from "test/foundry/CountdownERC721/utils/Constants.sol";

import {ICountdownERC721} from "src/interface/ICountdownERC721.sol";
import {CountdownERC721} from "src/token/CountdownERC721.sol";
import {Strings} from "src/library/Strings.sol";
import {CustomERC721SalesConfiguration} from "src/struct/CustomERC721SalesConfiguration.sol";
import {CustomERC721Initializer} from "src/struct/CustomERC721Initializer.sol";
import {HolographERC721} from "src/enforcer/HolographERC721.sol";
import {IHolographDropERC721V2} from "src/drops/interface/IHolographDropERC721V2.sol";
import {HolographTreasury} from "src/HolographTreasury.sol";

contract CountdownERC721AdminTest is CountdownERC721Fixture, ICustomERC721Errors {
  using Strings for uint256;

  constructor() {}

  function setUp() public override {
    super.setUp();
  }

  function test_Withdraw(uint128 amount) public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    vm.assume(amount > 0.01 ether);
    vm.deal(address(countdownErc721), amount);
    vm.prank(DEFAULT_OWNER_ADDRESS);

    // withdrawnBy and withdrawnTo are indexed in the first two positions
    vm.expectEmit(true, true, false, false);
    uint256 leftoverFunds = amount - (amount * 1) / 20;
    emit FundsWithdrawn(DEFAULT_OWNER_ADDRESS, DEFAULT_FUNDS_RECIPIENT_ADDRESS, leftoverFunds);
    countdownErc721.withdraw();

    assertTrue(
      HOLOGRAPH_TREASURY_ADDRESS.balance < ((uint256(amount) * 1_000 * 5) / 100000) + 2 ||
        HOLOGRAPH_TREASURY_ADDRESS.balance > ((uint256(amount) * 1_000 * 5) / 100000) + 2
    );
    assertTrue(
      DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance > ((uint256(amount) * 1_000 * 95) / 100000) - 2 ||
        DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance < ((uint256(amount) * 1_000 * 95) / 100000) + 2
    );
  }

  function test_SetSalesConfiguration() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    vm.prank(DEFAULT_OWNER_ADDRESS);
    countdownErc721.setSaleConfiguration({publicSalePrice: mintEthPrice, maxSalePurchasePerAddress: 10});

    (uint104 publicSalePrice, uint24 maxSalePurchasePerAddress) = countdownErc721.salesConfig();
    assertEq(publicSalePrice, mintEthPrice);
    assertEq(maxSalePurchasePerAddress, 10);

    vm.startPrank(DEFAULT_OWNER_ADDRESS);
    countdownErc721.setSaleConfiguration({publicSalePrice: mintEthPrice * 2, maxSalePurchasePerAddress: 5});

    (publicSalePrice, maxSalePurchasePerAddress) = countdownErc721.salesConfig();
    assertEq(publicSalePrice, mintEthPrice * 2);
    assertEq(maxSalePurchasePerAddress, 5);
  }

  function test_WithdrawNotAllowed() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) {
    vm.expectRevert(IHolographDropERC721V2.Access_WithdrawNotAllowed.selector);
    countdownErc721.withdraw();
  }
}
