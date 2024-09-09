// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";

library ForkHelper {
  function forkByChainId(uint256 chainId) internal {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string memory rpcUrl;
    /* -------------------------------- Mainnets -------------------------------- */
    if (chainId == vm.envUint("ETH_CHAIN_ID")) rpcUrl = vm.rpcUrl("ethereum");
    if (chainId == vm.envUint("POLYGON_CHAIN_ID")) rpcUrl = vm.rpcUrl("polygon");
    if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) rpcUrl = vm.rpcUrl("avalanche");
    if (chainId == vm.envUint("BSC_CHAIN_ID")) rpcUrl = vm.rpcUrl("bsc");
    if (chainId == vm.envUint("OP_CHAIN_ID")) rpcUrl = vm.rpcUrl("optimism");
    if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) rpcUrl = vm.rpcUrl("arbitrum");
    if (chainId == vm.envUint("ZORA_CHAIN_ID")) rpcUrl = vm.rpcUrl("zora");
    if (chainId == vm.envUint("MANTLE_CHAIN_ID")) rpcUrl = vm.rpcUrl("mantle");
    if (chainId == vm.envUint("BASE_CHAIN_ID")) rpcUrl = vm.rpcUrl("base");
    if (chainId == vm.envUint("LINEA_CHAIN_ID")) rpcUrl = vm.rpcUrl("linea");
    /* -------------------------------- Testnets -------------------------------- */
    if (chainId == vm.envUint("SEPOLIA_CHAIN_ID")) rpcUrl = vm.rpcUrl("sepolia");
    if (chainId == vm.envUint("MUMBAI_CHAIN_ID")) rpcUrl = vm.rpcUrl("mumbai");
    if (chainId == vm.envUint("FUJI_CHAIN_ID")) rpcUrl = vm.rpcUrl("fuji");
    if (chainId == vm.envUint("BSC_TESTNET_CHAIN_ID")) rpcUrl = vm.rpcUrl("bscTestnet");
    if (chainId == vm.envUint("OP_SEPOLIA_CHAIN_ID")) rpcUrl = vm.rpcUrl("opsepolia");
    if (chainId == vm.envUint("ARB_SEPOLIA_CHAIN_ID")) rpcUrl = vm.rpcUrl("arbsepolia");
    if (chainId == vm.envUint("ZORA_SEPOLIA_CHAIN_ID")) rpcUrl = vm.rpcUrl("zorasepolia");
    if (chainId == vm.envUint("MANTLE_SEPOLIA_CHAIN_ID")) rpcUrl = vm.rpcUrl("mantleTestnet");
    if (chainId == vm.envUint("BASE_SEPOLIA_CHAIN_ID")) rpcUrl = vm.rpcUrl("baseSepolia");
    if (chainId == vm.envUint("LINEA_SEPOLIA_CHAIN_ID")) rpcUrl = vm.rpcUrl("lineaSepolia");

    vm.createSelectFork(rpcUrl);
  }

  function getChainName(uint256 chainId) internal returns (string memory) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    
    if (chainId == vm.envUint("ETH_CHAIN_ID")) return "Ethereum";
    if (chainId == vm.envUint("POLYGON_CHAIN_ID")) return "Polygon";
    if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) return "Avalanche";
    if (chainId == vm.envUint("BSC_CHAIN_ID")) return "BNB Smart Chain";
    if (chainId == vm.envUint("OP_CHAIN_ID")) return "Optimism";
    if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) return "Arbitrum";
    if (chainId == vm.envUint("ZORA_CHAIN_ID")) return "Zora";
    if (chainId == vm.envUint("MANTLE_CHAIN_ID")) return "Mantle";
    if (chainId == vm.envUint("BASE_CHAIN_ID")) return "Base";
    if (chainId == vm.envUint("LINEA_CHAIN_ID")) return "Linea";
    if (chainId == vm.envUint("SEPOLIA_CHAIN_ID")) return "Ethereum sepolia";
    if (chainId == vm.envUint("MUMBAI_CHAIN_ID")) return "Mumbai";
    if (chainId == vm.envUint("FUJI_CHAIN_ID")) return "Fuji";
    if (chainId == vm.envUint("BSC_TESTNET_CHAIN_ID")) return "BNB Smart Chain Testnet";
    if (chainId == vm.envUint("OP_SEPOLIA_CHAIN_ID")) return "Optimism Sepolia";
    if (chainId == vm.envUint("ARB_SEPOLIA_CHAIN_ID")) return "Arbitrum Sepolia";
    if (chainId == vm.envUint("ZORA_SEPOLIA_CHAIN_ID")) return "Zora Sepolia";
    if (chainId == vm.envUint("MANTLE_SEPOLIA_CHAIN_ID")) return "Mantle Testnet";
    if (chainId == vm.envUint("BASE_SEPOLIA_CHAIN_ID")) return "Base Sepolia";
    if (chainId == vm.envUint("LINEA_SEPOLIA_CHAIN_ID")) return "Linea Sepolia";
  }

  function getBlockScanUrl(uint256 chainId, bytes32 txHash) internal returns (string memory) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    if (chainId == vm.envUint("ETH_CHAIN_ID")) return "https://etherscan.io/";
    if (chainId == vm.envUint("POLYGON_CHAIN_ID")) return "https://polygonscan.com/";
    if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) return "https://snowtrace.io/";
    if (chainId == vm.envUint("BSC_CHAIN_ID")) return "https://bscscan.com/";
    if (chainId == vm.envUint("OP_CHAIN_ID")) return "https://optimistic.etherscan.io/";
    if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) return "https://arbiscan.io/";
    if (chainId == vm.envUint("ZORA_CHAIN_ID")) return "https://zorascan.xyz/";
    if (chainId == vm.envUint("MANTLE_CHAIN_ID")) return "https://mantlescan.xyz/";
    if (chainId == vm.envUint("BASE_CHAIN_ID")) return "https://basescan.org/";
    if (chainId == vm.envUint("LINEA_CHAIN_ID")) return "https://lineascan.build/";
    if (chainId == vm.envUint("SEPOLIA_CHAIN_ID")) return "https://sepolia.etherscan.io/";
    if (chainId == vm.envUint("MUMBAI_CHAIN_ID")) return "https://amoy.polygonscan.com/";
    if (chainId == vm.envUint("FUJI_CHAIN_ID")) return "https://testnet.snowtrace.io/";
    if (chainId == vm.envUint("BSC_TESTNET_CHAIN_ID")) return "https://testnet.bscscan.com/";
    if (chainId == vm.envUint("OP_SEPOLIA_CHAIN_ID")) return "https://sepolia-optimism.etherscan.io/";
    if (chainId == vm.envUint("ARB_SEPOLIA_CHAIN_ID")) return "https://sepolia.arbiscan.io/";
    if (chainId == vm.envUint("ZORA_SEPOLIA_CHAIN_ID")) return "https://999999999.testnet.routescan.io/";
    if (chainId == vm.envUint("MANTLE_SEPOLIA_CHAIN_ID")) return "https://sepolia.mantlescan.xyz/";
    if (chainId == vm.envUint("BASE_SEPOLIA_CHAIN_ID")) return "https://sepolia.basescan.org/";
    if (chainId == vm.envUint("LINEA_SEPOLIA_CHAIN_ID")) return "https://sepolia.lineascan.build/";
  }

  function getTxLink(uint256 chainId, bytes32 txHash) internal returns (string memory) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string memory blockScanUrl = getBlockScanUrl(chainId, txHash);

    return string(abi.encodePacked(blockScanUrl, "tx/", vm.toString(txHash)));
  }

  function isTestnet(uint256 chainId) internal returns (bool) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    return (
      chainId == vm.envUint("SEPOLIA_CHAIN_ID") ||
      chainId == vm.envUint("MUMBAI_CHAIN_ID") ||
      chainId == vm.envUint("FUJI_CHAIN_ID") ||
      chainId == vm.envUint("BSC_TESTNET_CHAIN_ID") ||
      chainId == vm.envUint("OP_SEPOLIA_CHAIN_ID") ||
      chainId == vm.envUint("ARB_SEPOLIA_CHAIN_ID") ||
      chainId == vm.envUint("ZORA_SEPOLIA_CHAIN_ID") ||
      chainId == vm.envUint("MANTLE_SEPOLIA_CHAIN_ID") ||
      chainId == vm.envUint("BASE_SEPOLIA_CHAIN_ID") ||
      chainId == vm.envUint("LINEA_SEPOLIA_CHAIN_ID")
    );
  }
}
