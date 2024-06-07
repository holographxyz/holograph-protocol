// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IHolographDropERC721V2} from "src/drops/interface/IHolographDropERC721V2.sol";
import {HolographDropERC721V2} from "src/drops/token/HolographDropERC721V2.sol";

contract HolographDropERC721Test is Test {
  /// @notice Event emitted when the funds are withdrawn from the minting contract
  /// @param withdrawnBy address that issued the withdraw
  /// @param withdrawnTo address that the funds were withdrawn to
  /// @param amount amount that was withdrawn
  event FundsWithdrawn(address indexed withdrawnBy, address indexed withdrawnTo, uint256 amount);

  function setUp() public {
  }

  function test_V2PurchaseFreeMoeWithOldVersion() public {
    /// @dev To run this test you need to use a fork of sepolia at the block 6031724
    ///      You can create a fork like that using tenderly and creating a new fork at block 6031723
    assertEq(block.number, 6031724);
    assertEq(block.chainid, 11155111);

    vm.prank(0xa57106357F9A487F6AfBaA3758e7fCcB787113c4);
    (bool success, bytes memory data) = address(0x731F5129F241edAc48fA088c5DE3b3149dF822FD).call{value: 609888904007765}(
      abi.encodeWithSelector(
        IHolographDropERC721V2.purchase.selector,
        1
      )
    );

    assertTrue(success);
    console.logBytes(data);
  }

  function test_V2PurchaseFreeMoeWithNewVersion() public {
    /// @dev To run this test you need to use a fork of sepolia at the block 6031724
    ///      You can create a fork like that using tenderly and creating a new fork at block 6031723
    assertEq(block.number, 6031724);
    assertEq(block.chainid, 11155111);

    // replacing the contract with the new version
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
    console.logBytes(data);
  }
}
