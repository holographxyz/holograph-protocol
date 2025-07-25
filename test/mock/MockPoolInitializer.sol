// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../src/interfaces/IPoolInitializer.sol";

contract MockPoolInitializer is IPoolInitializer {
    function initialize(address asset, address numeraire, uint256 numTokensToSell, bytes32 salt, bytes calldata data)
        external
        returns (address pool)
    {
        // Create mock pool address
        pool = address(uint160(uint256(keccak256(abi.encode(asset, numeraire, salt, "pool")))));
    }

    function exitLiquidity(address pool)
        external
        returns (
            uint160 sqrtPriceX96,
            address token0,
            uint128 fees0,
            uint128 balance0,
            address token1,
            uint128 fees1,
            uint128 balance1
        )
    {
        // Return mock values
        sqrtPriceX96 = 79228162514264337593543950336; // sqrt(1) in Q96
        token0 = address(0);
        fees0 = 0;
        balance0 = 0;
        token1 = pool; // Use pool address as placeholder
        fees1 = 0;
        balance1 = 0;
    }
}
