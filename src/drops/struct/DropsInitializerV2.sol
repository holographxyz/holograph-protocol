// SPDX-License-Identifier: MIT

/*SOLIDITY_COMPILER_VERSION*/

import {SalesConfiguration} from "./SalesConfiguration.sol";

/// @param initialOwner User that owns and can mint the edition, gets royalty and sales payouts and can update the base url if needed.
/// @param fundsRecipient Wallet/user that receives funds from sale
/// @param editionSize Number of editions that can be minted in total. If type(uint64).max, unlimited editions can be minted as an open edition.
/// @param royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty.
/// @param salesConfiguration The initial SalesConfiguration
/// @param metadataRenderer Renderer contract to use
/// @param metadataRendererInit Renderer data initial contract
struct DropsInitializerV2 {
  address initialOwner;
  address payable fundsRecipient;
  uint64 editionSize;
  uint16 royaltyBPS;
  SalesConfiguration salesConfiguration;
  address metadataRenderer;
  bytes metadataRendererInit;
}
