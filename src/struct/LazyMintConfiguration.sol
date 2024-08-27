// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @notice LazyMint configuration
struct LazyMintConfiguration {
  /// @dev _amount The amount of tokens to lazy mint (basically the batch size)
  uint256 _amount;
  /// @dev _baseURIForTokens The base URI for the tokens in this batch
  string _baseURIForTokens;
  /// @dev _data The data to be used to set the encrypted URI.
  ///      A bytes containing a sub bytes and a bytes32 => abi.encode(bytes(0x00..0), bytes32(0x00..0));
  bytes _data;
}