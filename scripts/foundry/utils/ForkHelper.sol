// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ETH_CHAIN_ID, POLYGON_CHAIN_ID, AVALANCHE_CHAIN_ID, BSC_CHAIN_ID, OP_CHAIN_ID, ARBITRUM_CHAIN_ID, ZORA_CHAIN_ID, MANTLE_CHAIN_ID, BASE_CHAIN_ID, LINEA_CHAIN_ID, SEPOLIA_CHAIN_ID, AMOY_CHAIN_ID, FUJI_CHAIN_ID, BSC_TESTNET_CHAIN_ID, OP_SEPOLIA_CHAIN_ID, ARB_SEPOLIA_CHAIN_ID, ZORA_SEPOLIA_CHAIN_ID, MANTLE_SEPOLIA_CHAIN_ID, BASE_SEPOLIA_CHAIN_ID, LINEA_SEPOLIA_CHAIN_ID} from "./constants.sol";

library ForkHelper {
  using stdJson for string;

  /* -------------------------------------------------------------------------- */
  /*                               Fork management                              */
  /* -------------------------------------------------------------------------- */

  function forkByChainId(uint256 chainId) internal {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string memory rpcUrl = getRpcUrl(chainId);

    if (abi.encodePacked(rpcUrl).length == 0) {
      revert(
        string(
          abi.encodePacked(
            "The ",
            string(abi.encodePacked("\x1b[33m", getFoundryEndpointEnvVarName(getChainFoundryName(chainId)), "\x1b[0m")),
            " environment variable is not set. Please add it to the holograph-protocol repository's ",
            "\x1b[36m.env\x1b[0m",
            " file to deploy to ",
            string(abi.encodePacked("\x1b[32m", getChainName(chainId), "\x1b[0m"))
          )
        )
      );
    }

    vm.createSelectFork(rpcUrl);
  }

  function supportedMainnetIds() internal returns (uint256[] memory chainIds) {
    chainIds = new uint256[](10);
    chainIds[0] = ETH_CHAIN_ID;
    chainIds[1] = POLYGON_CHAIN_ID;
    chainIds[2] = AVALANCHE_CHAIN_ID;
    chainIds[3] = BSC_CHAIN_ID;
    chainIds[4] = OP_CHAIN_ID;
    chainIds[5] = ARBITRUM_CHAIN_ID;
    chainIds[6] = ZORA_CHAIN_ID;
    chainIds[7] = MANTLE_CHAIN_ID;
    chainIds[8] = BASE_CHAIN_ID;
    chainIds[9] = LINEA_CHAIN_ID;
  }

  function supportedTestnetIds() internal returns (uint256[] memory chainIds) {
    chainIds = new uint256[](10);
    chainIds[0] = SEPOLIA_CHAIN_ID;
    chainIds[1] = AMOY_CHAIN_ID;
    chainIds[2] = FUJI_CHAIN_ID;
    chainIds[3] = BSC_TESTNET_CHAIN_ID;
    chainIds[4] = OP_SEPOLIA_CHAIN_ID;
    chainIds[5] = ARB_SEPOLIA_CHAIN_ID;
    chainIds[6] = ZORA_SEPOLIA_CHAIN_ID;
    chainIds[7] = MANTLE_SEPOLIA_CHAIN_ID;
    chainIds[8] = BASE_SEPOLIA_CHAIN_ID;
    chainIds[9] = LINEA_SEPOLIA_CHAIN_ID;
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Chain names                                */
  /* -------------------------------------------------------------------------- */

  function getChainName(uint256 chainId) internal returns (string memory) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    if (chainId == ETH_CHAIN_ID) return "Ethereum";
    if (chainId == POLYGON_CHAIN_ID) return "Polygon";
    if (chainId == AVALANCHE_CHAIN_ID) return "Avalanche";
    if (chainId == BSC_CHAIN_ID) return "BNB Smart Chain";
    if (chainId == OP_CHAIN_ID) return "Optimism";
    if (chainId == ARBITRUM_CHAIN_ID) return "Arbitrum";
    if (chainId == ZORA_CHAIN_ID) return "Zora";
    if (chainId == MANTLE_CHAIN_ID) return "Mantle";
    if (chainId == BASE_CHAIN_ID) return "Base";
    if (chainId == LINEA_CHAIN_ID) return "Linea";
    if (chainId == SEPOLIA_CHAIN_ID) return "Ethereum sepolia";
    if (chainId == AMOY_CHAIN_ID) return "Amoy";
    if (chainId == FUJI_CHAIN_ID) return "Fuji";
    if (chainId == BSC_TESTNET_CHAIN_ID) return "BNB Smart Chain Testnet";
    if (chainId == OP_SEPOLIA_CHAIN_ID) return "Optimism Sepolia";
    if (chainId == ARB_SEPOLIA_CHAIN_ID) return "Arbitrum Sepolia";
    if (chainId == ZORA_SEPOLIA_CHAIN_ID) return "Zora Sepolia";
    if (chainId == MANTLE_SEPOLIA_CHAIN_ID) return "Mantle Testnet";
    if (chainId == BASE_SEPOLIA_CHAIN_ID) return "Base Sepolia";
    if (chainId == LINEA_SEPOLIA_CHAIN_ID) return "Linea Sepolia";
  }

  function getChainFoundryName(uint256 chainId) internal returns (string memory) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /* -------------------------------- Mainnets -------------------------------- */
    if (chainId == ETH_CHAIN_ID) return "ethereum";
    if (chainId == POLYGON_CHAIN_ID) return "polygon";
    if (chainId == AVALANCHE_CHAIN_ID) return "avalanche";
    if (chainId == BSC_CHAIN_ID) return "bsc";
    if (chainId == OP_CHAIN_ID) return "optimism";
    if (chainId == ARBITRUM_CHAIN_ID) return "arbitrum";
    if (chainId == ZORA_CHAIN_ID) return "zora";
    if (chainId == MANTLE_CHAIN_ID) return "mantle";
    if (chainId == BASE_CHAIN_ID) return "base";
    if (chainId == LINEA_CHAIN_ID) return "linea";
    /* -------------------------------- Testnets -------------------------------- */
    if (chainId == SEPOLIA_CHAIN_ID) return "sepolia";
    if (chainId == AMOY_CHAIN_ID) return "amoy";
    if (chainId == FUJI_CHAIN_ID) return "fuji";
    if (chainId == BSC_TESTNET_CHAIN_ID) return "bscTestnet";
    if (chainId == OP_SEPOLIA_CHAIN_ID) return "opsepolia";
    if (chainId == ARB_SEPOLIA_CHAIN_ID) return "arbsepolia";
    if (chainId == ZORA_SEPOLIA_CHAIN_ID) return "zorasepolia";
    if (chainId == MANTLE_SEPOLIA_CHAIN_ID) return "mantleTestnet";
    if (chainId == BASE_SEPOLIA_CHAIN_ID) return "baseSepolia";
    if (chainId == LINEA_SEPOLIA_CHAIN_ID) return "lineaSepolia";
  }

  function getFoundryEndpointEnvVarName(string memory chainFoundryName) internal returns (string memory) {
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("ethereum"))) return "ETHEREUM_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("polygon"))) return "POLYGON_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("avalanche"))) return "AVALANCHE_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("bsc"))) return "BINANCE_SMART_CHAIN_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("optimism"))) return "OPTIMISM_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("arbitrum"))) return "ARBITRUM_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("zora"))) return "ZORA_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("mantle"))) return "MANTLE_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("base"))) return "BASE_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("linea"))) return "LINEA_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("sepolia")))
      return "ETHEREUM_TESTNET_SEPOLIA_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("amoy"))) return "POLYGON_TESTNET_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("fuji"))) return "AVALANCHE_TESTNET_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("bscTestnet")))
      return "BINANCE_SMART_CHAIN_TESTNET_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("opsepolia")))
      return "OPTIMISM_TESTNET_SEPOLIA_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("arbsepolia")))
      return "ARBITRUM_TESTNET_SEPOLIA_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("zorasepolia")))
      return "ZORA_TESTNET_SEPOLIA_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("mantleTestnet")))
      return "MANTLE_TESTNET_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("baseSepolia")))
      return "BASE_TESTNET_SEPOLIA_RPC_URL";
    if (keccak256(abi.encode(chainFoundryName)) == keccak256(abi.encode("lineaSepolia")))
      return "LINEA_TESTNET_SEPOLIA_RPC_URL";
  }

  /* -------------------------------------------------------------------------- */
  /*                               Block explorer                               */
  /* -------------------------------------------------------------------------- */

  function getBlockScanUrl(uint256 chainId, bytes32 txHash) internal returns (string memory) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    if (chainId == 0) return "https://layerzeroscan.com/";
    if (chainId == ETH_CHAIN_ID) return "https://etherscan.io/";
    if (chainId == POLYGON_CHAIN_ID) return "https://polygonscan.com/";
    if (chainId == AVALANCHE_CHAIN_ID) return "https://snowtrace.io/";
    if (chainId == BSC_CHAIN_ID) return "https://bscscan.com/";
    if (chainId == OP_CHAIN_ID) return "https://optimistic.etherscan.io/";
    if (chainId == ARBITRUM_CHAIN_ID) return "https://arbiscan.io/";
    if (chainId == ZORA_CHAIN_ID) return "https://zorascan.xyz/";
    if (chainId == MANTLE_CHAIN_ID) return "https://mantlescan.xyz/";
    if (chainId == BASE_CHAIN_ID) return "https://basescan.org/";
    if (chainId == LINEA_CHAIN_ID) return "https://lineascan.build/";
    if (chainId == SEPOLIA_CHAIN_ID) return "https://sepolia.etherscan.io/";
    if (chainId == AMOY_CHAIN_ID) return "https://amoy.polygonscan.com/";
    if (chainId == FUJI_CHAIN_ID) return "https://testnet.snowtrace.io/";
    if (chainId == BSC_TESTNET_CHAIN_ID) return "https://testnet.bscscan.com/";
    if (chainId == OP_SEPOLIA_CHAIN_ID) return "https://sepolia-optimism.etherscan.io/";
    if (chainId == ARB_SEPOLIA_CHAIN_ID) return "https://sepolia.arbiscan.io/";
    if (chainId == ZORA_SEPOLIA_CHAIN_ID) return "https://999999999.testnet.routescan.io/";
    if (chainId == MANTLE_SEPOLIA_CHAIN_ID) return "https://sepolia.mantlescan.xyz/";
    if (chainId == BASE_SEPOLIA_CHAIN_ID) return "https://sepolia.basescan.org/";
    if (chainId == LINEA_SEPOLIA_CHAIN_ID) return "https://sepolia.lineascan.build/";
  }

  function getTxLink(uint256 chainId, bytes32 txHash) internal returns (string memory) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string memory blockScanUrl = getBlockScanUrl(chainId, txHash);

    return string(abi.encodePacked(blockScanUrl, "tx/", vm.toString(txHash)));
  }

  /* -------------------------------------------------------------------------- */
  /*                                     Rpc                                    */
  /* -------------------------------------------------------------------------- */

  function getRpcUrl(uint256 chainId) internal returns (string memory rpcUrl) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string memory chainFoundryName = getChainFoundryName(chainId);

    rpcUrl = vm.rpcUrl(chainFoundryName);
  }

  /* -------------------------------------------------------------------------- */
  /*                                   Helpers                                  */
  /* -------------------------------------------------------------------------- */

  function isTestnet(uint256 chainId) internal returns (bool) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    return (chainId == SEPOLIA_CHAIN_ID ||
      chainId == AMOY_CHAIN_ID ||
      chainId == FUJI_CHAIN_ID ||
      chainId == BSC_TESTNET_CHAIN_ID ||
      chainId == OP_SEPOLIA_CHAIN_ID ||
      chainId == ARB_SEPOLIA_CHAIN_ID ||
      chainId == ZORA_SEPOLIA_CHAIN_ID ||
      chainId == MANTLE_SEPOLIA_CHAIN_ID ||
      chainId == BASE_SEPOLIA_CHAIN_ID ||
      chainId == LINEA_SEPOLIA_CHAIN_ID);
  }

  function revertIfNotEnoughFunds(address deployer, uint256 gasSpent) internal {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string[] memory inputs = new string[](2);
    inputs[0] = "curl";
    inputs[1] = string(
      abi.encodePacked(vm.envString("GAS_API_URL"), "/networks/", vm.toString(block.chainid), "/suggestedGasFees")
    );
    string memory gasJson = string(vm.ffi(inputs));

    // float gas price in gwei
    string memory gasPriceGwei = string(gasJson.parseRaw(".high.suggestedMaxFeePerGas"));
    uint256 gasPrice = gweiStringToWeiUint256(gasPriceGwei);
    uint256 gasCost = gasPrice * gasSpent;

    if (address(deployer).balance < (gasCost * 12) / 10) {
      revert(
        string(
          abi.encodePacked(
            "Deployer(",
            vm.toString(deployer),
            ") does not have enough funds on ",
            getChainName(block.chainid),
            ". Estimated gas cost: ",
            vm.toString(gasCost),
            " wei."
          )
        )
      );
    }
  }

  function gweiStringToWeiUint256(string memory gweiString) public pure returns (uint256) {
    bytes memory b = bytes(gweiString);
    uint256 integerPart = 0;
    uint256 decimalPart = 0;
    uint256 decimalDivisor = 1;
    bool hasDecimal = false;
    bool numberStarted = false;

    for (uint256 i = 0; i < b.length; i++) {
      bytes1 char = b[i];

      // Skip any leading non-numeric characters
      if (!numberStarted) {
        if ((char >= "0" && char <= "9") || char == ".") {
          numberStarted = true;
          if (char == ".") {
            hasDecimal = true;
          } else {
            uint256 digit = uint8(char) - uint8(bytes1("0"));
            integerPart = integerPart * 10 + digit;
          }
        } else {
          continue; // Ignore non-numeric characters before the number starts
        }
      } else {
        // Number parsing has started
        if (char >= "0" && char <= "9") {
          uint256 digit = uint8(char) - uint8(bytes1("0"));
          if (!hasDecimal) {
            integerPart = integerPart * 10 + digit;
          } else {
            decimalPart = decimalPart * 10 + digit;
            decimalDivisor *= 10;
          }
        } else if (char == "." && !hasDecimal) {
          hasDecimal = true;
        } else {
          // Stop parsing when encountering non-numeric characters after the number starts
          break;
        }
      }
    }

    require(numberStarted, "No valid number found in input string");

    // Convert integer part from Gwei to Wei
    uint256 integerPartWei = integerPart * 1e9;

    // Convert decimal part from Gwei to Wei
    uint256 decimalPartWei = (decimalPart * 1e9) / decimalDivisor;

    return integerPartWei + decimalPartWei;
  }
}
