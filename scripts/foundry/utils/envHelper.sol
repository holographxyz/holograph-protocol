// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

library EnvHelper {
  using stdJson for string;

  /**
   * @dev Check if every required environment variable is set
   * GAS_API_URL
   */
  function checkHolographDeployerRequiredEnv() internal {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    try vm.envString("GAS_API_URL") returns (string memory gasPriceApiUrl) {} catch {
      revert(
        string(
          abi.encodePacked(
            "The ",
            "\x1b[33mGAS_API_URL\x1b[0m",
            " environment variable is not set. Please add it to the holograph-protocol repository's ",
            "\x1b[36m.env\x1b[0m",
            " file. You can use the infura gas price API \x1b[36mhttps://docs.infura.io/api/infura-expansion-apis/gas-api\x1b[0m"
          )
        )
      );
    }
  }
}
