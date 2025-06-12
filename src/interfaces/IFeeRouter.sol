// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ──────────────────────────────────────────────────────────────────────────
//  FeeRouter interface for omnichain fee routing
// ──────────────────────────────────────────────────────────────────────────
interface IFeeRouter {
    function routeFeeETH() external payable;
    function receiveFee() external payable;
    function bridge(uint256 minGas, uint256 minHlg) external;
    function swapAndDistribute(uint256 minHlg) external;
}
