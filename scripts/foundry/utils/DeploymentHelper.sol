// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";

library DeploymentHelper {
  function computeGenesisDeploymentAddress(bytes32 salt, bytes memory sourceCode) internal view returns (address) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    return
      address(
        uint160(
          uint256(
            keccak256(abi.encodePacked(bytes1(0xff), vm.envAddress("GENESIS_ADDRESS"), salt, keccak256(sourceCode)))
          )
        )
      );
  }

  function getEndpointId(uint256 chainId) internal view returns (uint32 endpointId) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /* -------------------------------- Mainnets -------------------------------- */
    if (chainId == vm.envUint("ETH_CHAIN_ID")) endpointId = 30101;
    if (chainId == vm.envUint("POLYGON_CHAIN_ID")) endpointId = 30109;
    if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) endpointId = 30106;
    if (chainId == vm.envUint("BSC_CHAIN_ID")) endpointId = 30102;
    if (chainId == vm.envUint("OP_CHAIN_ID")) endpointId = 30111;
    if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) endpointId = 30110;
    if (chainId == vm.envUint("ZORA_CHAIN_ID")) endpointId = 30195;
    if (chainId == vm.envUint("MANTLE_CHAIN_ID")) endpointId = 30181;
    if (chainId == vm.envUint("BASE_CHAIN_ID")) endpointId = 30184;
    if (chainId == vm.envUint("LINEA_CHAIN_ID")) endpointId = 30183;
    /* -------------------------------- Testnets -------------------------------- */
    if (chainId == vm.envUint("SEPOLIA_CHAIN_ID")) endpointId = 40161;
    if (chainId == vm.envUint("MUMBAI_CHAIN_ID")) endpointId = 40267;
    if (chainId == vm.envUint("FUJI_CHAIN_ID")) endpointId = 40106;
    if (chainId == vm.envUint("BSC_TESTNET_CHAIN_ID")) endpointId = 40102;
    if (chainId == vm.envUint("OP_SEPOLIA_CHAIN_ID")) endpointId = 40232;
    if (chainId == vm.envUint("ARB_SEPOLIA_CHAIN_ID")) endpointId = 40231;
    if (chainId == vm.envUint("ZORA_SEPOLIA_CHAIN_ID")) endpointId = 40249;
    if (chainId == vm.envUint("MANTLE_SEPOLIA_CHAIN_ID")) endpointId = 40246;
    if (chainId == vm.envUint("BASE_SEPOLIA_CHAIN_ID")) endpointId = 40245;
    if (chainId == vm.envUint("LINEA_SEPOLIA_CHAIN_ID")) endpointId = 40287;
  }

  function getLzExecutor(uint256 chainId) internal view returns (address lzExecutor) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /* -------------------------------- Mainnets -------------------------------- */
    if (chainId == vm.envUint("ETH_CHAIN_ID")) lzExecutor = address(0x173272739Bd7Aa6e4e214714048a9fE699453059);
    if (chainId == vm.envUint("POLYGON_CHAIN_ID")) lzExecutor = address(0xCd3F213AD101472e1713C72B1697E727C803885b);
    if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) lzExecutor = address(0x90E595783E43eb89fF07f63d27B8430e6B44bD9c);
    if (chainId == vm.envUint("BSC_CHAIN_ID")) lzExecutor = address(0x3ebD570ed38B1b3b4BC886999fcF507e9D584859);
    if (chainId == vm.envUint("OP_CHAIN_ID")) lzExecutor = address(0x2D2ea0697bdbede3F01553D2Ae4B8d0c486B666e);
    if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) lzExecutor = address(0x31CAe3B7fB82d847621859fb1585353c5720660D);
    if (chainId == vm.envUint("ZORA_CHAIN_ID")) lzExecutor = address(0x4f8B7a7a346Da5c467085377796e91220d904c15);
    if (chainId == vm.envUint("MANTLE_CHAIN_ID")) lzExecutor = address(0x4Fc3f4A38Acd6E4cC0ccBc04B3Dd1CCAeFd7F3Cd);
    if (chainId == vm.envUint("BASE_CHAIN_ID")) lzExecutor = address(0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4);
    if (chainId == vm.envUint("LINEA_CHAIN_ID")) lzExecutor = address(0x0408804C5dcD9796F22558464E6fE5bDdF16A7c7);
    /* -------------------------------- Testnets -------------------------------- */
    if (chainId == vm.envUint("SEPOLIA_CHAIN_ID")) lzExecutor = address(0x718B92b5CB0a5552039B593faF724D182A881eDA);
    if (chainId == vm.envUint("MUMBAI_CHAIN_ID")) lzExecutor = address(0x4Cf1B3Fa61465c2c907f82fC488B43223BA0CF93);
    if (chainId == vm.envUint("FUJI_CHAIN_ID")) lzExecutor = address(0xa7BFA9D51032F82D649A501B6a1f922FC2f7d4e3);
    if (chainId == vm.envUint("BSC_TESTNET_CHAIN_ID")) lzExecutor = address(0x31894b190a8bAbd9A067Ce59fde0BfCFD2B18470);
    if (chainId == vm.envUint("OP_SEPOLIA_CHAIN_ID")) lzExecutor = address(0xDc0D68899405673b932F0DB7f8A49191491A5bcB);
    if (chainId == vm.envUint("ARB_SEPOLIA_CHAIN_ID")) lzExecutor = address(0x5Df3a1cEbBD9c8BA7F8dF51Fd632A9aef8308897);
    if (chainId == vm.envUint("ZORA_SEPOLIA_CHAIN_ID"))
      lzExecutor = address(0x4Cf1B3Fa61465c2c907f82fC488B43223BA0CF93);
    if (chainId == vm.envUint("MANTLE_SEPOLIA_CHAIN_ID"))
      lzExecutor = address(0x8BEEe743829af63F5b37e52D5ef8477eF12511dE);
    if (chainId == vm.envUint("BASE_SEPOLIA_CHAIN_ID"))
      lzExecutor = address(0x8A3D588D9f6AC041476b094f97FF94ec30169d3D);
    if (chainId == vm.envUint("LINEA_SEPOLIA_CHAIN_ID"))
      lzExecutor = address(0xe1a12515F9AB2764b887bF60B923Ca494EBbB2d6);
  }

  function getLzEndpoint(uint256 chainId) internal view returns (address lzEndpoint) {
    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /* -------------------------------- Mainnets -------------------------------- */
    if (chainId == vm.envUint("ETH_CHAIN_ID")) lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
    if (chainId == vm.envUint("POLYGON_CHAIN_ID")) lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
    if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
    if (chainId == vm.envUint("BSC_CHAIN_ID")) lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
    if (chainId == vm.envUint("OP_CHAIN_ID")) lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
    if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
    if (chainId == vm.envUint("ZORA_CHAIN_ID")) lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
    if (chainId == vm.envUint("MANTLE_CHAIN_ID")) lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
    if (chainId == vm.envUint("BASE_CHAIN_ID")) lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
    if (chainId == vm.envUint("LINEA_CHAIN_ID")) lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
    /* -------------------------------- Testnets -------------------------------- */
    if (chainId == vm.envUint("SEPOLIA_CHAIN_ID")) lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
    if (chainId == vm.envUint("MUMBAI_CHAIN_ID")) lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
    if (chainId == vm.envUint("FUJI_CHAIN_ID")) lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
    if (chainId == vm.envUint("BSC_TESTNET_CHAIN_ID")) lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
    if (chainId == vm.envUint("OP_SEPOLIA_CHAIN_ID")) lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
    if (chainId == vm.envUint("ARB_SEPOLIA_CHAIN_ID")) lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
    if (chainId == vm.envUint("ZORA_SEPOLIA_CHAIN_ID"))
      lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
    if (chainId == vm.envUint("MANTLE_SEPOLIA_CHAIN_ID"))
      lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
    if (chainId == vm.envUint("BASE_SEPOLIA_CHAIN_ID"))
      lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
    if (chainId == vm.envUint("LINEA_SEPOLIA_CHAIN_ID"))
      lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
  }
}
