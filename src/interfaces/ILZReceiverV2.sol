// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILZReceiverV2 {
    function lzReceive(uint32, bytes calldata, address, bytes calldata) external payable;
}
