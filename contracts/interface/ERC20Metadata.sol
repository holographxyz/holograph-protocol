// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.11;

interface ERC20Metadata {

    function decimals() external pure returns (uint8);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

}
