// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HolographEvents {
  enum HolographERC20Event {
    bridgeIn,
    bridgeOut,
    afterApprove,
    beforeApprove,
    afterOnERC20Received,
    beforeOnERC20Received,
    afterBurn,
    beforeBurn,
    afterMint,
    beforeMint,
    afterSafeTransfer,
    beforeSafeTransfer,
    afterTransfer,
    beforeTransfer,
    onAllowance
  }

  enum HolographERC721Event {
    bridgeIn,
    bridgeOut,
    afterApprove,
    beforeApprove,
    afterApprovalAll,
    beforeApprovalAll,
    afterBurn,
    beforeBurn,
    afterMint,
    beforeMint,
    afterSafeTransfer,
    beforeSafeTransfer,
    afterTransfer,
    beforeTransfer,
    beforeOnERC721Received,
    afterOnERC721Received,
    onIsApprovedForAll,
    customContractURI
  }

  // enum HolographERC1155Event {

  // }

  function configureEvents(uint256[] memory config) public pure returns (bytes memory) {
    bytes memory binary = new bytes(256);
    for (uint256 i = 0; i < 256; i++) {
      binary[i] = "0";
    }

    for (uint256 i = 0; i < config.length; i++) {
      uint256 num = config[i];
      require(num >= 0 && num < 256, "Invalid event number");
      binary[num] = "1";
    }

    for (uint256 i = 0; i < 128; i++) {
      (binary[i], binary[255 - i]) = (binary[255 - i], binary[i]);
    }

    bytes memory hexString = new bytes(64);
    for (uint256 i = 0; i < 32; i++) {
      hexString[i * 2] = _toHexChar((uint8(binary[i * 8]) << 4) | uint8(binary[i * 8 + 1]));
      hexString[i * 2 + 1] = _toHexChar((uint8(binary[i * 8 + 2]) << 4) | uint8(binary[i * 8 + 3]));
    }

    return hexString;
  }

  function _toHexChar(uint8 b) internal pure returns (bytes1) {
    if (b < 10) {
      return bytes1(b + 0x30);
    } else {
      return bytes1(b + 0x57);
    }
  }
}
