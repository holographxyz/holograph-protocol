// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../../src/interfaces/IGovernanceFactory.sol";

contract MockGovernanceFactory is IGovernanceFactory {
    function create(address asset, bytes calldata data) external returns (address governance, address timelock) {
        // Create mock governance and timelock addresses
        governance = address(uint160(uint256(keccak256(abi.encode(asset, "governance", block.timestamp)))));
        timelock = address(uint160(uint256(keccak256(abi.encode(asset, "timelock", block.timestamp)))));
    }
}
