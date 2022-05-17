// SPDX-License-Identifier: UNLICENSED

<<<<<<< HEAD
pragma solidity 0.8.13;

interface ERC20Safer {
  function safeTransfer(address recipient, uint256 amount) external returns (bool);

  function safeTransfer(
    address recipient,
    uint256 amount,
    bytes memory data
  ) external returns (bool);

  function safeTransferFrom(
    address account,
    address recipient,
    uint256 amount
  ) external returns (bool);

  function safeTransferFrom(
    address account,
    address recipient,
    uint256 amount,
    bytes memory data
  ) external returns (bool);
=======
pragma solidity 0.8.12;

interface ERC20Safer {

  function safeTransfer(address recipient, uint256 amount) external returns(bool);

  function safeTransfer(address recipient, uint256 amount, bytes memory data) external returns(bool);

  function safeTransferFrom(address account, address recipient, uint256 amount) external returns(bool);

  function safeTransferFrom(address account, address recipient, uint256 amount, bytes memory data) external returns(bool);

>>>>>>> main
}
