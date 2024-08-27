// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ICustomERC721Errors} from "test/foundry/interface/ICustomERC721Errors.sol";
import {CustomERC721Fixture} from "test/foundry/fixtures/CustomERC721Fixture.t.sol";

import {Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {DEFAULT_BASE_URI, DEFAULT_PLACEHOLDER_URI, DEFAULT_ENCRYPT_DECRYPT_KEY, DEFAULT_MAX_SUPPLY} from "test/foundry/CustomERC721/utils/Constants.sol";

import {ICustomERC721} from "src/interface/ICustomERC721.sol";
import {Strings} from "src/library/Strings.sol";

contract CustomERC721PurchaseTest is CustomERC721Fixture, ICustomERC721Errors {
  using Strings for uint256;

  constructor() {}

  function setUp() public override {
    super.setUp();
  }

  function test_Purchase() public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) setUpPurchase {
    /* -------------------------------- Purchase -------------------------------- */
    vm.prank(address(TEST_ACCOUNT));
    vm.deal(address(TEST_ACCOUNT), totalCost);
    uint256 tokenId = customErc721.purchase{value: totalCost}(1);

    // First token ID is this long number due to the chain id prefix
    require(erc721Enforcer.ownerOf(tokenId) == address(TEST_ACCOUNT), "Incorrect owner for newly minted token");
    assertEq(address(sourceContractAddress).balance, nativePrice);

    /* ----------------------------- Check tokenURI ----------------------------- */

    // TokenURI call should revert because the metadata of the batch has not been set yet (need to call lazyMint before)
    vm.expectRevert(abi.encodeWithSelector(BatchMintInvalidTokenId.selector, tokenId));
    customErc721.tokenURI(tokenId);
    vm.expectRevert(abi.encodeWithSelector(BatchMintInvalidTokenId.selector, 0));
    customErc721.tokenURI(0);
  }

  // TODO: Fix this test (It's reverting but not with the matching correct price in the error message)
  function test_PurchaseWrongPrice() public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) setUpPurchase {
    /* -------------------------------- Purchase -------------------------------- */

    uint256 amount = 1;
    uint104 price = usd100;
    vm.prank(address(TEST_ACCOUNT));
    vm.deal(address(TEST_ACCOUNT), totalCost - 1);
    vm.expectRevert(abi.encodeWithSelector(ICustomERC721.Purchase_WrongPrice.selector, uint256(price)));

    customErc721.purchase{value: totalCost - 1}(amount);
  }

  function test_GetContractURI() public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) setUpPurchase {
    string memory expectedURI = "https://example.com/metadata.json";

    assertEq(customErc721.contractURI(), expectedURI);
  }

  function test_SetContractURI() public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) setUpPurchase {
    string memory expectedURI = "https://example.com/new-metadata.json";

    vm.prank(DEFAULT_OWNER_ADDRESS);
    vm.recordLogs();

    customErc721.setContractURI(expectedURI);
    assertEq(customErc721.contractURI(), expectedURI);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 1);
    assertEq(entries[0].topics[0], keccak256("ContractURIUpdated(string,string)"));
    assertEq(abi.decode(entries[0].data, (string)), "https://example.com/metadata.json");

    // TODO: Figure out how to get the second parameter from the event
    // assertEq(abi.decode(entries[0].data, (string)), "https://example.com/new-metadata.json");
  }

  function test_GetSourceChainPrepend() public setupTestCustomERC21(DEFAULT_MAX_SUPPLY) setUpPurchase {
    // Calls must come from the source contract via the onlySource modifier
    vm.prank(sourceContractAddress);
    uint256 sourceChainPrepend = erc721Enforcer.sourceGetChainPrepend();

    console.log("sourceChainPrepend", sourceChainPrepend);
  }
}
