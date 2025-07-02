// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CreateParams} from "./DopplerStructs.sol";

interface IAirlock {
    function create(
        CreateParams calldata params
    ) external returns (address asset, address pool, address governance, address timelock, address migrationPool);

    function collectIntegratorFees(address to, address token, uint256 amount) external;
}
