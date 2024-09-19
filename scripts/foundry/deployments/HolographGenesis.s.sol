// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {HolographGenesis} from "src/HolographGenesis.sol";

import {Logger} from "../utils/Logger.sol";
import {ForkHelper} from "../utils/ForkHelper.sol";

contract HolographGenesisDeployScript is Script, Logger {
  function deploy(bytes32 deployerPrivateKey, uint256[] calldata chainIds) public {
    address deployer = vm.addr(uint256(deployerPrivateKey));

    if (deployerPrivateKey == 0x0) {
      logHlgDeployerMessage("Need to provide deployer private key");
    }

    for (uint256 i = 0; i < chainIds.length; i++) {
      ForkHelper.forkByChainId(chainIds[i]);
      ForkHelper.revertIfNoFund(deployer);

      vm.startBroadcast(uint256(deployerPrivateKey));
      HolographGenesis hlg = new HolographGenesis();
      vm.stopBroadcast();

      logHlgDeployerMessage(string(abi.encodePacked(
        "new HolographGenesis(",
        vm.toString(chainIds[i]),
        "::",
        vm.toString(address(hlg)),
        ")"
      )));
    }
  }
}
