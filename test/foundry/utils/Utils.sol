// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {console} from "forge-std/console.sol";

library Utils {
  function stringToBytes32(string memory input) public pure returns (bytes32) {
    require(bytes(input).length <= 32, "Input string must be less than or equal to 32 bytes");

    bytes32 result;
    assembly {
      result := mload(add(input, 32))
    }
    return result >> (8 * (32 - bytes(input).length));
  }
}

library RandomAddress {
    /**
     * @notice Generate a random address for testing purposes.
     * @dev This function generates a random address by hashing the current block timestamp and difficulty
     * using the keccak256 algorithm, and then converting the resulting hash to an address.
     * @return address A randomly generated address.
     */
    function randomAddress() public view returns (address) {
        uint256 randomNum = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
        return address(uint160(randomNum));
    }
}
