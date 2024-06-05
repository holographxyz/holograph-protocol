// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, Vm} from "forge-std/Test.sol";

import {IHolographDropERC721V2} from "src/drops/interface/IHolographDropERC721V2.sol";
import {HolographDropERC721V2} from "src/drops/token/HolographDropERC721V2.sol";

/**
 * @title HolographDropERC721Test
 * @notice The goal of this test is to reproduce the exact transaction made at block 6031723 one time, and
 *         then to reproduce the same transaction but with the new version of the contract to confirm that
 *         the new version fixed the whole issue.
 * @dev To run this test you need to use a fork of sepolia at the block 6031724 and to use -vvvv flag to see
 *      the logs. The fixes should fix one of the ETH transfer that was made to the contract and that was
 *      reverting with an EvmError: OutOfFunds
 */
contract HolographDropERC721Test is Test {

  function setUp() public {
  }

  /**
   * @dev This test reproduce the exact transaction made at block 6031723
   *      => https://sepolia.etherscan.io/tx/0xb8dcf96afafb93d9148c1c469712ec37be17b8913a68f2c1a1d371a18d1194fb
   *      => https://dashboard.tenderly.co/tx/sepolia/0xb8dcf96afafb93d9148c1c469712ec37be17b8913a68f2c1a1d371a18d1194fb/debugger?trace=0.4.3.3.23
   * @dev To run this test you need to use a fork of sepolia at the block 6031724 and to use -vvvv flag to see
   *      the logs. You should see the transfer to 0xa57106357F9A487F6AfBaA3758e7fCcB787113c4 with a value of 609888904007765 wei
   *      failing with an EvmError: OutOfFunds
   */
  function test_V2PurchaseFreeMoeWithOldVersion() public {
    /// @dev To run this test you need to use a fork of sepolia at the block 6031724
    ///      You can create a fork like that using tenderly and creating a new fork at block 6031723
    assertEq(block.number, 6031724);
    assertEq(block.chainid, 11155111);

    // Doing the exact same call as the target transaction
    vm.prank(0xa57106357F9A487F6AfBaA3758e7fCcB787113c4);
    (bool success, bytes memory data) = address(0x731F5129F241edAc48fA088c5DE3b3149dF822FD).call{value: 609888904007765}(
      abi.encodeWithSelector(
        IHolographDropERC721V2.purchase.selector,
        1
      )
    );

    assertTrue(success);
  }

  /**
   * @dev This test reproduce the exact transaction made at block 6031723 BUT with the fixed version of the HolographDropERC721V2
   *      The HolographDropERC721V2 is at the address 0xf43953DDE38d03F3feA00DD76685857E57Af49C8, and its bytecode is replaced
   *      with the new version of the contract.
   *      => https://sepolia.etherscan.io/tx/0xb8dcf96afafb93d9148c1c469712ec37be17b8913a68f2c1a1d371a18d1194fb
   *      => https://dashboard.tenderly.co/tx/sepolia/0xb8dcf96afafb93d9148c1c469712ec37be17b8913a68f2c1a1d371a18d1194fb/debugger?trace=0.4.3.3.23
   * @dev To run this test you need to use a fork of sepolia at the block 6031724 and to use -vvvv flag to see
   *      the logs. You should see the transfer to 0xa57106357F9A487F6AfBaA3758e7fCcB787113c4 with a value of 609888904007765 wei
   *      succeeding this time.
   */
  function test_V2PurchaseFreeMoeWithNewVersion() public {
    /// @dev To run this test you need to use a fork of sepolia at the block 6031724
    ///      You can create a fork like that using tenderly and creating a new fork at block 6031723
    assertEq(block.number, 6031724);
    assertEq(block.chainid, 11155111);

    // Doing the exact same call as the target transaction
    address holographDropERC721V2Address = 0xf43953DDE38d03F3feA00DD76685857E57Af49C8;
    vm.etch(holographDropERC721V2Address, type(HolographDropERC721V2).runtimeCode);

    // Doing the exact same call as the previous test
    vm.prank(0xa57106357F9A487F6AfBaA3758e7fCcB787113c4);
    (bool success, bytes memory data) = address(0x731F5129F241edAc48fA088c5DE3b3149dF822FD).call{value: 609888904007765}(
      abi.encodeWithSelector(
        IHolographDropERC721V2.purchase.selector,
        1
      )
    );

    assertTrue(success);
  }
}
