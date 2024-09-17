// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

library SafeWallet {
  function createTransaction(address safeWallet, address to, bytes memory data) internal returns (bytes memory res) {
    createTransactionOnChain(safeWallet, block.chainid, to, data);
  }

  function createTransactionOnChain(
    address safeWallet,
    uint256 chainId,
    address to,
    bytes memory data
  ) internal returns (bytes memory res) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string[] memory inputs = new string[](11);
    inputs[0] = string(abi.encodePacked("./scripts/utils/safeCLI/targets/", getTsUtilsCliFileName()));
    inputs[1] = "safeTx";
    inputs[2] = "--chain";
    inputs[3] = vm.toString(chainId);
    inputs[4] = "--calldata";
    inputs[5] = vm.toString(data);
    inputs[6] = "--safe";
    inputs[7] = vm.toString(safeWallet);
    inputs[8] = "--to";
    inputs[9] = vm.toString(to);
    inputs[10] = "--silent";

    res = vm.ffi(inputs);
  }

  /**
   * @notice Get the name of the ts-utils-cli file for the current machine
   * @dev Does not work on windows
   * @dev Possible values: ts-utils-cli-linux-x64, ts-utils-cli-macos-arm64, ts-utils-cli-macos-x64
   * @return fileName The name of the ts-utils-cli file for the current machine
   */
  function getTsUtilsCliFileName() internal returns (string memory fileName) {
    string memory arch = getArch();
    string memory kernel = getKernel();

    if (keccak256(abi.encodePacked(arch)) == keccak256(abi.encodePacked("Linux"))) {
      fileName = "ts-utils-cli-linux-x64";
    } else if (keccak256(abi.encodePacked(arch)) == keccak256(abi.encodePacked("Darwin"))) {
      if (keccak256(abi.encodePacked(kernel)) == keccak256(abi.encodePacked("arm64"))) {
        fileName = "ts-utils-cli-macos-arm64";
      } else {
        fileName = "ts-utils-cli-macos-x64";
      }
    }
  }

  /**
   * @notice Get the architecture of the current machine
   * @dev Does not work on windows
   */
  function getArch() internal returns (string memory) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string[] memory inputs = new string[](2);
    inputs[0] = "uname";
    inputs[1] = "-s";

    return string(vm.ffi(inputs));
  }

  /**
   * @notice Get the kernel of the current machine
   * @dev Does not work on windows
   */
  function getKernel() internal returns (string memory) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string[] memory inputs = new string[](2);
    inputs[0] = "uname";
    inputs[1] = "-m";

    return string(vm.ffi(inputs));
  }
}
