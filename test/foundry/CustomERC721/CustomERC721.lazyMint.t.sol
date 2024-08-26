// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {console2} from "forge-std/console2.sol";

import {ICustomERC721Errors} from "test/foundry/interface/ICustomERC721Errors.sol";
import {CustomERC721Fixture} from "test/foundry/fixtures/CustomERC721Fixture.t.sol";

import {Strings} from "src/library/Strings.sol";

import {DEFAULT_MAX_SUPPLY, DEFAULT_MINT_INTERVAL, DEFAULT_BASE_URI, DEFAULT_BASE_URI_2, DEFAULT_PLACEHOLDER_URI, DEFAULT_PLACEHOLDER_URI_2} from "test/foundry/CustomERC721/utils/Constants.sol";

contract CustomERC721LazyMintTest is CustomERC721Fixture, ICustomERC721Errors {
  using Strings for uint256;

  constructor() {}

  function setUp() public override {
    super.setUp();
  }

  function test_lazyMintDuringInit() public setupTestCustomERC21WithLazyMint(DEFAULT_MAX_SUPPLY) {
    // Check first lazymint
    assertEq(customErc721.encryptedData(DEFAULT_MAX_SUPPLY/2), defaultLazyMintConfigurations[0]._data, "Encrypted data should match the default config");
    assertEq(customErc721.baseURI(0), DEFAULT_PLACEHOLDER_URI, "Wrong base uri for token 0");

    // Check second lazymint
    assertEq(customErc721.encryptedData(DEFAULT_MAX_SUPPLY), defaultLazyMintConfigurations[1]._data, "Encrypted data should match the default config");
    assertEq(customErc721.baseURI(DEFAULT_MAX_SUPPLY / 2), DEFAULT_PLACEHOLDER_URI_2, "Wrong base uri for token (DEFAULT_MAX_SUPPLY / 2)");
  }

  // function test_syncLazyMint() public setupTestCustomERC21WithLazyMint(DEFAULT_MAX_SUPPLY) {
  //   // Call syncLazyMint
  //   vm.prank(DEFAULT_OWNER_ADDRESS);
  //   chainPrepend = customErc721.syncLazyMint();

  //   // Check if lazy mint can't be called anymore
  //   vm.prank(DEFAULT_OWNER_ADDRESS);
  //   vm.expectRevert(LazyMint_AlreadyInitialized.selector);
  //   customErc721.syncLazyMint();

  //   /* ----------------- Check if lazy mint has synced correctly ---------------- */

  //   if(chainPrepend != 0) {
  //     assertEq(customErc721.encryptedData(DEFAULT_MAX_SUPPLY/2), "", "Encrypted data should has been removed");
  //     assertEq(customErc721.baseURI(0), "", "Base uri for token 0 should has been removed");

  //     assertEq(customErc721.encryptedData(DEFAULT_MAX_SUPPLY), "", "Encrypted data should has been removed");
  //     assertEq(customErc721.baseURI(DEFAULT_MAX_SUPPLY / 2), DEFAULT_PLACEHOLDER_URI_2, "Base uri for token (DEFAULT_MAX_SUPPLY / 2) should has been removed");
  //   }
    
  //   // Check first lazymint
  //   assertEq(customErc721.encryptedData(chainPrepend + DEFAULT_MAX_SUPPLY/2), defaultLazyMintConfigurations[0]._data, "Encrypted data (with prepend) should match the default config");
  //   assertEq(customErc721.baseURI(chainPrepend + 0), DEFAULT_PLACEHOLDER_URI, "Base uri (with prepend) for token 0 should match the default config");

  //   // Check second lazymint
  //   assertEq(customErc721.encryptedData(chainPrepend + DEFAULT_MAX_SUPPLY), defaultLazyMintConfigurations[1]._data, "Encrypted data (with prepend) should match the default config");
  //   assertEq(customErc721.baseURI(chainPrepend + DEFAULT_MAX_SUPPLY / 2), DEFAULT_PLACEHOLDER_URI_2, "Base uri (with prepend) for token (DEFAULT_MAX_SUPPLY / 2) should match the default config");
  // }

  function test_placeholderUri() public setupTestCustomERC21WithLazyMint(DEFAULT_MAX_SUPPLY) {
    // Check first lazymint
    assertEq(customErc721.tokenURI(1), string(abi.encodePacked(DEFAULT_PLACEHOLDER_URI, "1")), "Wrong token uri for token 1");
    assertEq(customErc721.tokenURI(10), string(abi.encodePacked(DEFAULT_PLACEHOLDER_URI, "10")), "Wrong token uri for token 10");

    // Check second lazymint
    assertEq(customErc721.tokenURI(DEFAULT_MAX_SUPPLY / 2 + 1), string(abi.encodePacked(DEFAULT_PLACEHOLDER_URI_2, uint256(DEFAULT_MAX_SUPPLY / 2 + 1).toString())), "Wrong token uri for token (DEFAULT_MAX_SUPPLY / 2 + 1)");
    assertEq(customErc721.tokenURI(DEFAULT_MAX_SUPPLY / 2 + 10), string(abi.encodePacked(DEFAULT_PLACEHOLDER_URI_2, uint256(DEFAULT_MAX_SUPPLY / 2 + 10).toString())), "Wrong token uri for token (DEFAULT_MAX_SUPPLY / 2 + 10)");
  }

  function test_lazyMintDataWhenReveal() public setupTestCustomERC21WithLazyMint(DEFAULT_MAX_SUPPLY) {}

}
