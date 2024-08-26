// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct MetadataParams {
  string name;
  string description;
  string imageURI;
  string animationURI;
  string externalUrl;
  string encryptedMediaUrl;
  string decryptionKey;
  string hash;
  string decryptedMediaUrl;
  uint256 tokenOfEdition;
  uint256 editionSize;
}
