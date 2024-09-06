// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {GasParameters} from "src/struct/GasParameters.sol";

library ChainGasParameters {
  function getGasParameters(uint256 chainId) internal pure returns (GasParameters memory) {
    // TODO: Implement the gas parameters for each chain
    return
      GasParameters({
        msgBaseGas: 110000,
        msgGasPerByte: 25,
        jobBaseGas: 160000,
        jobGasPerByte: 25,
        minGasPrice: 40000000000,
        maxGasLimit: 15000000
      });
  }
}
