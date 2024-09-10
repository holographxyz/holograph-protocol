// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

enum ReturnType {
  UINT256,
  ADDRESS,
  BYTES32,
  BYTES
}

library bytesSlicer {
  function slice(
    bytes memory data,
    uint256 start,
    uint256 end,
    ReturnType returnType
  ) public pure returns (bytes32, uint256, address, bytes memory) {
    require(end > start, "End must be greater than start");
    require(end <= data.length, "End index out of bounds");

    // Créer un nouvel array bytes pour stocker le slice
    bytes memory sliced = new bytes(end - start);

    // Copier les bytes dans le nouvel array
    for (uint256 i = start; i < end; i++) {
      sliced[i - start] = data[i];
    }

    // Selon le type de retour souhaité, effectuer les conversions appropriées
    if (returnType == ReturnType.UINT256) {
      require(sliced.length <= 32, "Bytes too long for uint256");
      uint256 result;
      assembly {
        result := mload(add(sliced, 32))
      }
      return (bytes32(0), result, address(0), new bytes(0));
    } else if (returnType == ReturnType.ADDRESS) {
      require(sliced.length == 20, "Bytes length must be 20 for address");
      address result;
      assembly {
        result := mload(add(sliced, 20))
      }
      return (bytes32(0), 0, result, new bytes(0));
    } else if (returnType == ReturnType.BYTES32) {
      require(sliced.length <= 32, "Bytes too long for bytes32");
      bytes32 result;
      assembly {
        result := mload(add(sliced, 32))
      }
      return (result, 0, address(0), new bytes(0));
    } else if (returnType == ReturnType.BYTES) {
      // Retourner directement le slice en bytes
      return (bytes32(0), 0, address(0), sliced);
    } else {
      revert("Invalid return type");
    }
  }
}
