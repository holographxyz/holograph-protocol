// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import {CustomERC721SalesConfiguration} from "src/struct/CustomERC721SalesConfiguration.sol";

struct CountdownERC721Initializer {
  string description; // The description of the token.
  string imageURI; // The URI for the image associated with this contract.
  string animationURI; // The URI for the animation associated with this contract.
  string externalLink; // The URI for the external metadata associated with this contract.
  string encryptedMediaURI; // The URI for the encrypted media associated with this contract.
  uint40 startDate; // The starting date for the countdown
  uint32 initialMaxSupply; // The theoretical initial maximum supply of tokens at the start of the countdown.
  uint24 mintInterval; // The interval between possible mints,
  address initialOwner; // Address of the initial owner, who has administrative privileges.
  address initialMinter; // Address of the initial minter, who can mint new tokens for those who purchase offchain.
  address payable fundsRecipient; // Address of the recipient for funds gathered from sales.
  string contractURI; // URI for the metadata associated with this contract.
  CustomERC721SalesConfiguration salesConfiguration; // Configuration of sales settings for this contract.
}
