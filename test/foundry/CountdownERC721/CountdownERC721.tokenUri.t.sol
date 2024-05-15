// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ICustomERC721Errors} from "test/foundry/interface/ICustomERC721Errors.sol";
import {CountdownERC721Fixture} from "test/foundry/fixtures/CountdownERC721Fixture.t.sol";

import {Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Base64} from "test/foundry/CountdownERC721/utils/Helper.sol";
import {DEFAULT_MAX_SUPPLY} from "test/foundry/CountdownERC721/utils/Constants.sol";

import {MetadataParams} from "src/struct/MetadataParams.sol";
import {Strings} from "src/library/Strings.sol";
import {NFTMetadataRenderer} from "src/library/NFTMetadataRenderer.sol";

contract CountdownERC721TokenUriTest is CountdownERC721Fixture, ICustomERC721Errors {
  using Strings for uint256;

  constructor() {}

  function setUp() public override {
    super.setUp();
  }

  function test_decodedTokenUri() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) setUpPurchase {
    /* -------------------------------- Purchase -------------------------------- */
    vm.prank(address(TEST_ACCOUNT));
    vm.deal(address(TEST_ACCOUNT), mintEthPrice);
    uint256 tokenId = countdownErc721.purchase{value: mintEthPrice}(1);

    // First token ID is this long number due to the chain id prefix
    require(erc721Enforcer.ownerOf(tokenId) == address(TEST_ACCOUNT), "Incorrect owner for newly minted token");
    assertEq(address(sourceContractAddress).balance, mintEthPrice);

    /* ----------------------------- Check tokenURI ----------------------------- */

    // Expected token URI for newly minted token
    // {
    //     "name": "Contract Name 115792089183396302089269705419353877679230723318366275194376439045705909141505",
    //     "description": "Description of the token",
    //     "external_url": "https://example.com",
    //     "image": ar://o8eyC27OuSZF0z-zIen5NTjJOKTzOQzKJzIe3F7Lmg0/1.png",
    //     "encrypted_media_url": "",
    //     "decryption_key": "",
    //     "hash": "",
    //     "decrypted_media_url": "",
    //     "animation_url": "",
    //     "properties": {
    //         "number": 115792089183396302089269705419353877679230723318366275194376439045705909141505,
    //         "name": "Contract Name"
    //     }
    // }
    string
      memory expectedTokenUri = '{"name": "Contract Name 115792089183396302089269705419353877679230723318366275194376439045705909141505", "description": "Description of the token", "external_url": "https://example.com", "image": "ar://o8eyC27OuSZF0z-zIen5NTjJOKTzOQzKJzIe3F7Lmg0/1.png", "encrypted_media_url": "", "decryption_key": "", "hash": "", "decrypted_media_url": "", "animation_url": "", "properties": {"number": 115792089183396302089269705419353877679230723318366275194376439045705909141505, "name": "Contract Name"}}';

    bytes memory base64TokenUri = bytes(countdownErc721.tokenURI(tokenId));
    bytes memory rawBase64TokenUri = new bytes(base64TokenUri.length);

    uint256 tokenUriLength;
    uint256 tokenUriDataPtr;
    bytes32 data;

    // Remove the "data:application/json;base64," (length == 29) from the token uri string for decoding
    assembly {
      // Token uri length (loading the first 32 bytes of the bytes array)
      tokenUriLength := mload(base64TokenUri)
      // Token uri data pointer (adding 0x20 to skip the length of the bytes array)
      tokenUriDataPtr := add(add(base64TokenUri, 0x20), 29)
      // Calculate the pointer of the memory to write
      // => rawBase64TokenUri + 0x20 to skip the length of the bytes array
      let resultData := add(rawBase64TokenUri, 0x20)

      // Copy the data from the input string to the result string, starting from the 30th character
      for {
        let i := 0
      } lt(i, tokenUriLength) {
        i := add(i, 1)
      } {
        // Write the byte from the token uri data to the result data
        mstore8(
          // Location to write the byte to
          add(resultData, i),
          // Load the 1st byte from the token uri data loaded from memory
          // => Since the mload function loads 32 bytes and mstore8 writes the last byte of the value passed to it,
          //    We need to fetch the fist byte using the function `byte`, which returns the byte at the given index
          byte(0, mload(add(tokenUriDataPtr, i)))
        )
      }

      // Update the length of the result bytes array with the new length
      mstore(rawBase64TokenUri, sub(tokenUriLength, 29))
    }

    string memory decodedTokenUri = string(Base64.decode(string(rawBase64TokenUri)));
    assertEq(decodedTokenUri, expectedTokenUri, "Incorrect tokenURI for newly minted token");
  }

  function test_tokenUri() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) setUpPurchase {
    /* -------------------------------- Purchase -------------------------------- */
    vm.prank(address(TEST_ACCOUNT));
    vm.deal(address(TEST_ACCOUNT), mintEthPrice);
    uint256 tokenId = countdownErc721.purchase{value: mintEthPrice}(1);

    // First token ID is this long number due to the chain id prefix
    require(erc721Enforcer.ownerOf(tokenId) == address(TEST_ACCOUNT), "Incorrect owner for newly minted token");
    assertEq(address(sourceContractAddress).balance, mintEthPrice);

    /* ----------------------------- Check tokenURI ----------------------------- */

    // Expected token URI for newly minted token
    // {
    //     "name": "Contract Name 115792089183396302089269705419353877679230723318366275194376439045705909141505",
    //     "description": "Description of the token",
    //     "external_url": "https://example.com",
    //     "image": ar://o8eyC27OuSZF0z-zIen5NTjJOKTzOQzKJzIe3F7Lmg0/1.png",
    //     "encrypted_media_url": "",
    //     "decryption_key": "",
    //     "hash": "",
    //     "decrypted_media_url": "",
    //     "animation_url": "",
    //     "properties": {
    //         "number": 115792089183396302089269705419353877679230723318366275194376439045705909141505,
    //         "name": "Contract Name"
    //     }
    // }
    string memory expectedTokenUri = NFTMetadataRenderer.encodeMetadataJSON(
      '{"name": "Contract Name 115792089183396302089269705419353877679230723318366275194376439045705909141505", "description": "Description of the token", "external_url": "https://example.com", "image": "ar://o8eyC27OuSZF0z-zIen5NTjJOKTzOQzKJzIe3F7Lmg0/1.png", "encrypted_media_url": "", "decryption_key": "", "hash": "", "decrypted_media_url": "", "animation_url": "", "properties": {"number": 115792089183396302089269705419353877679230723318366275194376439045705909141505, "name": "Contract Name"}}'
    );
    expectedTokenUri = NFTMetadataRenderer.encodeMetadataJSON(
      '{"name": "Contract Name 115792089183396302089269705419353877679230723318366275194376439045705909141505", "description": "Description of the token", "external_url": "https://example.com", "image": "ar://o8eyC27OuSZF0z-zIen5NTjJOKTzOQzKJzIe3F7Lmg0/1.png", "encrypted_media_url": "", "decryption_key": "", "hash": "", "decrypted_media_url": "", "animation_url": "", "properties": {"number": 115792089183396302089269705419353877679230723318366275194376439045705909141505, "name": "Contract Name"}}'
    );

    string memory base64TokenUri = countdownErc721.tokenURI(tokenId);

    console.log("base64TokenUri: ", base64TokenUri);

    assertEq(base64TokenUri, expectedTokenUri, "Incorrect tokenURI for newly minted token");
  }

  function test_setMetadataParams() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) setUpPurchase {
    /* -------------------------------- Purchase -------------------------------- */
    vm.prank(address(TEST_ACCOUNT));
    vm.deal(address(TEST_ACCOUNT), mintEthPrice);
    uint256 tokenId = countdownErc721.purchase{value: mintEthPrice}(1);

    // First token ID is this long number due to the chain id prefix
    require(erc721Enforcer.ownerOf(tokenId) == address(TEST_ACCOUNT), "Incorrect owner for newly minted token");
    assertEq(address(sourceContractAddress).balance, mintEthPrice);

    /* ----------------------------- Check tokenURI ----------------------------- */

    // assertEq(base64TokenUri, expectedTokenUri, "Incorrect tokenURI for newly minted token");

    /* ----------------------------- Set Metadata Params ----------------------------- */

    // Expected token URI for newly minted token
    // {
    //     "name": "Contract Name 115792089183396302089269705419353877679230723318366275194376439045705909141505",
    //     "description": "Description of the token",
    //     "external_url": "https://example.com",
    //     "image": ar://o8eyC27OuSZF0z-zIen5NTjJOKTzOQzKJzIe3F7Lmg0/1.png",
    //     "encrypted_media_url": "ar://encryptedMediaUriHere",
    //     "decryption_key": "decryptionKeyHere",
    //     "hash": "uniqueHashHere",
    //     "decrypted_media_url": "ar://decryptedMediaUriHere",
    //     "animation_url": "ar://animationUriHere",
    //     "properties": {
    //         "number": 115792089183396302089269705419353877679230723318366275194376439045705909141505,
    //         "name": "Contract Name"
    //     }
    // }
    string memory expectedTokenUri = NFTMetadataRenderer.encodeMetadataJSON(
      '{"name": "Contract Name 115792089183396302089269705419353877679230723318366275194376439045705909141505", "description": "Description of the token", "external_url": "https://example.com", "image": "ar://o8eyC27OuSZF0z-zIen5NTjJOKTzOQzKJzIe3F7Lmg0/1.png", "encrypted_media_url": "ar://encryptedMediaUriHere", "decryption_key": "decryptionKeyHere", "hash": "uniqueHashHere", "decrypted_media_url": "ar://decryptedMediaUriHere", "animation_url": "ar://animationUriHere", "properties": {"number": 115792089183396302089269705419353877679230723318366275194376439045705909141505, "name": "Contract Name"}}'
    );

    // NOTE: The metadata params struct needs to have all it's values set,
    //       but the setMetadataParams function only sets the imageURI, externalUrl,
    //       encryptedMediaUrl, decryptionKey, hash, and decryptedMediaUrl
    MetadataParams memory metadataParams = MetadataParams({
      name: "Contract Name", // NOT USED
      description: "Description of the token", // NOT USED
      tokenOfEdition: 0, // NOT USED
      editionSize: 0, // NOT USED
      imageURI: "ar://o8eyC27OuSZF0z-zIen5NTjJOKTzOQzKJzIe3F7Lmg0/1.png",
      animationURI: "ar://animationUriHere",
      externalUrl: "https://example.com",
      encryptedMediaUrl: "ar://encryptedMediaUriHere",
      decryptionKey: "decryptionKeyHere",
      hash: "uniqueHashHere",
      decryptedMediaUrl: "ar://decryptedMediaUriHere"
    });

    vm.prank(address(DEFAULT_OWNER_ADDRESS));
    countdownErc721.setMetadataParams(metadataParams);

    string memory base64TokenUri = countdownErc721.tokenURI(tokenId);
    console.log("base64TokenUri: ", base64TokenUri);

    assertEq(base64TokenUri, expectedTokenUri, "Incorrect tokenURI for newly minted token");
  }
}
