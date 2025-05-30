// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ──────────────────────────────────────────────────────────────────────────
//  Minimal FeeRouter interface (native + ERC-20 routes)
// ──────────────────────────────────────────────────────────────────────────
interface IFeeRouter {
    function routeFeeETH() external payable;
    function routeFee(address asset, uint256 amount) external;
}
