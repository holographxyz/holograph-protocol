// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../lib/doppler/src/interfaces/ILiquidityMigrator.sol";

contract MockLiquidityMigrator is ILiquidityMigrator {
    function initialize(
        address asset,
        address numeraire,
        bytes calldata data
    ) external returns (address migrationPool) {
        // Create mock migration pool address
        migrationPool = address(uint160(uint256(keccak256(abi.encode(asset, numeraire, "migration")))));
    }

    function migrate(
        uint160 sqrtPriceX96,
        address token0,
        address token1,
        address recipient
    ) external payable returns (uint256 liquidity) {
        // Mock migration - return dummy liquidity value
        liquidity = 1000e18;
    }
}
