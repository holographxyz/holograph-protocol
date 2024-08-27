// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {console2} from "forge-std/console2.sol";

import {ICustomERC721Errors} from "test/foundry/interface/ICustomERC721Errors.sol";
import {CustomERC721Fixture} from "test/foundry/fixtures/CustomERC721Fixture.t.sol";

import {Strings} from "src/library/Strings.sol";

import {DEFAULT_START_DATE, DEFAULT_MAX_SUPPLY, DEFAULT_MINT_INTERVAL} from "test/foundry/CustomERC721/utils/Constants.sol";

contract CustomERC721CountdownTest is CustomERC721Fixture, ICustomERC721Errors {
  using Strings for uint256;

  constructor() {}

  function setUp() public override {
    super.setUp();
  }

  function test_init() public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) {
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

  function test_currentTheoricalMaxSupply() public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) setUpPurchase {
    // Current Max supply should be the same as initial max supply before the start date
    assertEq(customErc721.currentTheoricalMaxSupply(), DEFAULT_MAX_SUPPLY, "Wrong current max supply");

    // Current Max supply still the same at the exacte start date timestamp
    vm.warp(customErc721.START_DATE());
    assertEq(customErc721.currentTheoricalMaxSupply(), DEFAULT_MAX_SUPPLY, "Wrong current max supply at start date");

    vm.warp(customErc721.START_DATE() + 10 * customErc721.MINT_INTERVAL());
    assertEq(customErc721.currentTheoricalMaxSupply(), DEFAULT_MAX_SUPPLY - 10, "Wrong current max supply after start date");
  }

  function test_purchaseCantExceedMaxSupplyAtStartDate() public setupTestCustomERC21(1000) setUpPurchase {
    uint256 maxSupply = customErc721.INITIAL_MAX_SUPPLY();
    uint256 start = customErc721.START_DATE();

    vm.warp(start);
    vm.prank(address(TEST_ACCOUNT));
    vm.deal(address(TEST_ACCOUNT), type(uint256).max);

    // Purchase all the supply
    for (uint256 i = 0; i < maxSupply; i++) {
      customErc721.purchase{value: totalCost}(1);
    }

    // Try to purchase one more
    vm.expectRevert(abi.encodeWithSelector(Purchase_CountdownCompleted.selector));
    customErc721.purchase{value: totalCost}(1);

    assertEq(customErc721.totalMinted(), maxSupply, "Wrong total minted");
    assertEq(customErc721.END_DATE(), start, "Wrong end date");
  }

  function test_purchaseCantExceedMaxSupply() public setupTestCustomERC21(1000) setUpPurchase {
    uint256 initialMaxSupply = customErc721.INITIAL_MAX_SUPPLY();
    uint256 start = customErc721.START_DATE();

    // Wrap to the timestamp where the total epochs
    vm.warp(start + (initialMaxSupply / 2) * customErc721.MINT_INTERVAL());
    vm.prank(address(TEST_ACCOUNT));
    vm.deal(address(TEST_ACCOUNT), type(uint256).max);

    uint256 newMaxSupply = initialMaxSupply / 2;

    // Purchase all the supply
    for (uint256 i = 0; i < newMaxSupply; i++) {
      customErc721.purchase{value: totalCost}(1);
    }

    // Try to purchase one more
    vm.expectRevert(abi.encodeWithSelector(Purchase_CountdownCompleted.selector));
    customErc721.purchase{value: totalCost}(1);

    assertEq(customErc721.totalMinted(), initialMaxSupply / 2, "Wrong total minted");
  }

  /* -------------------------------------------------------------------------- */
  /*                               Invariant tests                              */
  /* -------------------------------------------------------------------------- */

  function test_Invariant_complexMaxSupply(
    uint256 elapsedTimeBetweenPurchase
  ) public setupTestCustomERC21(2000) setUpPurchase {
    uint256 mintInterval = customErc721.MINT_INTERVAL();
    uint256 initialMaxSupply = customErc721.INITIAL_MAX_SUPPLY();
    uint256 start = customErc721.START_DATE();
    uint256 maxIntervalCount = 5;

    elapsedTimeBetweenPurchase = bound(elapsedTimeBetweenPurchase, mintInterval, mintInterval * maxIntervalCount - 1);

    vm.warp(start);
    vm.prank(address(TEST_ACCOUNT));
    vm.deal(address(TEST_ACCOUNT), type(uint256).max);

    // Purchase all the supply
    uint256 i = 1;
    while (customErc721.totalMinted() < customErc721.currentTheoricalMaxSupply()) {
      customErc721.purchase{value: totalCost}(1);

      vm.warp(block.timestamp + elapsedTimeBetweenPurchase);

      uint256 elapsedInterval = (block.timestamp - start) / mintInterval;
      assertEq(customErc721.totalMinted(), i, "Wrong total minted");
      assertEq(
        customErc721.currentTheoricalMaxSupply(),
        elapsedInterval > initialMaxSupply ? 0 : initialMaxSupply - elapsedInterval,
        "Wrong current max supply"
      );
      i++;
    }

    // Try to purchase one more
    vm.expectRevert(abi.encodeWithSelector(Purchase_CountdownCompleted.selector));
    customErc721.purchase{value: totalCost}(1);
    uint256 totalMinted = customErc721.totalMinted();
    uint256 expectedMaxSupply;

    if (block.timestamp >= start + initialMaxSupply * mintInterval) {
      expectedMaxSupply = 0; // All intervals have elapsed
    } else {
      uint256 intervalsElapsed = (block.timestamp - start) / mintInterval;
      expectedMaxSupply = initialMaxSupply - intervalsElapsed;
    }

    // The total minted should be equal to the current max supply
    assertEq(expectedMaxSupply, customErc721.currentTheoricalMaxSupply(), "Wrong expectedMaxSupply");
    assertEq(totalMinted, i - 1, "Wrong total minted");
    // Approx eq maxIntervalCount because the current block timestamp can be a bit more that the last mint exact
    // interval
    assertApproxEqAbs(customErc721.totalMinted(), customErc721.currentTheoricalMaxSupply(), maxIntervalCount);
  }

  function test_Invariant_currentTheoricalMaxSupply(
    uint256 elapsedInterval
  ) public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) setUpPurchase {
    elapsedInterval = bound(elapsedInterval, 0, DEFAULT_MAX_SUPPLY * 10);

    vm.warp(customErc721.START_DATE() + elapsedInterval * customErc721.MINT_INTERVAL());

    // If the elapsed interval is greater than the max supply, the current max supply should be 0
    if (block.timestamp > DEFAULT_START_DATE + DEFAULT_MAX_SUPPLY * DEFAULT_MINT_INTERVAL) {
      assertEq(customErc721.currentTheoricalMaxSupply(), 0, "Wrong current max supply after start date");
    } else {
      assertEq(
        customErc721.currentTheoricalMaxSupply(),
        DEFAULT_MAX_SUPPLY - elapsedInterval,
        "Wrong current max supply after start date"
      );
    }
  }
}
