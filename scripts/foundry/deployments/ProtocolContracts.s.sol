// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {HolographGenesis} from "src/HolographGenesis.sol";

import {Logger} from "../utils/Logger.sol";
import {ForkHelper} from "../utils/ForkHelper.sol";
import {EnvHelper} from "../utils/EnvHelper.sol";

contract ProtocolContractsDeployScript is Script, Logger {
  function deploy(bytes32 deployerPrivateKey, string memory contractName, bytes memory bytecode, bytes memory initcode, uint256[] calldata chainIds) public {
    logHlgDeployerMessage(contractName);
    logHlgDeployerMessage(vm.toString(bytecode));
    logHlgDeployerMessage(vm.toString(initcode));
  }
}
