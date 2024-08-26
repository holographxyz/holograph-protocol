// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import {CustomERC721SalesConfiguration} from "src/struct/CustomERC721SalesConfiguration.sol";
import {LazyMintConfiguration} from "src/struct/LazyMintConfiguration.sol";

/// @param initialOwner User that owns and can mint the edition, gets royalty and sales payouts and can update the base url if needed.
/// @param initialMinter User that can mint on behalf of those who purchase offchain
/// @param fundsRecipient Wallet/user that receives funds from sale
/// @param mintTimeCost The time to subtract from the countdownEnd on each mint
/// @param countdownEnd The countdown end time
/// @param royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty.
/// @param salesConfiguration The initial SalesConfiguration
/// @param lazyMintsConfigurations The initial Lazy mints configurations
struct CustomERC721Initializer {
  uint40 startDate; // max start date in year 36_812
  uint32 initialMaxSupply; // max initial supply 4_294_967_295 tokens
  uint24 mintInterval; // max mint interval 16_777_215 seconds
  address initialOwner;
  address initialMinter;
  address payable fundsRecipient;
  string contractURI;
  CustomERC721SalesConfiguration salesConfiguration;
  LazyMintConfiguration[] lazyMintsConfigurations;
}
