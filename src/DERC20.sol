// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title DERC20 (stub)
 * @notice Minimal interface stub so block-explorer verification can compile Doppler's Airlock.
 *         Only the functions used by Airlock are declared. No implementation needed.
 *
 * NOTE: This file should not be imported by our core contracts; it exists solely for
 *       off-chain verification. The real implementation lives in `lib/doppler/src/DERC20.sol`.
 */
contract DERC20 {
    function lockPool(address) external {}
    function unlockPool() external {}
}
