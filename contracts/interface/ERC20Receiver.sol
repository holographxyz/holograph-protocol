// SPDX-License-Identifier: UNLICENSED

<<<<<<< HEAD
pragma solidity 0.8.13;

interface ERC20Receiver {
  function onERC20Received(
    address account,
    address recipient,
    uint256 amount,
    bytes memory data
  ) external returns (bytes4);
=======
pragma solidity 0.8.12;

interface ERC20Receiver {

  function onERC20Received(address account, address recipient, uint256 amount, bytes memory data) external returns(bytes4);

>>>>>>> main
}
