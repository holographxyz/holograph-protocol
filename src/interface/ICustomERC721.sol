// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import {AddressMintDetails} from "../drops/struct/AddressMintDetails.sol";
import {CustomERC721SaleDetails} from "src/struct/CustomERC721SaleDetails.sol";

/// @notice Interface for HOLOGRAPH Drops contract
interface ICustomERC721 {
  // Access errors
  /// @notice Only admin can access this function
  error Access_OnlyAdmin();
  /// @notice Only minter can access this function
  error Access_OnlyMinter();
  /// @notice Missing the given role or admin access
  error Access_MissingRoleOrAdmin(bytes32 role);
  /// @notice Withdraw is not allowed by this user
  error Access_WithdrawNotAllowed();
  /// @notice Cannot withdraw funds due to ETH send failure.
  error Withdraw_FundsSendFailure();
  /// @notice Mint fee send failure
  error MintFee_FundsSendFailure();
  /// @notice Lazy mint initialization failed
  error LazyMint_AlreadyInitialized();
  /// @notice Contract is not initialized yet
  error NotInitialized();

  /// @notice Call to external metadata renderer failed.
  error ExternalMetadataRenderer_CallFailed();

  // Sale/Purchase errors
  /// @notice Sale is inactive
  error Sale_Inactive();
  /// @notice Wrong price for purchase
  error Purchase_WrongPrice(uint256 correctPrice);
  /// @notice NFT sold out
  error Mint_SoldOut();
  /// @notice Too many purchase for address
  error Purchase_TooManyForAddress();
  /// @notice Fee payout failed
  error FeePaymentFailed();
  /// @notice The countdown has been completed
  error Purchase_CountdownCompleted();

  // Init errors
  error CountdownEndMustBeDivisibleByMintTimeCost(uint128 countdownEnd, uint128 mintTimeCost);

  // Admin errors
  /// @notice Royalty percentage too high
  error Setup_RoyaltyPercentageTooHigh(uint16 maxRoyaltyBPS);
  /// @notice Invalid admin upgrade address
  error Admin_InvalidUpgradeAddress(address proposedAddress);
  /// @notice Unable to finalize an edition not marked as open (size set to uint64_max_value)
  error Admin_UnableToFinalizeNotOpenEdition();

  /// @notice Event emitted for mint fee payout
  /// @param mintFeeAmount amount of the mint fee
  /// @param mintFeeRecipient recipient of the mint fee
  /// @param success if the payout succeeded
  event MintFeePayout(uint256 mintFeeAmount, address mintFeeRecipient, bool success);

  /// @notice Event emitted for each sale
  /// @param to address sale was made to
  /// @param quantity quantity of the minted nfts
  /// @param pricePerToken price for each token
  /// @param firstPurchasedTokenId first purchased token ID (to get range add to quantity for max)
  event Sale(
    address indexed to,
    uint256 indexed quantity,
    uint256 indexed pricePerToken,
    uint256 firstPurchasedTokenId
  );

  /// @notice Sales configuration has been changed
  /// @dev To access new sales configuration, use getter function.
  /// @param changedBy Changed by user
  event SalesConfigChanged(address indexed changedBy);

  /// @notice Event emitted when the funds recipient is changed
  /// @param newAddress new address for the funds recipient
  /// @param changedBy address that the recipient is changed by
  event FundsRecipientChanged(address indexed newAddress, address indexed changedBy);

  /// @notice Event emitted when the funds are withdrawn from the minting contract
  /// @param withdrawnBy address that issued the withdraw
  /// @param withdrawnTo address that the funds were withdrawn to
  /// @param amount amount that was withdrawn
  event FundsWithdrawn(address indexed withdrawnBy, address indexed withdrawnTo, uint256 amount);

  /// @notice Event emitted when an open mint is finalized and further minting is closed forever on the contract.
  /// @param sender address sending close mint
  /// @param numberOfMints number of mints the contract is finalized at
  event OpenMintFinalized(address indexed sender, uint256 numberOfMints);

  /// @notice Event emitted when an nfs is minted
  /// @param recipient address that the nft was minted to
  /// @param tokenId id of the minted nft
  /// @param id id of the minted nft with chain id prefix
  event NFTMinted(address indexed recipient, uint256 indexed tokenId, uint256 id);

  /// @notice Getter for the sale start date
  function START_DATE() external view returns (uint256);

  /// @notice Getter for the initial max supply
  function INITIAL_MAX_SUPPLY() external view returns (uint256);

  /// @notice Getter for the mint interval
  function MINT_INTERVAL() external view returns (uint256);

  /// @notice Getter for the minter role
  function minter() external view returns (address);

  /// @notice Admin function to update the sales configuration settings
  /// @param publicSalePrice public sale price in ether
  /// @param maxSalePurchasePerAddress Max # of purchases (public) per address allowed
  function setSaleConfiguration(uint104 publicSalePrice, uint24 maxSalePurchasePerAddress) external;

  /// @notice External purchase function (payable in eth)
  /// @param quantity to purchase
  /// @return first minted token ID
  function purchase(uint256 quantity) external payable returns (uint256);

  /// @notice Function to return the global sales details for the given drop
  function saleDetails() external view returns (CustomERC721SaleDetails memory);

  /// @notice Function to return the current max supply
  function currentTheoricalMaxSupply() external view returns (uint256);

  /// @notice Function to return the specific sales details for a given address
  /// @param minter address for minter to return mint information for
  function mintedPerAddress(address minter) external view returns (AddressMintDetails memory);

  /// @notice This is the opensea/public owner setting that can be set by the contract admin
  function owner() external view returns (address);

  /// @dev Getter for admin role associated with the contract to handle metadata
  /// @return boolean if address is admin
  function isAdmin(address user) external view returns (bool);
}
