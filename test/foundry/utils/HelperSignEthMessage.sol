// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
library HelperSignEthMessage {
  /**
   * @dev Returns the keccak256 digest of an ERC-191 signed data with version
   * `0x45` (`personal_sign` messages).
   *
   * The digest is calculated by prefixing a bytes32 `messageHash` with
   * `"\x19Ethereum Signed Message:\n32"` and hashing the result. It corresponds with the
   * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
   *
   * NOTE: The `messageHash` parameter is intended to be the result of hashing a raw message with
   * keccak256, although any bytes32 value can be safely used because the final digest will
   * be re-hashed.
   *
   * See {ECDSA-recover}.
   */
  function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
    /// @solidity memory-safe-assembly
    assembly {
      mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
      mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
      digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
    }
  }
}
