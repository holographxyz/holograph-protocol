/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

/// @title Holograph ERC-721 Non-Fungible Token Standard
/// @dev See https://holograph.network/standard/ERC-721
///  Note: the ERC-165 identifier for this interface is 0xFFFFFFFF.
interface HolographedERC721 {
  // event id = 1
  function bridgeIn(
    uint32 _chainId,
    address _from,
    address _to,
    uint256 _tokenId,
    bytes calldata _data
  ) external returns (bool success);

  // event id = 2
  function bridgeOut(
    uint32 _chainId,
    address _from,
    address _to,
    uint256 _tokenId
  ) external returns (bytes memory _data);
}
