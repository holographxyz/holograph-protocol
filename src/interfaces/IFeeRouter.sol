// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ──────────────────────────────────────────────────────────────────────────
//  FeeRouter interface for omnichain fee routing + Doppler integration
// ──────────────────────────────────────────────────────────────────────────
interface IFeeRouter {
    // Core fee intake
    function receiveFee() external payable;
    function routeFeeETH() external payable;
    function routeFeeToken(address token, uint256 amt) external;

    // Doppler integrator pull (keeper-only)
    function pullAndSlice(address airlock, address token, uint128 amt) external;

    // Cross-chain bridging (keeper-only)
    function bridge(uint256 minGas, uint256 minHlg) external;
    function bridgeToken(address token, uint256 minGas, uint256 minHlg) external;

    // Legacy compatibility
    function swapAndDistribute(uint256 minHlg) external;

    // Admin functions
    function setTreasury(address newTreasury) external;
    function setTrustedRemote(uint32 eid, bytes32 remote) external;
    function pause() external;
    function unpause() external;
}
