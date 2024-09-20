// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {HolographGenesis} from "src/HolographGenesis.sol";

import {Logger} from "../utils/Logger.sol";
import {ForkHelper} from "../utils/ForkHelper.sol";
import {EnvHelper} from "../utils/EnvHelper.sol";

contract HolographGenesisDeployScript is Script, Logger {
  function deploy(bytes32 deployerPrivateKey, uint256[] calldata chainIds) public {
    EnvHelper.checkHolographDeployerRequiredEnv();

    address deployer = vm.addr(uint256(deployerPrivateKey));

    for (uint256 i = 0; i < chainIds.length; i++) {
      ForkHelper.forkByChainId(chainIds[i]);

      vm.startBroadcast(uint256(deployerPrivateKey));
      uint256 gasBefore = gasleft();
      HolographGenesis hlg = new HolographGenesis();
      uint256 gasAfter = gasleft();
      vm.stopBroadcast();

      uint256 gasUsed = gasBefore - gasAfter;
      ForkHelper.revertIfNotEnoughFunds(deployer, gasUsed);
    }
  }
}
