// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {LayerZeroV2ModuleFixture} from "test/foundry/fixtures/LayerZeroV2ModuleFixture.sol";

import {CxipERC721} from "src/token/CxipERC721.sol";
import {TokenUriType} from "src/enum/TokenUriType.sol";
import {HolographBridgeInterface} from "src/interface/HolographBridgeInterface.sol";
import {Holographable} from "src/interface/Holographable.sol";
import {HolographRegistryInterface} from "src/interface/HolographRegistryInterface.sol";

contract LayerZeroV2ModuleBridgeOut is Test, LayerZeroV2ModuleFixture {
  uint256 gasLimit = 13314000;
  uint256 gasPrice = 40000000001;

  function setUp() public override {
    super.setUp();
  }

  // Emit event when cross chain message is sent
  event CrossChainMessageSent(bytes32 messageHash);

  function test_bridgeOutRequest() public {
    // Psuedo random token id in range [0, 1_000_000)
    uint256 nextTokenId = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 1_000_000;

    uint256 chainPrepend = uint256(bytes32(abi.encodePacked(holograph.getHolographChainId(), uint224(0))));
    uint256 prefixedTokenId = chainPrepend + uint256(nextTokenId);

    // Mint ERC721 token
    vm.prank(CxipERC721(payable(erc721)).owner());
    CxipERC721(payable(erc721)).cxipMint(uint224(nextTokenId), TokenUriType.HTTPS, "https://host.com/asset.png");

    // Bridge out payload
    bytes memory bridgeOutPayload = abi.encode(erc721Owner, erc721Owner, prefixedTokenId);

    // Get the CxipERC721 bridge out payload
    bytes memory holographableBridgePayload = abi.encode(TokenUriType.HTTPS, "https://host.com/asset.png");

    // Get the HLG fee
    uint256 hlgFee = layerZeroV2Module.getHlgFee(
      uint32(defaultDestinationChain),
      gasLimit,
      gasPrice,
      holographableBridgePayload
    );

    // Get the hToken
    address hToken = HolographRegistryInterface(holographOperator.getRegistry()).getHToken(
      holograph.getHolographChainId()
    );

    // Encode the message payload
    bytes memory encodedData = abi.encodeWithSelector(
      HolographBridgeInterface.bridgeInRequest.selector,
      holographBridge.getJobNonce() + 1,
      holograph.getHolographChainId(),
      erc721,
      bridgeOutPayload,
      hToken,
      address(0),
      hlgFee,
      true,
      holographableBridgePayload
    );
    encodedData = abi.encodePacked(encodedData, gasLimit, gasPrice);

    bytes32 messageHash = keccak256(encodedData);

    // console.logBytes(encodedData);
    console.logBytes(encodedData);

    vm.expectEmit(false, false, false, true, address(holographOperator));
    emit CrossChainMessageSent(messageHash);

    // Bridge out request
    holographBridge.bridgeOutRequest{value: 0.002 ether}(
      uint32(defaultDestinationChain),
      erc721,
      gasLimit,
      gasPrice,
      bridgeOutPayload
    );
  }

  function test_executorLzReceive() public {
    string memory forkUrl = vm.envString("ARBITRUM_TESTNET_SEPOLIA_RPC_URL");
    uint256 forkId = vm.createFork(forkUrl);
    vm.selectFork(forkId);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Fallback functions                             */
  /* -------------------------------------------------------------------------- */

  receive() external payable {}

  fallback() external payable {}
}
